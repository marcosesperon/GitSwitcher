import Foundation

/// Cómo se instaló la app, que decide cómo se actualiza.
enum InstallMethod: Equatable, Sendable {
    /// Con `brew install --cask`: se actualiza con `brew upgrade`, para que
    /// Homebrew sepa siempre qué versión hay.
    case homebrew
    /// A mano (zip de GitHub): se actualiza ella sola.
    case manual

    /// Dónde guarda Homebrew su registro del cask (Apple Silicon e Intel).
    static let caskroomPaths = [
        "/opt/homebrew/Caskroom/gitswitcher",
        "/usr/local/Caskroom/gitswitcher",
    ]

    /// Es de Homebrew si existe su registro del cask y la app está donde Homebrew
    /// la pone (`/Applications`). Si alguien tiene el cask pero ejecuta otra
    /// copia (p. ej. una compilada), esa copia se trata como manual.
    static func detect(
        appURL: URL = Bundle.main.bundleURL,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> InstallMethod {
        let inApplications = appURL.deletingLastPathComponent().standardizedFileURL.path == "/Applications"
        let hasCask = caskroomPaths.contains(where: fileExists)
        return inApplications && hasCask ? .homebrew : .manual
    }
}
