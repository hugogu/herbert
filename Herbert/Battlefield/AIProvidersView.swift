import HerbertBattlefield
import SwiftUI

struct AIProvidersView: View {
    @EnvironmentObject private var battlefield: BattlefieldModel
    @State private var adding = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow(text: "AI BATTLEFIELD / CONNECTIONS")
                    Text("AI 配置").font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("连接你的模型，探索不同的解题思路。")
                        .foregroundStyle(Palette.muted)
                }
                BattlefieldNotice(text: L10n.text("配置保存在本机，API Key 保存在系统钥匙串。模型发现和比赛会连接你选择的服务商，可能产生 API 费用。"))
                Link(
                    L10n.text("隐私说明"),
                    destination: URL(string: "https://github.com/hugogu/herbert/blob/main/PRIVACY.md")!)
                BattlefieldMessages()
                HStack {
                    Text("服务商").font(.title2.bold())
                    Spacer()
                    Button {
                        adding = true
                    } label: {
                        Label("添加服务商", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent).accessibilityIdentifier("addAIProvider")
                }
                if battlefield.settings.providers.isEmpty {
                    ContentUnavailableView(
                        L10n.text("还没有服务商"), systemImage: "network",
                        description: Text("添加 OpenRouter、SiliconFlow 或兼容 OpenAI 的服务商，自动获取可用模型。")
                    )
                    .panel()
                }
                ForEach(battlefield.settings.providers) { provider in
                    NavigationLink {
                        AIProviderDetail(providerID: provider.id)
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "server.rack").font(.title2).foregroundStyle(Palette.mint)
                                .frame(width: 50, height: 50).background(
                                    Palette.mintLight, in: RoundedRectangle(cornerRadius: 14))
                            VStack(alignment: .leading, spacing: 6) {
                                Text(provider.name).font(.headline).foregroundStyle(Palette.ink)
                                Text(provider.baseURL).font(.caption).foregroundStyle(Palette.muted).lineLimit(1)
                                Text(
                                    L10n.text(
                                        "%ld 个模型 · %ld 个默认参赛", provider.models.count,
                                        provider.presets.filter(\.isDefault).count)
                                ).font(.caption).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Palette.muted)
                        }.panel()
                    }.buttonStyle(.plain).accessibilityIdentifier("provider-\(provider.name)")
                }
            }.padding(28).frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity)
        }.background(Palette.paper)
            .sheet(isPresented: $adding) { AIProviderEditor(provider: ProviderConfiguration(kind: .openRouter)) }
    }
}

private struct AIProviderDetail: View {
    @EnvironmentObject private var battlefield: BattlefieldModel
    @Environment(\.dismiss) private var dismiss
    let providerID: UUID
    @State private var search = ""
    @State private var editing = false
    @State private var removing = false
    @State private var selectedPreset: ModelPreset?
    private var provider: ProviderConfiguration? { battlefield.settings.providers.first { $0.id == providerID } }

    var body: some View {
        Group {
            if let provider {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(provider.name).font(.largeTitle.bold())
                                Text(provider.baseURL).font(.caption.monospaced()).textSelection(.enabled)
                                Label(
                                    battlefield.hasKey(provider.id)
                                        ? L10n.text("API Key 已配置") : L10n.text("需要 API Key"),
                                    systemImage: "key"
                                ).font(.caption).foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Button("编辑") { editing = true }
                        }
                        BattlefieldMessages()
                        HStack {
                            Text("可用模型").font(.title2.bold())
                            Spacer()
                            if battlefield.discovering == provider.id { ProgressView().controlSize(.small) }
                            Button {
                                Task { await battlefield.discover(provider.id) }
                            } label: {
                                Label("刷新模型", systemImage: "arrow.clockwise")
                            }.disabled(battlefield.discovering != nil).accessibilityIdentifier("refreshAIModels")
                        }
                        if let date = provider.discoveredAt {
                            Text(date, format: .dateTime.year().month().day().hour().minute()).font(.caption)
                                .foregroundStyle(Palette.muted)
                        }
                        Text("勾选默认参赛模型；点击滑杆设置每个模型的参数。")
                            .font(.callout).foregroundStyle(Palette.muted)
                        TextField("搜索模型", text: $search).textFieldStyle(.roundedBorder)
                        ForEach(
                            provider.models.filter {
                                search.isEmpty || $0.id.localizedCaseInsensitiveContains(search)
                                    || $0.name.localizedCaseInsensitiveContains(search)
                            }
                        ) { model in
                            modelRow(model, provider: provider)
                        }
                        if provider.models.isEmpty {
                            BattlefieldNotice(text: L10n.text("尚未获取到模型。请检查 API Key 和地址，然后刷新。"))
                        }
                        Button("移除服务商", role: .destructive) { removing = true }.padding(.top, 20)
                    }.padding(28).frame(maxWidth: 1000, alignment: .leading).frame(maxWidth: .infinity)
                }.background(Palette.paper)
                    .sheet(isPresented: $editing) { AIProviderEditor(provider: provider) }
                    .sheet(item: $selectedPreset) { preset in AIModelEditor(providerID: provider.id, preset: preset) }
                    .confirmationDialog("移除服务商及其 API Key？", isPresented: $removing, titleVisibility: .visible) {
                        Button("移除服务商", role: .destructive) {
                            battlefield.removeProvider(provider.id)
                            dismiss()
                        }
                    } message: {
                        Text("已有比赛历史会保留。")
                    }
            }
        }.navigationTitle(provider?.name ?? "")
    }

    private func modelRow(_ model: AIModel, provider: ProviderConfiguration) -> some View {
        let saved = provider.presets.first { $0.model.id == model.id }
        return HStack(spacing: 16) {
            Toggle(
                isOn: Binding(
                    get: { saved?.isDefault == true },
                    set: { value in
                        var preset = saved ?? ModelPreset(model: model)
                        preset.isDefault = value
                        battlefield.savePreset(preset, provider: provider.id)
                    })
            ) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.displayName).font(.headline)
                    if model.name != model.id {
                        Text(model.id).font(.caption.monospaced()).foregroundStyle(Palette.muted)
                    }
                    if let context = model.contextLength {
                        Text(L10n.text("上下文 %ld tokens", context)).font(.caption).foregroundStyle(
                            Palette.muted)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.toggleStyle(.checkboxCompatible).accessibilityIdentifier("defaultModel-\(model.id)")
            Button {
                selectedPreset = saved ?? ModelPreset(model: model)
            } label: {
                Image(systemName: "slider.horizontal.3")
            }
            .accessibilityLabel(L10n.text("模型参数")).accessibilityIdentifier("parameters-\(model.id)")
        }.panel(padding: 16)
    }
}

private struct AIProviderEditor: View {
    @EnvironmentObject private var battlefield: BattlefieldModel
    @Environment(\.dismiss) private var dismiss
    @State var provider: ProviderConfiguration
    @State private var apiKey = ""
    @State private var saving = false

    var body: some View {
        BattlefieldSheet(title: L10n.text("服务商设置")) {
            Form {
                Section {
                    Picker("服务类型", selection: $provider.kind) {
                        ForEach(ProviderKind.allCases, id: \.self) { kind in Text(kind.title).tag(kind) }
                    }.onChange(of: provider.kind) { old, new in
                        if provider.baseURL == old.defaultURL { provider.baseURL = new.defaultURL }
                        if provider.name == old.title { provider.name = new.title }
                    }
                    TextField("名称", text: $provider.name).accessibilityIdentifier("providerName")
                    TextField("API 基础地址", text: $provider.baseURL)
                        .autocorrectionDisabled()
                    SecureField(
                        battlefield.hasKey(provider.id) ? L10n.text("留空保留已有 API Key") : "API Key", text: $apiKey
                    )
                    .autocorrectionDisabled().accessibilityIdentifier("providerAPIKey")
                    Picker("输出上限参数", selection: $provider.outputTokenParameter) {
                        ForEach(OutputTokenParameter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                } footer: {
                    Text("填写 HTTPS 基础地址，例如 https://api.siliconflow.cn/v1。保存后会请求 /models。更改地址时需要重新填写 API Key。")
                }
                Section {
                    BattlefieldMessages()
                    Button {
                        saving = true
                        Task {
                            if await battlefield.saveProvider(provider, apiKey: apiKey) { dismiss() }
                            saving = false
                        }
                    } label: {
                        HStack {
                            if saving { ProgressView().controlSize(.small) }
                            Text("保存并检测模型")
                        }
                    }.disabled(saving).accessibilityIdentifier("saveAIProvider")
                }
            }.formStyle(.grouped)
        }.interactiveDismissDisabled(saving)
    }
}

struct AIModelEditor: View {
    @EnvironmentObject private var battlefield: BattlefieldModel
    @Environment(\.dismiss) private var dismiss
    let providerID: UUID
    @State var preset: ModelPreset
    @State private var temperature = ""
    @State private var topP = ""
    @State private var invalid = false

    var body: some View {
        BattlefieldSheet(title: L10n.text("模型参数")) {
            Form {
                Section {
                    Text(preset.model.displayName).font(.headline)
                    Toggle("默认参与比赛", isOn: $preset.isDefault)
                    if let maximum = preset.model.maximumOutputTokens {
                        Text(L10n.text("服务商声明的模型输出上限：%ld tokens", maximum)).font(.caption)
                    }
                    TextField("Temperature（留空使用服务商默认值）", text: $temperature)
                    TextField("Top P（留空使用服务商默认值）", text: $topP)
                } footer: {
                    Text("模型输出额度由全局比赛设置决定。部分模型不支持采样参数，留空可提高兼容性。")
                }
                Section("高级参数 JSON") {
                    Toggle("自动启用最高推理强度", isOn: $preset.parameters.automaticReasoning)
                        .accessibilityIdentifier("automaticReasoning")
                    Text("按服务商及模型能力默认启用推理并选用最高支持强度。下方 JSON 可覆盖默认推理配置。")
                        .font(.caption).foregroundStyle(Palette.muted)
                    if let provider = battlefield.settings.providers.first(where: { $0.id == providerID }),
                        let data = try? JSONSerialization.data(
                            withJSONObject: ReasoningDefaults.parameters(
                                for: Entrant(provider: provider, preset: preset)),
                            options: [.prettyPrinted, .sortedKeys]),
                        let json = String(data: data, encoding: .utf8)
                    {
                        Text(json).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                            .accessibilityIdentifier("defaultReasoningJSON")
                    }
                    TextEditor(text: $preset.parameters.extraJSON).font(.system(.body, design: .monospaced)).frame(
                        minHeight: 110)
                    Text(
                        "允许 seed、top_k、min_p、frequency_penalty、presence_penalty、reasoning_effort、reasoning、enable_thinking 和 thinking_budget。"
                    )
                    .font(.caption).foregroundStyle(Palette.muted)
                }
                if invalid { Text("参数无效，请检查数值范围和 JSON。 ").foregroundStyle(Palette.danger) }
                Button("保存参数") { save() }.accessibilityIdentifier("saveModelParameters")
            }.formStyle(.grouped)
        }.onAppear {
            temperature = preset.parameters.temperature.map(String.init(describing:)) ?? ""
            topP = preset.parameters.topP.map(String.init(describing:)) ?? ""
        }
    }

    private func save() {
        guard temperature.isEmpty || Double(temperature) != nil, topP.isEmpty || Double(topP) != nil else {
            invalid = true
            return
        }
        preset.parameters.temperature = Double(temperature)
        preset.parameters.topP = Double(topP)
        do {
            _ = try preset.parameters.validated()
            battlefield.savePreset(preset, provider: providerID)
            if battlefield.message == nil { dismiss() }
        } catch { invalid = true }
    }
}

private struct CheckboxCompatibleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        #if os(macOS)
            Toggle(configuration).toggleStyle(.checkbox)
        #else
            Toggle(configuration).toggleStyle(.switch)
        #endif
    }
}

extension ToggleStyle where Self == CheckboxCompatibleStyle {
    fileprivate static var checkboxCompatible: CheckboxCompatibleStyle { CheckboxCompatibleStyle() }
}
