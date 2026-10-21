import Foundation

/// Guarda en `UserDefaults` los ajustes de la app y las preferencias de cada
/// cuenta. Aquí no hay nada secreto (ni tokens ni contraseñas), por eso basta
/// con UserDefaults.
struct PreferencesStorage {
    private let defaults: UserDefaults

    private enum Key {
        static let accountPreferences = "accountPreferences"
        static let iconOnly = "iconOnly"
        static let changeGitAuthor = "changeGitAuthor"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Mostrar solo el icono en la barra, sin el alias.
    var iconOnly: Bool {
        get { defaults.bool(forKey: Key.iconOnly) }
        nonmutating set { defaults.set(newValue, forKey: Key.iconOnly) }
    }

    /// Cambiar también `user.name` / `user.email` globales al cambiar de cuenta.
    var changeGitAuthor: Bool {
        get { defaults.bool(forKey: Key.changeGitAuthor) }
        nonmutating set { defaults.set(newValue, forKey: Key.changeGitAuthor) }
    }

    /// Preferencias por cuenta, indexadas por `GhAccount.id` ("host/login").
    /// Si lo guardado está corrupto empezamos de cero en vez de fallar: son
    /// datos fáciles de volver a poner.
    var accountPreferences: [String: AccountPreferences] {
        get {
            guard let data = defaults.data(forKey: Key.accountPreferences) else { return [:] }
            return (try? JSONDecoder().decode([String: AccountPreferences].self, from: data)) ?? [:]
        }
        nonmutating set {
            let data = try? JSONEncoder().encode(newValue)
            defaults.set(data, forKey: Key.accountPreferences)
        }
    }
}
