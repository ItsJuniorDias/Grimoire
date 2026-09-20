//
//  Components.swift
//  Grimoire — Design System
//
//  Componentes-base que consomem os tokens DS. SwiftUI puro por enquanto —
//  os pontos onde o Pow entra estão marcados com // POW: ...
//  Depois de adicionar o package Pow (github.com/movingparts-io/Pow),
//  descomente as linhas indicadas.
//

import SwiftUI
// import Pow

// ============================================================
// Botão — cantos duros, sombra de tinta, acento vermelho Hellboy
// ============================================================

enum GButtonVariant { case primary, secondary, ghost }

struct GButton: View {
    /// LocalizedStringKey, nao String: o literal no call site vira chave do
    /// String Catalog sozinho, como acontece com `Text("...")`. Com String
    /// o texto passava direto e nunca era traduzido.
    let title: LocalizedStringKey
    var variant: GButtonVariant = .primary
    var icon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.xs) {
                if let icon { Image(systemName: icon) }
                Text(title).font(DS.Typography.subtitle)
            }
            .foregroundStyle(fg)
            .padding(.horizontal, DS.Space.lg)
            .padding(.vertical, DS.Space.sm)
            .frame(maxWidth: variant == .primary ? .infinity : nil, minHeight: 52)
            .background(bg, in: .rect(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(variant == .ghost ? DS.Colors.accent : .clear,
                            lineWidth: 1.5)
            )
            .dsShadow(variant == .primary ? .hard : .none)
        }
        .buttonStyle(.plain)
        // POW: .conditionalEffect(.pushDown, condition: isPressed)
    }

    private var bg: Color {
        switch variant {
        case .primary:   DS.Colors.accent
        case .secondary: DS.Colors.surface
        case .ghost:     .clear
        }
    }
    private var fg: Color {
        switch variant {
        case .primary:   DS.Colors.textOnAccent
        case .secondary: DS.Colors.textPrimary
        case .ghost:     DS.Colors.accent
        }
    }
}

// ============================================================
// Card de história — arte em spot-black, título display
// ============================================================

struct StoryCard: View {
    let title: String
    let subtitle: String
    var imageName: String? = nil
    var locked: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let imageName {
                            Image(imageName).resizable().aspectRatio(contentMode: .fill)
                        } else {
                            // Placeholder no tom: gradiente ferrugem→tinta
                            LinearGradient(
                                colors: [DS.Palette.red700, DS.Palette.ink800],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        }
                    }
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [.clear, DS.Palette.black.opacity(0.85)],
                            startPoint: .center, endPoint: .bottom
                        )
                    )

                    if locked {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(DS.Colors.brass)
                            .padding(DS.Space.sm)
                    }
                }

                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                    Text(title).font(DS.Typography.heading)
                        .foregroundStyle(DS.Colors.textPrimary)
                        .lineLimit(2)
                    Text(subtitle).font(DS.Typography.bodySm)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineLimit(1)
                }
                .padding(DS.Space.md)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(DS.Colors.surface, in: .rect(cornerRadius: DS.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(DS.Colors.border, lineWidth: 1)
            )
            .dsShadow(.md)
        }
        .buttonStyle(.plain)
        // POW: .transition(.movingParts.glare.combined(with: .opacity))
    }
}

// ============================================================
// Badge de nível
// ============================================================

struct LevelBadge: View {
    let level: MWLevel

    var body: some View {
        HStack(spacing: DS.Space.xxs) {
            Image(systemName: level.symbol)
            Text(level.rawValue).font(DS.Typography.caption)
        }
        .foregroundStyle(DS.Palette.ink900)
        .padding(.horizontal, DS.Space.sm)
        .padding(.vertical, DS.Space.xxs)
        .background(DS.Colors.level(level), in: .rect(cornerRadius: DS.Radius.sm))
    }
}
