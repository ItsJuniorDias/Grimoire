//
//  Colors.swift
//  Grimoire — Design System
//
//  Paleta construída em torno do vermelho Hellboy como primary.
//  As cores semânticas vêm do Asset Catalog (Colors/*.colorset), então
//  o dark/light é resolvido automaticamente pelo sistema. Use SEMPRE
//  os tokens semânticos (DS.Colors) na UI — nunca a Palette bruta.
//
//  Uso:
//    Text("Capítulo 1").foregroundStyle(DS.Colors.textPrimary)
//    someView.background(DS.Colors.surface)
//

import SwiftUI

extension DS {
    enum Colors {
        // ---- Semânticas (Asset Catalog, dark/light automático) ----
        static let accent        = SwiftUI.Color("AccentPrimary")   // vermelho Hellboy — AÇÃO
        static let background     = SwiftUI.Color("Background")
        static let surface        = SwiftUI.Color("Surface")
        static let surfaceAlt     = SwiftUI.Color("SurfaceAlt")
        static let textPrimary    = SwiftUI.Color("TextPrimary")
        static let textSecondary  = SwiftUI.Color("TextSecondary")
        static let textMuted      = SwiftUI.Color("TextMuted")
        static let border         = SwiftUI.Color("Border")

        // ---- Acentos de grimório ----
        static let brass          = SwiftUI.Color("Brass")   // ouro/latão — o "mágico", warning
        static let night          = SwiftUI.Color("Night")   // azul-noite — mistério
        static let moss           = SwiftUI.Color("Moss")    // verde-musgo — sucesso, antagonistas
        static let blood          = SwiftUI.Color("Blood")   // sangue escuro — perigo profundo

        // ---- Feedback (aliases semânticos) ----
        static let danger   = accent   // perigo compartilha o vermelho de ação (Mignola: paleta econômica)
        static let warning  = brass
        static let success  = moss

        // ---- Texto sobre acento ----
        static let textOnAccent = SwiftUI.Color("TextPrimary") // papel sobre o vermelho

        // ---- Níveis de progressão ----
        static func level(_ level: MWLevel) -> SwiftUI.Color {
            switch level {
            case .apprentice: textSecondary
            case .initiate:   moss
            case .conjurer:   night
            case .archmage:   brass
            }
        }
    }

    /// Palette bruta — exposta só para casos específicos (gradientes, sombras
    /// de tinta). NÃO use direto como cor de UI; prefira DS.Colors.
    enum Palette {
        // Vermelho Hellboy
        static let red700 = Color(hex: 0x8A2318)
        static let red600 = Color(hex: 0xA62D20)
        static let red500 = Color(hex: 0xC1352A)   // PRIMARY
        static let red400 = Color(hex: 0xD65B4A)
        static let red300 = Color(hex: 0xE68878)

        // Tinta & couro
        static let ink900 = Color(hex: 0x0C0A09)
        static let ink800 = Color(hex: 0x16130F)
        static let ink700 = Color(hex: 0x201B16)
        static let ink600 = Color(hex: 0x2C251E)
        static let ink500 = Color(hex: 0x3B322A)
        static let ink400 = Color(hex: 0x574B40)
        static let ink300 = Color(hex: 0x7A6B5C)
        static let ink200 = Color(hex: 0xA89684)
        static let ink100 = Color(hex: 0xCBBBA6)

        // Pergaminho
        static let paper      = Color(hex: 0xE8DCC6)
        static let paperLight = Color(hex: 0xF2E9D8)

        // Acentos
        static let brass500 = Color(hex: 0xC79A3E)
        static let night600 = Color(hex: 0x263A4D)
        static let moss600  = Color(hex: 0x4A5A3C)
        static let blood700 = Color(hex: 0x5E1410)

        static let black = Color(hex: 0x000000)
    }
}

enum MWLevel: String, CaseIterable {
    case apprentice = "Apprentice"
    case initiate   = "Initiate"
    case conjurer   = "Conjurer"
    case archmage   = "Archmage"

    var symbol: String {
        switch self {
        case .apprentice: "flame"
        case .initiate:   "flame.fill"
        case .conjurer:   "sparkles"
        case .archmage:   "crown.fill"
        }
    }
}

extension Color {
    /// Cria Color de um hex 0xRRGGBB.
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
