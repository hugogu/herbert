import SwiftUI

#if os(iOS)
    import UIKit
#else
    import AppKit
#endif

@MainActor
final class EditorController: ObservableObject {
    #if os(iOS)
        weak var textView: UITextView?
    #else
        weak var textView: NSTextView?
    #endif

    func insert(_ text: String) {
        guard let textView else { return }
        #if os(iOS)
            textView.becomeFirstResponder()
            textView.insertText(text)
        #else
            textView.window?.makeFirstResponder(textView)
            textView.insertText(text, replacementRange: textView.selectedRange())
        #endif
    }

    func dismiss() {
        #if os(iOS)
            textView?.resignFirstResponder()
        #else
            textView?.window?.makeFirstResponder(nil)
        #endif
    }
}

#if os(iOS)
    struct CodeEditor: UIViewRepresentable {
        @Binding var text: String
        let controller: EditorController

        func makeUIView(context: Context) -> UITextView {
            let view = UITextView()
            view.delegate = context.coordinator
            view.font = .monospacedSystemFont(ofSize: 20, weight: .medium)
            view.textColor = UIColor(Palette.ink)
            view.backgroundColor = .clear
            view.autocapitalizationType = .none
            view.autocorrectionType = .no
            view.spellCheckingType = .no
            view.smartQuotesType = .no
            view.smartDashesType = .no
            view.smartInsertDeleteType = .no
            view.keyboardType = .asciiCapable
            view.textContainerInset = UIEdgeInsets(top: 14, left: 8, bottom: 14, right: 8)
            view.accessibilityIdentifier = "code-editor"
            view.accessibilityLabel = L10n.text("H 代码")
            controller.textView = view
            return view
        }

        func updateUIView(_ view: UITextView, context: Context) {
            context.coordinator.parent = self
            if view.text != text { view.text = text }
        }

        func makeCoordinator() -> Coordinator { Coordinator(self) }

        final class Coordinator: NSObject, UITextViewDelegate {
            var parent: CodeEditor
            init(_ parent: CodeEditor) { self.parent = parent }
            func textViewDidChange(_ textView: UITextView) { parent.text = textView.text }
            func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String)
                -> Bool
            {
                (textView.text as NSString).replacingCharacters(in: range, with: text).utf8.count <= 16_384
            }
        }
    }
#else
    struct CodeEditor: NSViewRepresentable {
        @Binding var text: String
        let controller: EditorController

        func makeNSView(context: Context) -> NSScrollView {
            let scroll = NSTextView.scrollableTextView()
            guard let view = scroll.documentView as? NSTextView else { return scroll }
            view.delegate = context.coordinator
            view.font = .monospacedSystemFont(ofSize: 20, weight: .medium)
            view.textColor = NSColor(Palette.ink)
            view.backgroundColor = .clear
            view.drawsBackground = false
            view.isRichText = false
            view.isAutomaticQuoteSubstitutionEnabled = false
            view.isAutomaticDashSubstitutionEnabled = false
            view.isAutomaticTextReplacementEnabled = false
            view.isAutomaticSpellingCorrectionEnabled = false
            view.isContinuousSpellCheckingEnabled = false
            view.textContainerInset = NSSize(width: 8, height: 14)
            view.setAccessibilityIdentifier("code-editor")
            view.setAccessibilityLabel(L10n.text("H 代码"))
            scroll.drawsBackground = false
            scroll.hasVerticalScroller = true
            controller.textView = view
            return scroll
        }

        func updateNSView(_ scroll: NSScrollView, context: Context) {
            context.coordinator.parent = self
            if let view = scroll.documentView as? NSTextView, view.string != text { view.string = text }
        }

        func makeCoordinator() -> Coordinator { Coordinator(self) }

        final class Coordinator: NSObject, NSTextViewDelegate {
            var parent: CodeEditor
            init(_ parent: CodeEditor) { self.parent = parent }
            func textView(
                _ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?
            ) -> Bool {
                (textView.string as NSString).replacingCharacters(in: affectedCharRange, with: replacementString ?? "")
                    .utf8.count <= 16_384
            }
            func textDidChange(_ notification: Notification) {
                if let view = notification.object as? NSTextView { parent.text = view.string }
            }
        }
    }
#endif
