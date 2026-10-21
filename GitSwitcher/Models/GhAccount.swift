import Foundation

/// Una cuenta en la que `gh` tiene sesión iniciada.
///
/// Todo lo que hay aquí sale de `gh auth status --json hosts`; la app no se
/// inventa ni guarda cuentas por su cuenta. Guardamos el `host` aunque de momento
/// solo pintemos las de github.com, para poder añadir GitHub Enterprise sin
/// tocar el modelo.
struct GhAccount: Identifiable, Hashable, Sendable {
    let host: String
    let login: String
    let isActive: Bool
    /// `false` cuando gh dice que el token ya no vale (caducado, revocado…).
    let isValid: Bool

    /// Clave estable para guardar preferencias de la cuenta (alias, autor git).
    var id: String { "\(host)/\(login)" }
}

/// El host que mostramos en la interfaz. Si algún día se soporta Enterprise,
/// esto pasará a ser una lista configurable.
let defaultGitHubHost = "github.com"

// MARK: - Lectura del JSON de `gh auth status --json hosts`

/// Forma del JSON que devuelve gh. Solo declaramos los campos que usamos, así
/// que si gh añade campos nuevos no se rompe nada.
private struct AuthStatusPayload: Decodable {
    struct Entry: Decodable {
        let host: String
        let login: String
        let active: Bool
        let state: String
    }

    let hosts: [String: [Entry]]
}

enum AuthStatusParser {
    /// Convierte la salida JSON de gh en cuentas, ordenadas por host y login para
    /// que el menú no baile de un refresco a otro.
    static func parse(_ data: Data) throws -> [GhAccount] {
        let payload = try JSONDecoder().decode(AuthStatusPayload.self, from: data)
        return payload.hosts.values
            .flatMap { $0 }
            .map { entry in
                GhAccount(
                    host: entry.host,
                    login: entry.login,
                    isActive: entry.active,
                    isValid: entry.state == "success"
                )
            }
            .sorted { ($0.host, $0.login.lowercased()) < ($1.host, $1.login.lowercased()) }
    }
}
