//
//  Analytics.swift
//  Grimoire — cliente de analytics (anônimo)
//
//  Envia eventos para o backend próprio. É ANÔNIMO: cada aparelho tem um
//  UUID aleatório gerado na primeira execução (não vinculado à identidade
//  da pessoa nem ao Apple ID). Serve só para medir a jornada de conversão
//  de forma agregada.
//
//  Falha graciosamente: se não houver rede ou o servidor estiver fora, o
//  evento é descartado sem afetar o app. Analytics nunca quebra a UX.
//

import SwiftUI

@MainActor
@Observable
final class Analytics {

    /// URL do servidor de analytics no Render.
    private let endpoint = "https://analytics-grimoire.onrender.com"

    /// Identificador do jogo. Vai como properties.game em todo evento,
    /// permitindo filtrar métricas por jogo no dashboard.
    private let gameID = "grimoire"

    /// Chave opcional de ingestão. Se você definiu INGEST_KEY no servidor,
    /// ponha o mesmo valor aqui. Se deixou sem, mantenha vazio.
    private let ingestKey = ""

    /// Liga/desliga o envio. Desligado em DEBUG: rodar o app no simulador,
    /// testar compra com o .storekit ou abrir a mesma história vinte vezes
    /// seguidas não pode entrar no funil de conversão. Só build de Release
    /// (TestFlight e App Store) manda evento.
    #if DEBUG
    private let enabled = false
    #else
    private let enabled = true
    #endif

    private let deviceID: String
    private let appVersion: String

    /// Código ISO 3166-1 alpha-2 do país do dispositivo (ex: "BR", "US").
    /// Resolvido na init porque `Locale.current` não muda durante a execução
    /// do app — cachear evita chamar o subsistema de Locale em cada evento.
    /// Fica nil se o sistema não expor a região (raro, mas possível).
    private let country: String?

    private let defaults = UserDefaults.standard

    init() {
        // ID anônimo estável por instalação.
        if let saved = defaults.string(forKey: "grimoire.analytics.deviceID") {
            deviceID = saved
        } else {
            let new = UUID().uuidString
            defaults.set(new, forKey: "grimoire.analytics.deviceID")
            deviceID = new
        }
        appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"

        // País do dispositivo. `Locale.Region.identifier` já retorna em ISO
        // 3166-1 alpha-2 maiúsculo (formato que o backend espera). Guarda
        // nil se vier string vazia — evita mandar "" pro server (que rejeita).
        let regionID = Locale.current.region?.identifier
        country = (regionID?.isEmpty == false) ? regionID : nil
    }

    /// Registra um evento com propriedades opcionais.
    /// Dispara em background e ignora qualquer falha.
    /// O identificador do jogo é injetado automaticamente em properties.game.
    func track(_ event: Event, _ properties: [String: String] = [:]) {
        #if DEBUG
        // Em DEBUG nada sai do aparelho, mas o console mostra o que teria
        // saído — dá pra conferir o funil sem sujar os dados de produção.
        print("[analytics/dev] \(event.rawValue)", properties.isEmpty ? "" : "\(properties)")
        #endif
        guard enabled, let url = URL(string: "\(endpoint)/track") else { return }

        // Mescla properties do call site com o identificador do jogo.
        // Se o chamador passar "game" explicitamente, o dele ganha.
        var merged = properties
        if merged["game"] == nil { merged["game"] = gameID }

        var body: [String: Any] = [
            "device_id": deviceID,
            "name": event.rawValue,
            "app_version": appVersion,
            "platform": "ios",
            "properties": merged,
        ]
        // Country só entra se resolveu. O backend aceita ausência do campo
        // (salva NULL na coluna), então omitir é mais limpo que mandar "".
        if let country = country { body["country"] = country }

        guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !ingestKey.isEmpty { req.setValue(ingestKey, forHTTPHeaderField: "x-api-key") }
        req.httpBody = data
        req.timeoutInterval = 8

        // Fire-and-forget: não esperamos resposta nem tratamos erro.
        Task.detached {
            _ = try? await URLSession.shared.data(for: req)
        }
    }

    /// Eventos rastreados. Os cinco primeiros formam o funil de conversão.
    enum Event: String {
        case app_opened
        case story_opened
        case story_finished
        case paywall_viewed
        case purchase_started
        case purchase_completed
        case purchase_failed
        case favorite_added
        case narration_started
    }
}
