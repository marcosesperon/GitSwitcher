import AppKit
import SwiftUI

/// Pestaña Guía: qué hace falta para usar la app y en qué punto está este Mac.
/// Cada paso enseña si ya está hecho (comprobándolo de verdad) y, si tiene
/// comando, deja copiarlo o lanzarlo en Terminal.
struct GuideView: View {
    @Bindable var store: AccountsStore

    var body: some View {
        Form {
            installStep
            signInStep
            gitCredentialsStep
            commitAuthorStep
            Section {
                HStack {
                    Button("Check Again") {
                        Task { await store.checkSetup() }
                    }
                    .disabled(store.isCheckingSetup)
                    if store.isCheckingSetup {
                        ProgressView().controlSize(.small)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        // Comprobamos cada vez que se entra en la pestaña: el usuario puede
        // venir de la terminal tras seguir un paso.
        .task { await store.checkSetup() }
    }

    // MARK: - Pasos

    private var installStep: some View {
        let path = store.setup?.ghPath
        return GuideStep(
            number: 1,
            state: checkState(path != nil),
            title: "Install GitHub CLI",
            explanation: "GitSwitcher uses the GitHub CLI (gh) to know your accounts and to switch between them."
        ) {
            if let path {
                Text(installedDetail(path: path, version: store.setup?.ghVersion))
                    .detailStyle()
            } else {
                if store.setup?.brewPath != nil {
                    CommandRow(command: "brew install gh") { store.installGhWithHomebrew() }
                }
                Link("Other ways to install gh", destination: URL(string: "https://cli.github.com")!)
                    .font(.callout)
            }
        }
    }

    private var signInStep: some View {
        let accounts = store.visibleAccounts
        return GuideStep(
            number: 2,
            state: checkState(!accounts.isEmpty),
            title: "Sign in with each account",
            explanation: "Run this once for every GitHub account you want in the menu. gh opens the browser to sign in and keeps the credentials in the macOS keychain."
        ) {
            if !accounts.isEmpty {
                Text(String(localized: "Signed in: \(accounts.map(\.login).formatted(.list(type: .and)))"))
                    .detailStyle()
            }
            CommandRow(command: "gh auth login") { store.addAccount() }
                .disabled(store.setup?.ghPath == nil)
        }
    }

    private var gitCredentialsStep: some View {
        let done = store.setup?.gitUsesGh ?? false
        return GuideStep(
            number: 3,
            state: checkState(done),
            title: "Let git use the active account",
            explanation: "Makes gh provide the credentials for git push and pull on github.com, so they always use the account selected in the menu. Without it, git keeps using whatever credentials it had saved."
        ) {
            CommandRow(command: "gh auth setup-git") { store.runGhInTerminal(["auth", "setup-git"]) }
                .disabled(store.setup?.ghPath == nil)
        }
    }

    private var commitAuthorStep: some View {
        GuideStep(
            number: 4,
            state: .optional,
            title: "Commit author (optional)",
            explanation: "Switching accounts doesn't change who signs your commits. GitSwitcher can change the global git author for you, or you can set it per folder with includeIf in ~/.gitconfig."
        ) {
            Button("Open Accounts Settings") { store.settingsTab = .accounts }
        }
    }

    // MARK: - Ayudas

    /// Mientras no hay resultado aún, no pintamos ni ✓ ni ✗.
    private func checkState(_ done: Bool) -> GuideStepState {
        store.setup == nil ? .unknown : (done ? .done : .pending)
    }

    private func installedDetail(path: String, version: String?) -> String {
        if let version {
            return String(localized: "gh \(version) at \(path)")
        }
        return String(localized: "gh at \(path)")
    }
}

// MARK: - Piezas de la guía

/// Estado de un paso: sin comprobar aún, hecho, pendiente u opcional (no se
/// comprueba).
enum GuideStepState {
    case unknown, done, pending, optional
}

/// Un paso de la guía: número, estado, título, explicación y lo que haga falta
/// debajo (detalle, comando…).
struct GuideStep<Content: View>: View {
    let number: Int
    let state: GuideStepState
    let title: LocalizedStringKey
    let explanation: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        Section {
            HStack(alignment: .top, spacing: 10) {
                statusIcon
                    .font(.title3)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Text(verbatim: "\(number).")
                        Text(title)
                    }
                    .font(.headline)
                    Text(explanation)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    content
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch state {
        case .unknown:
            Image(systemName: "circle.dotted").foregroundStyle(.secondary)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                .accessibilityLabel(Text("Done"))
        case .pending:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.orange)
                .accessibilityLabel(Text("Pending"))
        case .optional:
            Image(systemName: "info.circle").foregroundStyle(.secondary)
        }
    }
}

/// Un comando con sus botones «Copiar» y «Abrir en Terminal».
struct CommandRow: View {
    let command: String
    let runInTerminal: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(command)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            Spacer(minLength: 0)
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
            }
            Button("Open in Terminal", action: runInTerminal)
        }
        .controlSize(.small)
    }
}

private extension View {
    /// Estilo de las líneas con el resultado de una comprobación.
    func detailStyle() -> some View {
        font(.callout.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
    }
}
