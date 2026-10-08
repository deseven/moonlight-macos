//
//  KeyboardShortcutsView.swift
//  Moonlight for macOS
//
//  Shows the stream-specific keyboard shortcuts in a modal sheet.
//
//  When adding or changing a stream hotkey (see `onKeyboardEquivalent:` and
//  `flagsChanged:` in StreamViewController.m, and the View/Window menus in
//  Main.storyboard), keep `StreamShortcut.all` below in sync.
//

import Cocoa
import SwiftUI

struct StreamShortcut: Identifiable {
    let keys: [String]
    let title: String

    var id: String { keys.joined() }

    static let all: [StreamShortcut] = [
        StreamShortcut(keys: ["⌃", "⌥"], title: "Release the mouse cursor (press Control and Option together)"),
        StreamShortcut(keys: ["⌃", "⇧", "E"], title: "Toggle the stream statistics overlay"),
        StreamShortcut(keys: ["⌃", "⌥", "W"], title: "Disconnect from the stream, leaving the app running"),
        StreamShortcut(keys: ["⌃", "⇧", "W"], title: "Disconnect from the stream and quit the app"),
        StreamShortcut(keys: ["⌘", "W"], title: "Ask whether to disconnect or to disconnect and quit the app"),
        StreamShortcut(keys: ["⌘", "1"], title: "Resize the window to the actual stream size"),
    ]
}

private struct KeyCap: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .frame(minWidth: 18)
            .padding(.vertical, 3)
            .padding(.horizontal, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.secondary.opacity(0.5), lineWidth: 1)
            )
    }
}

struct KeyboardShortcutsView: View {
    var onClose: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Stream Keyboard Shortcuts")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(StreamShortcut.all) { shortcut in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        HStack(spacing: 4) {
                            ForEach(Array(shortcut.keys.enumerated()), id: \.offset) { _, key in
                                KeyCap(label: key)
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(width: 100)

                        Text(shortcut.title)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }

            Text("While streaming, all other keys are sent to the host.")
                .font(.footnote)
                .foregroundColor(.secondary)

            HStack {
                Spacer()
                Button("Done", action: onClose)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}

/// A window that can be dismissed with Escape, whether presented as a sheet or run modally.
private final class KeyboardShortcutsWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) {
        dismiss()
    }

    func dismiss() {
        if let parent = sheetParent {
            parent.endSheet(self)
        } else {
            NSApp.stopModal()
            orderOut(nil)
        }
    }
}

@objc class KeyboardShortcutsPresenter: NSObject {
    private static var window: KeyboardShortcutsWindow?

    /// Shows the shortcuts as a sheet on the key window, or as an app-modal window if there is no suitable parent.
    @objc class func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let window = KeyboardShortcutsWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
        let hostingController = NSHostingController(rootView: KeyboardShortcutsView(onClose: { [weak window] in
            window?.dismiss()
        }))
        window.contentViewController = hostingController
        hostingController.view.layoutSubtreeIfNeeded()
        window.setContentSize(hostingController.view.fittingSize)
        self.window = window

        if let parent = NSApp.keyWindow ?? NSApp.mainWindow, parent.attachedSheet == nil, parent.sheetParent == nil {
            parent.beginSheet(window) { _ in
                self.window = nil
            }
        } else {
            window.center()
            NSApp.runModal(for: window)
            self.window = nil
        }
    }
}
