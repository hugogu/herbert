import XCTest

extension XCUIElement {
    /// Waits until layout stops moving the element, for example while the iPad keyboard reflows a lesson.
    @MainActor
    func waitForStableFrame() {
        var frame = CGRect.null
        for _ in 0..<20 where self.frame != frame {
            frame = self.frame
            usleep(250_000)
        }
    }
}
