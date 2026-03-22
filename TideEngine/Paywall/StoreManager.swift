import StoreKit
import Foundation

@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()
    private static let productId = "com.tideengine.international"
    private static let suite = UserDefaults(suiteName: "group.com.tideengine")!
    private static let unlockKey = "internationalUnlocked"

    @Published private(set) var product: Product?
    @Published private(set) var isInternationalUnlocked: Bool
    @Published private(set) var isPurchasing = false

    private var transactionListener: Task<Void, Never>?

    init() {
        isInternationalUnlocked = Self.suite.bool(forKey: Self.unlockKey)
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.productId])
            product = products.first
        } catch {
            // Log but don't throw — product loading failure is not fatal
        }
    }

    func purchase() async throws -> Bool {
        guard let product else { return false }
        isPurchasing = true
        defer { isPurchasing = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            setUnlocked(true)
            provisionWorldTidesKey()
            return true
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch {
            // sync can fail silently — transaction listener handles actual restores
        }
    }

    private func setUnlocked(_ value: Bool) {
        isInternationalUnlocked = value
        Self.suite.set(value, forKey: Self.unlockKey)
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { break }
                if let transaction = try? self.checkVerified(result),
                   transaction.productID == Self.productId {
                    await self.setUnlocked(true)
                    self.provisionWorldTidesKey()
                    await transaction.finish()
                }
            }
        }
    }

    private nonisolated func provisionWorldTidesKey() {
        // Only provision if not already in Keychain
        guard KeychainHelper.loadWorldTidesKey() == nil else { return }

        // Obfuscated API key — XOR encoded to avoid plaintext in binary
        // To generate: XOR each byte of your real API key with 0x5A
        // For development/testing, use a placeholder that will be replaced before App Store submission
        let obfuscated: [UInt8] = [
            // Placeholder: "REPLACE_WITH_REAL_KEY" XOR'd with 0x5A
            0x08, 0x1F, 0x16, 0x1C, 0x1B, 0x19, 0x1F, 0x72,
            0x03, 0x1F, 0x0A, 0x18, 0x72, 0x08, 0x1F, 0x1B,
            0x1C, 0x72, 0x11, 0x1F, 0x0D
        ]
        let key = String(obfuscated.map { Character(UnicodeScalar($0 ^ 0x5A)) })

        try? KeychainHelper.saveWorldTidesKey(key)
    }

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified(_, let error): throw error
        }
    }
}
