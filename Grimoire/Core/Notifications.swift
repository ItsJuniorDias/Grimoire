//
//  Notifications.swift
//  Grimoire — lembretes locais
//
//  Gerencia três tipos de notificação local, todas agendadas SEM servidor:
//
//    1. Lembrete diário     — no horário escolhido pelo usuário (default 20:00).
//    2. Nova semana grátis  — toda segunda 09:00 (rotação do WeeklyFreeStories).
//    3. Streak em risco     — one-shot pras 21:00 do dia, se o usuário tem
//                             streak ≥ 2 e ainda não leu hoje.
//
//  Design:
//  - Identifiers fixos (um por tipo). Reagendar substitui o anterior — nunca
//    ficamos com duas dailies pendentes.
//  - `sync(app:)` é a ÚNICA porta pra reprogramar: cancela tudo e reagenda
//    baseado no estado atual. Chamado no launch, foreground e após leitura.
//  - Nunca pede permissão automaticamente. Só via toggle explícito em Profile.
//  - Falha silenciosamente: se o sistema recusa, o toggle volta pra off e o
//    Profile mostra o link pra Ajustes.
//

import SwiftUI
import UserNotifications

@MainActor
@Observable
final class NotificationsManager {

    /// Status atual de autorização — cacheado pra UI reagir sem async.
    /// Refrescado no init, no foreground e após pedir permissão.
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    /// Identifiers fixos. Reagendar com o mesmo id substitui o pendente.
    private enum ID {
        static let daily  = "grimoire.notif.daily"
        static let weekly = "grimoire.notif.weekly"
        static let streak = "grimoire.notif.streak"
    }

    private let center = UNUserNotificationCenter.current()

    init() {
        Task { await refreshAuthorizationStatus() }
    }

    // MARK: - Autorização

    /// Lê o status do sistema e cacheia. Chame no init, no foreground e
    /// depois de qualquer `requestAuthorization`.
    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Pede permissão ao sistema. Retorna se o usuário concedeu.
    /// Se já tinha sido decidido, retorna o resultado sem popup.
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            await refreshAuthorizationStatus()
            return false
        }
    }

    /// Abre a página do app em Ajustes → Notificações (pra reverter negação).
    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Sync — a única porta de reprogramação

    /// Cancela TODAS as pendentes e reagenda baseado no estado atual do app +
    /// preferências do usuário. Idempotente: rodar duas vezes seguidas dá o
    /// mesmo resultado. Chamado no launch, foreground e após leitura.
    func sync(app: AppState) async {
        // Sempre cancela tudo antes — evita órfãos de configurações antigas.
        center.removePendingNotificationRequests(
            withIdentifiers: [ID.daily, ID.weekly, ID.streak]
        )

        await refreshAuthorizationStatus()

        // Sem permissão OU toggle mestre off → não agenda nada.
        guard authorizationStatus == .authorized || authorizationStatus == .provisional,
              app.notificationsEnabled else { return }

        // Cada sub-preferência controla o seu agendamento.
        // Daily não tem toggle próprio (é o "principal") — sempre agenda se
        // o mestre está on. Se quiser desligar, o usuário desliga o mestre.
        scheduleDaily(hour: app.dailyReminderHour)

        if app.weeklyRefreshEnabled {
            scheduleWeekly()
        }

        if app.streakRiskEnabled {
            scheduleStreakRiskIfNeeded(streakCount: app.streakCount,
                                       hasReadToday: app.hasReadToday)
        }
    }

    // MARK: - Agendadores individuais

    /// Lembrete diário recorrente no horário escolhido. Copy fixa e curta —
    /// "chamada a um ritual", não anúncio publicitário.
    private func scheduleDaily(hour: Int) {
        let content = UNMutableNotificationContent()
        content.title = "A story before sleep?"
        content.body  = "Five quiet minutes with the grimoire."
        content.sound = .default

        var comps = DateComponents()
        comps.hour = max(0, min(23, hour))
        comps.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: ID.daily, content: content, trigger: trigger)
        center.add(request) { _ in }
    }

    /// Segunda de manhã (09:00 local), recorrente. Anuncia a rotação das 3
    /// livres da semana. O texto não diz quais — é pretexto pra abrir o app.
    private func scheduleWeekly() {
        let content = UNMutableNotificationContent()
        content.title = "Three new stories are free"
        content.body  = "This week's selection has changed."
        content.sound = .default

        var comps = DateComponents()
        comps.weekday = 2   // 1 = domingo; 2 = segunda
        comps.hour = 9
        comps.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: ID.weekly, content: content, trigger: trigger)
        center.add(request) { _ in }
    }

    /// One-shot pras 21:00 de HOJE. Só agenda se todas as condições valem:
    ///  • usuário tem streak ≥ 2 (perder 1 dia é pouco atrito; 2+ dói);
    ///  • ainda não leu hoje;
    ///  • horário atual < 21:00 (senão já passou).
    /// Sempre re-agendado no próximo dia via `sync` no launch/foreground.
    private func scheduleStreakRiskIfNeeded(streakCount: Int, hasReadToday: Bool) {
        guard streakCount >= 2, !hasReadToday else { return }

        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 21
        comps.minute = 0

        guard let fireDate = cal.date(from: comps), fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your streak is at risk"
        content.body  = "You're on a \(streakCount)-day streak. A chapter keeps it alive."
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: ID.streak, content: content, trigger: trigger)
        center.add(request) { _ in }
    }

    // MARK: - Debug (opcional)

    #if DEBUG
    /// Lista as pendentes no console. Útil pra confirmar que sync fez o certo.
    func debugDump() async {
        let pending = await center.pendingNotificationRequests()
        print("[notif] pendentes: \(pending.count)")
        for req in pending {
            print("  - \(req.identifier): \(req.content.title)")
            if let t = req.trigger as? UNCalendarNotificationTrigger {
                print("    trigger:", t.dateComponents, "repeats:", t.repeats)
            }
        }
    }
    #endif
}
