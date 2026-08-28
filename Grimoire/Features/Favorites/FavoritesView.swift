//
//  FavoritesView.swift
//  Grimoire — Favoritos
//
//  Grid de duas colunas com as histórias guardadas. Empty state é um
//  convite à ação, não enfeite. Tocar no marcador remove (com desfazer
//  implícito: é só tocar de novo no card na Home).
//

import SwiftUI

struct FavoritesView: View {
    @Environment(AppState.self) private var app
    @Environment(SubscriptionStore.self) private var store
    var goToHome: () -> Void

    @State private var path: [String] = []
    @State private var showPaywall = false

    private let columns = [
        GridItem(.flexible(), spacing: DS.Space.md),
        GridItem(.flexible(), spacing: DS.Space.md)
    ]

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if app.favoriteStories.isEmpty {
                    emptyState
                } else {
                    grid
                }
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
    }

    // MARK: Grid

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: DS.Space.lg) {
                ForEach(app.favoriteStories) { s in
                    FavoriteCard(
                        summary: s,
                        locked: !app.isUnlocked(s, isPro: store.isPro),
                        onTap: { path.append(s.id) },
                        onRemove: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                app.toggleFavorite(s.id)
                            }
                        }
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(DS.Space.lg)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: Empty

    private var emptyState: some View {
        StatusView(
            icon: "bookmark",
            title: "Nothing saved yet",
            message: "Tap the bookmark on a story to save it here and read whenever you like.",
            actionTitle: "Explore stories",
            actionIcon: "books.vertical.fill",
            action: { goToHome() }
        )
    }
}

// ============================================================
// Card de favorito
// ============================================================

struct FavoriteCard: View {
    let summary: StorySummary
    var locked: Bool
    var onTap: () -> Void
    var onRemove: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                ZStack(alignment: .topTrailing) {
                    CoverArt(story: summary, height: 150)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    HStack {
                        if locked { PremiumLock() }
                        Spacer()
                        FavoriteButton(isOn: true, action: onRemove)
                    }
                    .padding(DS.Space.xs)
                }
                Text(summary.title)
                    .font(DS.Typography.bodyMd.bold())
                    .foregroundStyle(DS.Colors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: DS.Space.xxs) {
                    Image(systemName: summary.level.symbol).font(.system(size: 9))
                        .foregroundStyle(summary.level.color)
                    Text("\(summary.readingMinutes) min")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
