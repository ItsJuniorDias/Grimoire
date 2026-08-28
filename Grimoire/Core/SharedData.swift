//
//  SharedData.swift
//  Grimoire — dados compartilhados app ↔ widget
//
//  Este arquivo é COMPILADO EM AMBOS OS TARGETS (app principal e widget).
//  Marque-o em "Target Membership" pros dois no Xcode.
//
//  Contrato:
//   • O APP escreve `WidgetSnapshot` no App Group toda vez que streak,
//     progresso ou "história do dia" mudam.
//   • O WIDGET só lê. Nunca escreve. Nunca carrega catalog nem StoreKit.
//   • Depois de escrever, o app chama `WidgetCenter.shared.reloadAllTimelines()`.
//
//  Por que assim: o timeline provider do widget precisa ser leve. Carregar
//  o AppState (que abre 50 JSONs do catálogo + StoreKit) ali seria caro e
//  desnecessário — o widget só precisa dos números finais.
//

import Foundation

// ============================================================
// App Group ID — usado por app e widget
// ============================================================

/// ID do App Group configurado nas capabilities de AMBOS os targets.
/// Se você mudar o bundle prefix do app, atualize aqui e nos dois entitlements.
enum SharedIDs {
    static let appGroup = "group.alexandrejunior.Grimoire"
}

// ============================================================
// Snapshot — o que o widget precisa pra desenhar
// ============================================================

/// Fotografia mínima do estado do app pro widget consumir. Codable JSON,
/// serializado no App Group. Mantém pequeno: cada campo aqui é lido em
/// cada refresh do widget, e o timeline provider é chamado com frequência.
struct WidgetSnapshot: Codable, Equatable {

    // Progressão
    let streakCount: Int
    let bestStreak: Int
    let finishedCount: Int
    let totalStories: Int

    // Rank
    let rankTitle: String        // "Apprentice", "Initiate", …
    let rankSymbolName: String   // "flame", "flame.fill", "sparkles", …
    let storiesToNextRank: Int   // 0 se já no topo

    // Continue reading — última história começada e não terminada
    let continueStoryID: String?
    let continueTitle: String?
    let continueNextChapter: Int?   // próximo capítulo a ler (1..3)

    // História do dia — sugestão determinística
    let dailyStoryID: String?
    let dailyStoryTitle: String?
    let dailyStoryReadingMinutes: Int?

    // Metadata
    let generatedAt: Date

    // Snapshot vazio pro placeholder do widget (antes de o app ter rodado
    // pela primeira vez, ou em preview). Nunca aparece em produção normal.
    static let empty = WidgetSnapshot(
        streakCount: 0, bestStreak: 0,
        finishedCount: 0, totalStories: 50,
        rankTitle: "Apprentice", rankSymbolName: "flame",
        storiesToNextRank: 3,
        continueStoryID: nil, continueTitle: nil, continueNextChapter: nil,
        dailyStoryID: nil, dailyStoryTitle: nil, dailyStoryReadingMinutes: nil,
        generatedAt: .distantPast
    )

    // Snapshot ilustrativo pra Xcode Previews — dados fake mas plausíveis.
    static let preview = WidgetSnapshot(
        streakCount: 6, bestStreak: 12,
        finishedCount: 7, totalStories: 50,
        rankTitle: "Initiate", rankSymbolName: "flame.fill",
        storiesToNextRank: 3,
        continueStoryID: "st-016",
        continueTitle: "The Boy Who Kept the Autumn",
        continueNextChapter: 2,
        dailyStoryID: "st-003",
        dailyStoryTitle: "The Girl Who Planted a Door",
        dailyStoryReadingMinutes: 8,
        generatedAt: Date()
    )
}

// ============================================================
// Storage — leitura e escrita no App Group
// ============================================================

/// Camada de persistência do snapshot. Grava como JSON num UserDefaults
/// que aponta pro App Group — assim app e widget veem os mesmos bytes.
enum SharedStore {

    private static let snapshotKey = "grimoire.widget.snapshot"

    /// Instância do UserDefaults do App Group. Fatal se o container não
    /// estiver configurado (bug de setup — melhor falhar no dev que rodar
    /// silencioso em produção).
    static var defaults: UserDefaults {
        guard let d = UserDefaults(suiteName: SharedIDs.appGroup) else {
            fatalError("App Group \(SharedIDs.appGroup) não está configurado. Habilite em Signing & Capabilities em AMBOS os targets.")
        }
        return d
    }

    /// Lê o snapshot atual. Retorna `.empty` se ainda não há nada gravado
    /// (primeira execução do app, por exemplo).
    static func loadSnapshot() -> WidgetSnapshot {
        guard let data = defaults.data(forKey: snapshotKey) else { return .empty }
        do {
            return try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        } catch {
            // Snapshot corrompido (mudança de schema, por ex.). Trata como vazio.
            return .empty
        }
    }

    /// Salva um snapshot. Idempotente. Se for igual ao atual, não escreve
    /// nem sinaliza o widget — evita reloads desnecessários.
    /// Retorna `true` se realmente mudou algo.
    @discardableResult
    static func saveSnapshot(_ snap: WidgetSnapshot) -> Bool {
        let current = loadSnapshot()
        // Ignora `generatedAt` na comparação pra não considerar mudança quando
        // só o timestamp difere.
        var currentSansTime = current; currentSansTime = withZeroedTimestamp(currentSansTime)
        var newSansTime = snap;         newSansTime = withZeroedTimestamp(newSansTime)
        if currentSansTime == newSansTime { return false }

        do {
            let data = try JSONEncoder().encode(snap)
            defaults.set(data, forKey: snapshotKey)
            return true
        } catch {
            return false
        }
    }

    private static func withZeroedTimestamp(_ s: WidgetSnapshot) -> WidgetSnapshot {
        WidgetSnapshot(
            streakCount: s.streakCount, bestStreak: s.bestStreak,
            finishedCount: s.finishedCount, totalStories: s.totalStories,
            rankTitle: s.rankTitle, rankSymbolName: s.rankSymbolName,
            storiesToNextRank: s.storiesToNextRank,
            continueStoryID: s.continueStoryID, continueTitle: s.continueTitle,
            continueNextChapter: s.continueNextChapter,
            dailyStoryID: s.dailyStoryID, dailyStoryTitle: s.dailyStoryTitle,
            dailyStoryReadingMinutes: s.dailyStoryReadingMinutes,
            generatedAt: .distantPast   // zerado só pra comparação
        )
    }
}

// ============================================================
// Deep-link URLs — widget → app
// ============================================================

/// URLs que o widget usa em `.widgetURL(...)` pra abrir o app numa
/// tela específica. O app trata em `onOpenURL`.
enum DeepLink {
    /// Custom scheme registrado no Info.plist do app.
    static let scheme = "grimoire"

    /// Abre a home simples.
    static var home: URL { URL(string: "\(scheme)://home")! }

    /// Abre uma história específica (pelo id do catálogo).
    static func story(_ id: String) -> URL {
        URL(string: "\(scheme)://story/\(id)")!
    }

    /// Abre o Profile (Your Path).
    static var profile: URL { URL(string: "\(scheme)://profile")! }
}
