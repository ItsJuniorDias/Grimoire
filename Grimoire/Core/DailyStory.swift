//
//  DailyStory.swift
//  Grimoire — sugestão de história do dia
//
//  Escolha determinística: mesma data → mesma história pra qualquer
//  dispositivo. Não precisa de estado persistido, não precisa de servidor.
//  A regra é pura, igual ao WeeklyFreeStories.
//
//  Se o usuário já terminou a história do dia, escolhemos a próxima não
//  terminada (mesma seed, offset). Se terminou TODAS, cai na do dia mesmo
//  como celebração — não faz sentido esconder achievement.
//

import Foundation

enum DailyStory {

    /// Escolhe a história do dia dado o catálogo + IDs já terminados.
    /// Determinística por data local do dispositivo (00:00 vira o dia).
    static func pick(from catalog: [StorySummary],
                     finished: Set<String>,
                     date: Date = Date()) -> StorySummary? {
        guard !catalog.isEmpty else { return nil }

        // Ordena por id pra ter sequência estável entre execuções — o `order`
        // do catálogo já é estável, mas o id é ainda mais canônico.
        let sorted = catalog.sorted { $0.id < $1.id }

        let baseIndex = seededIndex(for: date, count: sorted.count)

        // Percorre linearmente a partir do índice do dia procurando uma não
        // terminada. Se todas terminadas, retorna a do índice original.
        for offset in 0..<sorted.count {
            let idx = (baseIndex + offset) % sorted.count
            let story = sorted[idx]
            if !finished.contains(story.id) { return story }
        }
        return sorted[baseIndex]
    }

    /// Chave textual do dia — útil pra debug ou cache. Ex: "2026-08-26".
    static func dayKey(for date: Date = Date()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d",
                      c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Índice determinístico no catálogo, derivado da data.
    /// Usa (ano × 366 + dia-do-ano) módulo tamanho — distribui bem ao longo
    /// de anos e não repete no mesmo ano.
    private static func seededIndex(for date: Date, count: Int) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .current
        let year = cal.component(.year, from: date)
        let doy  = cal.ordinality(of: .day, in: .year, for: date) ?? 1
        let seed = year * 366 + doy
        return seed % max(count, 1)
    }
}
