import Foundation

/// Lo que el usuario puede ajustar de cada cuenta. Nada de esto es secreto:
/// los tokens siguen siendo cosa de gh y nunca pasan por aquí.
struct AccountPreferences: Codable, Hashable, Sendable {
    /// Nombre corto para la barra de menú («Trabajo», «Personal»…).
    var alias: String = ""
    /// Autor de git que se aplica al cambiar a esta cuenta (si está activado).
    var gitName: String = ""
    var gitEmail: String = ""
    /// Icono y color en la barra y el menú. `nil` = como siempre (icono genérico,
    /// sin color).
    var icon: AccountIcon?
    var color: AccountColor?

    init(alias: String = "", gitName: String = "", gitEmail: String = "", icon: AccountIcon? = nil, color: AccountColor? = nil) {
        self.alias = alias
        self.gitName = gitName
        self.gitEmail = gitEmail
        self.icon = icon
        self.color = color
    }

    // Lectura tolerante: las preferencias guardadas por versiones anteriores no
    // tienen icono ni color, y si algún día desaparece un icono de la lista, no
    // queremos perder por eso el alias ni el autor de git de la cuenta.
    private enum CodingKeys: String, CodingKey {
        case alias, gitName, gitEmail, icon, color
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        alias = try container.decodeIfPresent(String.self, forKey: .alias) ?? ""
        gitName = try container.decodeIfPresent(String.self, forKey: .gitName) ?? ""
        gitEmail = try container.decodeIfPresent(String.self, forKey: .gitEmail) ?? ""
        icon = (try? container.decodeIfPresent(AccountIcon.self, forKey: .icon)) ?? nil
        color = (try? container.decodeIfPresent(AccountColor.self, forKey: .color)) ?? nil
    }

    /// ¿Tiene algo personalizado en su aspecto?
    var hasCustomAppearance: Bool { icon != nil || color != nil }

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
