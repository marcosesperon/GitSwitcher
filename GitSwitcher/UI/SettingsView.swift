import SwiftUI

/// Ventana de ajustes, en pestañas. Todo lo que se cambia aquí se guarda al momento.
struct SettingsView: View {
    @Bindable var store: AccountsStore
    @Bindable var updates: UpdateStore

    var body: some View {
        TabView(selection: $store.settingsTab) {
            GeneralSettingsView(store: store, updates: updates)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            AccountsSettingsView(store: store)
                .tabItem { Label("Accounts", systemImage: "person.2") }
                .tag(SettingsTab.accounts)
            GuideView(store: store)
                .tabItem { Label("Guide", systemImage: "checklist") }
                .tag(SettingsTab.guide)
        }
        .frame(width: 520)
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @Bindable var store: AccountsStore
    @Bindable var updates: UpdateStore

    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginItemError: String?

    var body: some View {
        Form {
            Section {
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
            Section {
                Toggle("Check for updates automatically", isOn: $updates.checkAutomatically)
                LabeledContent("Version", value: updates.currentVersion.description)
            } footer: {
                Text("Once a day, GitSwitcher asks GitHub for the latest version. No personal data is sent.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
        // Si el usuario quita la app de los ítems de inicio desde Ajustes del
        // Sistema, lo reflejamos al volver a esta pestaña.
        .onAppear { launchAtLogin = LoginItem.isEnabled }
    }
}

// MARK: - Cuentas

struct AccountsSettingsView: View {
    @Bindable var store: AccountsStore

    var body: some View {
        Form {
            aliasSection
            gitAuthorSection
        }
        .formStyle(.grouped)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var aliasSection: some View {
        Section {
            if store.visibleAccounts.isEmpty {
                Text("No GitHub accounts signed in to gh")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.visibleAccounts) { account in
                TextField(account.login, text: preferenceBinding(account, \.alias), prompt: Text(account.login))
            }
            addAccountRow
        } header: {
            Text("Menu bar name")
        } footer: {
            Text("A short name to show in the menu bar instead of the GitHub username.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Botón para iniciar sesión con otra cuenta. Abre Terminal con
    /// `gh auth login`; cuando gh termina, el vigilante de su configuración
    /// refresca la lista y la cuenta nueva aparece aquí sola.
    private var addAccountRow: some View {
        HStack {
            Button("Add Account…") { store.addAccount() }
                .disabled(store.status == .ghMissing)
            Text("The new account will show up here when you finish.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

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
