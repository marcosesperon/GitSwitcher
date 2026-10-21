import SwiftUI

/// Ventana de ajustes. Todo lo que se cambia aquí se guarda al momento.
struct SettingsView: View {
    @Bindable var store: AccountsStore

    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginItemError: String?

    var body: some View {
        Form {
            generalSection
            accountsSection
            gitAuthorSection
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        // Si el usuario quita la app de los ítems de inicio desde Ajustes del
        // Sistema, lo reflejamos al volver a abrir la ventana.
        .onAppear { launchAtLogin = LoginItem.isEnabled }
    }

    // MARK: - General

    private var generalSection: some View {
        Section("General") {
            Toggle("Open at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        try LoginItem.setEnabled(enabled)
                        loginItemError = nil
                    } catch {
                        loginItemError = error.localizedDescription
                        launchAtLogin = LoginItem.isEnabled
                    }
                }
            if let loginItemError {
                Text(loginItemError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            Toggle("Show only the icon in the menu bar", isOn: $store.iconOnly)
        }
    }

    // MARK: - Alias

    private var accountsSection: some View {
        Section {
            if store.visibleAccounts.isEmpty {
                Text("No GitHub accounts signed in to gh")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.visibleAccounts) { account in
                TextField(account.login, text: preferenceBinding(account, \.alias), prompt: Text(account.login))
            }
        } header: {
            Text("Menu bar name")
        } footer: {
            Text("A short name to show in the menu bar instead of the GitHub username.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Autor de git

    private var gitAuthorSection: some View {
        Section {
            Toggle("Also change the git author when switching", isOn: $store.changeGitAuthor)
            if store.changeGitAuthor {
                ForEach(store.visibleAccounts) { account in
                    gitIdentityRows(for: account)
                }
            }
        } header: {
            Text("Git author")
        } footer: {
            Text("Sets user.name and user.email in your global ~/.gitconfig. Leave it off if you configure the author per repository or with includeIf.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func gitIdentityRows(for account: GhAccount) -> some View {
        LabeledContent {
            if store.fetchingProfiles.contains(account.id) {
                ProgressView().controlSize(.small)
            } else {
                Button("Fill from GitHub") {
                    Task { await store.fillGitIdentityFromGitHub(for: account, overwrite: true) }
                }
            }
        } label: {
            Text(account.login).bold()
        }
        TextField("Name", text: preferenceBinding(account, \.gitName))
        TextField("Email", text: preferenceBinding(account, \.gitEmail))
    }

    // MARK: - Ayudas

    /// Enlaza un campo de texto con una preferencia de una cuenta concreta.
    private func preferenceBinding(
        _ account: GhAccount,
        _ keyPath: WritableKeyPath<AccountPreferences, String>
    ) -> Binding<String> {
        Binding(
            get: { store.preferences(for: account)[keyPath: keyPath] },
            set: { newValue in store.updatePreferences(for: account) { $0[keyPath: keyPath] = newValue } }
        )
    }
}
