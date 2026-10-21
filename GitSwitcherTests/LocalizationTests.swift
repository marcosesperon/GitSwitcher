import Foundation
import Testing
@testable import GitSwitcher

/// Vigila que ninguna frase se quede sin traducir y que las traducciones
/// conserven los huecos (%@, %lld…) del texto original. Si alguien añade un
/// texto nuevo en el código y no lo traduce, este test lo dice.
@Suite("Traducciones")
struct LocalizationTests {
    /// Idiomas que la app promete (los mismos que CFBundleLocalizations).
    static let languages = ["es", "fr", "de", "it", "pt-BR", "ja", "zh-Hans", "ko"]

    /// Leemos el catálogo fuente directamente del repositorio.
    static let catalogURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("GitSwitcher/Resources/Localizable.xcstrings")

    private struct Catalog: Decodable {
        struct Entry: Decodable {
            struct Localization: Decodable {
                struct Unit: Decodable { let value: String }
                let stringUnit: Unit?
            }
            let localizations: [String: Localization]?
        }
        let strings: [String: Entry]
    }

    private func loadCatalog() throws -> Catalog {
        try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: Self.catalogURL))
    }

    /// Huecos de un texto sin el número de posición: «%1$@» cuenta como «%@».
    private func placeholders(_ text: String) -> [String] {
        let regex = try! NSRegularExpression(pattern: "%(?:\\d\\$)?(?:@|lld|d)")
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range)
            .map { String(text[Range($0.range, in: text)!]) }
            .map { $0.replacingOccurrences(of: #"\d\$"#, with: "", options: .regularExpression) }
            .sorted()
    }

    @Test func todasLasFrasesEstanEnTodosLosIdiomas() throws {
        let catalog = try loadCatalog()
        #expect(!catalog.strings.isEmpty)
        for (key, entry) in catalog.strings {
            for language in Self.languages {
                let value = entry.localizations?[language]?.stringUnit?.value
                #expect(value?.isEmpty == false, "Falta «\(key)» en \(language)")
            }
        }
    }

    @Test func lasTraduccionesConservanLosHuecos() throws {
        let catalog = try loadCatalog()
        for (key, entry) in catalog.strings {
            for language in Self.languages {
                guard let value = entry.localizations?[language]?.stringUnit?.value else { continue }
                #expect(placeholders(value) == placeholders(key), "Huecos distintos en «\(key)» (\(language)): \(value)")
            }
        }
    }

    @Test func laAppIncluyeTodosLosIdiomas() {
        // Los tests corren dentro de la app (TEST_HOST), así que Bundle.main es GitSwitcher.app.
        let bundled = Set(Bundle.main.localizations)
        for language in ["en"] + Self.languages {
            #expect(bundled.contains(language), "La app no incluye \(language).lproj")
        }
    }
}
