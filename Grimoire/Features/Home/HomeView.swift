//
//  HomeView.swift
//  Grimoire — Home
//
//  Estrutura: saudação + "continue lendo" (se houver progresso), história
//  em destaque, e trilhas horizontais agrupadas por nível. Cards levam ao
//  StoryDetailView. Premium bloqueado abre o paywall.
//

import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var app
    @Environment(SubscriptionStore.self) private var store

    @State private var path: [String] = []   // pilha de story ids
    @State private var showPaywall = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if app.catalog.isEmpty, app.loadError != nil {
                    // Catálogo não carregou — erro com opção de tentar de novo.
                    StatusView(
                        icon: "exclamationmark.triangle",
                        title: "Something went wrong",
                        message: "We couldn't load the stories. Please try again.",
                        actionTitle: "Try again",
                        actionIcon: "arrow.clockwise",
                        action: { app.loadCatalog() }
                    )
                    .background(DS.Colors.background.ignoresSafeArea())
                } else {
                    homeList
                }
            }
            .navigationDestination(for: String.self) { id in
                if let s = app.summary(id: id) {
                    StoryDetailView(summary: s, openPaywall: { showPaywall = true })
                        .toolbar(.hidden, for: .tabBar, .bottomBar)
                }
            }
        }
        .tint(DS.Colors.accent)
        .sheet(isPresented: $showPaywall) {
            PaywallView { showPaywall = false }
                .environment(store)
                .presentationDragIndicator(.visible)
        }
        .onChange(of: app.showPaywall) { _, wants in
            if wants { showPaywall = true; app.showPaywall = false }
        }
        .onAppear {
            if app.showPaywall { showPaywall = true; app.showPaywall = false }
            consumeWidgetDeepLink()
        }
        // Widget → story: quando o widget pede pra abrir uma história, o
        // AppState grava o id. HomeView empurra na navigation stack e limpa.
        .onChange(of: app.pendingStoryID) { _, _ in consumeWidgetDeepLink() }
    }

    /// Consome `pendingStoryID` empurrando a story na pilha. Robusto contra
    /// (a) history já apontando pra mesma story (evita duplicata) e (b) id
    /// que não existe mais no catálogo (limpa sem crash).
    private func consumeWidgetDeepLink() {
        guard let id = app.pendingStoryID else { return }
        defer { app.pendingStoryID = nil }
        guard app.summary(id: id) != nil else { return }
        if path.last != id { path.append(id) }
    }

    private var homeList: some View {
            List {
                // Header como PRIMEIRA LINHA da lista (não como Section header,
                // que ficaria fixo/pinned no topo). Como linha, rola junto com o
                // conteúdo E tem hit-testing próprio de célula — então o botão
                // Pro recebe o toque sem competir com o gesto de scroll.
                greeting
                    .listRowInsets(EdgeInsets(top: DS.Space.sm, leading: 0, bottom: 0, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                // Destaque das 3 histórias grátis da semana (só para quem não é Pro).
                if !store.isPro, !weeklyStories.isEmpty {
                    freeThisWeekSection
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                if let cont = continueStory {
                    continueCard(cont)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                if let feat = featuredStory {
                    featuredCard(feat)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                ForEach(app.byLevel, id: \.level) { group in
                    levelRail(group.level, group.stories)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .listRowSpacing(DS.Space.xl)
            .scrollContentBackground(.hidden)          // remove o fundo padrão da List
            .scrollIndicators(.hidden)                 // esconde a barra de scroll
            .background(DS.Colors.background.ignoresSafeArea())
    }

    // MARK: Saudação

    private var greeting: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Grimoire")
                    .font(DS.Typography.display(30, .bold))
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(store.isPro ? "Welcome back" : "\(app.weeklyFreeIDs.count) free stories this week")
                    .font(DS.Typography.bodySm)
                    .foregroundStyle(DS.Colors.textSecondary)
            }
            Spacer()
            if !store.isPro {
                Button { showPaywall = true } label: {
                    HStack(spacing: DS.Space.xxs) {
                        Image(systemName: "crown.fill").font(.system(size: 11))
                        Text("Pro").font(DS.Typography.caption.bold())
                    }
                    .foregroundStyle(DS.Palette.ink900)
                    .padding(.horizontal, DS.Space.sm)
                    .padding(.vertical, DS.Space.xs)
                    .background(Capsule().fill(DS.Colors.brass))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Space.lg)
    }

    // MARK: Continue lendo

    private var continueStory: StorySummary? {
        app.catalog
            .filter { app.isStarted($0.id) && !app.isFinished($0.id) }
            .max { app.lastChapter(of: $0.id) < app.lastChapter(of: $1.id) }
    }

    private func continueCard(_ s: StorySummary) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            Text("CONTINUE READING")
                .font(DS.Typography.caption).tracking(3)
                .foregroundStyle(DS.Colors.textMuted)
                .padding(.horizontal, DS.Space.lg)

            Button { open(s) } label: {
                HStack(spacing: DS.Space.md) {
                    CoverArt(story: s, height: 88)
                        .frame(width: 66)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        Text(s.localizedTitle).font(DS.Typography.subtitle)
                            .foregroundStyle(DS.Colors.textPrimary)
                            .lineLimit(1)
                        Text("Chapter \(app.lastChapter(of: s.id) + 1) of 3")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                        ChapterProgress(current: app.lastChapter(of: s.id), total: 3)
                    }
                    Spacer()
                    Image(systemName: "play.fill")
                        .foregroundStyle(DS.Palette.paper)
                        .padding(DS.Space.sm)
                        .background(Circle().fill(DS.Colors.accent))
                }
                .padding(DS.Space.md)
                .background(DS.Colors.surface, in: .rect(cornerRadius: DS.Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).stroke(DS.Colors.border, lineWidth: 1))
                .dsShadow(.md)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DS.Space.lg)
        }
    }

    // MARK: Destaque

    private var featuredStory: StorySummary? { app.catalog.first }

    /// As 3 histórias grátis desta semana, resolvidas do catálogo.
    private var weeklyStories: [StorySummary] {
        app.catalog.filter { app.weeklyFreeIDs.contains($0.id) }
    }

    /// Seção de destaque das grátis da semana — cria descoberta e urgência.
    private var freeThisWeekSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.xs) {
                Image(systemName: "gift.fill").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(DS.Colors.brass)
                Text("FREE THIS WEEK")
                    .font(DS.Typography.caption).tracking(3)
                    .foregroundStyle(DS.Colors.brass)
                Spacer()
                Text("rotates weekly")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textMuted)
            }
            .padding(.horizontal, DS.Space.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Space.md) {
                    ForEach(weeklyStories) { s in
                        Button { open(s) } label: {
                            ZStack(alignment: .bottomLeading) {
                                CoverArt(story: s, height: 200, isFocused: true)
                                    .frame(width: 300)
                                VStack(alignment: .leading, spacing: DS.Space.xxs) {
                                    HStack(spacing: DS.Space.xs) {
                                        GTag(text: s.level.label, icon: s.level.symbol, tint: s.level.color)
                                        GTag(text: String(localized: "\(s.readingMinutes) min"), icon: "clock")
                                    }
                                    Text(s.localizedTitle)
                                        .font(DS.Typography.display(20, .bold))
                                        .foregroundStyle(DS.Palette.paper)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(DS.Space.md)
                            }
                            .frame(width: 300)
                            .background(DS.Colors.surface)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                            .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg)
                                .stroke(DS.Colors.brass.opacity(0.6), lineWidth: 1.5))
                            .dsShadow(.lg)
                            .overlay(alignment: .topTrailing) {
                                Text("FREE")
                                    .font(.system(size: 10, weight: .heavy))
                                    .tracking(1)
                                    .foregroundStyle(DS.Palette.ink900)
                                    .padding(.horizontal, DS.Space.xs)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(DS.Colors.brass))
                                    .padding(DS.Space.sm)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.Space.lg)
            }
        }
    }

    private func featuredCard(_ s: StorySummary) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            Text("FEATURED")
                .font(DS.Typography.caption).tracking(3)
                .foregroundStyle(DS.Colors.textMuted)
                .padding(.horizontal, DS.Space.lg)

            Button { open(s) } label: {
                ZStack(alignment: .bottomLeading) {
                    CoverArt(story: s, height: 230, isFocused: true)
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        HStack(spacing: DS.Space.xs) {
                            GTag(text: s.level.label, icon: s.level.symbol, tint: s.level.color)
                            if let t = s.tags.first { GTag(text: t.localizedContent) }
                        }
                        Text(s.localizedTitle)
                            .font(DS.Typography.display(26, .bold))
                            .foregroundStyle(DS.Palette.paper)
                            .lineLimit(2)
                        Text(s.localizedSummary)
                            .font(DS.Typography.bodySm)
                            .foregroundStyle(DS.Palette.paper.opacity(0.85))
                            .lineLimit(2)
                    }
                    .padding(DS.Space.md)
                }
                .background(DS.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg).stroke(DS.Colors.border, lineWidth: 1))
                .dsShadow(.lg)
                .overlay(alignment: .topTrailing) {
                    if !app.isUnlocked(s, isPro: store.isPro) { PremiumLock().padding(DS.Space.sm) }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, DS.Space.lg)
        }
    }

    // MARK: Trilha por nível

    private func levelRail(_ level: StoryLevel, _ stories: [StorySummary]) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            HStack(spacing: DS.Space.xs) {
                Image(systemName: level.symbol).font(.system(size: 12, weight: .bold))
                    .foregroundStyle(level.color)
                Text(level.label)
                    .font(DS.Typography.heading)
                    .foregroundStyle(DS.Colors.textPrimary)
            }
            .padding(.horizontal, DS.Space.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Space.md) {
                    ForEach(stories) { s in
                        StoryTile(summary: s,
                                  locked: !app.isUnlocked(s, isPro: store.isPro),
                                  isFavorite: app.isFavorite(s.id),
                                  onTap: { open(s) },
                                  onFav: { app.toggleFavorite(s.id) })
                    }
                }
                .padding(.horizontal, DS.Space.lg)
            }
        }
    }

    // MARK: Navegação

    private func open(_ s: StorySummary) {
        path.append(s.id)
    }
}

// ============================================================
// Tile de história (card do carrossel)
// ============================================================

struct StoryTile: View {
    let summary: StorySummary
    var locked: Bool
    var isFavorite: Bool
    var onTap: () -> Void
    var onFav: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                ZStack(alignment: .topTrailing) {
                    CoverArt(story: summary, height: 180)
                        .frame(width: 150)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    VStack {
                        FavoriteButton(isOn: isFavorite, action: onFav)
                        Spacer()
                        if locked { PremiumLock() }
                    }
                    .padding(DS.Space.xs)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(width: 150)

                Text(summary.localizedTitle)
                    .font(DS.Typography.bodyMd.bold())
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(width: 150, alignment: .leading)

                HStack(spacing: DS.Space.xxs) {
                    Image(systemName: "clock").font(.system(size: 9))
                    Text("\(summary.readingMinutes) min")
                        .font(DS.Typography.caption)
                }
                .foregroundStyle(DS.Colors.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}
