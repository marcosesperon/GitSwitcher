import Foundation

/// Resultado de ejecutar un programa externo.
struct CommandResult: Sendable {
    let exitCode: Int32
    let stdout: Data
    let stderr: String

    var succeeded: Bool { exitCode == 0 }
    var stdoutString: String { String(decoding: stdout, as: UTF8.self) }
}

enum CommandError: LocalizedError {
    case launchFailed(String, underlying: String)
    case timedOut(String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let tool, let underlying):
            return String(localized: "Couldn't run \(tool): \(underlying)")
        case .timedOut(let tool):
            return String(localized: "\(tool) took too long to answer.")
        }
    }
}

/// Lanza programas (gh, git, el shell) sin bloquear la interfaz.
///
/// Siempre se pasan los argumentos como lista, nunca montando una cadena para el
/// shell, así que un login raro no puede colarse como comando.
enum CommandRunner {
    /// Ejecuta `executable` con `arguments` y espera a que termine.
    /// - Parameters:
    ///   - environment: variables extra que se suman a las del proceso actual.
    ///   - timeout: si el programa se cuelga (p. ej. pidiendo algo por teclado),
    ///     lo matamos pasado este tiempo para no dejar la app esperando.
    static func run(
        _ executable: URL,
        _ arguments: [String],
        environment: [String: String] = [:],
        timeout: TimeInterval = 20
    ) async throws -> CommandResult {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
        // Sin entrada estándar: si el programa quisiera preguntar algo, recibe
        // fin de fichero en vez de quedarse esperando.
        process.standardInput = FileHandle.nullDevice

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let toolName = executable.lastPathComponent

        // Leemos las tuberías en paralelo mientras el proceso corre; si
        // esperásemos al final, una salida grande llenaría el búfer y el proceso
        // se quedaría bloqueado.
        async let stdoutData = readAll(stdoutPipe.fileHandleForReading)
        async let stderrData = readAll(stderrPipe.fileHandleForReading)

        let exitCode: Int32 = try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { finished in
                continuation.resume(returning: finished.terminationStatus)
            }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                // Cerramos nuestro extremo de escritura para que los lectores
                // de arriba reciban fin de fichero y no se queden esperando.
                try? stdoutPipe.fileHandleForWriting.close()
                try? stderrPipe.fileHandleForWriting.close()
                continuation.resume(throwing: CommandError.launchFailed(toolName, underlying: error.localizedDescription))
                return
            }
            // Vigilante de tiempo: si sigue vivo al vencer el plazo, lo paramos.
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if process.isRunning { process.terminate() }
            }
        }

        let out = await stdoutData
        let err = await stderrData

        // terminate() deja el código de salida de SIGTERM (15) con motivo
        // "uncaughtSignal"; lo traducimos a un error entendible.
        if process.terminationReason == .uncaughtSignal {
            throw CommandError.timedOut(toolName)
        }
        return CommandResult(exitCode: exitCode, stdout: out, stderr: String(decoding: err, as: UTF8.self))
    }

    private static func readAll(_ handle: FileHandle) async -> Data {
        await Task.detached { (try? handle.readToEnd()) ?? Data() }.value
    }
}
