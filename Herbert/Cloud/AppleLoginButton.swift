#if APP_STORE && !LOCAL_LEARNING
    import AuthenticationServices
    import SwiftUI

    /// Apple's native control lets us obtain a one-use server nonce before presenting authorization.
    @MainActor struct AppleLoginButton {
        let action: @MainActor () -> Void
        func makeCoordinator() -> Coordinator { Coordinator(action: action) }
        @MainActor final class Coordinator: NSObject {
            let action: @MainActor () -> Void
            init(action: @escaping @MainActor () -> Void) { self.action = action }
            @objc func signIn() { action() }
        }
    }
    #if os(macOS)
        extension AppleLoginButton: NSViewRepresentable {
            func makeNSView(context: Context) -> ASAuthorizationAppleIDButton {
                let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
                button.target = context.coordinator
                button.action = #selector(Coordinator.signIn)
                return button
            }
            func updateNSView(_ nsView: ASAuthorizationAppleIDButton, context: Context) {}
        }
    #else
        extension AppleLoginButton: UIViewRepresentable {
            func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
                let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
                button.addTarget(context.coordinator, action: #selector(Coordinator.signIn), for: .touchUpInside)
                return button
            }
            func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
        }
    #endif
#endif
