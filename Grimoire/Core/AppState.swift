//
//  AppState.swift
//  Grimoire — estado global
//
//  Fonte de verdade de UI: favoritos (persistidos), progresso de leitura,
//  e flags de primeira execução. Injetado via @Environment.
//

import SwiftUI
import Observation
import WidgetKit

@MainActor
@Observable
final class AppState {

    // MARK: Catálogo (carregado do bundle na inicialização)
    private(set) var catalog: [StorySummary] = []
    private(set) var loadError: String?

    // MARK: Favoritos (persistidos em UserDefaults)
    private(set) var favorites: Set<String> = []

    // MARK: Progresso de leitura — storyID -> último capítulo lido (1..3)
    private(set) var progress: [String: Int] = [:]

    // MARK: Onboarding
    var hasSeenOnboarding: Bool {
        didSet { defaults.set(hasSeenOnboarding, forKey: Keys.onboarding) }
    }

    // MARK: Paywall — controle central de apresentação (não persistido).
    // Qualquer tela pede o paywall com `app.showPaywall = true`; o RootView
    // observa e apresenta o sheet num nível onde o binding é confiável.
    // Passar isso pelo AppState (já no environment de todas as views) evita o
    // bug do .sheet preso na TabView que não dispara a partir de um Tab.
    var showPaywall = false

    // MARK: Deep link — signals do widget → app.
    //
    // Widget tap abre o app com URL `grimoire://…`. O GrimoireApp parseia
    // no `onOpenURL` e escreve aqui. Views observam e navegam, limpando
    // depois de consumir (pra não re-navegar em rebuilds).
    //
    // Separado em dois signals pra permitir "vá pra home E abra story X"
    // numa mesma ação — RootView troca a tab, HomeView empurra a story.
    var pendingTab: String?         // "home", "favorites", "profile"
    var pendingStoryID: String?

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let favorites = "grimoire.favorites"
        static let progress  = "grimoire.progress"
        static let onboarding = "grimoire.hasSeenOnboarding"
        static let streakCount = "grimoire.streak.count"
        static let streakBest  = "grimoire.streak.best"
        static let streakLast  = "grimoire.streak.lastDay"   // Date (dia truncado)
        static let readAfterMidnight = "grimoire.readAfterMidnight"
        static let unlockedThisWeek = "grimoire.week.unlockedIDs"  // [String]
        static let unlockedWeekKey  = "grimoire.week.key"          // String
        // Notificações (v1: locais, sem push server).
        static let notifsEnabled   = "grimoire.notif.enabled"
        static let notifsHour      = "grimoire.notif.dailyHour"
        static let notifsWeekly    = "grimoire.notif.weekly"
        static let notifsStreak    = "grimoire.notif.streak"
    }

    // MARK: Streak de leitura (persistido)
    private(set) var streakCount: Int = 0
    private(set) var bestStreak: Int = 0
    // Exposto como private(set) pra o GrimoireApp observar mudanças com
    // .onChange e re-agendar notificações quando a pessoa lê algo hoje.
    private(set) var lastReadDay: Date?
    private(set) var readAfterMidnight: Bool = false

    // MARK: Notificações — preferências (persistidas)
    // O toggle mestre. Só true depois de permissão OK; toggle em Profile.
    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notifsEnabled) }
    }
    /// Hora do lembrete diário (0-23). Default 20 (bedtime).
    var dailyReminderHour: Int {
        didSet { defaults.set(dailyReminderHour, forKey: Keys.notifsHour) }
    }
    var weeklyRefreshEnabled: Bool {
        didSet { defaults.set(weeklyRefreshEnabled, forKey: Keys.notifsWeekly) }
    }
    var streakRiskEnabled: Bool {
        didSet { defaults.set(streakRiskEnabled, forKey: Keys.notifsStreak) }
    }

    /// True se o usuário já leu algo hoje (calendário local). Usado pra decidir
    /// se agenda o alerta de "streak em risco" das 21h.
    var hasReadToday: Bool {
        guard let last = lastReadDay else { return false }
        return Calendar.current.isDateInToday(last)
    }

    // MARK: Rotação semanal — histórias livres desta semana
    // As 3 da semana são determinísticas (WeeklyFreeStories). Além delas,
    // guardamos quais o usuário COMEÇOU nesta semana, para não cortar no meio
    // quando a semana virar — elas seguem liberadas até serem terminadas.
    private(set) var weeklyFreeIDs: Set<String> = []
    private var startedThisWeek: Set<String> = []

    init() {
        hasSeenOnboarding = defaults.bool(forKey: Keys.onboarding)
        favorites = Set(defaults.stringArray(forKey: Keys.favorites) ?? [])
        progress = (defaults.dictionary(forKey: Keys.progress) as? [String: Int]) ?? [:]
        streakCount = defaults.integer(forKey: Keys.streakCount)
        bestStreak = defaults.integer(forKey: Keys.streakBest)
        lastReadDay = defaults.object(forKey: Keys.streakLast) as? Date
        readAfterMidnight = defaults.bool(forKey: Keys.readAfterMidnight)

        // Preferências de notificação. Defaults: mestre off (nunca liga sozinho —
        // permissão só é pedida quando o usuário liga em Profile); sub-toggles on
        // por padrão pra que ativar o mestre já traga a experiência completa.
        // Hora padrão 20h = janela típica de "história antes de dormir".
        notificationsEnabled  = defaults.bool(forKey: Keys.notifsEnabled)
        let savedHour = defaults.object(forKey: Keys.notifsHour) as? Int
        dailyReminderHour     = savedHour ?? 20
        weeklyRefreshEnabled  = defaults.object(forKey: Keys.notifsWeekly) as? Bool ?? true
        streakRiskEnabled     = defaults.object(forKey: Keys.notifsStreak) as? Bool ?? true

        loadCatalog()
        refreshStreakIfBroken()
        refreshWeeklyFree()
    }

    // MARK: Catálogo

    func loadCatalog() {
        do {
            catalog = try StoryLoader.loadIndex().stories.sorted { $0.order < $1.order }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
            catalog = []
        }
        publishWidgetSnapshot()   // catálogo carregado → daily story disponível
    }

    func summary(id: String) -> StorySummary? { catalog.first { $0.id == id } }

    var favoriteStories: [StorySummary] {
        catalog.filter { favorites.contains($0.id) }
    }

    /// Agrupa o catálogo por nível, na ordem de progressão.
    var byLevel: [(level: StoryLevel, stories: [StorySummary])] {
        StoryLevel.allCases.compactMap { lvl in
            let items = catalog.filter { $0.level == lvl }
            return items.isEmpty ? nil : (lvl, items)
        }
    }

    // MARK: Favoritos

    func isFavorite(_ id: String) -> Bool { favorites.contains(id) }

    func toggleFavorite(_ id: String) {
        if favorites.contains(id) { favorites.remove(id) }
        else { favorites.insert(id) }
        defaults.set(Array(favorites), forKey: Keys.favorites)
    }

    // MARK: Progresso

    func lastChapter(of id: String) -> Int { progress[id] ?? 0 }
    func isStarted(_ id: String) -> Bool { (progress[id] ?? 0) > 0 }
    func isFinished(_ id: String) -> Bool { (progress[id] ?? 0) >= 3 }

    func markChapterRead(story id: String, chapter: Int) {
        let current = progress[id] ?? 0
        if chapter > current {
            progress[id] = chapter
            defaults.set(progress, forKey: Keys.progress)
        }
        noteStartedThisWeek(id)
        registerReadingActivity()
        publishWidgetSnapshot()   // progresso mudou → continue reading / finished
    }

    // MARK: - Streak

    /// Chamado sempre que o usuário lê algo. Atualiza a contagem de dias
    /// consecutivos com base no calendário local.
    func registerReadingActivity() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // marca "leu depois da meia-noite" (00:00–04:59) — usado por conquista
        let hour = cal.component(.hour, from: Date())
        if hour < 5, !readAfterMidnight {
            readAfterMidnight = true
            defaults.set(true, forKey: Keys.readAfterMidnight)
        }

        if let last = lastReadDay {
            let lastDay = cal.startOfDay(for: last)
            if lastDay == today { return }               // já contou hoje
            let days = cal.dateComponents([.day], from: lastDay, to: today).day ?? 99
            streakCount = (days == 1) ? streakCount + 1 : 1
        } else {
            streakCount = 1
        }
        lastReadDay = today
        bestStreak = max(bestStreak, streakCount)
        persistStreak()
    }

    /// Zera o streak se o usuário perdeu um ou mais dias desde a última leitura.
    /// Roda no launch para o número exibido estar sempre correto.
    private func refreshStreakIfBroken() {
        guard let last = lastReadDay else { return }
        let cal = Calendar.current
        let lastDay = cal.startOfDay(for: last)
        let today = cal.startOfDay(for: Date())
        let days = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
        if days >= 2 {                                   // pulou pelo menos 1 dia inteiro
            streakCount = 0
            persistStreak()
            publishWidgetSnapshot()   // widget precisa refletir streak zerado
        }
    }

    /// Versão pública para chamar quando o app volta ao primeiro plano.
    func refreshStreakOnForeground() { refreshStreakIfBroken() }

    private func persistStreak() {
        defaults.set(streakCount, forKey: Keys.streakCount)
        defaults.set(bestStreak, forKey: Keys.streakBest)
        defaults.set(lastReadDay, forKey: Keys.streakLast)
    }

    // MARK: - Progressão (rank + conquistas)

    var finishedCount: Int { catalog.filter { isFinished($0.id) }.count }
    var startedCount: Int { catalog.filter { isStarted($0.id) }.count }

    /// Rank atual do leitor, derivado das histórias terminadas.
    var readerRank: ReaderRank { ReaderRank.rank(forFinished: finishedCount) }

    /// Progresso (0…1) rumo ao próximo rank. 1 se já for o máximo.
    var rankProgress: Double {
        guard let next = readerRank.next else { return 1 }
        let base = readerRank.threshold
        let span = next.threshold - base
        guard span > 0 else { return 1 }
        return min(1, Double(finishedCount - base) / Double(span))
    }

    /// Quantas histórias faltam para o próximo rank (0 se já for o máximo).
    var storiesToNextRank: Int {
        guard let next = readerRank.next else { return 0 }
        return max(0, next.threshold - finishedCount)
    }

    /// Monta o snapshot que as conquistas consomem.
    var progressSnapshot: ProgressSnapshot {
        var finishedByLevel: [StoryLevel: Int] = [:]
        var totalByLevel: [StoryLevel: Int] = [:]
        var tagCounts: [String: Int] = [:]
        for s in catalog {
            totalByLevel[s.level, default: 0] += 1
            if isFinished(s.id) {
                finishedByLevel[s.level, default: 0] += 1
                for t in s.tags { tagCounts[t, default: 0] += 1 }
            }
        }
        return ProgressSnapshot(
            finishedCount: finishedCount,
            startedCount: startedCount,
            favoritesCount: favorites.count,
            currentStreak: streakCount,
            bestStreak: bestStreak,
            finishedByLevel: finishedByLevel,
            totalByLevel: totalByLevel,
            readAfterMidnight: readAfterMidnight,
            finishedTagCounts: tagCounts
        )
    }

    /// Conquistas desbloqueadas / total — para o resumo do perfil.
    var unlockedAchievementsCount: Int {
        let snap = progressSnapshot
        return Achievements.all.filter { $0.isUnlocked(snap) }.count
    }

    // MARK: - Rotação semanal + acesso central

    /// Recalcula as 3 livres da semana. Se a semana virou, reseta a lista de
    /// "começadas nesta semana" (as não terminadas re-bloqueiam; as terminadas
    /// nem entram nessa conta). Chamado no launch e ao voltar pro app.
    func refreshWeeklyFree() {
        weeklyFreeIDs = WeeklyFreeStories.freeIDs(from: catalog)

        let currentKey = WeeklyFreeStories.weekKey()
        let savedKey = defaults.string(forKey: Keys.unlockedWeekKey)
        if savedKey == currentKey {
            startedThisWeek = Set(defaults.stringArray(forKey: Keys.unlockedThisWeek) ?? [])
        } else {
            // semana nova: zera as "começadas nesta semana"
            startedThisWeek = []
            defaults.set(currentKey, forKey: Keys.unlockedWeekKey)
            defaults.set([String](), forKey: Keys.unlockedThisWeek)
        }
        // Foreground / virada de dia pode ter mudado a "história do dia".
        // O saveSnapshot é idempotente — se nada mudou, é no-op barato.
        publishWidgetSnapshot()
    }

    /// A regra ÚNICA de acesso a uma história. Todos os lugares usam isto.
    /// Desbloqueada se: é Pro, OU é uma das 3 da semana, OU o usuário já a
    /// começou nesta semana (cortesia para terminar).
    func isUnlocked(_ summary: StorySummary, isPro: Bool) -> Bool {
        if isPro { return true }
        if weeklyFreeIDs.contains(summary.id) { return true }
        if startedThisWeek.contains(summary.id) { return true }
        return false
    }

    /// Marca que o usuário começou a ler esta história nesta semana, para que
    /// ela continue acessível mesmo se a semana virar antes de terminar.
    private func noteStartedThisWeek(_ id: String) {
        guard weeklyFreeIDs.contains(id) || startedThisWeek.contains(id) else { return }
        if startedThisWeek.insert(id).inserted {
            defaults.set(Array(startedThisWeek), forKey: Keys.unlockedThisWeek)
        }
    }

    // MARK: - Widget snapshot
    //
    // Fonte de verdade única pro widget. Escreve no App Group, sinaliza o
    // WidgetKit e sai. Chamado quando algo relevante muda: streak, progresso,
    // catalog carregado, ou "história do dia" pode ter virado.
    //
    // É idempotente pelo SharedStore — se o snapshot é igual ao atual, não
    // reescreve nem sinaliza. Segue barato chamar toda hora.

    /// "Continue lendo": última história começada e não terminada, com o
    /// próximo capítulo pendente. Percorre em ordem de progresso, então pega
    /// a que o usuário mexeu mais recentemente é ordenada por ID (aproximação
    /// razoável — não temos timestamp de leitura).
    private func computeContinueReading() -> (story: StorySummary, nextChapter: Int)? {
        // Percorre catálogo procurando a de menor id que tenha progresso > 0
        // e não terminada. Aproximação — funciona bem pra V1.
        for story in catalog {
            let chap = progress[story.id] ?? 0
            if chap > 0 && chap < 3 {
                return (story, chap + 1)
            }
        }
        return nil
    }

    /// Monta o snapshot e escreve. Chame após qualquer mudança relevante.
    func publishWidgetSnapshot() {
        // Evita rodar antes do catálogo carregar — snapshot sem histórias
        // seria confuso pro widget desenhar.
        guard !catalog.isEmpty else { return }

        let finished = Set(catalog.filter { isFinished($0.id) }.map(\.id))
        let daily = DailyStory.pick(from: catalog, finished: finished)
        let cont = computeContinueReading()
        let rank = readerRank

        let snap = WidgetSnapshot(
            streakCount: streakCount,
            bestStreak: bestStreak,
            finishedCount: finished.count,
            totalStories: catalog.count,
            rankTitle: rank.title,
            rankSymbolName: rank.symbol,
            storiesToNextRank: storiesToNextRank,
            continueStoryID: cont?.story.id,
            continueTitle: cont?.story.title,
            continueNextChapter: cont?.nextChapter,
            dailyStoryID: daily?.id,
            dailyStoryTitle: daily?.title,
            dailyStoryReadingMinutes: daily?.readingMinutes,
            generatedAt: Date()
        )

        if SharedStore.saveSnapshot(snap) {
            // Só sinaliza WidgetKit se realmente mudou. Reload custa CPU e
            // frustra usuários que veem o widget "piscar" sem motivo.
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}
