//
//  TokenPurchaseView.swift
//  GAMSS
//
//  Created by cchanmi on 11/8/26.
//

import SwiftUI

struct TokenPurchaseView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TokenPurchaseViewModel

    init(viewModel: TokenPurchaseViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationBarView(title: "토큰 충전 (디버그)", onBack: { dismiss() })

            Text("보유 잔액: \(viewModel.balance)")
                .typography(.subtitle4)
                .foregroundStyle(Color.colorGray900)
                .padding(.horizontal, 18)
                .padding(.top, Spacing.spacing300)

            ForEach(viewModel.products) { product in
                Button {
                    Task { await viewModel.purchase(productId: product.id) }
                } label: {
                    MenuListItemView(
                        title: "\(product.tokenAmount)개",
                        trailingText: product.displayPrice
                    )
                    .padding(.horizontal, 18)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSubmitting)
            }

            Spacer()

            if let toastMessage = viewModel.toastMessage {
                ToastView(message: toastMessage)
                    .padding(.bottom, Spacing.spacing300)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.colorWhite)
        .animation(.easeInOut(duration: 0.2), value: viewModel.toastMessage)
        .task {
            await viewModel.loadProducts()
        }
    }
}
