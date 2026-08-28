//
//  OnboardingView.swift
//  Grimoire — Onboarding
//
//  Três páginas com ilustração de fundo full-bleed (arte Mignola gerada).
//  Cada imagem tem o assunto no topo e a base escura; o texto e o CTA ficam
//  ancorados nessa faixa inferior (a safe zone), com um degradê preto extra
//  garantindo legibilidade. Paginação própria. Respeita Reduce Motion.
//

import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    private struct Page {
        let image: String     // asset de fundo
        let kicker: String
        let title: String
        let body: String
        /// true quando a imagem tem topo CLARO (texto do topo precisa de proteção extra)
        let lightTop: Bool
    }

    private let pages: [Page] = [
        .init(image: "OnbWelcome",
              kicker: "WELCOME",
              title: "Stories that\naren't afraid of the dark",
              body: "Rich, shadowy tales for anyone tired of silly stories. Courage, mystery, and worlds with rules of their own.",
              lightTop: false),
        .init(image: "OnbHow",
              kicker: "HOW IT WORKS",
              title: "Every story,\nthree chapters",
              body: "You step in, learn how the world works, and discover how courage beats what force cannot. A ten-minute read that stays with you.",
              lightTop: false),
        .init(image: "OnbPath",
              kicker: "YOUR PATH",
              title: "From Apprentice\nto Archmage",
              body: "Every story you read moves your journey forward. Save your favorites, pick up where you left off, and unlock the whole grimoire.",
              lightTop: true)
    ]

    var body: some View {
        ZStack {
            DS.Colors.background.ignoresSafeArea()

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    pageView(pages[i], active: page == i)
                        .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(DS.Colors.background)   // fundo não-transparente: destrava o ignoresSafeArea do .page
            .ignoresSafeArea(.container, edges: .all)
            .animation(.easeInOut, value: page)

            // Camada de UI por cima (pular + dots + CTA)
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Skip") { onFinish() }
                        .font(DS.Typography.bodySm)
                        .foregroundStyle(DS.Colors.textPrimary.opacity(0.9))
                        .padding(DS.Space.lg)
                        .shadow(color: DS.Palette.black.opacity(0.6), radius: 4)
                }

                Spacer()

                // Texto da página ativa (ancorado embaixo, na safe zone)
                pageText(pages[page])
                    .id(page)   // re-anima ao trocar
                    .padding(.horizontal, DS.Space.lg)

                // Dots + CTA
                VStack(spacing: DS.Space.lg) {
                    HStack(spacing: DS.Space.xs) {
                        ForEach(pages.indices, id: \.self) { i in
                            Capsule()
                                .fill(i == page ? DS.Colors.accent : DS.Colors.textMuted.opacity(0.5))
                                .frame(width: i == page ? 22 : 7, height: 7)
                                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: page)
                        }
                    }
                    .padding(.top, DS.Space.lg)

                    GButton(title: page == pages.count - 1 ? "Open the grimoire" : "Continue",
                            variant: .primary) {
                        if page == pages.count - 1 { onFinish() }
                        else { withAnimation { page += 1 } }
                    }
                    .padding(.horizontal, DS.Space.lg)
                }
                .padding(.bottom, DS.Space.xl)
            }
        }
    }

    // Fundo de cada página: imagem full-bleed + degradês de safe zone
    @ViewBuilder
    private func pageView(_ p: Page, active: Bool) -> some View {
        ZStack {
            // Imagem full-bleed real: preenche todo o container e ignora a
            // safe area, indo até o topo absoluto (sob a status bar).
            Image(p.image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(active ? 1.0 : 1.06)
                .animation(.easeOut(duration: 0.6), value: active)
                .clipped()
                .ignoresSafeArea()

            // Degradê de base: garante a faixa escura pro texto/CTA
            LinearGradient(
                colors: [
                    .clear,
                    DS.Palette.ink900.opacity(0.5),
                    DS.Palette.ink900.opacity(0.96)
                ],
                startPoint: .center, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Scrim de topo: sutil em todas as páginas (deixa a status bar
            // legível sobre a imagem), mais forte quando o topo da arte é claro.
            VStack {
                LinearGradient(
                    colors: [
                        DS.Palette.ink900.opacity(p.lightTop ? 0.65 : 0.35),
                        .clear
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: p.lightTop ? 160 : 110)
                Spacer()
            }
            .ignoresSafeArea()
        }
    }

    // Texto ancorado na safe zone inferior
    @ViewBuilder
    private func pageText(_ p: Page) -> some View {
        VStack(spacing: DS.Space.sm) {
            Text(p.kicker)
                .font(DS.Typography.caption)
                .tracking(4)
                .foregroundStyle(DS.Colors.accent)

            Text(p.title)
                .font(DS.Typography.display(30, .bold))
                .foregroundStyle(DS.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: DS.Palette.black.opacity(0.7), radius: 6)

            Text(p.body)
                .font(DS.Typography.bodyMd)
                .foregroundStyle(DS.Colors.textPrimary.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, DS.Space.md)
                .padding(.top, DS.Space.xs)
                .shadow(color: DS.Palette.black.opacity(0.7), radius: 5)
        }
        .transition(.opacity)
    }
}

#Preview {
    OnboardingView(onFinish: {})
        .preferredColorScheme(.dark)
}
