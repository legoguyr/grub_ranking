import Foundation

/// One optional Dish-level classification. Custom values live inside the owning
/// account's Dish graph, never in a shared/global user-created taxonomy.
nonisolated struct Cuisine: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let label: String
}

nonisolated enum CuisineCatalog {
    static let maximumLabelLength = 80
    static let predefined: [Cuisine] = [
        ("american", "American"), ("italian", "Italian"), ("french", "French"),
        ("spanish", "Spanish"), ("greek", "Greek"), ("mediterranean", "Mediterranean"),
        ("israeli", "Israeli"), ("middle-eastern", "Middle Eastern"), ("lebanese", "Lebanese"),
        ("turkish", "Turkish"), ("moroccan", "Moroccan"), ("mexican", "Mexican"),
        ("caribbean", "Caribbean"), ("indian", "Indian"), ("chinese", "Chinese"),
        ("japanese", "Japanese"), ("korean", "Korean"), ("thai", "Thai"),
        ("vietnamese", "Vietnamese"), ("filipino", "Filipino"), ("indonesian", "Indonesian"),
        ("malaysian", "Malaysian"), ("ethiopian", "Ethiopian"), ("west-african", "West African"),
        ("southern-soul-food", "Southern / Soul Food"), ("cajun-creole", "Cajun / Creole")
    ].map { Cuisine(id: $0.0, label: $0.1) }

    static func display(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
    static func key(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let words = folded.unicodeScalars.map { scalar -> String in
            if CharacterSet.alphanumerics.contains(scalar) { return String(scalar) }
            if "'’".unicodeScalars.contains(scalar) { return "" }
            return " "
        }.joined()
        return display(words)
    }
    // Deliberately small, explicit aliases; no fuzzy matching or silent inference.
    private static let aliases = ["italain": "italian", "mediterranian": "mediterranean",
        "mediteranean": "mediterranean", "philipino": "filipino", "viet namese": "vietnamese",
        "southern soulfood": "southern soul food", "cajun and creole": "cajun creole"]

    static func options(saved: [Cuisine]) -> [Cuisine] {
        var seen = Set<String>()
        return (predefined + saved.sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending })
            .filter { seen.insert(key($0.label)).inserted }
    }
    static func existing(_ text: String, saved: [Cuisine] = []) -> Cuisine? {
        let normalized = key(text)
        let target = aliases[normalized] ?? normalized
        return options(saved: saved).first { key($0.label) == target }
    }
    static func resolve(_ text: String, saved: [Cuisine] = []) -> Cuisine? {
        if let existing = existing(text, saved: saved) { return existing }
        let label = display(text), normalized = key(label)
        guard !normalized.isEmpty, label.unicodeScalars.count <= maximumLabelLength else { return nil }
        return Cuisine(id: "custom:" + normalized, label: label)
    }
}
