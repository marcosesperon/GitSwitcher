import Foundation

enum GitConfigError: LocalizedError {
    case gitNotFound
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .gitNotFound:
            return String(localized: "git was not found on this Mac.")
        case .failed(let message):
            return String(localized: "Couldn't update git config: \(message)")
        }
    }
}

/// Cambia el autor global de git (`user.name` y `user.email` en `~/.gitconfig`).
/// Solo se usa si el usuario lo activa en ajustes.
enum GitConfigWriter {
    /// `/usr/bin/git` existe siempre en macOS (es un lanzador que usa el git de
    /// las Command Line Tools), así que es la opción más segura.
    static let gitExecutable = URL(fileURLWithPath: "/usr/bin/git")

    static func setGlobalIdentity(name: String, email: String) async throws {
        guard FileManager.default.isExecutableFile(atPath: gitExecutable.path) else {
            throw GitConfigError.gitNotFound
        }
        for (key, value) in [("user.name", name), ("user.email", email)] {
            let result = try await CommandRunner.run(gitExecutable, ["config", "--global", key, value])
            guard result.succeeded else {
                throw GitConfigError.failed(result.stderr.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }
}
