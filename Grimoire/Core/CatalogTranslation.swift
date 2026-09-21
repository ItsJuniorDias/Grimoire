//
//  CatalogTranslation.swift
//  Grimoire — tradução do catálogo, no aparelho
//
//  O IRMÃO DO ChapterTranslation
//
//  O `ChapterTranslation` cuida do corpo do capítulo: um texto longo, pedido
//  sob demanda quando o leitor abre. Este arquivo cuida de tudo que aparece
//  ANTES disso — título, sinopse, título de capítulo e tag — que são muitos
//  textos curtos, todos visíveis de uma vez na Home.
//
//  A diferença de forma manda na diferença de mecânica:
//
//    corpo do capítulo   1 texto grande   pedido quando abre   `translate(_:)`
//    catálogo            368 textos curtos  visíveis de uma vez  `translations(from:)`
//
//  Pedir 368 traduções uma a uma seria 368 idas ao modelo com a Home inteira
//  em inglês no meio do caminho. A API de lote resolve isso numa chamada por
//  fatia, e a tela troca por ondas conforme cada fatia volta.
//
//  A PRECEDÊNCIA É A MESMA, E ISSO IMPORTA
//
//      tradução humana (catálogo)  →  cache em disco  →  máquina  →  inglês
//
//  É a mesma cadeia que o ChapterTranslation documenta, e ela continua
//  valendo porque quem decide é o `String.localizedContent` em Stories.swift,
//  não este arquivo. Uma tag que ganhe tradução humana no `Localizable
//  .xcstrings` passa a ganhar da máquina sozinha, sem mudar uma linha aqui.
//
//  POR QUE UM SINGLETON, E NÃO UM @Environment
//
//  Quem consulta a tradução é `String.localizedContent` — um acessor de
//  `String`, que não tem environment. Passar o store por parâmetro obrigaria
//  a trocar `s.localizedTitle` por `algo.title(of: s)` em toda view. Como
//  `entries` é `@Observable` e é lida dentro do `body`, o SwiftUI registra a
//  dependência e redesenha sozinho quando a tradução chega — sem mudar
//  nenhuma call site.
//
//  O QUE ISSO NÃO RESOLVE
//
//  Tag é palavra solta, e palavra solta sem contexto é onde tradução de
//  máquina erra mais: `fair` em st-004 é a feira de inverno, não "justo".
//  Por isso as tags também entram no String Catalog como tradução humana —
//  ver `scripts/build_strings_catalog.py`. A máquina aqui é a rede de
//  segurança para tag nova que entre com história nova.
//

import Foundation
import Observation
import OSLog
import Translation

// ============================================================
// Cache em disco
// ============================================================

/// Guarda o catálogo já traduzido, um arquivo por idioma.
///
/// Mora no mesmo diretório do cache de capítulos (`Translations/`) de
/// propósito: é tudo conteúdo derivado do mesmo tipo, e um dia o botão de
/// limpar cache apaga os dois de uma vez só.
///
/// Um arquivo por idioma, e não um por string: são 368 textos curtos que
/// nascem e morrem juntos. 368 arquivos de 30 bytes desperdiçariam mais em
/// inode do que guardariam em conteúdo.
struct CatalogTranslationStore {

    private let root: URL
    private let log = Logger(subsystem: "alexandrejunior.Grimoire",
                             category: "translation")

    /// nonisolated pelo mesmo motivo do `TranslationCache`: este init aparece
    /// como valor padrão do init de `CatalogTranslation`, que é @MainActor —
    /// e default de parâmetro é avaliado fora do ator.
    nonisolated init(directory: String = "Translations") {
        root = URL.applicationSupportDirectory.appending(path: directory)
    }

    private func url(language: String) -> URL {
        root.appending(path: language).appending(path: "catalog.json")
    }

    func read(language: String) -> [String: String] {
        guard let data = try? Data(contentsOf: url(language: language)),
              let map = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return map
    }

    func write(_ map: [String: String], language: String) {
        let file = url(language: language)
        do {
            try FileManager.default.createDirectory(
                at: file.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            try JSONEncoder().encode(map).write(to: file, options: .atomic)
        } catch {
            // Falhar em gravar não pode quebrar a tela: o texto traduzido já
            // está em memória e na tela. Só vai ser traduzido de novo na
            // próxima abertura do app.
            log.error("cache do catálogo não gravou: \(error.localizedDescription)")
        }
    }
}

// ============================================================
// O store
// ============================================================

@MainActor
@Observable
final class CatalogTranslation {

    /// Ver a nota sobre singleton no cabeçalho: é `String.localizedContent`
    /// que consulta isto, e um acessor de String não tem environment.
    static let shared = CatalogTranslation()

    /// Texto-fonte em inglês → texto no idioma corrente. Lido pelo
    /// `localizedContent` dentro do `body` das views, que é o que faz a tela
    /// se redesenhar quando uma fatia nova chega.
    private(set) var entries: [String: String] = [:]

    /// Há lote em andamento. O leitor não mostra isso — a Home já tem o
    /// inglês na tela e trocar por ondas é menos ruidoso que um spinner —
    /// mas os ajustes podem querer exibir.
    private(set) var isWorking = false

    /// O par de idiomas não é suportado pelo sistema, ou o modelo falhou.
    /// A tela fica em inglês, sem alarde, e não tentamos de novo nesta sessão.
    private(set) var isUnavailable = false

    /// Não-nil dispara o `.translationTask` da RootView. Volta a nil quando a
    /// fila esvazia.
    private(set) var configuration: TranslationSession.Configuration?

    /// Textos pedidos e ainda não traduzidos.
    private var pending: Set<String> = []

    private let store: CatalogTranslationStore
    private let language: String
    private let log = Logger(subsystem: "alexandrejunior.Grimoire",
                             category: "translation")

    /// Quantos textos vão num `translations(from:)`. Lote único de 368 faria
    /// a Home esperar tudo para trocar qualquer coisa; fatiado, ela troca por
    /// ondas e a primeira chega cedo.
    private static let sliceSize = 64

    init(store: CatalogTranslationStore = CatalogTranslationStore()) {
        self.store = store
        self.language = ContentLanguage.current
        // Cache lido no init, de propósito síncrono: depois da primeira
        // execução a Home já nasce traduzida, sem piscar inglês antes.
        if ContentLanguage.canMachineTranslate {
            entries = store.read(language: language)
        }
    }

    // MARK: - Entrada

    /// Põe textos na fila. Ignora o que já está traduzido, o que já está na
    /// fila e o que não precisa de tradução.
    ///
    /// Barato de chamar de novo com a mesma lista — é o que a Home faz a cada
    /// recarga de catálogo.
    func request(_ strings: [String]) {
        guard ContentLanguage.canMachineTranslate, !isUnavailable else { return }

        let novos = strings.filter { texto in
            !texto.isEmpty
            && entries[texto] == nil
            && !pending.contains(texto)
            && !hasHumanTranslation(texto)
        }
        pending.formUnion(novos)

        // Re-arma sempre que há QUALQUER coisa na fila, não só quando entrou
        // texto novo. Um lote que falhou antes deixa sobra em `pending`, e
        // essa sobra faz `novos` vir vazio nas chamadas seguintes — sem esta
        // condição a fila ficaria parada para sempre depois do primeiro erro.
        if !pending.isEmpty { arm() }
    }

    /// Conveniência para o índice: título, sinopse e tags de cada história.
    /// Título de capítulo não entra aqui — só é conhecido depois de abrir o
    /// JSON da história, e quem pede é o `StoryDetailView`.
    func requestCatalog(_ catalog: [StorySummary]) {
        var textos: [String] = []
        textos.reserveCapacity(catalog.count * 4)
        for s in catalog {
            textos.append(s.title)
            textos.append(s.summary)
            textos.append(contentsOf: s.tags)
        }
        request(textos)
    }

    /// Títulos dos capítulos de uma história. Chamado quando o detalhe abre.
    ///
    /// SÓ o título. O corpo do capítulo NÃO pode entrar nesta fila, e a razão
    /// é sutil: `Chapter.hasHumanTranslation` decide se o `ChapterTranslation`
    /// entra em ação comparando `body` com `localizedBody`. Se o corpo
    /// estivesse em `entries`, `localizedBody` devolveria a versão de máquina,
    /// a comparação daria "diferente", e o leitor concluiria que existe
    /// tradução humana — desligando o caminho que traduz o capítulo com o
    /// contexto inteiro numa requisição só.
    ///
    /// Corpo de capítulo é assunto do `ChapterTranslation`, e só dele.
    func requestChapters(_ story: Story) {
        request(story.chapters.map(\.title))
    }

    /// Existe tradução humana desta string no String Catalog? Se existe, a
    /// máquina não tem o que fazer — é a mesma checagem que o
    /// `Chapter.hasHumanTranslation` faz para o corpo.
    private func hasHumanTranslation(_ texto: String) -> Bool {
        String(localized: LocalizedStringResource(stringLiteral: texto)) != texto
    }

    /// Arma (ou re-arma) o `.translationTask`.
    ///
    /// `invalidate()` muda a `version` da Configuration, que é o que a torna
    /// diferente da anterior e faz o SwiftUI rodar a task de novo. Se já há
    /// lote rodando não mexemos: invalidar cancelaria a task em andamento, e
    /// o loop de `run` drena a fila sozinho.
    private func arm() {
        guard !isWorking else { return }
        if configuration == nil {
            configuration = TranslationSession.Configuration(
                source: Locale.Language(identifier: ContentLanguage.source),
                target: Locale.Language(identifier: language))
        } else {
            configuration?.invalidate()
        }
    }

    // MARK: - Execução

    /// Chamado pelo `.translationTask` da RootView com a sessão pronta.
    ///
    /// Drena a fila em fatias, publicando cada fatia assim que chega — a Home
    /// vai trocando por ondas em vez de esperar as 368.
    func run(session: TranslationSession) async {
        guard !pending.isEmpty else {
            configuration = nil
            return
        }

        isWorking = true
        defer {
            isWorking = false
            configuration = nil
        }

        // O sistema pode não ter o par de idiomas. Em vez de descobrir isso
        // 368 traduções depois, pergunta antes e desiste quieto.
        guard await isPairSupported() else {
            log.notice("par \(ContentLanguage.source)→\(self.language) sem suporte; catálogo fica em inglês")
            isUnavailable = true
            pending.removeAll()
            return
        }

        // Primeiro uso do idioma pode exigir download do modelo — isto é o
        // que apresenta a folha do sistema. Falhar aqui não é fatal: a
        // tradução abaixo tenta assim mesmo e falha com mensagem melhor.
        try? await session.prepareTranslation()

        while !pending.isEmpty {
            guard !Task.isCancelled else { return }

            let fatia = Array(pending.prefix(Self.sliceSize))
            let pedidos = fatia.map {
                TranslationSession.Request(sourceText: $0, clientIdentifier: $0)
            }

            do {
                let respostas = try await session.translations(from: pedidos)
                guard !Task.isCancelled else { return }

                var novas: [String: String] = [:]
                for r in respostas {
                    // clientIdentifier é o texto-fonte: devolve o par certo
                    // mesmo que o lote volte fora de ordem.
                    let fonte = r.clientIdentifier ?? r.sourceText
                    guard !r.targetText.isEmpty else { continue }
                    novas[fonte] = r.targetText
                }

                pending.subtract(fatia)
                guard !novas.isEmpty else { continue }

                // Uma atribuição só por fatia: `entries` é observada, e
                // escrever chave a chave faria a Home redesenhar 64 vezes.
                entries.merge(novas) { _, nova in nova }
                store.write(entries, language: language)

            } catch {
                log.error("lote de tradução do catálogo falhou: \(error.localizedDescription)")
                // Para esta sessão, mas NÃO marca indisponível: a falha mais
                // comum aqui é transitória (modelo ainda baixando, download
                // recusado uma vez). `isUnavailable` é só para par de idiomas
                // sem suporte, que não melhora tentando de novo.
                //
                // O que já veio fica em `entries` e no disco. O resto volta
                // para a fila e o próximo `request` — abrir uma história, por
                // exemplo — re-arma a sessão e tenta de novo. Sem laço
                // apertado: só tenta quando o usuário faz algo.
                return
            }
        }
    }

    /// O sistema sabe traduzir do inglês para o idioma corrente?
    private func isPairSupported() async -> Bool {
        let status = await LanguageAvailability().status(
            from: Locale.Language(identifier: ContentLanguage.source),
            to: Locale.Language(identifier: language))
        switch status {
        case .installed, .supported: return true
        case .unsupported:           return false
        @unknown default:            return true   // tenta; o erro real aparece no lote
        }
    }
}
