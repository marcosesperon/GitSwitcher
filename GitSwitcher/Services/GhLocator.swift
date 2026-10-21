import Foundation

/// Dónde está gh y con qué entorno hay que lanzarlo.
struct GhEnvironment: Sendable, Equatable {
    /// Ruta al ejecutable de gh, o `nil` si no lo encontramos.
    let executable: URL?
    /// Variables que hay que pasarle a gh para que vea la misma configuración
    /// que en la terminal (p. ej. si el usuario cambió `GH_CONFIG_DIR`).
    let variables: [String: String]
    /// Carpeta de configuración de gh, donde vive `hosts.yml`.
    let configDirectory: URL
}

/// Busca gh y su carpeta de configuración.
///
/// El lío viene de que una app abierta desde el Finder no hereda el `PATH` ni las
/// variables que el usuario define en su `.zshrc`. Así que primero miramos en los
/// sitios habituales y, para lo demás, le preguntamos una vez al shell del usuario.
enum GhLocator {
    /// Sitios donde suelen instalar gh Homebrew, MacPorts, Nix y compañía.
    static let commonLocations = [
        "/opt/homebrew/bin/gh",
        "/usr/local/bin/gh",
        "/opt/local/bin/gh",
        "~/.nix-profile/bin/gh",
        "/run/current-system/sw/bin/gh",
        "~/.local/bin/gh",
        "~/bin/gh",
    ]

    static func locate() async -> GhEnvironment {
        let shell = await askLoginShell()
        let fileManager = FileManager.default

        // 1) Lo que diga el shell manda: es exactamente el gh que usa el usuario.
        // 2) Si el shell no ayuda (tarda, falla…), probamos los sitios habituales.
        let candidates = [shell.ghPath].compactMap { $0 } + commonLocations
        let executable = candidates
            .map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
            .first { fileManager.isExecutableFile(atPath: $0.path) }

        // Solo reenviamos a gh las variables que afectan a dónde guarda su config.
        var variables: [String: String] = [:]
        if let dir = shell.ghConfigDir { variables["GH_CONFIG_DIR"] = dir }
        if let xdg = shell.xdgConfigHome { variables["XDG_CONFIG_HOME"] = xdg }

        return GhEnvironment(
            executable: executable,
            variables: variables,
            configDirectory: configDirectory(ghConfigDir: shell.ghConfigDir, xdgConfigHome: shell.xdgConfigHome)
        )
    }

    /// Replica la regla de gh para decidir su carpeta de configuración:
    /// `GH_CONFIG_DIR` > `XDG_CONFIG_HOME/gh` > `~/.config/gh`.
    static func configDirectory(ghConfigDir: String?, xdgConfigHome: String?) -> URL {
        if let dir = ghConfigDir, !dir.isEmpty {
            return URL(fileURLWithPath: (dir as NSString).expandingTildeInPath, isDirectory: true)
        }
        if let xdg = xdgConfigHome, !xdg.isEmpty {
            return URL(fileURLWithPath: (xdg as NSString).expandingTildeInPath, isDirectory: true)
                .appendingPathComponent("gh", isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/gh", isDirectory: true)
    }

    // MARK: - Pregunta al shell

    struct ShellAnswer: Equatable {
        var ghPath: String?
        var ghConfigDir: String?
        var xdgConfigHome: String?
    }

    /// Separador para trocear la respuesta del shell. Los `.zshrc` a veces
    /// imprimen cosas (saludos, avisos…), así que solo nos fiamos de lo que va
    /// entre separadores.
    static let marker = "__GITSWITCHER__"

    /// Abre el shell del usuario como si fuera una terminal nueva (login +
    /// interactivo, para que lea `.zprofile` y `.zshrc`) y le pide tres datos.
    private static func askLoginShell() async -> ShellAnswer {
        let shellPath = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let script = """
        printf '\(marker)\\n'; command -v gh; \
        printf '\(marker)\\n%s\\n' "$GH_CONFIG_DIR"; \
        printf '\(marker)\\n%s\\n' "$XDG_CONFIG_HOME"; \
        printf '\(marker)\\n'
        """
        guard let result = try? await CommandRunner.run(
            URL(fileURLWithPath: shellPath), ["-l", "-i", "-c", script], timeout: 5
        ) else {
            return ShellAnswer()
        }
        return parseShellAnswer(result.stdoutString)
    }

    /// Saca los tres valores de entre los separadores. Si la salida no tiene la
    /// forma esperada devolvemos todo vacío, que es lo mismo que «no sé».
    static func parseShellAnswer(_ output: String) -> ShellAnswer {
        let parts = output.components(separatedBy: marker + "\n")
        // Esperamos: [ruido, gh, GH_CONFIG_DIR, XDG_CONFIG_HOME, resto]
        guard parts.count >= 5 else { return ShellAnswer() }

        func value(_ index: Int) -> String? {
            let text = parts[index].trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        }
        // `command -v` puede devolver un alias o una función en vez de una ruta;
        // solo nos vale si es una ruta absoluta.
        let ghPath = value(1).flatMap { $0.hasPrefix("/") ? $0 : nil }
        return ShellAnswer(ghPath: ghPath, ghConfigDir: value(2), xdgConfigHome: value(3))
    }
}
