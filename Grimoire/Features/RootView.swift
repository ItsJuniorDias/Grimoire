//
//  RootView.swift
//  Grimoire — raiz
//
//  TabView nativo do iOS 26 com barra Liquid Glass. A barra flutuante de
//  vidro some sozinha ao empilhar navegação (detalhe/leitor), então não
//  precisamos mais esconder nada na mão. Item ativo usa o accent do app,
//  que já é o vermelho Hellboy. .tabBarMinimizeBehavior encolhe a barra
//  quando o usuário rola pra baixo, liberando tela pra leitura.
//

import SwiftUI
// Pelo `.translationTask`, que é extensão de View vinda daqui.
import Translation

enum AppTab: Hashable {
    case home, favorites, profile
}

struct RootView: View {
    @Environment(AppState.self) private var app
    @Environment(SubscriptionStore.self) private var store

    @State private var selection: AppTab = .home

    var body: some View {
        Group {
            if !app.hasSeenOnboarding {
                OnboardingView {
                    withAnimation(.easeInOut) { app.hasSeenOnboarding = true }
                    if !store.isPro { app.showPaywall = true }
                }
                .transition(.opacity)
            } else {
                tabs.transition(.opacity)
            }
        }
        .task { if store.products.isEmpty { await store.load() } }
        // Tradução do catálogo (título, sinopse, título de capítulo, tag).
        //
        // Fica na raiz porque `.translationTask` precisa de uma view viva
        // para vender a sessão, e esta é a única que existe em toda a vida do
        // app — inclusive durante o onboarding, para que a Home já apareça
        // traduzida quando a pessoa chegar nela.
        //
        // `configuration` é nil na maioria das aberturas — app em inglês, ou
        // catálogo já traduzido e lido do cache no init — e então isto não
        // faz nada. Ver Core/CatalogTranslation.swift.
        .translationTask(CatalogTranslation.shared.configuration) { session in
            await CatalogTranslation.shared.run(session: session)
        }
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "book.closed.fill", value: .home) {
                HomeView()
            }
            Tab("Favorites", systemImage: "bookmark.fill", value: .favorites) {
                FavoritesView(goToHome: { selection = .home })
            }
            Tab("Your Path", systemImage: "flame.fill", value: .profile) {
                ProfileView()
            }
        }
        .tint(DS.Colors.accent)                       // item ativo em vermelho Hellboy
        .tabBarMinimizeBehavior(.onScrollDown)        // encolhe ao rolar (iOS 26)
        // Widget → tab: reage a `pendingTab` do AppState (setado pelo deep
        // link handler no GrimoireApp). Consome o signal em seguida pra não
        // re-navegar em rebuilds.
        .onChange(of: app.pendingTab) { _, requested in
            guard let requested else { return }
            switch requested {
            case "home":       selection = .home
            case "favorites":  selection = .favorites
            case "profile":    selection = .profile
            default:           break
            }
            app.pendingTab = nil
        }
    }
}
