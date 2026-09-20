//
//  ProfileView.swift
//  Grimoire — perfil e conquistas
//
//  Mostra o rank do leitor, o streak, o progresso rumo ao próximo posto,
//  e o grid de conquistas. O botão de progressão puxa pro paywall quando o
//  usuário está travado no teto gratuito — ligando hábito a conversão.
//

import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var app
    @Environment(SubscriptionStore.self) private var store
    @Environment(NotificationsManager.self) private var notifs
    @State private var showPaywall = false

    private let cols = [GridItem(.flexible(), spacing: DS.Space.md),
                        GridItem(.flexible(), spacing: DS.Space.md)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.xl) {
                    rankCard
                    streakRow
                    remindersSection
                    languageSection
                    achievementsSection
                    Color.clear.frame(height: DS.Space.xl)
                }
                .padding(.horizontal, DS.Space.lg)
                .padding(.top, DS.Space.sm)
            }
            .background(DS.Colors.background.ignoresSafeArea())
            .navigationTitle("Your Path")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .tint(DS.Colors.accent)
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showPaywall) {
            PaywallView { showPaywall = false }
                .environment(store)
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Card do rank atual

    private var rankCard: some View {
        let rank = app.readerRank
        return VStack(spacing: DS.Space.md) {
            Image(systemName: rank.symbol)
                .font(.system(size: 42))
                .foregroundStyle(DS.Colors.brass)
                .frame(height: 52)

            VStack(spacing: DS.Space.xxs) {
                Text(rank.title)
                    .font(DS.Typography.display(28, .bold))
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(rank.blurb)
                    .font(DS.Typography.bodySm)
                    .foregroundStyle(DS.Colors.textSecondary)
            }

            // Progresso rumo ao próximo rank
            if let next = rank.next {
                VStack(spacing: DS.Space.xs) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(DS.Colors.surface)
                            Capsule().fill(DS.Colors.accent)
                                .frame(width: max(6, geo.size.width * app.rankProgress))
                        }
                    }
                    .frame(height: 8)

                    Text("\(app.storiesToNextRank) more to become \(next.title)")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Colors.textMuted)
                }
                .padding(.top, DS.Space.xs)

                // Gancho de conversão: sem Pro, o teto chega rápido.
                if !store.isPro {
                    Button { showPaywall = true } label: {
                        Text("Unlock all 50 to keep climbing")
                            .font(DS.Typography.caption.bold())
                            .foregroundStyle(DS.Palette.ink900)
                            .padding(.horizontal, DS.Space.md)
                            .padding(.vertical, DS.Space.xs)
                            .background(Capsule().fill(DS.Colors.brass))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, DS.Space.xxs)
                }
            } else {
                Text("You've read the whole grimoire.")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.brass)
                    .padding(.top, DS.Space.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DS.Space.xl)
        .background(DS.Colors.surface.opacity(0.5), in: .rect(cornerRadius: DS.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.lg)
            .stroke(DS.Colors.border, lineWidth: 1))
    }

    // MARK: Streak + estatísticas rápidas

    private var streakRow: some View {
        HStack(spacing: DS.Space.md) {
            statTile(icon: "flame.fill",
                     value: "\(app.streakCount)",
                     label: app.streakCount == 1 ? "day streak" : "days streak",
                     tint: DS.Colors.accent)
            statTile(icon: "book.closed.fill",
                     value: "\(app.finishedCount)",
                     label: "finished",
                     tint: DS.Colors.brass)
            statTile(icon: "bookmark.fill",
                     value: "\(app.favoriteStories.count)",
                     label: "saved",
                     tint: DS.Colors.textSecondary)
        }
    }

    private func statTile(icon: String, value: String, label: LocalizedStringKey, tint: Color) -> some View {
        VStack(spacing: DS.Space.xxs) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(tint)
            Text(value).font(DS.Typography.subtitle.bold())
                .foregroundStyle(DS.Colors.textPrimary)
            Text(label).font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Space.md)
        .background(DS.Colors.surface.opacity(0.5), in: .rect(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md)
            .stroke(DS.Colors.border.opacity(0.6), lineWidth: 1))
    }

    // MARK: Conquistas

    private var achievementsSection: some View {
        let snap = app.progressSnapshot
        return VStack(alignment: .leading, spacing: DS.Space.md) {
            HStack {
                Text("ACHIEVEMENTS").font(DS.Typography.caption).tracking(3)
                    .foregroundStyle(DS.Colors.textMuted)
                Spacer()
                Text("\(app.unlockedAchievementsCount)/\(Achievements.all.count)")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textSecondary)
            }

            LazyVGrid(columns: cols, spacing: DS.Space.md) {
                ForEach(Achievements.all) { ach in
                    achievementCard(ach, snap: snap)
                }
            }
        }
    }

    // MARK: - Reminders (notificações locais)
    //
    // Card único com toggle mestre + sub-preferências. Estados possíveis:
    //   • sistema não decidiu → mestre off, ao ligar mostra permission prompt
    //   • sistema autorizou   → mestre ligável, mostra sub-toggles
    //   • sistema NEGOU       → mostra CTA pra Ajustes (não dá pra virar)
    //
    // Mudanças aqui disparam `sync()` do NotificationsManager. O sync já é
    // idempotente, então mesmo múltiplos toggles seguidos são seguros.

    private var remindersSection: some View {
        @Bindable var app = app   // habilita $-bindings pros toggles
        return VStack(alignment: .leading, spacing: DS.Space.md) {
            HStack {
                Text("REMINDERS").font(DS.Typography.caption).tracking(3)
                    .foregroundStyle(DS.Colors.textMuted)
                Spacer()
            }

            VStack(spacing: DS.Space.md) {
                // Linha 1: toggle mestre.
                Toggle(isOn: reminderMasterBinding(app: app)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reading reminders")
                            .font(DS.Typography.bodyMd)
                            .foregroundStyle(DS.Colors.textPrimary)
                        Text(masterSubtitle)
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.textMuted)
                    }
                }
                .tint(DS.Colors.brass)

                // Se sistema negou permissão, botão pra Ajustes.
                if notifs.authorizationStatus == .denied {
                    Divider().overlay(DS.Colors.border)
                    Button {
                        notifs.openSystemSettings()
                    } label: {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text("Enable in Settings")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                        .font(DS.Typography.bodyMd)
                        .foregroundStyle(DS.Colors.brass)
                    }
                    .buttonStyle(.plain)
                }

                // Sub-preferências: só quando o mestre está ativo e há permissão.
                if app.notificationsEnabled,
                   notifs.authorizationStatus == .authorized || notifs.authorizationStatus == .provisional {
                    Divider().overlay(DS.Colors.border)

                    // Horário do lembrete diário. Picker compacto — grau de
                    // customização suficiente sem virar tela cheia.
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Daily reminder")
                                .font(DS.Typography.bodyMd)
                                .foregroundStyle(DS.Colors.textPrimary)
                            Text(hourLabel(app.dailyReminderHour))
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.textMuted)
                        }
                        Spacer()
                        Picker("", selection: dailyHourBinding(app: app)) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(hourShort(h)).tag(h)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(DS.Colors.brass)
                    }

                    Divider().overlay(DS.Colors.border)

                    Toggle(isOn: weeklyBinding(app: app)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("New week alert")
                                .font(DS.Typography.bodyMd)
                                .foregroundStyle(DS.Colors.textPrimary)
                            Text("Monday morning, when 3 stories refresh.")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.textMuted)
                        }
                    }
                    .tint(DS.Colors.brass)

                    Toggle(isOn: streakBinding(app: app)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Streak protection")
                                .font(DS.Typography.bodyMd)
                                .foregroundStyle(DS.Colors.textPrimary)
                            Text("A gentle nudge at 9pm if your streak is at risk.")
                                .font(DS.Typography.caption)
                                .foregroundStyle(DS.Colors.textMuted)
                        }
                    }
                    .tint(DS.Colors.brass)
                }
            }
            .padding(DS.Space.md)
            .background(DS.Colors.surface.opacity(0.5), in: .rect(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.border.opacity(0.6), lineWidth: 1))
        }
    }

    // MARK: - Idioma
    //
    // A troca é aplicada em `AppleLanguages` e o bundle só relê isso no
    // launch. Em vez de fingir que a tela mudou, o card diz que precisa
    // reabrir — e explica de onde vem a tradução das histórias, porque
    // "traduzido automaticamente" no leitor sem aviso prévio surpreende.

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: DS.Space.md) {
            Text("LANGUAGE").font(DS.Typography.caption).tracking(3)
                .foregroundStyle(DS.Colors.textMuted)

            VStack(spacing: DS.Space.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("App language")
                            .font(DS.Typography.bodyMd)
                            .foregroundStyle(DS.Colors.textPrimary)
                        Text("Reopen Grimoire to finish switching.")
                            .font(DS.Typography.caption)
                            .foregroundStyle(DS.Colors.textMuted)
                    }
                    Spacer()
                    Picker("", selection: languageBinding(app: app)) {
                        Text("Follow system").tag(String?.none)
                        ForEach(AppState.availableLanguages, id: \.code) { lang in
                            // Cada idioma se apresenta no próprio idioma:
                            // quem não lê a língua atual do app ainda
                            // reconhece a sua na lista.
                            Text(lang.label).tag(String?.some(lang.code))
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(DS.Colors.brass)
                }

                Divider().overlay(DS.Colors.border)

                Text("Stories are translated on your device the first time you open a chapter.")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(DS.Space.md)
            .background(DS.Colors.surface.opacity(0.5), in: .rect(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md)
                .stroke(DS.Colors.border.opacity(0.6), lineWidth: 1))
        }
    }

    private func languageBinding(app: AppState) -> Binding<String?> {
        Binding(
            get: { app.preferredLanguage },
            set: { app.preferredLanguage = $0 }
        )
    }

    // Subtítulo dinâmico do toggle mestre, dependendo do estado do sistema.
    private var masterSubtitle: String {
        switch notifs.authorizationStatus {
        case .denied:       return String(localized: "Blocked by system. Tap below to enable.")
        case .notDetermined: return String(localized: "Choose when to be reminded.")
        default:
            return app.notificationsEnabled
                ? String(localized: "You'll be nudged to keep the ritual.")
                : String(localized: "Off — no reminders will be sent.")
        }
    }

    // "20h", "9h" — formato compacto pro Picker menu.
    private func hourShort(_ h: Int) -> String { "\(h)h" }

    // "8:00 PM", "9:00 AM" — legível pro subtítulo do row.
    private func hourLabel(_ h: Int) -> String {
        var comps = DateComponents(); comps.hour = h; comps.minute = 0
        let date = Calendar.current.date(from: comps) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    // MARK: Bindings do toggle mestre (com side-effects)
    //
    // Toggle mestre precisa de lógica além do set direto: se está ligando
    // e a permissão ainda não foi decidida, precisa pedir ao sistema. Por
    // isso vai via binding custom em vez de $app.notificationsEnabled.
    private func reminderMasterBinding(app: AppState) -> Binding<Bool> {
        Binding(
            get: { app.notificationsEnabled },
            set: { newValue in
                if newValue {
                    // Pede permissão se ainda não decidiu; ativa só se granted.
                    Task {
                        if notifs.authorizationStatus == .notDetermined {
                            let granted = await notifs.requestAuthorization()
                            app.notificationsEnabled = granted
                        } else if notifs.authorizationStatus == .denied {
                            // Sistema negou: mantém off (o CTA de Ajustes aparece).
                            app.notificationsEnabled = false
                        } else {
                            app.notificationsEnabled = true
                        }
                        await notifs.sync(app: app)
                    }
                } else {
                    app.notificationsEnabled = false
                    Task { await notifs.sync(app: app) }
                }
            }
        )
    }

    // Binding que sincroniza notificações após mudar. Usado pra sub-toggles.
    private func weeklyBinding(app: AppState) -> Binding<Bool> {
        Binding(
            get: { app.weeklyRefreshEnabled },
            set: { app.weeklyRefreshEnabled = $0
                   Task { await notifs.sync(app: app) } }
        )
    }
    private func streakBinding(app: AppState) -> Binding<Bool> {
        Binding(
            get: { app.streakRiskEnabled },
            set: { app.streakRiskEnabled = $0
                   Task { await notifs.sync(app: app) } }
        )
    }
    private func dailyHourBinding(app: AppState) -> Binding<Int> {
        Binding(
            get: { app.dailyReminderHour },
            set: { app.dailyReminderHour = $0
                   Task { await notifs.sync(app: app) } }
        )
    }

    private func achievementCard(_ ach: Achievement, snap: ProgressSnapshot) -> some View {
        let unlocked = ach.isUnlocked(snap)
        let value = min(ach.progressValue(snap), ach.goal)
        return VStack(alignment: .leading, spacing: DS.Space.xs) {
            HStack {
                Image(systemName: ach.symbol)
                    .font(.system(size: 20))
                    .foregroundStyle(unlocked ? DS.Colors.brass : DS.Colors.textMuted)
                Spacer()
                if unlocked {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(DS.Colors.brass)
                }
            }
            Text(ach.title)
                .font(DS.Typography.bodyMd.bold())
                .foregroundStyle(unlocked ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                .lineLimit(1)
            Text(ach.detail)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Colors.textMuted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if ach.goal > 1 && !unlocked {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DS.Palette.ink900.opacity(0.5))
                        Capsule().fill(DS.Colors.accent.opacity(0.8))
                            .frame(width: max(3, geo.size.width * Double(value) / Double(ach.goal)))
                    }
                }
                .frame(height: 5)
                Text("\(value)/\(ach.goal)")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.Colors.textMuted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .padding(DS.Space.md)
        .background(DS.Colors.surface.opacity(unlocked ? 0.6 : 0.3),
                    in: .rect(cornerRadius: DS.Radius.md))
        .overlay(RoundedRectangle(cornerRadius: DS.Radius.md)
            .stroke(unlocked ? DS.Colors.brass.opacity(0.5) : DS.Colors.border.opacity(0.5),
                    lineWidth: 1))
        .opacity(unlocked ? 1 : 0.85)
    }
}
