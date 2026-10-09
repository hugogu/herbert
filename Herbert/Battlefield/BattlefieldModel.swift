import HerbertBattlefield
import HerbertCore
import SwiftUI

struct BattlefieldModelOption: Identifiable {
    let provider: ProviderConfiguration
    let preset: ModelPreset
    var id: String { "\(provider.id.uuidString)/\(preset.model.id)" }
    var isDefault: Bool { preset.isDefault }
}

@MainActor
final class BattlefieldModel: ObservableObject {
    @Published private(set) var settings = BattlefieldSettings()
    @Published private(set) var history: [CompetitionSummary] = []
    @Published private(set) var liveResult: CompetitionResult?
    @Published private(set) var busy = false
    @Published private(set) var pendingRetries: [String: Int] = [:]
    @Published private(set) var initializing = true
    @Published private(set) var discovering: UUID?
    @Published var message: String?
    @Published var storageMessage: String?
    private let repository: (any BattlefieldRepository)?
    private let persistence: BattlefieldPersistence?
    private let keys: any APIKeyStore
    private let client: any AIClient
    private var settingsWritable = true
    private var engine: BattlefieldEngine?
    private var runTask: Task<Void, Never>?
    private var checkpointTask: Task<Void, Never>?
    private var checkpointedID: UUID?

    init() {
        let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        var selectedClient: any AIClient = OpenAICompatibleClient()
        var selectedKeys: any APIKeyStore = KeychainAPIKeyStore()
        #if DEBUG
            if testing {
                selectedKeys = TestAPIKeyStore()
                if ProcessInfo.processInfo.arguments.contains("--battlefield-fixture") {
                    selectedClient = BattlefieldFixtureClient(
                        diagnostics: ProcessInfo.processInfo.arguments.contains("--battlefield-diagnostics"),
                        streamErrors: ProcessInfo.processInfo.arguments.contains("--battlefield-stream-errors"),
                        specialErrors: ProcessInfo.processInfo.arguments.contains("--battlefield-special-errors"),
                        recovery: ProcessInfo.processInfo.arguments.contains("--battlefield-recovery"))
                }
            }
        #endif
        client = selectedClient
        keys = selectedKeys
        var local: LocalBattlefieldRepository?
        do {
            if testing {
                local = LocalBattlefieldRepository(
                    directory: FileManager.default.temporaryDirectory
                        .appendingPathComponent("Herbert-UITests/Battlefield", isDirectory: true))
                if ProcessInfo.processInfo.arguments.contains("--reset-progress"), let local,
                    FileManager.default.fileExists(atPath: local.directory.path)
                {
                    try FileManager.default.removeItem(at: local.directory)
                }
            } else {
                local = try .applicationDefault()
            }
            settings = try local!.loadSettings()
        } catch {
            settingsWritable = false
            storageMessage = L10n.text("AI 配置读取失败，已暂停保存以保护原文件。")
        }
        repository = local
        persistence = local.map { BattlefieldPersistence(repository: $0) }
        #if DEBUG
            if testing && ProcessInfo.processInfo.arguments.contains("--battlefield-fixture") {
                seedFixtures()
            }
        #endif
        Task { await restoreHistory() }
    }

    var modelOptions: [BattlefieldModelOption] {
        settings.providers.flatMap { provider in
            provider.models.map { model in
                var preset = provider.presets.first { $0.model.id == model.id } ?? ModelPreset(model: model)
                if !provider.presets.contains(where: { $0.model.id == model.id }) { preset.isDefault = false }
                return BattlefieldModelOption(provider: provider, preset: preset)
            }
        }
    }

    func hasKey(_ provider: UUID) -> Bool { (try? keys.hasKey(for: provider)) == true }

    private func saveSettings(_ new: BattlefieldSettings) throws {
        guard settingsWritable, let repository else { throw BattlefieldError.storageCorrupt }
        try repository.saveSettings(new)
        settings = new
    }

    func saveProvider(_ provider: ProviderConfiguration, apiKey: String) async -> Bool {
        do {
            _ = try provider.validated()
            let existing = settings.providers.first { $0.id == provider.id }
            let newKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if newKey.isEmpty && (existing?.baseURL != provider.baseURL || !hasKey(provider.id)) {
                throw BattlefieldError.missingKey
            }
            let oldKey = newKey.isEmpty ? nil : try keys.key(for: provider.id)
            var candidate = settings
            if let index = candidate.providers.firstIndex(where: { $0.id == provider.id }) {
                candidate.providers[index] = provider
            } else {
                candidate.providers.append(provider)
            }
            if !newKey.isEmpty { try keys.setKey(newKey, for: provider.id) }
            do { try saveSettings(candidate) } catch {
                if !newKey.isEmpty { try? keys.setKey(oldKey, for: provider.id) }
                throw error
            }
            await discover(provider.id)
            return true
        } catch {
            message = battlefieldError(error)
            return false
        }
    }

    func discover(_ id: UUID) async {
        guard discovering == nil, let provider = settings.providers.first(where: { $0.id == id }) else { return }
        discovering = id
        message = nil
        defer { discovering = nil }
        do {
            guard let key = try keys.key(for: id) else { throw BattlefieldError.missingKey }
            let models = try await client.models(provider: provider, apiKey: key)
            guard let index = settings.providers.firstIndex(where: { $0.id == id }) else { return }
            var candidate = settings
            candidate.providers[index].models = models
            candidate.providers[index].discoveredAt = .now
            for p in candidate.providers[index].presets.indices {
                if let model = models.first(where: { $0.id == candidate.providers[index].presets[p].model.id }) {
                    candidate.providers[index].presets[p].model = model
                }
            }
            try saveSettings(candidate)
        } catch { message = battlefieldError(error) }
    }

    func savePreset(_ preset: ModelPreset, provider id: UUID) {
        do {
            guard let p = settings.providers.firstIndex(where: { $0.id == id }) else { return }
            var candidate = settings
            if let index = candidate.providers[p].presets.firstIndex(where: { $0.model.id == preset.model.id }) {
                candidate.providers[p].presets[index] = preset
            } else {
                candidate.providers[p].presets.append(preset)
            }
            try saveSettings(candidate)
            message = nil
        } catch { message = battlefieldError(error) }
    }

    func removeProvider(_ id: UUID) {
        do {
            var candidate = settings
            candidate.providers.removeAll { $0.id == id }
            try saveSettings(candidate)
            try keys.setKey(nil, for: id)
        } catch { message = battlefieldError(error) }
    }

    func start(configuration: CompetitionConfiguration, selected: Set<String>, problems: [Problem]) {
        guard !busy, !initializing else { return }
        do {
            _ = try configuration.validated()
            let options = modelOptions.filter { selected.contains($0.id) }
            guard !options.isEmpty, options.count <= 32, !problems.isEmpty else {
                throw BattlefieldError.invalidConfiguration
            }
            let participants = try options.map { option in
                guard let key = try keys.key(for: option.provider.id), !key.isEmpty else {
                    throw BattlefieldError.missingKey
                }
                return CompetitionParticipant(
                    entrant: Entrant(provider: option.provider, preset: option.preset), apiKey: key)
            }
            var new = settings
            new.competition = configuration
            try saveSettings(new)
            let engine = BattlefieldEngine(client: client)
            self.engine = engine
            liveResult = nil
            message = nil
            busy = true
            runTask = Task { [weak self] in
                guard let self else { return }
                do {
                    let final = try await engine.run(
                        configuration: configuration, problems: problems, participants: participants
                    ) {
                        [weak self] result in await self?.receive(result, engine: engine)
                    }
                    await receive(final, engine: engine)
                } catch { message = battlefieldError(error) }
                busy = false
                runTask = nil
                await refreshHistory()
            }
        } catch { message = battlefieldError(error) }
    }

    func stop(reason: CompetitionStatus = .userStopped) async { await engine?.stop(reason: reason) }

    func retryKey(result: UUID, entrant: UUID, problem: Int) -> String { "\(result)/\(entrant)/\(problem)" }

    func canRetry(_ result: CompetitionResult, entrant: UUID, problem: Int) -> Bool {
        !initializing && (!busy || (liveResult?.id == result.id && liveResult?.status == .running))
            && pendingRetries[retryKey(result: result.id, entrant: entrant, problem: problem)] == nil
            && result.canRetry(entrantID: entrant, problemID: problem)
    }

    func retry(_ snapshot: CompetitionResult, entrantID: UUID, problemID: Int) {
        let result = liveResult?.id == snapshot.id ? liveResult! : snapshot
        guard canRetry(result, entrant: entrantID, problem: problemID),
            let entrant = result.entrants.first(where: { $0.id == entrantID })
        else { return }
        let key = retryKey(result: result.id, entrant: entrantID, problem: problemID)
        do {
            // Keys are current, but the endpoint and all model/puzzle settings remain the saved snapshot.
            guard let provider = settings.providers.first(where: { $0.id == entrant.entrant.provider.id }),
                provider.baseURL == entrant.entrant.provider.baseURL, provider.kind == entrant.entrant.kind
            else { throw BattlefieldError.invalidEndpoint }
            guard let apiKey = try keys.key(for: provider.id), !apiKey.isEmpty else {
                throw BattlefieldError.missingKey
            }
            let participant = CompetitionParticipant(entrant: entrant.entrant, apiKey: apiKey)
            pendingRetries[key] = entrant.answers.first { $0.id == problemID }?.attempts.count ?? 0
            message = nil
            if busy, let engine {
                Task {
                    do { try await engine.enqueueRetry(entrantID: entrantID, problemID: problemID) } catch {
                        pendingRetries[key] = nil
                        message = battlefieldError(error)
                    }
                }
            } else {
                let engine = BattlefieldEngine(client: client)
                self.engine = engine
                busy = true
                runTask = Task { [weak self] in
                    guard let self else { return }
                    do {
                        let final = try await engine.retry(result, participant: participant, problemID: problemID) {
                            [weak self] update in await self?.receive(update, engine: engine)
                        }
                        await receive(final, engine: engine)
                    } catch { message = battlefieldError(error) }
                    pendingRetries[key] = nil
                    busy = false
                    runTask = nil
                    await refreshHistory()
                }
            }
        } catch { message = battlefieldError(error) }
    }

    private func receive(_ result: CompetitionResult, engine: BattlefieldEngine) async {
        guard self.engine === engine else { return }
        liveResult = result
        for entrant in result.entrants {
            for answer in entrant.answers {
                let key = retryKey(result: result.id, entrant: entrant.id, problem: answer.id)
                if let count = pendingRetries[key], answer.attempts.count > count || result.status != .running {
                    pendingRetries[key] = nil
                }
            }
        }
        if result.status != .running || checkpointedID != result.id {
            checkpointTask?.cancel()
            checkpointTask = nil
            checkpointedID = result.id
            await saveCheckpoint(result)
        } else if checkpointTask == nil {
            checkpointTask = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
                guard let self else { return }
                checkpointTask = nil
                if let latest = liveResult { await saveCheckpoint(latest) }
            }
        }
    }

    private func saveCheckpoint(_ result: CompetitionResult) async {
        do {
            guard let persistence else { throw BattlefieldError.storageCorrupt }
            try await persistence.save(result)
            storageMessage = nil
        } catch {
            storageMessage = L10n.text("比赛结果保存失败。当前结果仍在内存中，请重试保存。")
            if result.status == .running { await engine?.stop(reason: .interrupted) }
        }
    }

    func retrySave() async {
        if let liveResult {
            await saveCheckpoint(liveResult)
            await refreshHistory()
        }
    }

    func loadResult(_ id: UUID) async -> CompetitionResult? {
        if let liveResult, liveResult.id == id { return liveResult }
        do { return try await persistence?.load(id) } catch {
            message = battlefieldError(error)
            return nil
        }
    }

    private func restoreHistory() async {
        defer { initializing = false }
        do {
            guard let persistence else { return }
            for summary in try await persistence.summaries() where summary.status == .running {
                var result = try await persistence.load(summary.id)
                let lastCheckpoint = result.updatedAt
                result.finish(.interrupted, at: lastCheckpoint)
                try await persistence.save(result)
            }
            await refreshHistory()
        } catch { storageMessage = L10n.text("比赛历史读取失败，原文件已保留。") }
    }

    private func refreshHistory() async {
        do { history = try await persistence?.summaries() ?? [] } catch {
            storageMessage = L10n.text("比赛历史读取失败，原文件已保留。")
        }
    }

    #if DEBUG
        private func seedFixtures() {
            if settings.providers.isEmpty {
                for index in 1...(ProcessInfo.processInfo.arguments.contains("--battlefield-three-models") ? 3 : 2) {
                    var provider = ProviderConfiguration(kind: .compatible, name: "Fixture Provider \(index)")
                    let model = AIModel(
                        id: "fixture-\(index)", name: "Fixture: Fixture Model \(index) (free)",
                        supportedParameters: ["enable_thinking", "reasoning_effort"],
                        maximumOutputTokens: ProcessInfo.processInfo.arguments.contains("--battlefield-diagnostics")
                            ? 4096 : nil)
                    provider.models = [model]
                    provider.presets = [ModelPreset(model: model)]
                    settings.providers.append(provider)
                }
                try? repository?.saveSettings(settings)
            }
            for provider in settings.providers { try? keys.setKey("fixture-not-a-real-key", for: provider.id) }
        }
    #endif
}

func battlefieldError(_ error: Error) -> String {
    if let http = error as? AIHTTPError { return L10n.text("AI 请求失败（HTTP %ld）。请检查密钥、模型权限和服务商额度。", http.status) }
    switch error as? BattlefieldError {
    case .invalidEndpoint: return L10n.text("请输入不含密钥或查询参数的 HTTPS API 基础地址。")
    case .missingKey: return L10n.text("请先保存 API Key；更换 API 地址后需重新输入密钥。")
    case .invalidParameters: return L10n.text("参数无效。请检查数值范围及高级 JSON；不要覆盖模型、消息或 Token 上限。")
    case .invalidConfiguration: return L10n.text("请选择 1–32 个模型和至少一道题，并检查比赛限制。")
    case .redirected: return L10n.text("API 地址发生重定向，请直接配置最终 HTTPS 地址。")
    case .responseTooLarge, .invalidResponse: return L10n.text("服务商响应无效或过大，请检查是否兼容 Chat Completions。")
    case .storageCorrupt: return L10n.text("本地 AI 数据无法安全读写，原文件已保留。")
    default: return L10n.text("AI 操作失败，请检查网络、钥匙串权限和服务商配置。")
    }
}

#if DEBUG
    actor BattlefieldFixtureClient: AIClient {
        let diagnostics: Bool
        let streamErrors: Bool
        let specialErrors: Bool
        let recovery: Bool
        private var calls: [String: Int] = [:]
        init(diagnostics: Bool = false, streamErrors: Bool = false, specialErrors: Bool = false, recovery: Bool = false)
        {
            self.diagnostics = diagnostics
            self.streamErrors = streamErrors
            self.specialErrors = specialErrors
            self.recovery = recovery
        }
        func models(provider: ProviderConfiguration, apiKey: String) async throws -> [AIModel] {
            try await Task.sleep(for: .milliseconds(100))
            return [
                AIModel(
                    id: "fixture-1", name: "Fixture: Fixture Model 1",
                    supportedParameters: ["enable_thinking", "reasoning_effort"]),
                AIModel(id: "fixture-2", name: "Fixture Model 2"),
            ]
        }
        func complete(
            _ request: AICompletionRequest,
            progress: @escaping @Sendable (AIProgress) async -> Void
        ) async throws -> AIReply {
            let problem = request.messages.first { $0.role == "user" }?.content ?? ""
            let firstAttempt = request.messages.count == 2 && !problem.contains("Judge feedback:")
            if recovery {
                let model = request.participant.entrant.preset.model.id
                calls[model, default: 0] += 1
                try await Task.sleep(for: .milliseconds(500))
                if model == "fixture-2", calls[model] == 1 {
                    throw AIHTTPError(
                        status: 402,
                        providerResponse:
                            #"{"error":{"code":402,"message":"This request requires more credits, or fewer max_tokens."}}"#
                    )
                }
                return AIReply(
                    text: "", usage: TokenUsage(input: 900, output: 12, estimated: false),
                    reasoning: AIReasoning(content: "I checked the target.\n\nFinal answer:\n\n```h\ns\n```"))
            }
            if specialErrors {
                let model = request.participant.entrant.preset.model.id
                let key = model + problem
                calls[key, default: 0] += 1
                try await Task.sleep(for: .milliseconds(400))
                if model == "fixture-2" {
                    throw AIHTTPError(status: 403, providerResponse: "Forbidden by provider")
                }
                if problem.contains("ID 10006") { throw URLError(.timedOut) }
                if calls[key] == 1 {
                    throw AIHTTPError(
                        status: 429,
                        providerResponse:
                            #"[{"error":{"code":429,"status":"RESOURCE_EXHAUSTED","details":[{"retryDelay":"12s"}],"message":"Quota exceeded. Please retry in 12s."}}]"#
                    )
                }
                return AIReply(text: "```h\ns\n```", usage: TokenUsage(input: 900, output: 12))
            }
            if streamErrors {
                let reasoning = AIReasoning(
                    content:
                        "### Path analysis\n\nI am still planning the route. Check **all targets** before returning the program."
                )
                for second in 1...12 {
                    try await Task.sleep(for: .seconds(1))
                    await progress(
                        AIProgress(text: "", usage: TokenUsage(input: 2442, output: second * 100), reasoning: reasoning)
                    )
                }
                if request.participant.entrant.preset.model.id == "fixture-2" {
                    throw URLError(.networkConnectionLost)
                }
                return AIReply(
                    text: "", usage: TokenUsage(input: 2442, output: 1200), finishReason: "error", reasoning: reasoning)
            }
            if diagnostics {
                if request.participant.entrant.preset.model.id == "fixture-2" {
                    try await Task.sleep(for: .seconds(12))
                    throw AIHTTPError(
                        status: 400,
                        providerResponse:
                            "{\"error\":{\"message\":\"assistant content is empty at index 2\",\"type\":\"invalid_request_error\"}}"
                    )
                }
                if firstAttempt {
                    try await Task.sleep(for: .seconds(8))
                    let reasoning = AIReasoning(
                        content:
                            "### Coordinate check\n\nInspecting **coordinates** before producing the H program.\n\n- Check the start and heading.\n- Trace each command."
                    )
                    let usage = TokenUsage(input: 1021, output: 4096, reasoning: 4096, estimated: false)
                    await progress(AIProgress(text: "", usage: usage, reasoning: reasoning))
                    try await Task.sleep(for: .seconds(2))
                    return AIReply(text: "", usage: usage, finishReason: "length", reasoning: reasoning)
                }
            }
            try await Task.sleep(for: .milliseconds(400))
            let examples = [(10006, "rsslsslss"), (10012, "a:ssssr\naaaa")]
            let program =
                request.participant.entrant.preset.model.id == "fixture-1"
                ? examples.first { problem.contains("ID \($0.0)") }?.1 ?? "s" : "s"
            let text = firstAttempt ? "z" : "```h\n\(program)\n```"
            let usage = TokenUsage(input: 900, output: 12, cached: 450, estimated: false)
            await progress(AIProgress(text: text, usage: usage, isFinal: true))
            return AIReply(text: text, usage: usage)
        }
    }
#endif
