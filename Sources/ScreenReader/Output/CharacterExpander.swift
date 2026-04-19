//
//  CharacterExpander.swift
//
//  Copyright © 2017-2026 Doug Russell. All rights reserved.
//

enum CharacterExpander {
    /// Expands a single grapheme cluster to a speakable name.
    /// Multi-character strings are returned as-is.
    /// Letters and digits in any script are returned as-is (synth handles them).
    /// All other single scalars use the Unicode name, lowercased, with overrides
    /// for cases where the Unicode name differs from screen reader convention.
    static func expand(_ text: String) -> String {
        guard text.unicodeScalars.count == 1,
              let scalar = text.unicodeScalars.first else {
            // Multi-scalar grapheme clusters (emoji ZWJ sequences, combining characters):
            // pass through — synth handles emoji descriptions natively.
            return text
        }

        switch scalar.properties.generalCategory {
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter,
             .modifierLetter, .otherLetter,
             .decimalNumber, .letterNumber, .otherNumber:
            return text
        default:
            break
        }

        if let override = overrides[text] {
            return override
        }

        if let name = scalar.properties.name {
            return name.lowercased()
        }

        return text
    }

    // Only override where the Unicode name is awkward for TTS or differs
    // from established screen reader convention.
    // TODO: Localization
    private static let overrides: [String: String] = [
        " ":  "space",
        "\n": "newline",
        "\r": "return",
        "\t": "tab",
        ".":  "period",
        "'":  "apostrophe",
        "\"": "quote",
        "-":  "dash",
        "#":  "pound",
        "/": "forward slash",
    ]
}
