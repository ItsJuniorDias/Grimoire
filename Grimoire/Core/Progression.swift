//
//  Progression.swift
//  Grimoire — progressão do leitor
//
//  Modelo de ranks (o leitor sobe conforme termina histórias) e conquistas.
//  Puro modelo/valor — sem estado. O AppState calcula tudo a partir do
//  progresso e do streak já existentes. Isso mantém a fonte de verdade única.
//

import SwiftUI

// MARK: - Rank do leitor

/// O posto do LEITOR (não confundir com StoryLevel, que classifica histórias).
/// Sobe conforme o número de histórias terminadas.
enum ReaderRank: Int, CaseIterable, Comparable {
    case apprentice = 0
    case initiate
    case conjurer
    case archmage
    case grandmaster

    static func < (a: ReaderRank, b: ReaderRank) -> Bool { a.rawValue < b.rawValue }

    /// Quantas histórias terminadas para ATINGIR este rank.
    var threshold: Int {
        switch self {
        case .apprentice:  return 0
        case .initiate:    return 3
        case .conjurer:    return 10
        case .archmage:    return 25
        case .grandmaster: return 50
        }
    }

    var title: String {
        switch self {
        case .apprentice:  return "Apprentice"
        case .initiate:    return "Initiate"
        case .conjurer:    return "Conjurer"
        case .archmage:    return "Archmage"
        case .grandmaster: return "Grandmaster"
        }
    }

    var symbol: String {
        switch self {
        case .apprentice:  return "flame"
        case .initiate:    return "flame.fill"
        case .conjurer:    return "sparkles"
        case .archmage:    return "crown.fill"
        case .grandmaster: return "seal.fill"
        }
    }

    /// Frase curta que descreve o posto.
    var blurb: String {
        switch self {
        case .apprentice:  return "Your journey begins."
        case .initiate:    return "The dark starts to open."
        case .conjurer:    return "You walk deeper now."
        case .archmage:    return "Few reach this far."
        case .grandmaster: return "The whole grimoire, read."
        }
    }

    /// Rank correspondente a um número de histórias terminadas.
    static func rank(forFinished n: Int) -> ReaderRank {
        allCases.last { n >= $0.threshold } ?? .apprentice
    }

    /// Próximo rank (nil se já é o máximo).
    var next: ReaderRank? {
        ReaderRank(rawValue: rawValue + 1)
    }
}

// MARK: - Conquistas

/// Uma conquista desbloqueável. `isUnlocked` recebe um snapshot do progresso
/// e decide se está completa — assim toda a lógica fica declarativa e num
/// lugar só, e o AppState só fornece os números.
struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    /// Meta para 100% (usado na barra de progresso). 1 = booleana.
    let goal: Int
    /// Quanto do goal já foi cumprido, dado o snapshot.
    let progressValue: (ProgressSnapshot) -> Int

    var isUnlocked: (ProgressSnapshot) -> Bool {
        { snap in progressValue(snap) >= goal }
    }
}

/// Fotografia do estado do leitor num instante — tudo que as conquistas
/// precisam para decidir se foram cumpridas.
struct ProgressSnapshot {
    let finishedCount: Int
    let startedCount: Int
    let favoritesCount: Int
    let currentStreak: Int
    let bestStreak: Int
    let finishedByLevel: [StoryLevel: Int]
    let totalByLevel: [StoryLevel: Int]
    let readAfterMidnight: Bool
    let finishedTagCounts: [String: Int]
}

enum Achievements {
    /// Catálogo declarativo. Ordem = ordem de exibição.
    static let all: [Achievement] = [
        Achievement(
            id: "first-tale", title: "First Light",
            detail: "Finish your first story.", symbol: "book.closed.fill",
            goal: 1, progressValue: { min($0.finishedCount, 1) }
        ),
        Achievement(
            id: "five-tales", title: "Well Read",
            detail: "Finish five stories.", symbol: "books.vertical.fill",
            goal: 5, progressValue: { $0.finishedCount }
        ),
        Achievement(
            id: "ten-tales", title: "Deep Reader",
            detail: "Finish ten stories.", symbol: "book.pages.fill",
            goal: 10, progressValue: { $0.finishedCount }
        ),
        Achievement(
            id: "all-tales", title: "Keeper of the Grimoire",
            detail: "Finish all fifty stories.", symbol: "seal.fill",
            goal: 50, progressValue: { $0.finishedCount }
        ),
        Achievement(
            id: "streak-3", title: "Three Nights",
            detail: "Read three days in a row.", symbol: "flame",
            goal: 3, progressValue: { $0.bestStreak }
        ),
        Achievement(
            id: "streak-7", title: "A Week by Lamplight",
            detail: "Read seven days in a row.", symbol: "flame.fill",
            goal: 7, progressValue: { $0.bestStreak }
        ),
        Achievement(
            id: "midnight", title: "After Midnight",
            detail: "Read a story past midnight.", symbol: "moon.stars.fill",
            goal: 1, progressValue: { $0.readAfterMidnight ? 1 : 0 }
        ),
        Achievement(
            id: "collector", title: "Collector",
            detail: "Save ten favorites.", symbol: "bookmark.fill",
            goal: 10, progressValue: { $0.favoritesCount }
        ),
        Achievement(
            id: "apprentice-path", title: "Apprentice's Path",
            detail: "Finish every Apprentice story.", symbol: "flame",
            goal: 1, progressValue: {
                let done = $0.finishedByLevel[.apprentice] ?? 0
                let total = $0.totalByLevel[.apprentice] ?? 0
                return (total > 0 && done >= total) ? 1 : 0
            }
        ),
        Achievement(
            id: "courageous", title: "Courage",
            detail: "Finish five stories tagged courage.", symbol: "shield.fill",
            goal: 5, progressValue: { $0.finishedTagCounts["courage"] ?? 0 }
        ),
    ]
}
