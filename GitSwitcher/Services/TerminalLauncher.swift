import AppKit
import Foundation

/// Abre Terminal y ejecuta un comando a la vista del usuario.
///
/// Truco: escribimos un `.command` temporal y lo abrimos; macOS lo ejecuta en
/// Terminal sin pedir permisos de automatización. El script se borra solo al
/// terminar.
enum TerminalLauncher {
    /// - Parameters:
    ///   - arguments: el programa (ruta absoluta) y sus argumentos.
    ///   - environment: variables que hay que exportar antes (p. ej. `GH_CONFIG_DIR`).
    static func run(_ arguments: [String], environment: [String: String] = [:]) throws {
        var lines = ["#!/bin/sh"]
        for (key, value) in environment.sorted(by: { $0.key < $1.key }) {
            lines.append("export \(key)=\(shellQuoted(value))")
        }
        lines.append(arguments.map(shellQuoted).joined(separator: " "))
        lines.append("rm -f \"$0\"")

        let script = FileManager.default.temporaryDirectory
            .appendingPathComponent("gitswitcher-\(UUID().uuidString).command")
        try lines.joined(separator: "\n").appending("\n").write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        NSWorkspace.shared.open(script)
    }

    /// Envuelve un valor entre comillas simples para el shell, escapando las que
    /// tenga dentro. Así ningún valor puede colarse como otro comando.
    static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
