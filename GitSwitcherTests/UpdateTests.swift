import Foundation
import Testing
@testable import GitSwitcher

@Suite("Versiones")
struct AppVersionTests {
    @Test func comparaNumeroANumero() throws {
        let v190 = try #require(AppVersion("1.9.0"))
        let v1100 = try #require(AppVersion("v1.10.0"))
        #expect(v190 < v1100)
        #expect(AppVersion("1.2") == AppVersion("1.2.0"))
        #expect(AppVersion("2.0.0-beta") == AppVersion("2.0.0"))
        #expect(v1100.description == "1.10.0")
    }

    @Test func rechazaTextosQueNoSonVersiones() {
        #expect(AppVersion("") == nil)
        #expect(AppVersion("latest") == nil)
        #expect(AppVersion("1.x.0") == nil)
    }
}

@Suite("Releases de GitHub")
struct ReleaseFeedTests {
    static let json = """
    {
      "tag_name": "v1.2.0",
      "html_url": "https://github.com/marcosesperon/GitSwitcher/releases/tag/v1.2.0",
      "body": "**New:** updates from the app.",
      "assets": [
        {"name": "notes.txt", "browser_download_url": "https://example.com/notes.txt", "digest": null, "size": 10},
        {"name": "GitSwitcher-1.2.0.zip", "browser_download_url": "https://example.com/GitSwitcher-1.2.0.zip",
         "digest": "sha256:EF501F2901544C51D7018E029EC7BCFFC0CEB5F42F10D7D2C64FFD727D79B1EB", "size": 611007}
      ]
    }
    """

    @Test func leeVersionNotasYZip() throws {
        let release = try ReleaseFeed.parse(Data(Self.json.utf8))
        #expect(release.version == AppVersion("1.2.0"))
        #expect(release.notes == "**New:** updates from the app.")
        #expect(release.asset?.name == "GitSwitcher-1.2.0.zip")
        #expect(release.asset?.sha256 == "ef501f2901544c51d7018e029ec7bcffc0ceb5f42f10d7d2c64ffd727d79b1eb")
    }

    @Test func huellasRaras() {
        #expect(ReleaseFeed.parseDigest(nil) == nil)
        #expect(ReleaseFeed.parseDigest("md5:abc") == nil)
        #expect(ReleaseFeed.parseDigest("sha256:corta") == nil)
    }

    @Test func jsonQueNoEsUnaRelease() {
        #expect(throws: ReleaseFeedError.self) { try ReleaseFeed.parse(Data("{}".utf8)) }
    }
}

@Suite("Forma de instalación")
struct InstallMethodTests {
    let applications = URL(fileURLWithPath: "/Applications/GitSwitcher.app")

    @Test func homebrewSiHayCaskYEstaEnAplicaciones() {
        let method = InstallMethod.detect(appURL: applications) { $0 == "/opt/homebrew/Caskroom/gitswitcher" }
        #expect(method == .homebrew)
    }

    @Test func manualEnLosDemasCasos() {
        #expect(InstallMethod.detect(appURL: applications) { _ in false } == .manual)
        let elsewhere = URL(fileURLWithPath: "/Users/someone/Desktop/GitSwitcher.app")
        #expect(InstallMethod.detect(appURL: elsewhere) { _ in true } == .manual)
    }
}

/// Instalaciones de verdad, pero en una carpeta temporal y con una «app» de
/// mentira: así se prueba todo el camino sin tocar la app real.
@Suite("Instalación de una versión nueva", .serialized)
struct UpdateInstallerTests {
    let bundleID = "com.marcosesperon.GitSwitcher"

    /// Carpeta temporal con la app «instalada» (1.0.0) y el zip de la nueva.
    struct Fixture {
        let root: URL
        let installedApp: URL
        let zip: URL
        let zipHash: String
    }

    @Test func instalaYSustituyeLaApp() async throws {
        let fixture = try await makeFixture(newVersion: "9.9.9")
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let release = makeRelease(fixture, version: "9.9.9", hash: fixture.zipHash)
        try await UpdateInstaller(expectedBundleID: bundleID).install(release, over: fixture.installedApp)

        #expect(try installedVersion(fixture) == "9.9.9")
    }

    @Test func siLaHuellaNoCoincideNoTocaNada() async throws {
        let fixture = try await makeFixture(newVersion: "9.9.9")
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let release = makeRelease(fixture, version: "9.9.9", hash: String(repeating: "0", count: 64))
        await #expect(throws: UpdateError.checksumMismatch) {
            try await UpdateInstaller(expectedBundleID: bundleID).install(release, over: fixture.installedApp)
        }
        #expect(try installedVersion(fixture) == "1.0.0")
    }

    @Test func siEsOtraAppNoTocaNada() async throws {
        let fixture = try await makeFixture(newVersion: "9.9.9")
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let release = makeRelease(fixture, version: "9.9.9", hash: fixture.zipHash)
        await #expect(throws: UpdateError.self) {
            try await UpdateInstaller(expectedBundleID: "com.example.Other").install(release, over: fixture.installedApp)
        }
        #expect(try installedVersion(fixture) == "1.0.0")
    }

    @Test func siLaVersionNoEsLaAnunciadaNoTocaNada() async throws {
        let fixture = try await makeFixture(newVersion: "9.9.9")
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        // GitHub dice 9.9.10, pero el zip trae la 9.9.9.
        let release = makeRelease(fixture, version: "9.9.10", hash: fixture.zipHash)
        await #expect(throws: UpdateError.self) {
            try await UpdateInstaller(expectedBundleID: bundleID).install(release, over: fixture.installedApp)
        }
        #expect(try installedVersion(fixture) == "1.0.0")
    }

    @Test func siNoSePuedeEscribirNoDescargaNiTocaNada() async throws {
        let fixture = try await makeFixture(newVersion: "9.9.9")
        let folder = fixture.installedApp.deletingLastPathComponent()
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: folder.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder.path)
            try? FileManager.default.removeItem(at: fixture.root)
        }

        let release = makeRelease(fixture, version: "9.9.9", hash: fixture.zipHash)
        await #expect(throws: UpdateError.notWritable(folder.path)) {
            try await UpdateInstaller(expectedBundleID: bundleID).install(release, over: fixture.installedApp)
        }
        #expect(try installedVersion(fixture) == "1.0.0")
    }

    // MARK: - Ayudas

    private func makeRelease(_ fixture: Fixture, version: String, hash: String) -> ReleaseInfo {
        ReleaseInfo(
            version: AppVersion(version)!,
            notes: "",
            pageURL: URL(string: "https://example.com")!,
            asset: .init(name: fixture.zip.lastPathComponent, downloadURL: fixture.zip, sha256: hash, size: 0)
        )
    }

    private func installedVersion(_ fixture: Fixture) throws -> String? {
        let plist = fixture.installedApp.appendingPathComponent("Contents/Info.plist")
        let data = try Data(contentsOf: plist)
        let info = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        return info?["CFBundleShortVersionString"] as? String
    }

    private func makeFixture(newVersion: String) async throws -> Fixture {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("GitSwitcherUpdateTests-\(UUID().uuidString)", isDirectory: true)
        let installed = root.appendingPathComponent("Applications/GitSwitcher.app", isDirectory: true)
        let build = root.appendingPathComponent("build/GitSwitcher.app", isDirectory: true)

        try makeApp(at: installed, version: "1.0.0")
        try makeApp(at: build, version: newVersion)
        try await run("/usr/bin/codesign", ["--force", "--sign", "-", build.path])

        let zip = root.appendingPathComponent("GitSwitcher-\(newVersion).zip")
        try await run("/usr/bin/ditto", ["-c", "-k", "--keepParent", build.path, zip.path])
        let hash = UpdateInstaller.sha256(try Data(contentsOf: zip))
        return Fixture(root: root, installedApp: installed, zip: zip, zipHash: hash)
    }

    /// Una app mínima: Info.plist y un ejecutable (copia de /usr/bin/true) para
    /// que se pueda firmar como una de verdad.
    private func makeApp(at url: URL, version: String) throws {
        let macOS = url.appendingPathComponent("Contents/MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        try FileManager.default.copyItem(atPath: "/usr/bin/true", toPath: macOS.appendingPathComponent("GitSwitcher").path)
        let info: [String: Any] = [
            "CFBundleIdentifier": bundleID,
            "CFBundleShortVersionString": version,
            "CFBundleVersion": "1",
            "CFBundleExecutable": "GitSwitcher",
            "CFBundlePackageType": "APPL",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try data.write(to: url.appendingPathComponent("Contents/Info.plist"))
    }

    private func run(_ tool: String, _ arguments: [String]) async throws {
        let result = try await CommandRunner.run(URL(fileURLWithPath: tool), arguments)
        #expect(result.succeeded, "\(tool) falló: \(result.stderr)")
    }
}

@Suite("Actualizar con Homebrew")
struct HomebrewUpgradeTests {
    @Test func primeroActualizaHomebrewYLuegoLaApp() {
        let commands = UpdateStore.homebrewUpgradeCommands { $0 == "/opt/homebrew/bin/brew" }
        #expect(commands == [
            ["/opt/homebrew/bin/brew", "update"],
            ["/opt/homebrew/bin/brew", "upgrade", "--cask", "gitswitcher"],
        ])
    }

    @Test func sinBrewConocidoUsaElPathDeLaTerminal() {
        let commands = UpdateStore.homebrewUpgradeCommands { _ in false }
        #expect(commands.first == ["/usr/bin/env", "brew", "update"])
    }

    @Test func elScriptEncadenaConAndYBorraElFichero() {
        let script = TerminalLauncher.scriptContents(commands: [["/bin/echo", "a b"], ["/bin/echo", "it's"]])
        #expect(script.contains("'/bin/echo' 'a b' && '/bin/echo' 'it'\\''s'"))
        #expect(script.hasSuffix("rm -f \"$0\"\n"))
    }

    /// Ejecuta el script de verdad con `sh`: si el primer comando falla, el
    /// segundo no se ejecuta, y el script se borra igualmente.
    @Test func siFallaElPrimeroNoSeEjecutaElSegundo() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("GitSwitcherScript-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let marker = directory.appendingPathComponent("segundo")
        let script = directory.appendingPathComponent("prueba.command")

        try TerminalLauncher.scriptContents(commands: [["/usr/bin/false"], ["/usr/bin/touch", marker.path]])
            .write(to: script, atomically: true, encoding: .utf8)
        _ = try await CommandRunner.run(URL(fileURLWithPath: "/bin/sh"), [script.path])

        #expect(!FileManager.default.fileExists(atPath: marker.path))
        #expect(!FileManager.default.fileExists(atPath: script.path))
    }
}
