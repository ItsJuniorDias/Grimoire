//
//  GrimoireApp.swift
//  Grimoire
//

import SwiftUI

@main
struct GrimoireApp: App {
    @State private var app = AppState()
    @State private var store = SubscriptionStore()
    @State private var analytics = Analytics()
    @State private var notifications = NotificationsManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(store)
                .environment(analytics)
                .environment(notifications)
                .preferredColorScheme(.dark)   // Grimoire nasce no escuro
                .task {
                    analytics.track(.app_opened)
                    // Reprograma tudo no launch — cobre "usuário mudou hora do
                    // sistema", "app ficou dias fechado", "instalou update".
                    await notifications.sync(app: app)
                }
                // Quando a pessoa lê algo hoje, `lastReadDay` muda pra hoje.
                // Isso dispara re-sync que CANCELA o streak-risk das 21h —
                // não faz sentido avisar "streak em risco" se ela já leu.
                .onChange(of: app.lastReadDay) { _, _ in
                    Task { await notifications.sync(app: app) }
                }
                // Deep links do widget: URL vira signal no AppState, que as
                // views consomem. Parsing centralizado aqui pra ter um único
                // ponto de mapeamento URL → estado.
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            // Ao voltar pro app, revalida a semana (as 3 podem ter rodado) e
            // o streak (pode ter quebrado por inatividade). Notificações também
            // reprograma — cobre o caso do usuário ter mudado permissão em
            // Ajustes enquanto o app estava em background.
            if phase == .active {
                app.refreshWeeklyFree()
                app.refreshStreakOnForeground()
                Task { await notifications.sync(app: app) }
            }
        }
    }

    /// Traduz `grimoire://…` em signals de navegação. Formatos aceitos:
    ///   grimoire://home         → tab Home
    ///   grimoire://profile      → tab Profile (Your Path)
    ///   grimoire://favorites    → tab Favorites
    ///   grimoire://story/<id>   → tab Home + push da história
    /// URLs desconhecidas são ignoradas silenciosamente.
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "grimoire", let host = url.host else { return }
        switch host {
        case "home":       app.pendingTab = "home"
        case "profile":    app.pendingTab = "profile"
        case "favorites":  app.pendingTab = "favorites"
        case "story":
            // pathComponents inclui "/" — filtra fora.
            let id = url.pathComponents.first(where: { $0 != "/" }) ?? ""
            guard !id.isEmpty else { return }
            app.pendingTab = "home"       // muda pra Home antes de empurrar
            app.pendingStoryID = id
        default:
            break
        }
    }
}
