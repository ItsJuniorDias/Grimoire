//
//  ChapterTranslation.swift
//  Grimoire — tradução automática de capítulo, no aparelho
//
//  POR QUE NÃO TRADUZIR TUDO ANTES
//
//  O acervo tem 103 mil palavras. Em seis idiomas são 620 mil — seis
//  romances — e a maior parte disso seria aposta: ninguém garante que
//  alguém vai abrir O Relojoeiro das Horas Roubadas em italiano. Traduzir
//  à mão o que talvez nunca seja lido é caro pelo lado errado.
//
//  POR QUE NO APARELHO E NÃO NUMA API
//
//  Três coisas quebrariam de uma vez com tradutor na nuvem:
//
//  1. A promessa do produto. Grimoire é leitura na cama, com o aparelho
//     no avião ou no metrô. Abrir um capítulo não pode exigir rede.
//  2. A revisão de privacidade. Mandar o que a pessoa lê à noite pra um
//     terceiro é uma conversa que não precisamos ter — ainda mais com o
//     app já sem privacy manifest.
//  3. O custo por leitura, que cresce com o uso — exatamente o tipo de
//     conta que uma assinatura plana não quer ter.
//
//  O framework Translation da Apple resolve os três: roda local, de
//  graça, sem chave e sem servidor.
//
//  O QUE ISSO CUSTA, E É UM CUSTO REAL
//
//  Tradução de máquina achata a voz, e a voz é o produto aqui — prosa
//  gótica vive de ritmo. Por isso a precedência deixa a porta aberta pra
//  tradução humana entrar depois, história por história, com base no que
//  as pessoas realmente lerem:
//
//      tradução humana (catálogo)  →  cache em disco  →  máquina  →  inglês
//
//  E o leitor diz quando o que está na tela veio da máquina. Sem isso a
//  pessoa julga a escrita do app pela tradução da Apple.
//

import Foundation
import Observation
import OSLog
import Translation

// MARK: - Cache

/// Guarda em disco o que a máquina já traduziu.
///
/// Um arquivo por capítulo e por idioma, em vez de um índice único: um
/// arquivo corrompido custa um capítulo, não o acervo inteiro. Fica em
/// Application Support porque é conteúdo derivado — sobrevive à
/// atualização do app, e o sistema pode limpar sob pressão de espaço sem
/// que nada se perca de verdade.
struct TranslationCache {

    private let root: URL
    private let log = Logger(subsystem: "alexandrejunior.Grimoire",
                             category: "translation")

    /// nonisolated: este init aparece como valor padrão do init de
    /// `ChapterTranslation`, que é @MainActor — e default de parâmetro é
    /// avaliado fora do ator.
    nonisolated init(directory: String = "Translations") {
        root = URL.applicationSupportDirectory.appending(path: directory)
    }

    private func url(storyID: String, chapter: Int, language: String) -> URL {
        root.appending(path: language)
            .appending(path: "\(storyID)-ch\(chapter).txt")
    }

    func read(storyID: String, chapter: Int, language: String) -> String? {
        let file = url(storyID: storyID, chapter: chapter, language: language)
        guard let text = try? String(contentsOf: file, encoding: .utf8),
              !text.isEmpty
        else { return nil }
        return text
    }

    func write(_ text: String, storyID: String, chapter: Int, language: String) {
        let file = url(storyID: storyID, chapter: chapter, language: language)
        do {
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try text.write(to: file, atomically: true, encoding: .utf8)
        } catch {
            // Falhar em gravar o cache não pode impedir a leitura: o texto
            // já está na tela, só vai ser traduzido de novo na próxima
            // abertura.
            log.error("cache de tradução não gravou: \(error.localizedDescription)")
        }
    }

    /// Apaga tudo. Ligado ao botão dos ajustes.
    func clear() {
        try? FileManager.default.removeItem(at: root)
    }

    /// Quanto o cache ocupa, pra mostrar nos ajustes.
    var byteSize: Int64 {
        guard let walker = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in walker {
            let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize
            total += Int64(size ?? 0)
        }
        return total
    }
}

// MARK: - Estado da tradução de um capítulo

@MainActor
@Observable
final class ChapterTranslation {

    enum State: Equatable {
        /// O que está na tela é o texto de origem — ou porque o app está
        /// em inglês, ou porque há tradução humana no catálogo.
        case source
        /// A máquina está trabalhando. Primeira abertura do capítulo.
        case working
        /// Traduzido pela máquina. O leitor rotula.
        case machine(String)
        /// Não deu: par de idiomas sem suporte, ou o modelo falhou.
        /// A tela cai no inglês sem alarde.
        case unavailable
    }

    private(set) var state: State = .source

    /// Não-nil dispara o `.translationTask` do leitor. Volta a nil quando
    /// não há nada a fazer.
    private(set) var configuration: TranslationSession.Configuration?

    private var pendingBody: String?
    private var pendingStory: String?
    private var pendingChapter: Int?

    private let cache: TranslationCache
    private let log = Logger(subsystem: "alexandrejunior.Grimoire",
                             category: "translation")

    init(cache: TranslationCache = TranslationCache()) {
        self.cache = cache
    }

    /// O texto a mostrar, ou nil pra usar o do capítulo.
    var machineText: String? {
        if case .machine(let text) = state { return text }
        return nil
    }

    /// Verdadeiro quando a tela mostra prosa de máquina, e portanto
    /// precisa dizer isso.
    var isMachineTranslated: Bool { machineText != nil }

    /// Os parágrafos que o leitor deve desenhar pra este capítulo.
    /// Máquina ganha do texto do capítulo; sem máquina, o capítulo já
    /// resolve humana-ou-inglês sozinho pelo String Catalog.
    func paragraphs(for chapter: Chapter) -> [String] {
        if let machine = machineText { return Chapter.paragraphs(in: machine) }
        return chapter.localizedParagraphs
    }

    // MARK: Ciclo

    /// Decide o que fazer com um capítulo que acabou de abrir.
    ///
    /// Síncrono de propósito: as três saídas rápidas — inglês, tradução
    /// humana, cache — resolvem antes do primeiro desenho, e só o caminho
    /// lento arma a `configuration`. Assim capítulo já traduzido abre sem
    /// piscar.
    func prepare(chapter: Chapter, storyID: String) {
        configuration = nil

        let target = ContentLanguage.current
        guard ContentLanguage.canMachineTranslate else {
            state = .source
            return
        }

        // Há tradução humana: ela ganha da máquina sempre.
        guard !chapter.hasHumanTranslation else {
            state = .source
            return
        }

        if let cached = cache.read(storyID: storyID,
                                   chapter: chapter.index,
                                   language: target) {
            state = .machine(cached)
            return
        }

        pendingBody = chapter.body
        pendingStory = storyID
        pendingChapter = chapter.index
        state = .working
        configuration = TranslationSession.Configuration(
            source: Locale.Language(identifier: ContentLanguage.source),
            target: Locale.Language(identifier: target))
    }

    /// Chamado pelo `.translationTask` com a sessão pronta.
    func run(session: TranslationSession) async {
        guard let body = pendingBody,
              let storyID = pendingStory,
              let index = pendingChapter
        else { return }

        let target = ContentLanguage.current

        do {
            // O capítulo inteiro numa requisição só, não parágrafo a
            // parágrafo: o modelo precisa do contexto em volta pra escolher
            // tempo verbal e pronome, e picar o texto entrega prosa que não
            // se liga com o parágrafo anterior.
            let response = try await session.translate(body)
            guard !Task.isCancelled else { return }

            cache.write(response.targetText,
                        storyID: storyID, chapter: index, language: target)
            state = .machine(response.targetText)
        } catch {
            log.error("tradução falhou para \(storyID)#\(index): \(error.localizedDescription)")
            state = .unavailable
        }

        configuration = nil
        pendingBody = nil
        pendingStory = nil
        pendingChapter = nil
    }

    /// Descarta o estado ao sair do leitor.
    func teardown() {
        configuration = nil
        pendingBody = nil
        pendingStory = nil
        pendingChapter = nil
        state = .source
    }
}
