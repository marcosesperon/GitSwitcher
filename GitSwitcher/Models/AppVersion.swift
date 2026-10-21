import Foundation

/// Número de versión del estilo «1.2.3» (también acepta «v1.2.3»).
///
/// Se compara número a número, así que 1.10.0 es mayor que 1.9.0 (cosa que una
/// comparación de texto haría al revés).
struct AppVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    let components: [Int]

    init?(_ text: String) {
        var cleaned = text.trimmingCharacters(in: .whitespaces)
        if cleaned.hasPrefix("v") || cleaned.hasPrefix("V") { cleaned.removeFirst() }
        // Si viene con sufijo («1.2.0-beta»), nos quedamos con la parte numérica.
        let core = cleaned.split(separator: "-", maxSplits: 1).first.map(String.init) ?? cleaned
        let numbers = core.split(separator: ".").map { Int($0) }
        guard !numbers.isEmpty, numbers.allSatisfy({ $0 != nil }) else { return nil }
        components = numbers.compactMap { $0 }
    }

    /// La versión de la app que se está ejecutando.
    static var current: AppVersion {
        let text = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return text.flatMap(AppVersion.init) ?? AppVersion("0")!
    }

    var description: String { components.map(String.init).joined(separator: ".") }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        // Rellenamos con ceros para que 1.2 y 1.2.0 cuenten como iguales.
        let length = max(lhs.components.count, rhs.components.count)
        for index in 0..<length {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }

    func hash(into hasher: inout Hasher) {
        // Coherente con `==`: quitamos los ceros finales antes de calcular.
        var trimmed = components
        while trimmed.last == 0 { trimmed.removeLast() }
        hasher.combine(trimmed)
    }
}
