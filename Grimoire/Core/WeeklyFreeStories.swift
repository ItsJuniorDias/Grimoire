//
//  WeeklyFreeStories.swift
//  Grimoire — rotação semanal de histórias grátis
//
//  Toda semana, 3 histórias do pool (Apprentice + Initiate) ficam liberadas.
//  As 3 são escolhidas DETERMINISTICAMENTE a partir do número da semana do
//  ano — não de um sorteio salvo. Consequências:
//   • o mesmo aparelho mostra as mesmas 3 na mesma semana, sem sincronizar;
//   • reinstalar o app NÃO troca as 3 da semana (a semente é a data);
//   • virar a semana troca as 3 (as não começadas voltam a bloquear).
//
//  É local e, portanto, burlável mudando o relógio — aceitável por ora.
//  A regra é pura (sem estado), fácil de migrar pra um endpoint depois.
//

import Foundation

enum WeeklyFreeStories {

    /// Quantas histórias ficam livres por semana.
    static let perWeek = 3

    /// Níveis elegíveis para o sorteio (os mais acessíveis).
    static let eligibleLevels: Set<StoryLevel> = [.apprentice, .initiate]

    /// Identificador estável da semana atual: "ano-semana" (ISO 8601).
    /// Ex.: 2026-34. Usado como semente e como chave de "semana começada".
    static func weekKey(for date: Date = Date()) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let year = comps.yearForWeekOfYear ?? 0
        let week = comps.weekOfYear ?? 0
        return "\(year)-\(week)"
    }

    /// Semente numérica derivada da semana — determinística.
    private static func seed(for date: Date = Date()) -> UInt64 {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        let year = UInt64(comps.yearForWeekOfYear ?? 0)
        let week = UInt64(comps.weekOfYear ?? 0)
        // combina ano e semana num número estável
        return year &* 53 &+ week
    }

    /// As 3 histórias livres desta semana, dado o catálogo.
    /// Determinístico: mesma semana + mesmo catálogo => mesmas 3.
    static func freeIDs(from catalog: [StorySummary], date: Date = Date()) -> Set<String> {
        // pool elegível, ordenado de forma estável (por id) pra o sorteio ser
        // reprodutível independente da ordem do catálogo.
        let pool = catalog
            .filter { eligibleLevels.contains($0.level) }
            .map(\.id)
            .sorted()

        guard !pool.isEmpty else { return [] }
        let count = min(perWeek, pool.count)

        // Shuffle determinístico via gerador semeado — escolhe `count` ids.
        var rng = WeeklyRNG(seed: seed(for: date))
        var indices = Array(pool.indices)
        // Fisher–Yates parcial
        for i in 0..<count {
            let j = Int(rng.next() % UInt64(indices.count - i)) + i
            indices.swapAt(i, j)
        }
        let chosen = indices.prefix(count).map { pool[$0] }
        return Set(chosen)
    }
}

/// Gerador de números pseudoaleatórios semeado e portátil (SplitMix64).
/// Determinístico entre execuções e dispositivos — não usa o RNG do sistema.
struct WeeklyRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed &+ 0x9E3779B97F4A7C15 }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
