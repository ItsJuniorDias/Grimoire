//
//  Stories.swift
//  Grimoire — camada de conteúdo
//
//  Modelos Codable + loader estático. As histórias moram como recursos
//  no bundle do app (index.json + stories/st-XXX.json) e são lidas
//  localmente, sem rede.
//
//  SETUP NO XCODE:
//    1. Arraste a pasta `Content/` (com index.json e a pasta stories/)
//       para o projeto. IMPORTANTE: escolha "Create folder references"
//       (pasta azul), não "Create groups" — assim a subpasta stories/
//       é preservada no bundle.
//    2. Confirme que os .json estão em "Copy Bundle Resources" no target.
//
//  USO:
//    let index = try StoryLoader.loadIndex()
//    let story = try StoryLoader.loadStory(id: "st-001")
//

import Foundation

// ============================================================
// Conteúdo localizado
// ============================================================

extension String {

    /// Resolve esta string como CONTEÚDO traduzido.
    ///
    /// A ideia: título, sinopse, título de capítulo e tag existem em inglês
    /// no JSON do bundle, e a tradução vem de uma destas três fontes, nesta
    /// ordem de precedência:
    ///
    ///     tradução humana (catálogo)  →  máquina (cache)  →  inglês
    ///
    ///   1. `Localizable.xcstrings`, com a própria string-fonte como chave.
    ///      É o que vale para as tags, que são palavra solta e é onde a
    ///      máquina mais erra.
    ///   2. `CatalogTranslation`, que traduz o catálogo no aparelho em lote
    ///      e guarda em disco. Cobre título, sinopse e título de capítulo, e
    ///      é a rede de segurança de qualquer texto que entre sem tradução
    ///      humana.
    ///   3. O inglês de volta, que é a string original.
    ///
    /// A ordem importa: humana ganha sempre. Adicionar uma tradução humana
    /// no catálogo aposenta a da máquina sozinha, sem tocar em código.
    ///
    /// Nome diferente de `.localized` de propósito: este é o caminho do
    /// CONTEÚDO. Rótulo de interface passa pelo `LocalizedStringKey` de
    /// sempre, que o SwiftUI resolve sozinho.
    ///
    /// O corpo do capítulo NÃO passa por aqui — é texto longo, precisa de
    /// contexto inteiro numa requisição só, e tem tela de progresso própria.
    /// Ver `ChapterTranslation`.
    ///
    /// COMO ADICIONAR TRADUÇÃO HUMANA DE CONTEÚDO:
    ///   1. Abra `scripts/build_strings_catalog.py`.
    ///   2. Chave nova = o texto em inglês inteiro, do primeiro ao último
    ///      caractere, exatamente como está no JSON.
    ///   3. Preencha os 6 idiomas e rode o script. Ele falha se faltar um.
    var localizedContent: String {
        // 1. Humana. O String Catalog devolve a própria chave quando não há
        //    entrada, então "veio diferente" é o sinal de que existe.
        let humana = String(localized: LocalizedStringResource(stringLiteral: self))
        if humana != self { return humana }

        // 2. Máquina. Ler `entries` aqui dentro do `body` de uma view é o que
        //    registra a dependência de observação e faz a tela se redesenhar
        //    quando o lote chega.
        if let maquina = CatalogTranslation.shared.entries[self] { return maquina }

        // 3. Inglês.
        return self
    }
}

/// O idioma em que o CONTEÚDO existe, que não é o mesmo em que a
/// interface existe.
///
/// A interface fala sete línguas. As histórias foram escritas uma vez, em
/// inglês, e a narração foi gravada uma vez, em inglês. Gravar de novo em
/// seis línguas é produção de áudio, não código — então fora do inglês o
/// leitor desliga o transporte e diz por quê. Tocar a faixa inglesa pra
/// quem pôs o app em português entrega uma voz que a pessoa não pediu.
///
/// Quando houver narração em outra língua, `narrated` vira uma consulta ao
/// que existe por idioma e o resto do código não muda.
enum ContentLanguage {

    /// A língua em que o conteúdo foi escrito e gravado.
    static let source = "en"

    /// Línguas em que há narração gravada.
    static let narrated: Set<String> = [source]

    /// Línguas que a interface fala. Precisa bater com `knownRegions` no
    /// project.pbxproj e com `AppState.availableLanguages`.
    static let supported: [String] = [source, "pt-BR", "es", "fr", "de", "it", "ar"]

    /// A língua que o bundle realmente resolveu — respeita tanto o idioma
    /// do sistema quanto o override de `AppState.preferredLanguage`,
    /// porque os dois passam por `AppleLanguages`.
    static var current: String {
        Bundle.main.preferredLocalizations.first ?? source
    }

    /// Estamos fora do inglês, então faz sentido pedir tradução à máquina.
    static var canMachineTranslate: Bool { current != source }

    /// Há narração na língua corrente.
    static var hasNarration: Bool { narrated.contains(current) }
}

// ============================================================
// Modelos — espelham schema.json 1:1
// ============================================================

struct StoryCover: Codable, Hashable {
    let asset: String
    let accent: String   // hex, ex. "#C1352A"
}

enum StoryLevel: String, Codable, CaseIterable {
    case apprentice, initiate, conjurer, archmage
}

struct Chapter: Codable, Hashable, Identifiable {
    let index: Int
    let title: String
    let body: String
    let wordCount: Int?

    var id: Int { index }

    /// Parágrafos da string-fonte em inglês. Use `localizedParagraphs` na
    /// UI — este fica pro que precisa do original (narração, busca).
    var paragraphs: [String] {
        Chapter.paragraphs(in: body)
    }

    // MARK: Conteúdo localizado
    //
    // Os `let` originais continuam sendo a fonte em inglês (que é a chave
    // de tradução) e seguem disponíveis. As views usam estes acessores.

    var localizedTitle: String { title.localizedContent }
    var localizedBody: String { body.localizedContent }

    /// Parágrafos do texto que vai pra tela. Quando há tradução humana no
    /// catálogo, a quebra acontece nos parágrafos daquele idioma.
    var localizedParagraphs: [String] {
        Chapter.paragraphs(in: localizedBody)
    }

    /// Existe tradução humana desta capítulo no catálogo.
    /// Falso quando o catálogo devolveu a própria string-fonte de volta —
    /// é o sinal de que o `ChapterTranslation` deve tentar a máquina.
    var hasHumanTranslation: Bool { body != localizedBody }

    /// Quebra qualquer texto em parágrafos. Estático porque o texto vindo
    /// da tradução automática não pertence a nenhum `Chapter`.
    static func paragraphs(in text: String) -> [String] {
        text.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

/// Entrada leve do índice (sem corpo dos capítulos) — pro catálogo/cards.
struct StorySummary: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let slug: String
    let premium: Bool
    let order: Int
    let level: StoryLevel
    let cover: StoryCover
    let summary: String
    let readingMinutes: Int
    let tags: [String]
    let language: String
    let file: String

    // MARK: Conteúdo localizado
    var localizedTitle: String { title.localizedContent }
    var localizedSummary: String { summary.localizedContent }
}

/// História completa (com os 3 capítulos).
struct Story: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let slug: String
    let premium: Bool
    let order: Int
    let level: StoryLevel
    let cover: StoryCover
    let summary: String
    let readingMinutes: Int
    let tags: [String]
    let language: String
    let chapters: [Chapter]

    // MARK: Conteúdo localizado
    var localizedTitle: String { title.localizedContent }
    var localizedSummary: String { summary.localizedContent }
}

struct StoryIndex: Codable {
    let version: Int
    let language: String
    let total: Int
    let plannedTotal: Int
    let freeCount: Int
    let stories: [StorySummary]
}

// ============================================================
// Loader estático
// ============================================================

enum StoryLoaderError: Error, LocalizedError {
    case indexNotFound
    case storyNotFound(String)
    case decodingFailed(String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .indexNotFound:
            return "index.json not found in bundle (Content/index.json)."
        case .storyNotFound(let id):
            return "Story \(id) not found in bundle."
        case .decodingFailed(let file, let underlying):
            return "Falha ao decodificar \(file): \(underlying.localizedDescription)"
        }
    }
}

enum StoryLoader {

    private static let decoder = JSONDecoder()

    /// Carrega o índice do catálogo (leve — só metadados).
    static func loadIndex() throws -> StoryIndex {
        guard let url = bundleURL(name: "index", subdir: "Content") else {
            throw StoryLoaderError.indexNotFound
        }
        return try decode(StoryIndex.self, from: url, label: "index.json")
    }

    /// Carrega uma história completa pelo id (ex. "st-001").
    static func loadStory(id: String) throws -> Story {
        // Os arquivos ficam em Content/stories/st-XXX.json
        guard let url = bundleURL(name: id, subdir: "Content/stories") else {
            throw StoryLoaderError.storyNotFound(id)
        }
        return try decode(Story.self, from: url, label: "\(id).json")
    }

    /// Conveniência: carrega todas as histórias listadas no índice.
    /// Use com parcimônia — prefira carregar sob demanda ao abrir cada história.
    static func loadAll() throws -> [Story] {
        let index = try loadIndex()
        return try index.stories
            .sorted { $0.order < $1.order }
            .map { try loadStory(id: $0.id) }
    }

    /// URL do MP3 narrado de um capítulo, se estiver acessível agora.
    /// Os arquivos ficam em Content/audio/st-XXX-chY.mp3.
    /// Retorna nil também quando o pacote de narração da história ainda não
    /// foi baixado (On-Demand Resources) — o NarrationController baixa no
    /// primeiro play. Ver ContentPacks.swift.
    static func audioURL(storyID: String, chapterIndex: Int) -> URL? {
        NarrationController.audioURL(storyID: storyID, chapterIndex: chapterIndex)
    }

    // MARK: - Helpers

    private static func bundleURL(name: String, subdir: String) -> URL? {
        // Tenta com subdiretório (folder reference) e sem (flat).
        Bundle.main.url(forResource: name, withExtension: "json", subdirectory: subdir)
            ?? Bundle.main.url(forResource: name, withExtension: "json")
    }

    private static func decode<T: Decodable>(_ type: T.Type, from url: URL, label: String) throws -> T {
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(T.self, from: data)
        } catch {
            throw StoryLoaderError.decodingFailed(label, underlying: error)
        }
    }
}
