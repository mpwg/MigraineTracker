import Foundation
import StoreKit

nonisolated enum SymiPlusProductConfiguration {
    static let defaultProductID = "eu.mpwg.MigraineTracker.symiPlus.yearly"

    static var productIDs: [String] {
        productIDs(from: Bundle.main.object(forInfoDictionaryKey: "SYMI_PLUS_PRODUCT_IDS") as? String)
    }

    static func productIDs(from rawValue: String?) -> [String] {
        guard
            let rawValue,
            !rawValue.isEmpty,
            !rawValue.contains("$(")
        else {
            return [defaultProductID]
        }

        let productIDs = rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return productIDs.isEmpty ? [defaultProductID] : productIDs
    }
}

enum SymiPlusStoreLoadState: Equatable {
    case idle
    case loading
    case loaded
    case unavailable
    case failed(String)
}

enum SymiPlusEntitlementState: Equatable {
    case unknown
    case inactive
    case active
}

enum SymiPlusPurchaseState: Equatable {
    case idle
    case purchasing
    case restoring
    case pending
    case succeeded
    case failed(String)
}

@MainActor
@Observable
final class SymiPlusStore {
    private(set) var loadState: SymiPlusStoreLoadState = .idle
    private(set) var entitlementState: SymiPlusEntitlementState = .unknown
    private(set) var purchaseState: SymiPlusPurchaseState = .idle
    private(set) var products: [Product] = []
    private(set) var selectedProduct: Product?

    private let productIDs: [String]
    @ObservationIgnored private var transactionUpdatesTask: Task<Void, Never>?

    init(productIDs: [String] = SymiPlusProductConfiguration.productIDs) {
        self.productIDs = productIDs
        self.transactionUpdatesTask = listenForTransactionUpdates()
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var primaryButtonTitle: String {
        if entitlementState == .active {
            return "Symi Plus aktiv"
        }

        switch loadState {
        case .idle, .loading:
            return "App Store laden..."
        case .loaded:
            if let price = selectedProduct?.displayPrice {
                return "Für \(price) aktivieren"
            }
            return "Symi Plus aktivieren"
        case .unavailable, .failed:
            return "Nicht verfügbar"
        }
    }

    var footerText: String {
        switch loadState {
        case .loaded:
            if let displayName = selectedProduct?.displayName, let price = selectedProduct?.displayPrice {
                return "\(displayName) wird direkt aus dem App Store geladen: \(price).\nDu kannst Käufe jederzeit wiederherstellen."
            }
            return "Der aktuelle Preis wird direkt aus dem App Store geladen.\nDu kannst Käufe jederzeit wiederherstellen."
        case .unavailable:
            return "Symi Plus ist im App Store noch nicht verfügbar.\nPrüfe die Product-ID in App Store Connect."
        case .failed(let message):
            return "\(message)\nDu kannst Käufe jederzeit wiederherstellen."
        case .idle, .loading:
            return "Der aktuelle Preis wird direkt aus dem App Store geladen.\nDu kannst Käufe jederzeit wiederherstellen."
        }
    }

    var statusMessage: String? {
        switch (entitlementState, purchaseState) {
        case (.active, _):
            return "Symi Plus ist auf diesem Apple Account aktiv."
        case (_, .pending):
            return "Der Kauf wartet auf Bestätigung."
        case (_, .succeeded):
            return "Kauf erfolgreich wiederhergestellt."
        case (_, .failed(let message)):
            return message
        default:
            return nil
        }
    }

    var canStartPurchase: Bool {
        selectedProduct != nil &&
            entitlementState != .active &&
            loadState == .loaded &&
            !isWorking
    }

    var canRestorePurchases: Bool {
        !isWorking
    }

    private var isWorking: Bool {
        switch purchaseState {
        case .purchasing, .restoring:
            return true
        case .idle, .pending, .succeeded, .failed:
            return loadState == .loading
        }
    }

    func loadProducts() async {
        guard loadState != .loading else {
            return
        }

        loadState = .loading

        do {
            let products = try await Product.products(for: productIDs)
            self.products = products.sorted { $0.displayName < $1.displayName }
            self.selectedProduct = self.products.first
            await refreshEntitlements()
            loadState = self.products.isEmpty ? .unavailable : .loaded
        } catch {
            loadState = .failed("Der App Store konnte nicht geladen werden.")
        }
    }

    func purchaseSelectedProduct() async {
        if selectedProduct == nil {
            await loadProducts()
        }

        guard let selectedProduct else {
            purchaseState = .failed("Symi Plus ist im App Store noch nicht verfügbar.")
            return
        }

        purchaseState = .purchasing

        do {
            let result = try await selectedProduct.purchase()

            switch result {
            case .success(let verificationResult):
                let transaction = try Self.verified(verificationResult)
                await transaction.finish()
                await refreshEntitlements()
                purchaseState = .succeeded
            case .pending:
                purchaseState = .pending
            case .userCancelled:
                purchaseState = .idle
            @unknown default:
                purchaseState = .failed("Der Kauf konnte nicht abgeschlossen werden.")
            }
        } catch {
            purchaseState = .failed("Der Kauf konnte nicht abgeschlossen werden.")
        }
    }

    func restorePurchases() async {
        purchaseState = .restoring

        do {
            try await AppStore.sync()
            await refreshEntitlements()
            purchaseState = entitlementState == .active ? .succeeded : .failed("Es wurden keine aktiven Symi-Plus-Käufe gefunden.")
        } catch {
            purchaseState = .failed("Käufe konnten nicht wiederhergestellt werden.")
        }
    }

    func refreshEntitlements() async {
        var hasActiveEntitlement = false

        for await verificationResult in Transaction.currentEntitlements {
            guard let transaction = try? Self.verified(verificationResult) else {
                continue
            }

            if productIDs.contains(transaction.productID), transaction.revocationDate == nil {
                hasActiveEntitlement = true
                break
            }
        }

        entitlementState = hasActiveEntitlement ? .active : .inactive
    }

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task { [weak self] in
            for await verificationResult in Transaction.updates {
                guard let self else {
                    return
                }

                guard let transaction = try? Self.verified(verificationResult) else {
                    await MainActor.run {
                        self.purchaseState = .failed("Die App-Store-Transaktion konnte nicht verifiziert werden.")
                    }
                    continue
                }

                await transaction.finish()
                await self.refreshEntitlements()
            }
        }
    }

    private static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw StoreKitVerificationError.unverifiedTransaction
        }
    }
}

private enum StoreKitVerificationError: Error {
    case unverifiedTransaction
}
