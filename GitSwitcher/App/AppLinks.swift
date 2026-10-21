import Foundation

/// Direcciones y datos del proyecto que se usan en varios sitios de la app.
/// Así, si algo cambia (p. ej. el repositorio), se toca solo aquí.
enum AppLinks {
    /// «propietario/repositorio» en GitHub; lo usan la web y la API de releases.
    static let repositoryPath = "marcosesperon/GitSwitcher"
    static let repository = URL(string: "https://github.com/\(repositoryPath)")!
    /// Página de donación (la misma que en los demás proyectos del autor).
    static let donation = URL(string: "https://buymeacoffee.com/marcosesperon")!
    /// Nombre del autor tal cual: no se traduce.
    static let author = "Marcos Esperón"
}
