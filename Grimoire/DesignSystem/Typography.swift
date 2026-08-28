//
//  Typography.swift
//  Grimoire — Design System
//
//  Duas famílias:
//    • Display — grotesca condensada de peso alto (títulos, capítulos,
//      wordmark). Carrega o peso Mignola.
//    • Corpo   — serifa de leitura, confortável em blocos longos.
//
//  A fonte-bolha infantil do app original (Comic Relief) foi descartada.
//
//  COMO PLUGAR AS FONTES CUSTOM:
//    1. Arraste os .ttf/.otf para o target (Copy items if needed).
//    2. Info.plist → adicione a chave "Fonts provided by application"
//       (UIAppFonts) listando cada arquivo, ex.: "Oswald-Bold.ttf".
//    3. Troque os nomes em `Family` abaixo pelo PostScript name real
//       (descubra no app Font Book, ou via Font(name:) que loga aviso).
//
//  Enquanto as fontes não estão no target, `useCustomFonts = false`
//  mantém tudo no system font (serif/rounded) e o app roda normal.
//

import SwiftUI

extension DS {
    enum Typography {

        /// Vire para `true` depois de adicionar os .ttf e configurar o Info.plist.
        static let useCustomFonts = false

        enum Family {
            // TODO: substituir pelos PostScript names reais.
            static let display     = "Oswald-Bold"
            static let displaySemi = "Oswald-SemiBold"
            static let body        = "IBMPlexSerif"
            static let bodyBold    = "IBMPlexSerif-Bold"
        }

        // ---- Escala Display (títulos) ----
        static var hero:     Font { display(40, .bold) }
        static var title:    Font { display(28, .bold) }
        static var heading:  Font { display(24, .heavy) }
        static var subtitle: Font { display(20, .semibold) }

        // ---- Escala Corpo (leitura) ----
        static var bodyLg:   Font { body(18) }
        static var bodyMd:   Font { body(16) }
        static var bodySm:   Font { body(14) }
        static var caption:  Font { body(12) }

        // ---- Construtores ----
        static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
            if useCustomFonts {
                return .custom(Family.display, size: size).weight(weight)
            }
            // Fallback: system serif pesado aproxima o tom até plugar a custom.
            return .system(size: size, weight: weight, design: .serif)
        }

        static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
            if useCustomFonts {
                return .custom(Family.body, size: size).weight(weight)
            }
            return .system(size: size, weight: weight, design: .serif)
        }
    }
}

// Modificadores de conveniência: aplica fonte + cor de texto num passo só.
extension View {
    func dsText(_ font: Font, _ color: Color = DS.Colors.textPrimary) -> some View {
        self.font(font).foregroundStyle(color)
    }
}
