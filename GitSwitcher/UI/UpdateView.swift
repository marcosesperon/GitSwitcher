import AppKit
import SwiftUI

/// Ventana que avisa de una versión nueva: qué cambia y cómo actualizar.
struct UpdateView: View {
    @Bindable var store: UpdateStore
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if let release = store.availableRelease {
                notes(for: release)
                if let progress = store.installProgress {
                    ProgressView(value: progress) {
                        Text(progress < 1 ? "Downloading…" : "Installing…")
                            .font(.callout)
                    }
                }
                if let error = store.installError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if store.installMethod == .homebrew {
                    Text("GitSwitcher was installed with Homebrew, so Homebrew updates it. Open GitSwitcher again when it finishes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                buttons(for: release)
            } else {
                // Si alguien deja la ventana abierta y la versión desaparece
                // (p. ej. ya se actualizó por otro lado).
                Text("You're up to date.")
                HStack { Spacer(); Button("Close", action: close).keyboardShortcut(.defaultAction) }
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text("A new version of GitSwitcher is available")
                    .font(.headline)
                if let release = store.availableRelease {
                    Text("Version \(release.version.description) is ready. You have \(store.currentVersion.description).")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func notes(for release: ReleaseInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What's new").font(.subheadline.bold())
            ScrollView {
                Text(formattedNotes(release.notes))
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(10)
            }
            .frame(height: 150)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private func buttons(for release: ReleaseInfo) -> some View {
        let busy = store.installProgress != nil
        return HStack {
            Button("View on GitHub") { NSWorkspace.shared.open(release.pageURL) }
            Spacer()
            Button("Not Now", action: close)
                .keyboardShortcut(.cancelAction)
                .disabled(busy)
            if store.installMethod == .homebrew {
                Button("Update with Homebrew") {
                    store.upgradeWithHomebrew()
                    close()
                }
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Install and Relaunch") {
                    Task { await store.installAndRelaunch() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(busy || release.asset == nil)
            }
        }
    }

    /// Las notas de GitHub vienen en Markdown; mostramos negritas, enlaces y
    /// demás. Si no se puede interpretar, se enseña tal cual.
    private func formattedNotes(_ markdown: String) -> AttributedString {
        guard !markdown.isEmpty else {
            return AttributedString(String(localized: "No release notes."))
        }
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: markdown, options: options)) ?? AttributedString(markdown)
    }
}

/// Ventana propia para el aviso de actualización (igual que la de ajustes).
@MainActor
final class UpdateWindowController {
    private let store: UpdateStore
    private var window: NSWindow?

    init(store: UpdateStore) {
        self.store = store
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: UpdateView(store: store) { [weak self] in self?.window?.close() })
            hosting.sizingOptions = [.preferredContentSize]
            let window = NSWindow(contentViewController: hosting)
            window.title = String(localized: "Software Update")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        store.clearInstallError()
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
