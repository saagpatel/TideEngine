import SwiftUI
import StoreKit

struct PaywallView: View {
    @ObservedObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    var onPurchased: () -> Void

    @State private var purchaseError: String?

    private let teal = Color(red: 0, green: 0.9, blue: 1.0)
    private let background = Color(red: 0.04, green: 0.055, blue: 0.10)

    var body: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.gray)
                }
            }
            .padding()

            Spacer()

            // Globe icon
            Image(systemName: "globe.americas.fill")
                .font(.system(size: 72))
                .foregroundStyle(teal)
                .padding(.bottom, 24)

            // Title
            Text("Unlock Global Tides")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
                .padding(.bottom, 8)

            Text("One-time purchase")
                .font(.subheadline)
                .foregroundStyle(.gray)
                .padding(.bottom, 32)

            // Benefits
            VStack(alignment: .leading, spacing: 20) {
                benefitRow(icon: "water.waves", text: "Tides for any coastline worldwide")
                benefitRow(icon: "sailboat.fill", text: "WorldTides — trusted by sailors globally")
                benefitRow(icon: "checkmark.seal.fill", text: "One-time purchase, no subscription")
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()

            // Error banner
            if let purchaseError {
                Text(purchaseError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 32)
            }

            // Purchase button
            Button {
                purchaseError = nil
                Task {
                    do {
                        _ = try await storeManager.purchase()
                    } catch {
                        purchaseError = error.localizedDescription
                    }
                }
            } label: {
                Group {
                    if storeManager.isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(priceLabel)
                            .font(.title3.weight(.bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(teal)
            .disabled(storeManager.isPurchasing || storeManager.product == nil)
            .padding(.horizontal, 32)

            // Restore
            Button {
                Task { await storeManager.restorePurchases() }
            } label: {
                Text("Restore Purchase")
                    .font(.footnote)
                    .foregroundStyle(.gray)
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(background.ignoresSafeArea())
        .task {
            await storeManager.loadProducts()
        }
        .onChange(of: storeManager.isInternationalUnlocked) { _, unlocked in
            if unlocked {
                onPurchased()
                dismiss()
            }
        }
    }

    private var priceLabel: String {
        if let product = storeManager.product {
            return "Unlock for \(product.displayPrice)"
        }
        return "Loading..."
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(teal)
                .frame(width: 28)
            Text(text)
                .font(.body)
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    PaywallView(storeManager: .shared, onPurchased: {})
}
