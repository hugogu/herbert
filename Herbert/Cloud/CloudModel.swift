#if APP_STORE && !LOCAL_LEARNING
    import AuthenticationServices
    import HerbertCloud
    import HerbertCore
    import Security
    import SwiftUI

    @MainActor
    final class CloudModel: NSObject, ObservableObject, ASAuthorizationControllerDelegate,
        ASAuthorizationControllerPresentationContextProviding
    {
        @Published private(set) var user: CloudUser?
        @Published private(set) var busy = false
        @Published var message: String?
        @Published var suggestedName: String?
        private let client: CloudClient?
        private var session: CloudSession?
        private var challenge: LoginChallenge?
        private var controller: ASAuthorizationController?
        private var pendingUpload: (problem: Problem, source: String)?
        private let keychainService: String
        private static var previewAccount: Bool {
            #if DEBUG
                ProcessInfo.processInfo.arguments.contains("--ui-testing")
                    && ProcessInfo.processInfo.arguments.contains("--ui-testing-cloud-account")
            #else
                false
            #endif
        }

        override init() {
            // UI fixtures have no network client or session and never access the real Keychain.
            let endpoint =
                Self.previewAccount || Self.offlinePreview
                ? "" : Bundle.main.object(forInfoDictionaryKey: "HerbertLeaderboardURL") as? String ?? ""
            client = URL(string: endpoint).flatMap { try? CloudClient(endpoint: $0) }
            keychainService = "info.hugogu.Herbert.Cloud." + endpoint
            super.init()
            if Self.previewAccount {
                user = try? JSONDecoder().decode(
                    CloudUser.self, from: Data(#"{"user_id":"ui-preview","display_name":"Learner preview"}"#.utf8))
                return
            }
            if Self.offlinePreview { return }
            do {
                var query = keychainQuery
                query[kSecReturnData as String] = true
                var item: CFTypeRef?
                let status = SecItemCopyMatching(query as CFDictionary, &item)
                if status == errSecSuccess, let data = item as? Data {
                    session = try JSONDecoder().decode(CloudSession.self, from: data)
                    user = session?.user
                } else if status != errSecItemNotFound {
                    throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
                }
            } catch { handle(error) }
        }
        var configured: Bool { client != nil || Self.previewAccount }
        private static var offlinePreview: Bool {
            #if DEBUG
                ProcessInfo.processInfo.arguments.contains("--ui-testing")
                    && ProcessInfo.processInfo.arguments.contains("--ui-testing-cloud-offline")
            #else
                false
            #endif
        }
        func problemLeaderboard(_ problem: Problem) async throws -> ProblemLeaderboard? {
            #if DEBUG
                if Self.previewAccount {
                    return try JSONDecoder().decode(
                        ProblemLeaderboard.self,
                        from: Data(
                            """
                            {"problem_id":\(problem.id),"puzzle_version":"\(CloudPuzzle.version(problem))","entries":[
                            {"rank":1,"user_id":"ui-preview","display_name":"Learner preview","points":80,"bytes":1,"accepted":1,"lit_targets":1,"target_count":1}]}
                            """.utf8))
                }
            #endif
            guard let client else { return nil }
            return try await client.problemLeaderboard(problem.id)
        }
        func totalLeaderboard() async throws -> Leaderboard? {
            #if DEBUG
                if Self.previewAccount {
                    return try JSONDecoder().decode(
                        Leaderboard.self,
                        from: Data(
                            #"{"puzzle_count":30,"entries":[{"rank":1,"user_id":"ui-preview","display_name":"Learner preview","points":80,"percentage":2.67,"solved":1}]}"#
                                .utf8))
                }
            #endif
            guard let client else { return nil }
            return try await client.leaderboard()
        }
        private func handle(_ error: Error) {
            if case CloudError.request(401, _) = error { try? persist(nil) }
            message = error.localizedDescription
        }
        private var keychainQuery: [String: Any] {
            [
                kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: keychainService,
                kSecAttrAccount as String: "session",
            ]
        }
        private func persist(_ next: CloudSession?) throws {
            if let next {
                let data = try JSONEncoder().encode(next)
                let result = SecItemUpdate(
                    keychainQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
                if result == errSecItemNotFound {
                    var query = keychainQuery
                    query[kSecValueData as String] = data
                    query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
                    let status = SecItemAdd(query as CFDictionary, nil)
                    guard status == errSecSuccess else {
                        throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
                    }
                } else if result != errSecSuccess {
                    throw NSError(domain: NSOSStatusErrorDomain, code: Int(result))
                }
            } else {
                let result = SecItemDelete(keychainQuery as CFDictionary)
                guard result == errSecSuccess || result == errSecItemNotFound else {
                    throw NSError(domain: NSOSStatusErrorDomain, code: Int(result))
                }
            }
            session = next
            user = next?.user
        }
        private func token() async throws -> String {
            guard let client, let current = session else { throw CloudError.request(401, L10n.text("请先登录。")) }
            if current.expiresAt > Date.now.timeIntervalSince1970 + 60 { return current.accessToken }
            do {
                var next = try await client.refresh(current.refreshToken)
                next.user = current.user
                try persist(next)
                return next.accessToken
            } catch {
                if case CloudError.request(401, _) = error { try persist(nil) }
                throw error
            }
        }
        func load() async {
            guard let client, !busy, session != nil else { return }
            busy = true
            defer { busy = false }
            do {
                let account = try await client.me(token: token())
                var next = session
                next?.user = account
                try persist(next)
            } catch { handle(error) }
        }
        func signIn() async {
            guard let client, !busy else { return }
            busy = true
            message = nil
            do {
                let challenge = try await client.challenge()
                self.challenge = challenge
                let request = ASAuthorizationAppleIDProvider().createRequest()
                request.nonce = challenge.nonce
                // Apple supplies a name only on first authorization; use it as an optional nickname suggestion.
                request.requestedScopes = [.fullName]
                let controller = ASAuthorizationController(authorizationRequests: [request])
                self.controller = controller
                controller.delegate = self
                controller.presentationContextProvider = self
                controller.performRequests()
            } catch {
                message = error.localizedDescription
                busy = false
                pendingUpload = nil
            }
        }
        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            #if os(macOS)
                NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? NSWindow()
            #else
                UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                    .flatMap(\.windows).first(where: \.isKeyWindow) ?? UIWindow()
            #endif
        }
        func authorizationController(
            controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization
        ) {
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let identity = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }),
                let code = credential.authorizationCode.flatMap({ String(data: $0, encoding: .utf8) }),
                let challenge, let client
            else {
                busy = false
                pendingUpload = nil
                self.controller = nil
                self.challenge = nil
                message = L10n.text("Apple 登录未完成。")
                return
            }
            Task {
                defer {
                    busy = false
                    self.controller = nil
                    self.challenge = nil
                    pendingUpload = nil
                }
                do {
                    try persist(
                        try await client.signIn(challenge: challenge, identityToken: identity, authorizationCode: code))
                    if let fullName = credential.fullName {
                        let name = PersonNameComponentsFormatter().string(from: fullName)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !name.isEmpty { suggestedName = name }
                    }
                    if let pendingUpload {
                        try await submit(pendingUpload.problem, source: pendingUpload.source)
                    }
                } catch { handle(error) }
            }
        }
        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            if (error as? ASAuthorizationError)?.code != .canceled { message = error.localizedDescription }
            busy = false
            self.controller = nil
            challenge = nil
            pendingUpload = nil
        }
        /// Retain the executed answer across Apple authorization, never a mutable editor binding.
        func uploadAnswer(_ problem: Problem, source: String) async {
            guard configured, !busy, problem.lesson != nil else { return }
            message = nil
            if user == nil {
                pendingUpload = (problem, source)
                await signIn()
                return
            }
            busy = true
            defer { busy = false }
            do { try await submit(problem, source: source) } catch { handle(error) }
        }
        private func submit(_ problem: Problem, source: String) async throws {
            guard let client else { return }
            let result = try await client.submit(problem: problem, source: source, requestID: UUID(), token: token())
            message = L10n.text("已上传并验证：%@ 分 · %@", result.points.formatted(), result.feedback)
        }
        func upload(_ records: [ProblemProgress], problems: [Problem]) async {
            guard let client, !busy else { return }
            busy = true
            defer { busy = false }
            do {
                let token = try await token()
                var accepted = 0
                for record in records {
                    guard let source = record.bestSolution,
                        let problem = problems.first(where: { $0.id == record.problemID && $0.lesson != nil })
                    else { continue }
                    let result = try await client.submit(
                        problem: problem, source: source, requestID: UUID(), token: token)
                    if result.accepted { accepted += 1 } else { message = "\(problem.number): \(result.feedback)" }
                }
                if message == nil { message = L10n.text("已验证并上传 %ld 份解答。", accepted) }
            } catch { handle(error) }
        }
        func updateDisplayName(_ name: String) async -> Bool {
            guard let client, !busy else { return false }
            busy = true
            message = nil
            defer { busy = false }
            do {
                let account = try await client.updateDisplayName(name, token: token())
                var next = session
                next?.user = account
                try persist(next)
                suggestedName = nil
                return true
            } catch {
                handle(error)
                return false
            }
        }
        func signOut() async {
            guard let client, !busy else { return }
            busy = true
            defer { busy = false }
            do {
                try await client.logout(token: token())
                try persist(nil)
                suggestedName = nil
            } catch { handle(error) }
        }
        func deleteAccount() async {
            guard let client, !busy else { return }
            busy = true
            defer { busy = false }
            do {
                try await client.deleteAccount(token: token())
                try persist(nil)
                suggestedName = nil
                message = L10n.text("云账号已删除，本地练习记录已保留。")
            } catch { handle(error) }
        }
    }
#endif
