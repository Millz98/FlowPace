import Foundation
import StoreKit

@MainActor
class StoreKitManager: ObservableObject {
    @Published var isPro = false
    @Published var products: [Product] = []
    @Published var purchaseInProgress = false
    @Published var errorMessage: String?

    private let productIdentifiers = [
        "com.flowpace.pro.onetime"     // $2.99 CAD one-time purchase (support the developer)
    ]

    // Pro extras — nice-to-have features on top of supporting development
    var proFeatures: [ProFeature] {
        [
            ProFeature(icon: "icloud.fill", title: "iCloud Sync", description: "Sync routines across all your Apple devices"),
            ProFeature(icon: "chart.line.uptrend.xyaxis", title: "Advanced Analytics", description: "Streaks, trends, and time-per-routine insights"),
            ProFeature(icon: "square.and.arrow.up", title: "CSV Export", description: "Export your analytics data to CSV"),
            ProFeature(icon: "heart.fill", title: "Support Development", description: "Help keep FlowPace free for everyone")
        ]
    }
    private var updateListenerTask: Task<Void, Never>?

    init() {
        updateListenerTask = listenForTransactions()

        Task {
            await loadProducts()
            await updateProStatus()
        }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Product Loading

    @MainActor
    func loadProducts() async {
        do {
            products = try await Product.products(for: productIdentifiers)
        } catch {
            print("Failed to load products: \(error)")
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }

    // MARK: - Purchase Management

    func purchasePro(productId: String) async {
        guard let proProduct = products.first(where: { $0.id == productId }) else {
            errorMessage = "Pro product not available"
            return
        }

        purchaseInProgress = true
        errorMessage = nil

        do {
            let result = try await proProduct.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await deliverProFeatures(transaction: transaction)
                case .unverified(_, let error):
                    errorMessage = "Transaction verification failed: \(error.localizedDescription)"
                }
            case .userCancelled:
                errorMessage = "Purchase cancelled"
            case .pending:
                errorMessage = "Purchase pending approval"
            @unknown default:
                errorMessage = "Unknown purchase result"
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }

        purchaseInProgress = false
    }

    func restorePurchases() async {
        purchaseInProgress = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await updateProStatus()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }

        purchaseInProgress = false
    }

    // MARK: - Transaction Handling

    private func deliverProFeatures(transaction: Transaction) async {
        isPro = true
        UserDefaults.standard.set(true, forKey: "isPro")
        await transaction.finish()
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { @MainActor in
            for await result in Transaction.updates {
                await handleTransactionUpdate(result)
            }
        }
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            await deliverProFeatures(transaction: transaction)
        case .unverified(_, let error):
            print("Transaction verification failed: \(error)")
        }
    }

    // MARK: - Pro Status Management

    private func updateProStatus() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if productIdentifiers.contains(transaction.productID) {
                    isPro = true
                    UserDefaults.standard.set(true, forKey: "isPro")
                    return
                }
            }
        }

        isPro = UserDefaults.standard.bool(forKey: "isPro")
    }

    // MARK: - Utility Methods

    func getProProduct(productId: String) -> Product? {
        products.first(where: { $0.id == productId })
    }

    func getProPrice(productId: String) -> String? {
        getProProduct(productId: productId)?.displayPrice
    }

    func getOneTimeProduct() -> Product? {
        getProProduct(productId: "com.flowpace.pro.onetime")
    }

    var canPurchasePro: Bool {
        !products.isEmpty && !purchaseInProgress
    }

    func getProFeaturesText() -> String {
        return proFeatures.map { "• \($0.title): \($0.description)" }.joined(separator: "\n")
    }

    // MARK: - Development/Testing

    #if DEBUG
    func simulateProPurchase() {
        isPro = true
        UserDefaults.standard.set(true, forKey: "isPro")
    }

    func simulateProRevocation() {
        isPro = false
        UserDefaults.standard.set(false, forKey: "isPro")
    }
    #endif
}

// MARK: - Pro Feature Model

struct ProFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}
