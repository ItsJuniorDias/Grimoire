//
//  PaywallView.swift
//  Grimoire — Paywall (StoreKit 2)
//
//  Mensal + anual, anual pré-selecionado com selo de economia. Value
//  props do lado do usuário. Preço e trial vêm dos Product reais.
//  Fecha sozinho quando isPro vira true.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    var onClose: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionStore.self) private var store
    @Environment(Analytics.self) private var analytics

    @State private var selected = GrimoireProduct.annual
    @State private var working = false

    private let valueProps: [(icon: String, title: LocalizedStringKey, sub: LocalizedStringKey)] = [
        ("books.vertical.fill", "All 50 stories", "The whole grimoire, always unlocked"),
        ("moon.stars.fill",     "Made for the night",     "Rich ten-minute tales, perfect before bed"),
        ("bookmark.fill",       "Favorites and progress", "Save what you love and pick up where you left off"),
        ("nosign",              "No ads",                 "Nothing interrupts the reading")
    ]

    var body: some View {
        ZStack {
            DS.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: DS.Space.xl) {
                    hero            // imagem de fundo já traz o brilho + título
                    Group {
                        props
                        plans
                        cta
                        legal
                    }
                    .padding(.horizontal, DS.Space.lg)
                }
                .padding(.bottom, DS.Space.xl)
            }
            .scrollIndicators(.hidden)

            // Botão fechar flutua por cima do hero
            VStack {
                closeRow
                Spacer()
            }
        }
        .task {
            if store.products.isEmpty { await store.load() }
            analytics.track(.paywall_viewed)
        }
        .onChange(of: store.isPro) { _, pro in
            if pro {
                analytics.track(.purchase_completed, ["plan": selected])
                close()
            }
        }
        // Garante que a seleção aponte pra um produto REAL assim que os planos
        // carregam. Sem isso, 'selected' pode ficar num id que não existe em
        // store.products e o botão de compra falha silenciosamente.
        .onChange(of: store.products.map(\.id)) { _, ids in
            if !ids.contains(selected) {
                selected = store.annual?.id ?? store.monthly?.id ?? ids.first ?? selected
            }
        }
        .onAppear {
            let ids = store.products.map(\.id)
            if !ids.isEmpty, !ids.contains(selected) {
                selected = store.annual?.id ?? store.monthly?.id ?? ids.first ?? selected
            }
        }
    }

    private var closeRow: some View {
        HStack {
            Spacer()
            Button {
                close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .padding(DS.Space.xs)
                    .background(Circle().fill(DS.Palette.black.opacity(0.4)))
            }
            .padding(.trailing, DS.Space.lg)
        }
        .padding(.top, DS.Space.sm)
    }

    // Hero com a arte gerada de fundo; título ancorado na base da imagem
    private var hero: some View {
        ZStack(alignment: .bottom) {
            Image("PaywallHero")
                .resizable()
                .scaledToFill()
                .frame(height: 460)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(
                    // Blend mais suave: começa cedo, várias paradas até o preto
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: DS.Palette.ink900.opacity(0.15), location: 0.45),
                            .init(color: DS.Palette.ink900.opacity(0.55), location: 0.72),
                            .init(color: DS.Palette.ink900.opacity(0.9), location: 0.9),
                            .init(color: DS.Palette.ink900, location: 1.0),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            VStack(spacing: DS.Space.xxs) {
                Text("Grimoire Pro")
                    .font(DS.Typography.display(34, .bold))
                    .foregroundStyle(DS.Colors.textPrimary)
                    .shadow(color: DS.Palette.black.opacity(0.8), radius: 8)
                Text("Unlock the whole grimoire")
                    .font(DS.Typography.bodyMd)
                    .foregroundStyle(DS.Colors.textPrimary.opacity(0.85))
                    .shadow(color: DS.Palette.black.opacity(0.8), radius: 5)
            }
            .padding(.bottom, DS.Space.xl)
        }
    }

    private var props: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            ForEach(valueProps, id: \.icon) { p in
                HStack(spacing: DS.Space.md) {
                    Image(systemName: p.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Colors.accent)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(DS.Colors.accent.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.title).font(DS.Typography.bodyMd)
                            .foregroundStyle(DS.Colors.textPrimary)
                        Text(p.sub).font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Space.md)
        .background(DS.Colors.surface.opacity(0.5), in: .rect(cornerRadius: DS.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(DS.Colors.border.opacity(0.6), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var plans: some View {
        if store.loading && store.products.isEmpty {
            VStack(spacing: DS.Space.sm) {
                ProgressView().tint(DS.Colors.accent)
                Text("Loading plans…")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(DS.Space.xl)
        } else if store.products.isEmpty {
            VStack(spacing: DS.Space.sm) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 26))
                    .foregroundStyle(DS.Colors.textMuted)
                Text("Plans unavailable")
                    .font(DS.Typography.bodyMd.bold())
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(store.purchaseError ?? "Check your connection and try again.")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Try again") { Task { await store.load() } }
                    .font(DS.Typography.bodySm.bold())
                    .foregroundStyle(DS.Colors.accent)
                    .padding(.top, DS.Space.xxs)
            }
            .frame(maxWidth: .infinity)
            .padding(DS.Space.lg)
            .background(DS.Colors.surface.opacity(0.5), in: .rect(cornerRadius: DS.Radius.lg))
        } else {
            VStack(spacing: DS.Space.sm) {
                if let annual = store.annual {
                    planRow(
                        product: annual,
                        title: "Annual",
                        priceLine: annual.displayPrice,
                        caption: store.annualPerMonth.map { LocalizedStringKey("\($0)/mo · billed once a year") },
                        badge: store.annualSavingsPercent.map { "-\($0)%" },
                        trial: trialText(annual)
                    )
                }
                if let monthly = store.monthly {
                    planRow(
                        product: monthly,
                        title: "Monthly",
                        priceLine: "\(monthly.displayPrice)/mo",
                        caption: "billed monthly",
                        badge: nil,
                        trial: trialText(monthly)
                    )
                }
            }
        }
    }

    private func planRow(product: Product, title: LocalizedStringKey, priceLine: String,
                         caption: LocalizedStringKey?, badge: String?, trial: String?) -> some View {
        let isSel = selected == product.id
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selected = product.id }
        } label: {
            HStack(spacing: DS.Space.md) {
                // radio
                ZStack {
                    Circle().stroke(isSel ? DS.Colors.accent : DS.Colors.border, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSel {
                        Circle().fill(DS.Colors.accent).frame(width: 12, height: 12)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DS.Space.xs) {
                        Text(title).font(DS.Typography.subtitle)
                            .foregroundStyle(DS.Colors.textPrimary)
                        if let badge {
                            Text(badge).font(DS.Typography.caption.bold())
                                .foregroundStyle(DS.Palette.ink900)
                                .padding(.horizontal, DS.Space.xs)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(DS.Colors.brass))
                        }
                    }
                    if let trial {
                        Text(trial).font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.accent)
                    }
                    if let caption {
                        Text(caption).font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                }
                Spacer()
                Text(priceLine).font(DS.Typography.bodyMd.bold())
                    .foregroundStyle(DS.Colors.textPrimary)
            }
            .padding(DS.Space.md)
            .background(DS.Colors.surface, in: .rect(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(isSel ? DS.Colors.accent : DS.Colors.border, lineWidth: isSel ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var cta: some View {
        VStack(spacing: DS.Space.sm) {
            GButton(title: working ? "Processing…" : ctaTitle, variant: .primary) {
                Task { await buy() }
            }
            .disabled(working || store.products.isEmpty)
            .opacity(working ? 0.7 : 1)

            Button("Restore purchases") { Task { await store.restore() } }
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textSecondary)

            if let err = store.purchaseError {
                Text(err).font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.danger)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var legal: some View {
        // "Terms" e "Privacy Policy" viram links clicáveis (exigência da Apple
        // para apps com assinatura). Markdown dentro do texto cria os links.
        let terms = "https://www.notion.so/Grimoire-Terms-of-use-Support-3c72f13e5f7d8071a473eae870a80496"
        let privacy = "https://www.notion.so/Grimoire-Privacy-Policy-3c72f13e5f7d80dea134d6ef542fe560"
        // String(localized:) resolve os %@ na ordem do idioma; alguns
        // invertem a ordem dos dois links. AttributedString(markdown:) pode
        // lançar se a tradução tiver colchete solto — o `try?` cai num Text
        // simples em vez de derrubar o paywall.
        let raw = String(localized: "The subscription renews automatically until canceled. Cancel anytime in Settings. By continuing, you accept the [Terms of Use](\(terms)) and [Privacy Policy](\(privacy)).")
        let text = (try? AttributedString(markdown: raw)) ?? AttributedString(raw)
        return Text(text)
            .font(.system(size: 10))
            .foregroundStyle(DS.Colors.textMuted)
            .tint(DS.Colors.accent)               // cor dos links (vermelho Hellboy)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DS.Space.sm)
    }

    private var ctaTitle: LocalizedStringKey {
        if let p = store.products.first(where: { $0.id == selected }), trialText(p) != nil {
            return "Start free trial"
        }
        return "Subscribe now"
    }

    private func trialText(_ product: Product) -> String? {
        guard let offer = product.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        // Sem concatenar "s": plural não se forma assim em todo idioma.
        // Cada forma é uma chave própria no catálogo.
        let n = offer.period.value
        switch offer.period.unit {
        case .day:
            return n > 1 ? String(localized: "\(n) days free")
                         : String(localized: "\(n) day free")
        case .week:  return String(localized: "\(n * 7) days free")
        case .month:
            return n > 1 ? String(localized: "\(n) months free")
                         : String(localized: "\(n) month free")
        case .year:  return String(localized: "1 year free")
        @unknown default: return String(localized: "Free trial")
        }
    }

    private func buy() async {
        // Usa o plano selecionado; se por algum motivo não bater com um produto
        // carregado, cai pro anual, depois mensal, depois o primeiro disponível.
        let product = store.products.first(where: { $0.id == selected })
            ?? store.annual ?? store.monthly ?? store.products.first
        guard let product else {
            store.purchaseError = String(localized: "Plans aren't ready yet. Please try again in a moment.")
            return
        }
        selected = product.id
        working = true
        defer { working = false }
        analytics.track(.purchase_started, ["plan": product.id])
        let ok = await store.purchase(product)
        // Se retornou false E o store setou um erro, foi falha real (não userCancelled/pending).
        if !ok, let err = store.purchaseError {
            analytics.track(.purchase_failed, ["plan": product.id, "error": err])
        }
    }

    private func close() {
        onClose?()
        dismiss()
    }
}

#Preview {
    PaywallView()
        .environment(SubscriptionStore())
        .preferredColorScheme(.dark)
}
