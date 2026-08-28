//
//  SubscriptionStore.swift
//  Grimoire — assinatura (StoreKit 2)
//
//  Mensal + anual. Transaction.currentEntitlements é a autoridade do
//  status Pro — sem cache frágil. Escuta Transaction.updates pra
//  renovação/reembolso/cross-device.
//
//  SETUP:
//    • Product IDs abaixo devem existir no App Store Connect (mesmo
//      grupo de assinatura) E no arquivo Grimoire.storekit (pra testar
//      no simulador sem sandbox).
//    • Ative o .storekit no scheme: Edit Scheme → Run → Options →
//      StoreKit Configuration → Grimoire.storekit
//

import StoreKit
import Observation

enum GrimoireProduct {
    static let monthly = "grimoire.pro.monthly"
    static let annual  = "grimoire.pro.annual"
    static let all = [monthly, annual]
}

@MainActor
@Observable
final class SubscriptionStore {
    private(set) var products: [Product] = []
    private(set) var isPro = false
    private(set) var loading = true
    var purchaseError: String?

    // Task de escuta das transações — retida enquanto o store viver.
    private var updatesTask: Task<Void, Never>?

    var monthly: Product? { products.first { $0.id == GrimoireProduct.monthly } }
    var annual:  Product? { products.first { $0.id == GrimoireProduct.annual } }

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if let tx = try? self.verified(update) {
                    await tx.finish()
                    await self.refresh()
                }
            }
        }
    }

    // Sem deinit: a task usa [weak self]; quando o store é desalocado,
    // self vira nil no próximo evento e o loop encerra. Transaction.updates
    // não retém o store, então não há vazamento.


    func load() async {
        loading = true
        defer { loading = false }
        do {
            products = try await Product.products(for: GrimoireProduct.all)
                .sorted { ($0.price) < ($1.price) }
            await refresh()
        } catch {
            purchaseError = "Couldn't load the plans. Try again."
        }
    }

    func refresh() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if let tx = try? verified(result),
               tx.productType == .autoRenewable,
               tx.revocationDate == nil {
                active = true
            }
        }
        isPro = active
    }

    /// StoreKit apresenta a folha nativa da Apple — o usuário confirma lá.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        purchaseError = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let tx = try verified(verification)
                await tx.finish()
                await refresh()
                return isPro
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = "The purchase didn't go through."
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refresh()
        } catch {
            purchaseError = "Couldn't restore. Try again."
        }
    }

    // MARK: derivados de preço

    /// Economia % do anual vs mensal×12. Nil se anual não for mais barato.
    var annualSavingsPercent: Int? {
        guard let m = monthly?.price, let a = annual?.price else { return nil }
        let year = m * 12
        guard a < year else { return nil }
        let pct = (1 - (a as NSDecimalNumber).doubleValue / (year as NSDecimalNumber).doubleValue) * 100
        return Int(pct.rounded())
    }

    /// Preço do anual expresso como equivalente por mês.
    var annualPerMonth: String? {
        guard let annual else { return nil }
        let perMonth = (annual.price as NSDecimalNumber).doubleValue / 12
        return annual.priceFormatStyle.format(Decimal(perMonth))
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreKitError.notEntitled
        case .verified(let safe): return safe
        }
    }
}
