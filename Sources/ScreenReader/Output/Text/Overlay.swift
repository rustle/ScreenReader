//
//  Overlay.swift
//

import Cocoa

@MainActor
final class Overlay {
    private var window: NSWindow?
    private var textView: NSTextView?

    func show(_ text: String) {
        setupWindowIfNeeded()
        textView?.string = text
        window?.orderFront(nil)
    }

    func clear() {
        textView?.string = ""
    }

    private func setupWindowIfNeeded() {
        guard window == nil else { return }

        let window = NSWindow(
            contentRect: defaultFrame(),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        window.level = NSWindow.Level(Int(kCGAssistiveTechHighWindowLevel))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false

        guard let contentView = window.contentView else { return }

        let textView = NSTextView(frame: contentView.bounds)
        textView.autoresizingMask = [.width, .height]
        textView.isRichText = false
        textView.isEditable = false
        textView.isSelectable = false
        textView.font = NSFont.monospacedSystemFont(
            ofSize: 20,
            weight: .black
        )

        contentView.addSubview(textView)

        self.window = window
        self.textView = textView
    }

    private func defaultFrame() -> NSRect {
        let visibleFrame = NSScreen.main?.visibleFrame
            ?? NSScreen.screens.first?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width: CGFloat = floor(visibleFrame.size.width * 2/3)
        let height: CGFloat = 80
        let x = visibleFrame.minX + (visibleFrame.width - width) / 2
        let y = visibleFrame.minY + 40
        return NSRect(x: x, y: y, width: width, height: height)
    }
}
