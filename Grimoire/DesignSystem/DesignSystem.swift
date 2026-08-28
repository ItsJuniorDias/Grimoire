//
//  DesignSystem.swift
//  Grimoire — Design System
//
//  Namespace raiz `DS` e os tokens de layout (espaço, raio, sombra, motion).
//  Cor e tipografia estão em Colors.swift e Typography.swift, no mesmo
//  namespace via extension.
//

import SwiftUI

/// Namespace raiz do design system. Tudo pendura aqui: DS.Colors, DS.Typography,
/// DS.Space, DS.Radius, DS.Shadow, DS.Motion.
enum DS {}

// ============================================================
// Espaçamento — múltiplos de 4
// ============================================================

extension DS {
    enum Space {
        static let xxxs: CGFloat = 2
        static let xxs:  CGFloat = 4
        static let xs:   CGFloat = 8
        static let sm:   CGFloat = 12
        static let md:   CGFloat = 16
        static let lg:   CGFloat = 24
        static let xl:   CGFloat = 32
        static let xxl:  CGFloat = 40
        static let xxxl: CGFloat = 64
    }
}

// ============================================================
// Raio — cantos duros (Mignola é geométrico)
// ============================================================

extension DS {
    enum Radius {
        static let none: CGFloat = 0
        static let xs:   CGFloat = 2
        static let sm:   CGFloat = 4
        static let md:   CGFloat = 8
        static let lg:   CGFloat = 10
        static let xl:   CGFloat = 12
        static let pill: CGFloat = 999
    }
}

// ============================================================
// Sombra — vira MASSA PRETA (tinta), não blur suave
// ============================================================

extension DS {
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat

        static let none = Shadow(color: .clear, radius: 0, x: 0, y: 0)
        /// Sombra dura estilo tinta: sem blur, offset marcado.
        static let hard = Shadow(color: DS.Palette.black.opacity(0.9), radius: 0, x: 4, y: 4)
        static let md   = Shadow(color: DS.Palette.black.opacity(0.6), radius: 6, x: 2, y: 4)
        static let lg   = Shadow(color: DS.Palette.black.opacity(0.7), radius: 14, x: 0, y: 8)
        /// Halo de vermelho para o CTA principal.
        static let accent = Shadow(color: DS.Palette.red500.opacity(0.5), radius: 12, x: 0, y: 6)
    }
}

extension View {
    /// Aplica um token de sombra. Ex.: `.dsShadow(.hard)`
    func dsShadow(_ s: DS.Shadow) -> some View {
        self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
}

// ============================================================
// Motion — durações e curvas (casa com os presets do Pow)
// ============================================================

extension DS {
    enum Motion {
        static let fast:   Double = 0.15
        static let normal: Double = 0.25
        static let slow:   Double = 0.40
        static let slower: Double = 0.80

        /// Ease-out pesado — Mignola pede peso, nada de bounce fofo.
        static let standard = Animation.easeOut(duration: normal)
        static let heavy    = Animation.easeInOut(duration: slow)
    }
}
