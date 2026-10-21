import AppKit
import Testing
@testable import GitSwitcher

@Suite("Icono y color por cuenta")
struct AppearanceTests {
    @Test func preferenciasAntiguasSinIconoNiColorSeLeen() throws {
        // Lo que guardaban las versiones anteriores: sin icon ni color.
        let json = #"{"alias":"Work","gitName":"Octo","gitEmail":"o@example.com"}"#
        let preferences = try JSONDecoder().decode(AccountPreferences.self, from: Data(json.utf8))
        #expect(preferences.alias == "Work")
        #expect(preferences.icon == nil)
        #expect(preferences.color == nil)
        #expect(!preferences.hasCustomAppearance)
    }

    @Test func unIconoDesconocidoNoBorraLoDemas() throws {
        let json = #"{"alias":"Work","gitName":"","gitEmail":"","icon":"unicorn","color":"blue"}"#
        let preferences = try JSONDecoder().decode(AccountPreferences.self, from: Data(json.utf8))
        #expect(preferences.alias == "Work")
        #expect(preferences.icon == nil)
        #expect(preferences.color == .blue)
    }

    @Test func seGuardanYRecuperanIconoYColor() throws {
        let original = AccountPreferences(alias: "Home", icon: .house, color: .green)
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(AccountPreferences.self, from: data) == original)
    }

    /// Lo que se guarda es el nombre del caso: si alguien lo cambia, los iconos
    /// que eligieron los usuarios se perderían.
    @Test func losIdentificadoresGuardadosSonEstables() {
        #expect(AccountIcon.allCases.count == 24)
        #expect(AccountIcon.briefcase.rawValue == "briefcase")
        #expect(AccountIcon.house.rawValue == "house")
        #expect(AccountColor.allCases.count == 12)
        #expect(AccountColor.blue.rawValue == "blue")
    }

    @Test func todosLosSimbolosExisten() {
        for icon in AccountIcon.allCases {
            #expect(NSImage(systemSymbolName: icon.symbolName, accessibilityDescription: nil) != nil, "Falta \(icon.symbolName)")
        }
    }

    @Test func sinColorEsPlantillaYConColorNo() throws {
        let plain = try #require(AccountBadge.image(icon: .briefcase, color: nil))
        let colored = try #require(AccountBadge.image(icon: .briefcase, color: .blue))
        #expect(plain.isTemplate)
        #expect(!colored.isTemplate)
        // Sin icono elegido se usa el de siempre.
        #expect(AccountBadge.image(icon: nil, color: nil) != nil)
    }
}
