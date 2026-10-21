import AppKit
import CryptoKit
import Foundation

enum UpdateError: LocalizedError, Equatable {
    case noDownload
    case noChecksum
    case notWritable(String)
    case downloadFailed(String)
    case checksumMismatch
    case badArchive
    case wrongApp(String)
    case invalidSignature
    case replaceFailed(String)

    var errorDescription: String? {
        switch self {
        case .noDownload:
            return String(localized: "This version has no download for GitSwitcher.")
        case .noChecksum:
            return String(localized: "GitHub didn't publish a checksum for the download, so it can't be verified.")
        case .notWritable(let folder):
            return String(localized: "GitSwitcher can't write to \(folder). Update it from GitHub instead.")
        case .downloadFailed(let reason):
            return String(localized: "The download failed: \(reason)")
        case .checksumMismatch:
            return String(localized: "The download doesn't match the published file. Nothing was changed.")
        case .badArchive:
            return String(localized: "The downloaded file doesn't contain GitSwitcher.")
        case .wrongApp(let reason):
            return String(localized: "The downloaded app isn't the expected one: \(reason)")
        case .invalidSignature:
            return String(localized: "The downloaded app's code signature is broken.")
        case .replaceFailed(let reason):
            return String(localized: "Couldn't replace the app: \(reason)")
        }
    }
}

/// Descarga una versión nueva y sustituye la app instalada.
///
/// Va paso a paso y **no toca la app instalada hasta el final**: si cualquier
/// comprobación falla, lo descargado se tira y todo queda como estaba.
struct UpdateInstaller: Sendable {
    /// Identificador que tiene que tener la app descargada.
    var expectedBundleID = Bundle.main.bundleIdentifier ?? "com.marcosesperon.GitSwitcher"
    var session: URLSession = .shared

    /// Instala `release` en lugar de la app que hay en `appURL`.
    /// - Parameter progress: avance de la descarga, de 0 a 1.
    func install(
        _ release: ReleaseInfo,
        over appURL: URL,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws {
        guard let asset = release.asset else { throw UpdateError.noDownload }
        guard let expectedHash = asset.sha256 else { throw UpdateError.noChecksum }

        // 1) Antes de descargar nada: ¿podremos escribir donde está la app?
        let folder = appURL.deletingLastPathComponent()
        guard FileManager.default.isWritableFile(atPath: folder.path) else {
            throw UpdateError.notWritable(folder.path)
        }

        let workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitSwitcher-update-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        // Pase lo que pase, al terminar no dejamos basura.
        defer { try? FileManager.default.removeItem(at: workDirectory) }

        // 2) Descargar y 3) comprobar la huella.
        let zipData = try await download(asset, progress: progress)
        guard Self.sha256(zipData) == expectedHash.lowercased() else { throw UpdateError.checksumMismatch }
        let zipURL = workDirectory.appendingPathComponent(asset.name)
        try zipData.write(to: zipURL)

        // 4) Descomprimir y 5) comprobar que es la app que esperamos.
        let newApp = try await unzipApp(zipURL, into: workDirectory)
        try verify(newApp, expectedVersion: release.version)
        try await verifySignature(newApp)

        // 6) Cambiar la vieja por la nueva de una vez. Si falla, la vieja sigue.
        do {
            _ = try FileManager.default.replaceItemAt(appURL, withItemAt: newApp)
        } catch {
            throw UpdateError.replaceFailed(error.localizedDescription)
        }
    }

    /// Abre la app recién instalada en cuanto esta se cierre, y la cierra.
    ///
    /// Un pequeño script espera a que nuestro proceso termine (para no tener dos
    /// GitSwitcher a la vez) y entonces abre la app nueva.
    @MainActor
    static func relaunch(_ appURL: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = "while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, appURL.path]
        try? process.run()
        NSApp.terminate(nil)
    }

    // MARK: - Pasos

    private func download(_ asset: ReleaseInfo.Asset, progress: @escaping @Sendable (Double) -> Void) async throws -> Data {
        do {
            let (bytes, response) = try await session.bytes(from: asset.downloadURL)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                throw UpdateError.downloadFailed("HTTP \(http.statusCode)")
            }
            let expected = max(asset.size, Int(response.expectedContentLength), 1)
            var data = Data()
            data.reserveCapacity(expected)
            var lastReported = 0
            for try await byte in bytes {
                data.append(byte)
                // Avisamos cada ~64 KB, no por cada byte.
                if data.count - lastReported >= 65_536 {
                    lastReported = data.count
                    progress(min(Double(data.count) / Double(expected), 1))
                }
            }
            progress(1)
            return data
        } catch let error as UpdateError {
            throw error
        } catch {
            throw UpdateError.downloadFailed(error.localizedDescription)
        }
    }

    private func unzipApp(_ zipURL: URL, into directory: URL) async throws -> URL {
        let destination = directory.appendingPathComponent("unzipped", isDirectory: true)
        // ditto respeta los atributos del bundle; es lo que usa release.sh al empaquetar.
        let result = try await CommandRunner.run(
            URL(fileURLWithPath: "/usr/bin/ditto"), ["-x", "-k", zipURL.path, destination.path], timeout: 60
        )
        let app = destination.appendingPathComponent("GitSwitcher.app", isDirectory: true)
        guard result.succeeded, FileManager.default.fileExists(atPath: app.path) else {
            throw UpdateError.badArchive
        }
        return app
    }

    private func verify(_ app: URL, expectedVersion: AppVersion) throws {
        guard let bundle = Bundle(url: app) else { throw UpdateError.badArchive }
        guard bundle.bundleIdentifier == expectedBundleID else {
            throw UpdateError.wrongApp(bundle.bundleIdentifier ?? "?")
        }
        let versionText = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        guard let version = versionText.flatMap(AppVersion.init), version == expectedVersion else {
            throw UpdateError.wrongApp(String(localized: "version \(versionText ?? "?") instead of \(expectedVersion.description)"))
        }
    }

    /// La app no está firmada con Developer ID, pero sí lleva una firma ad hoc que
    /// detecta si algún fichero se ha modificado tras compilarla.
    private func verifySignature(_ app: URL) async throws {
        let result = try await CommandRunner.run(
            URL(fileURLWithPath: "/usr/bin/codesign"), ["--verify", "--deep", "--strict", app.path], timeout: 60
        )
        guard result.succeeded else { throw UpdateError.invalidSignature }
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
