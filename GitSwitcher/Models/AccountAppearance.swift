import AppKit

/// Iconos que se pueden elegir para una cuenta.
///
/// Lo que se guarda en preferencias es el nombre del caso (`briefcase`…), no el
/// del símbolo de macOS: así podemos cambiar de símbolo en el futuro sin perder
/// lo que eligió el usuario.
enum AccountIcon: String, CaseIterable, Codable, Sendable, Identifiable {
    case person, people, briefcase, house, building, institution
    case code, terminal, chip, server, cloud, globe
    case graduation, book, key, shield
    case star, heart, bolt, leaf, flag, paperplane, cat, paintbrush

    var id: String { rawValue }

    /// Nombre del SF Symbol que se dibuja.
    var symbolName: String {
        switch self {
        case .person: "person.fill"
        case .people: "person.2.fill"
        case .briefcase: "briefcase.fill"
        case .house: "house.fill"
        case .building: "building.2.fill"
        case .institution: "building.columns.fill"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .terminal: "terminal.fill"
        case .chip: "cpu.fill"
        case .server: "server.rack"
        case .cloud: "cloud.fill"
        case .globe: "globe"
        case .graduation: "graduationcap.fill"
        case .book: "book.fill"
        case .key: "key.fill"
        case .shield: "shield.fill"
        case .star: "star.fill"
        case .heart: "heart.fill"
        case .bolt: "bolt.fill"
        case .leaf: "leaf.fill"
        case .flag: "flag.fill"
        case .paperplane: "paperplane.fill"
        case .cat: "cat.fill"
        case .paintbrush: "paintbrush.fill"
        }
    }

    /// Nombre que se enseña en el selector, traducido.
    var localizedName: String {
        switch self {
        case .person: String(localized: "Person")
        case .people: String(localized: "People")
        case .briefcase: String(localized: "Briefcase")
        case .house: String(localized: "House")
        case .building: String(localized: "Building")
        case .institution: String(localized: "Institution")
        case .code: String(localized: "Code")
        case .terminal: String(localized: "Terminal")
        case .chip: String(localized: "Chip")
        case .server: String(localized: "Server")
        case .cloud: String(localized: "Cloud")
        case .globe: String(localized: "Globe")
        case .graduation: String(localized: "Graduation Cap")
        case .book: String(localized: "Book")
        case .key: String(localized: "Key")
        case .shield: String(localized: "Shield")
        case .star: String(localized: "Star")
        case .heart: String(localized: "Heart")
        case .bolt: String(localized: "Bolt")
        case .leaf: String(localized: "Leaf")
        case .flag: String(localized: "Flag")
        case .paperplane: String(localized: "Paper Plane")
        case .cat: String(localized: "Cat")
        case .paintbrush: String(localized: "Paintbrush")
        }
    }
}

/// Colores que se pueden elegir para el icono de una cuenta.
///
/// Son los colores «de sistema» de macOS: cada uno tiene una variante para modo
/// claro y otra para modo oscuro, así que se ven bien en cualquier barra.
enum AccountColor: String, CaseIterable, Codable, Sendable, Identifiable {
    case red, orange, yellow, green, mint, cyan, blue, indigo, purple, pink, brown, gray

    var id: String { rawValue }

    var nsColor: NSColor {
        switch self {
        case .red: .systemRed
        case .orange: .systemOrange
        case .yellow: .systemYellow
        case .green: .systemGreen
        case .mint: .systemMint
        case .cyan: .systemCyan
        case .blue: .systemBlue
        case .indigo: .systemIndigo
        case .purple: .systemPurple
        case .pink: .systemPink
        case .brown: .systemBrown
        case .gray: .systemGray
        }
    }

    var localizedName: String {
        switch self {
        case .red: String(localized: "Red")
        case .orange: String(localized: "Orange")
        case .yellow: String(localized: "Yellow")
        case .green: String(localized: "Green")
        case .mint: String(localized: "Mint")
        case .cyan: String(localized: "Cyan")
        case .blue: String(localized: "Blue")
        case .indigo: String(localized: "Indigo")
        case .purple: String(localized: "Purple")
        case .pink: String(localized: "Pink")
        case .brown: String(localized: "Brown")
        case .gray: String(localized: "Gray")
        }
    }
}

/// Dibuja el icono de una cuenta para la barra, el menú y los ajustes.
enum AccountBadge {
    /// Icono que se usa cuando la cuenta no tiene uno elegido.
    static let defaultSymbol = "person.crop.circle.fill"

    /// - Sin color: imagen «plantilla», que macOS pinta en negro o blanco según
    ///   el fondo (igual que el resto de iconos de la barra).
    /// - Con color: el símbolo pintado de ese color. Deja de ser plantilla, así
    ///   que macOS ya no lo recolorea.
    static func image(icon: AccountIcon?, color: AccountColor?, fallbackSymbol: String = defaultSymbol) -> NSImage? {
        let symbol = icon?.symbolName ?? fallbackSymbol
        guard let base = NSImage(systemSymbolName: symbol, accessibilityDescription: icon?.localizedName) else {
            return nil
        }
        guard let color else {
            base.isTemplate = true
            return base
        }
        let colored = base.withSymbolConfiguration(.init(paletteColors: [color.nsColor])) ?? base
        colored.isTemplate = false
        return colored
    }

    static func image(for preferences: AccountPreferences, fallbackSymbol: String = defaultSymbol) -> NSImage? {
        image(icon: preferences.icon, color: preferences.color, fallbackSymbol: fallbackSymbol)
    }

    /// Circulito de color para el selector de color de los ajustes.
    static func swatch(_ color: AccountColor) -> NSImage {
        let image = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            color.nsColor.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
