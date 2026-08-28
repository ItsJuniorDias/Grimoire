//
//  SharedUI.swift
//  Grimoire — componentes compartilhados das telas
//
//  Peças reaproveitadas por Onboarding/Paywall/Home/Favoritos.
//  O elemento-assinatura do app é o SELO DE CERA — a ousadia mora aqui;
//  o resto fica quieto e disciplinado.
//

import SwiftUI

// ============================================================
// Selo de cera — a assinatura visual do Grimoire
// ============================================================

struct WaxSeal: View {
    var letter: String = "G"
    var size: CGFloat = 96
    var pulse: Bool = false

    @State private var animate = false

    var body: some View {
        ZStack {
            // Aro externo irregular (cera derramada)
            Circle()
                .fill(DS.Palette.red600)
                .frame(width: size, height: size)
                .overlay(
                    Circle().stroke(DS.Palette.red700, lineWidth: size * 0.03)
                )
                .overlay(
                    // brilho de cera
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [DS.Palette.red400.opacity(0.9), .clear],
                                center: .init(x: 0.35, y: 0.3),
                                startRadius: 0, endRadius: size * 0.5
                            )
                        )
                )

            // Disco interno prensado
            Circle()
                .fill(DS.Palette.red500)
                .frame(width: size * 0.82, height: size * 0.82)
                .overlay(
                    Circle().stroke(DS.Palette.red700.opacity(0.6), lineWidth: 1)
                )

            // Letra gravada
            Text(letter)
                .font(DS.Typography.display(size * 0.42, .heavy))
                .foregroundStyle(DS.Palette.ink900.opacity(0.85))
                .shadow(color: DS.Palette.red300.opacity(0.5), radius: 0, x: 0, y: -1)
        }
        .dsShadow(.hard)
        .scaleEffect(animate ? 1.0 : (pulse ? 0.94 : 1.0))
        .animation(pulse ? .easeInOut(duration: 2).repeatForever(autoreverses: true) : nil, value: animate)
        .onAppear { if pulse { animate = true } }
    }
}

// ============================================================
// Chip de tag / metadado
// ============================================================

struct GTag: View {
    let text: String
    var icon: String? = nil
    var tint: Color = DS.Colors.textSecondary

    var body: some View {
        HStack(spacing: DS.Space.xxs) {
            if let icon { Image(systemName: icon).font(.system(size: 10, weight: .semibold)) }
            Text(text).font(DS.Typography.caption)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, DS.Space.xs)
        .padding(.vertical, DS.Space.xxs)
        .background(
            Capsule().fill(DS.Colors.surfaceAlt)
        )
        .overlay(
            Capsule().stroke(DS.Colors.border, lineWidth: 1)
        )
    }
}

// ============================================================
// Botão de favoritar — com pop de escala
// ============================================================

struct FavoriteButton: View {
    let isOn: Bool
    let action: () -> Void
    @State private var bump = false

    var body: some View {
        Button {
            action()
            bump = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { bump = false }
        } label: {
            Image(systemName: isOn ? "bookmark.fill" : "bookmark")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isOn ? DS.Colors.accent : DS.Colors.textSecondary)
                .padding(DS.Space.xs)
                .background(Circle().fill(DS.Palette.black.opacity(0.35)))
                .scaleEffect(bump ? 1.35 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: bump)
        }
        .buttonStyle(.plain)
    }
}

// ============================================================
// Barra de progresso de leitura (3 capítulos)
// ============================================================

struct ChapterProgress: View {
    let current: Int   // 0..3
    let total: Int

    var body: some View {
        HStack(spacing: DS.Space.xxs) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i < current ? DS.Colors.accent : DS.Colors.border)
                    .frame(height: 3)
            }
        }
    }
}

// ============================================================
// Cadeado premium
// ============================================================

struct PremiumLock: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(DS.Palette.ink900)
            .padding(DS.Space.xxs)
            .background(Circle().fill(DS.Colors.brass))
    }
}

// ============================================================
// StatusView — estado de erro ou vazio, reutilizável
// ============================================================
//
// Uma peça única para telas de "algo deu errado" e "nada aqui ainda".
// Mantém consistência visual e evita repetir o layout em cada tela.
// A ação é opcional: erros ganham "Try again", vazios podem ter um CTA.

struct StatusView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var actionIcon: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: DS.Space.lg) {
            Spacer()
            ZStack {
                Circle().fill(DS.Colors.surface).frame(width: 96, height: 96)
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(DS.Colors.textMuted)
            }
            VStack(spacing: DS.Space.xs) {
                Text(title)
                    .font(DS.Typography.heading)
                    .foregroundStyle(DS.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(DS.Typography.bodyMd)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Space.xl)
            }
            if let actionTitle, let action {
                GButton(title: actionTitle, variant: .primary, icon: actionIcon) {
                    action()
                }
                .fixedSize()
            }
            Spacer()
            Spacer()
        }
        .padding(DS.Space.lg)
        .frame(maxWidth: .infinity)
    }
}

// ============================================================
// Helpers de nível
// ============================================================

extension StoryLevel {
    var label: String {
        switch self {
        case .apprentice: "Apprentice"
        case .initiate:   "Initiate"
        case .conjurer:   "Conjurer"
        case .archmage:   "Archmage"
        }
    }
    var symbol: String {
        switch self {
        case .apprentice: "flame"
        case .initiate:   "flame.fill"
        case .conjurer:   "sparkles"
        case .archmage:   "crown.fill"
        }
    }
    var color: Color {
        switch self {
        case .apprentice: DS.Colors.textSecondary
        case .initiate:   DS.Colors.moss
        case .conjurer:   DS.Colors.night
        case .archmage:   DS.Colors.brass
        }
    }
}

extension StoryCover {
    /// Converte o hex "#RRGGBB" do JSON pra Color.
    var accentColor: Color {
        let hex = accent.hasPrefix("#") ? String(accent.dropFirst()) : accent
        var v: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&v)
        return Color(hex: UInt(v))
    }
}
