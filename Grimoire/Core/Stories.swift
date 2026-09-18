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

    /// Parágrafos já separados, prontos pra renderizar.
    var paragraphs: [String] {
        body.components(separatedBy: "\n\n").filter { !$0.isEmpty }
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
