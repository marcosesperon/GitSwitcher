import Foundation

/// Lo que el usuario puede ajustar de cada cuenta. Nada de esto es secreto:
/// los tokens siguen siendo cosa de gh y nunca pasan por aquí.
struct AccountPreferences: Codable, Hashable, Sendable {
    /// Nombre corto para la barra de menú («Trabajo», «Personal»…).
    var alias: String = ""
    /// Autor de git que se aplica al cambiar a esta cuenta (si está activado).
    var gitName: String = ""
    var gitEmail: String = ""

    /// Lo que se enseña en la barra: el alias si hay, si no el login.
    func displayName(for account: GhAccount) -> String {
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? account.login : trimmed
    }

    /// Solo tiene sentido tocar el autor de git si están los dos datos.
    var hasGitIdentity: Bool {
        !gitName.trimmingCharacters(in: .whitespaces).isEmpty
            && !gitEmail.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

/// Datos públicos del perfil que devuelve `gh api user`. Los usamos para
/// proponer el nombre y el correo del autor de git.
struct GitHubProfile: Decodable, Sendable {
    let id: Int
    let login: String
    let name: String?
    let email: String?

    /// Nombre a proponer: el del perfil o, si no lo tiene, el login.
    var suggestedName: String {
        if let name, !name.trimmingCharacters(in: .whitespaces).isEmpty { return name }
        return login
    }

    /// Correo a proponer: el público si lo hay; si no, el anónimo que GitHub
    /// asigna a cada usuario y que también le atribuye los commits.
    var suggestedEmail: String {
        if let email, !email.isEmpty { return email }
        return "\(id)+\(login)@users.noreply.github.com"
    }
}
