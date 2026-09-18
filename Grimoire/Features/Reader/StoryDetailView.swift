//
//  StoryDetailView.swift
//  Grimoire — detalhe + leitor
//
//  Detalhe: capa grande, sinopse, capítulos, botão ler. Premium bloqueado
//  chama o paywall. Reader: leitura capítulo a capítulo, marca progresso.
//
//  >>> VERSÃO COM BLOQUEIO TOTAL + FIX DO NEXT (v2) <<<
//  Se você vê este comentário no Xcode, está com a versão correta.
//

import SwiftUI

struct StoryDetailView: View {
    let summary: StorySummary
    var openPaywall: () -> Void

    @Environment(AppState.self) private var app
    @Environment(SubscriptionStore.self) private var store
    @Environment(Analytics.self) private var analytics
    @Environment(\.dismiss) private var dismiss

    @State private var story: Story?
    @State private var loadError: String?
    @State private var reading: Int? = nil   // capítulo aberto no leitor

    private var locked: Bool { !app.isUnlocked(summary, isPro: store.isPro) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.lg) {
                ZStack(alignment: .bottomLeading) {
                    CoverArt(story: summary, height: 280, isFocused: true)
                    LinearGradient(colors: [.clear, DS.Palette.ink900],
                                   startPoint: .center, endPoint: .bottom)
                        .frame(height: 280)
                    VStack(alignment: .leading, spacing: DS.Space.xs) {
                        HStack(spacing: DS.Space.xs) {
                            GTag(text: summary.level.label, icon: summary.level.symbol, tint: summary.level.color)
                            GTag(text: "\(summary.readingMinutes) min", icon: "clock")
                        }
                        Text(summary.title)
                            .font(DS.Typography.display(30, .bold))
                            .foregroundStyle(DS.Palette.paper)
                    }
                    .padding(DS.Space.lg)
                }

                VStack(alignment: .leading, spacing: DS.Space.md) {
                    Text(summary.summary)
                        .font(DS.Typography.bodyLg)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineSpacing(4)

                    HStack(spacing: DS.Space.xs) {
                        ForEach(summary.tags, id: \.self) { GTag(text: $0) }
                    }

                    Divider().overlay(DS.Colors.border)

                    // Capítulos
                    Text("CHAPTERS").font(DS.Typography.caption).tracking(3)
                        .foregroundStyle(DS.Colors.textMuted)

                    if let story {
                        ForEach(story.chapters) { ch in
                            chapterRow(ch)
                        }
                    } else if loadError != nil {
                        // Erro ao carregar a história — com opção de tentar de novo.
                        VStack(spacing: DS.Space.md) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 28, weight: .light))
                                .foregroundStyle(DS.Colors.textMuted)
                            Text("Couldn't open this story.")
                                .font(DS.Typography.bodyMd)
                                .foregroundStyle(DS.Colors.textSecondary)
                            GButton(title: "Try again", variant: .secondary, icon: "arrow.clockwise") {
                                loadError = nil
                                Task { await load() }
                            }
                            .fixedSize()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Space.xl)
                    } else {
                        ProgressView().tint(DS.Colors.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Space.xl)
                    }
                }
                .padding(.horizontal, DS.Space.lg)
            }
        }
        .background(DS.Colors.background.ignoresSafeArea())
        .ignoresSafeArea(edges: .top)
        .scrollIndicators(.hidden)
        .toolbar(.hidden, for: .tabBar, .bottomBar)   // esconde a barra de vidro nesta tela
        .safeAreaInset(edge: .bottom) { ctaBar }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                FavoriteButton(isOn: app.isFavorite(summary.id)) {
                    app.toggleFavorite(summary.id)
                }
            }
        }
        .task {
            await load()
            analytics.track(.story_opened, ["story_id": summary.id, "title": summary.title])
        }
        .fullScreenCover(item: Binding(
            get: { reading.map { ReaderChapterRef(index: $0) } },
            set: { reading = $0?.index }
        )) { ref in
            if let story {
                ReaderView(
                    story: story,
                    startAt: ref.index,
                    locked: locked,
                    onRead: { readIndex in
                        // Detecta a transição "acabou de terminar agora" pra não
                        // disparar story_finished toda vez que reler o último capítulo.
                        let wasFinished = app.isFinished(summary.id)
                        app.markChapterRead(story: summary.id, chapter: readIndex)
                        if !wasFinished, app.isFinished(summary.id) {
                            analytics.track(.story_finished,
                                            ["story_id": summary.id, "title": summary.title])
                        }
                    },
                    onLockedNext: {
                        reading = nil          // fecha o leitor
                        openPaywall()          // e abre o paywall
                    }
                )
            }
        }
    }

    private func chapterRow(_ ch: Chapter) -> some View {
        let read = app.lastChapter(of: summary.id) >= ch.index
        let available = !locked
        return Button {
            if available { reading = ch.index } else { openPaywall() }
        } label: {
            HStack(spacing: DS.Space.md) {
                ZStack {
                    Circle().fill(read ? DS.Colors.accent : DS.Colors.surface)
                        .frame(width: 32, height: 32)
                    if read {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                            .foregroundStyle(DS.Palette.paper)
                    } else {
                        Text("\(ch.index)").font(DS.Typography.bodySm.bold())
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(ch.title).font(DS.Typography.bodyMd)
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text("\(ch.wordCount ?? 0) words")
                        .font(DS.Typography.caption).foregroundStyle(DS.Colors.textMuted)
                }
                Spacer()
                Image(systemName: available ? "chevron.right" : "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(available ? DS.Colors.textMuted : DS.Colors.brass)
            }
            .padding(DS.Space.sm)
            .background(DS.Colors.surface, in: .rect(cornerRadius: DS.Radius.md))
        }
        .buttonStyle(.plain)
    }

    private var ctaBar: some View {
        let started = app.isStarted(summary.id)
        let next = min(app.lastChapter(of: summary.id) + 1, 3)
        return VStack(spacing: 0) {
            if locked {
                GButton(title: "Unlock with Pro", variant: .primary, icon: "crown.fill") {
                    openPaywall()
                }
                .padding(DS.Space.lg)
            } else {
                GButton(title: started ? "Continue · Chapter \(next)" : "Start reading",
                        variant: .primary, icon: "book.fill") {
                    reading = next
                }
                .padding(DS.Space.lg)
            }
        }
        .background(.ultraThinMaterial)
    }

    private func load() async {
        do { story = try StoryLoader.loadStory(id: summary.id) }
        catch { loadError = "Couldn't open this story." }
    }
}

private struct ReaderChapterRef: Identifiable { let index: Int; var id: Int { index } }

// ============================================================
// Reader — leitura de um capítulo, com navegação entre capítulos
// ============================================================

struct ReaderView: View {
    let story: Story
    let startAt: Int
    var locked: Bool                       // história premium sem acesso
    var onRead: (Int) -> Void
    var onLockedNext: () -> Void           // tentou avançar pra capítulo travado

    @Environment(\.dismiss) private var dismiss
    @Environment(Analytics.self) private var analytics
    @State private var current: Int = 1
    @State private var narration = NarrationController()

    private var chapter: Chapter? { story.chapters.first { $0.index == current } }

    /// Um capítulo é acessível somente se a história não está travada.
    /// Bloqueio total: nem o capítulo 1 abre em histórias bloqueadas.
    private func isAccessible(_ index: Int) -> Bool { !locked }

    var body: some View {
        ZStack {
            DS.Colors.background.ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Space.lg) {
                        VStack(alignment: .leading, spacing: DS.Space.xs) {
                            Text("CHAPTER \(current)").font(DS.Typography.caption).tracking(4)
                                .foregroundStyle(DS.Colors.accent)
                            Text(chapter?.title ?? "")
                                .font(DS.Typography.display(28, .bold))
                                .foregroundStyle(DS.Colors.textPrimary)
                        }
                        .padding(.top, DS.Space.xxl)
                        .id("readerTop")   // âncora pro topo da leitura

                        if let chapter {
                            ForEach(Array(chapter.paragraphs.enumerated()), id: \.offset) { idx, para in
                                Text(para)
                                    .font(DS.Typography.bodyLg)
                                    .foregroundStyle(
                                        narration.spokenParagraph == idx
                                        ? DS.Colors.textPrimary
                                        : (narration.isSpeaking ? DS.Colors.textSecondary : DS.Colors.textPrimary)
                                    )
                                    .lineSpacing(7)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.vertical, narration.spokenParagraph == idx ? DS.Space.xs : 0)
                                    .background(
                                        narration.spokenParagraph == idx
                                        ? DS.Colors.surface.opacity(0.5)
                                        : Color.clear,
                                        in: .rect(cornerRadius: DS.Radius.md)
                                    )
                                    .id("para-\(idx)")
                                    .animation(.easeInOut(duration: 0.25), value: narration.spokenParagraph)
                                    // Cada parágrafo faz um fade-in suave ao entrar na tela.
                                    // O texto já está legível ao chegar na área de leitura,
                                    // então nunca segura o leitor — só a borda inferior revela.
                                    .scrollTransition(
                                        axis: .vertical
                                    ) { content, phase in
                                        content
                                            .opacity(phase.isIdentity ? 1 : 0)
                                            .offset(y: phase.isIdentity ? 0 : 14)
                                            .blur(radius: phase.isIdentity ? 0 : 2)
                                    }
                            }
                        }

                        navFooter
                        // Folga bottom: o FAB de narração (60pt + 24pt padding)
                        // fica fixo no bottomTrailing e sobreporia o botão Next.
                        // Este spacer reserva espaço no fim do scroll pra os
                        // controles do navFooter caírem acima do FAB.
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, DS.Space.lg)
                }
                // Ao trocar de capítulo: o conteúdo troca instantaneamente
                // (animar o texto inteiro trava), e só o scroll sobe suave.
                .onChange(of: current) { _, _ in
                    proxy.scrollTo("readerTop", anchor: .top)
                }
                // A tela acompanha a narração: rola até o parágrafo falado.
                .onChange(of: narration.spokenParagraph) { _, idx in
                    guard idx >= 0 else { return }
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo("para-\(idx)", anchor: .center)
                    }
                }
                .scrollIndicators(.hidden)
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    narration.stop()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(DS.Colors.textPrimary)
                        .padding(DS.Space.sm)
                        .background(Circle().fill(DS.Colors.surface))
                }
                .padding(DS.Space.md)
            }
            // Botão de narração flutuante — apagar a luz e ouvir.
            .overlay(alignment: .bottomTrailing) {
                Button {
                    if let chapter {
                        // Só conta como "narração iniciada" se estava parado —
                        // pausar/retomar e tocar durante o download não
                        // disparam evento.
                        let willStart = !narration.isSpeaking && !narration.isPaused
                            && !narration.isLoading
                        narration.toggle(
                            storyID: story.id,
                            chapterIndex: current,
                            paragraphs: chapter.paragraphs,
                            title: story.title,
                            subtitle: "Chapter \(current) · \(chapter.title)",
                            artwork: story.cover.asset
                        )
                        if willStart {
                            analytics.track(.narration_started,
                                            ["story_id": story.id, "chapter": String(current)])
                        }
                    }
                } label: {
                    narrationGlyph
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(DS.Palette.ink900)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(DS.Colors.accent))
                        .dsShadow(.lg)
                }
                .padding(DS.Space.lg)
                .accessibilityLabel(narrationLabel)
            }
        }
        .onAppear {
            // Blindagem: se abrirem já num capítulo inacessível, cai no 1.
            current = isAccessible(startAt) ? startAt : 1
            onRead(current)
        }
        .onChange(of: current) { _, _ in
            narration.stop()   // troca de capítulo interrompe a narração anterior
        }
        .onDisappear {
            narration.stop()   // fecha o leitor -> para o áudio e libera a sessão
        }
    }

    /// Miolo do botão de narração. A narração é On-Demand Resource (ver
    /// ContentPacks.swift): o primeiro play de uma história baixa o áudio,
    /// e o botão é o único lugar do leitor que mostra isso.
    @ViewBuilder
    private var narrationGlyph: some View {
        if narration.isLoading {
            ProgressView()
                .tint(DS.Palette.ink900)
        } else {
            Image(systemName: narrationIcon)
        }
    }

    /// Ícone do botão de narração conforme o estado.
    private var narrationIcon: String {
        if narration.loadFailed { return "arrow.clockwise" }
        if narration.isSpeaking && !narration.isPaused { return "pause.fill" }
        return "play.fill"
    }

    private var narrationLabel: String {
        if narration.isLoading { return "Downloading narration" }
        if narration.loadFailed { return "Couldn't download narration. Try again" }
        return narration.isSpeaking && !narration.isPaused ? "Pause narration" : "Play narration"
    }

    private var navFooter: some View {
        HStack {
            if current > 1 {
                Button {
                    current -= 1
                    onRead(current)
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                        .font(DS.Typography.bodySm)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
            }
            Spacer()
            if current < story.chapters.count {
                // O próximo capítulo é acessível? Se não, o botão vira paywall.
                if isAccessible(current + 1) {
                    Button {
                        current += 1
                        onRead(current)
                    } label: {
                        Label("Next", systemImage: "chevron.right")
                            .labelStyle(.titleAndIcon)
                            .font(DS.Typography.bodyMd.bold())
                            .foregroundStyle(DS.Colors.accent)
                    }
                } else {
                    Button {
                        onLockedNext()      // dispara o paywall, NÃO avança
                    } label: {
                        Label("Unlock with Pro", systemImage: "lock.fill")
                            .labelStyle(.titleAndIcon)
                            .font(DS.Typography.bodyMd.bold())
                            .foregroundStyle(DS.Colors.brass)
                    }
                }
            } else {
                Text("The End").font(DS.Typography.bodyMd.bold())
                    .foregroundStyle(DS.Colors.brass)
            }
        }
        .padding(.top, DS.Space.lg)
    }
}
