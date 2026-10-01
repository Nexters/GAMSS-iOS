//
//  CardShredView.swift
//  GAMSS
//
//  Created by 이건준 on 8/21/26.
//

import SwiftUI

struct CardShredView: View {
    let onBack: () -> Void
    let onComplete: () -> Void
    let stripImageName: String

    @StateObject private var viewModel: CardShredViewModel

    private let strips: [ShredStrip] = [
        .init(xRatio: 0.06, width: 36, height: 420),
        .init(xRatio: 0.18, width: 32, height: 360),
        .init(xRatio: 0.29, width: 38, height: 480),
        .init(xRatio: 0.42, width: 34, height: 400),
        .init(xRatio: 0.53, width: 40, height: 450),
        .init(xRatio: 0.66, width: 33, height: 380),
        .init(xRatio: 0.77, width: 37, height: 470),
        .init(xRatio: 0.89, width: 31, height: 390)
    ]

    init(
        viewModel: CardShredViewModel,
        stripImageName: String,
        onBack: @escaping () -> Void,
        onComplete: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.stripImageName = stripImageName
        self.onBack = onBack
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationBarView(title: "비우기", onBack: onBack)

            powerToggle

            paperArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 27)
                .overlay(alignment: .bottom) {
                    ZStack {
                        if let toastMessage = viewModel.toastMessage {
                            ToastView(message: toastMessage)
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: viewModel.toastMessage)
                }

            shredButton
                .padding(.horizontal, 18)
                .padding(.top, Spacing.spacing300)
                .padding(.bottom, 42)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.colorWhite)
        .hidesTabBar()
    }

    private var powerToggle: some View {
        HStack {
            HStack(spacing: 0) {
                Text("OFF")
                    .typography(.body4Medium)
                    .foregroundStyle(viewModel.isPowerOn ? Color.colorGray500 : Color.colorWhite)
                    .padding(.horizontal, 8)
                    .frame(maxHeight: .infinity)
                    .background(viewModel.isPowerOn ? Color.clear : Color.colorApricot)
                    .clipShape(Capsule())

                Text("ON")
                    .typography(.body4Medium)
                    .foregroundStyle(viewModel.isPowerOn ? Color.colorWhite : Color.colorGray500)
                    .padding(.horizontal, 8)
                    .frame(maxHeight: .infinity)
                    .background(viewModel.isPowerOn ? Color.colorGreen : Color.clear)
                    .clipShape(Capsule())
            }
            .padding(4)
            .frame(height: 40)
            .background(Color.colorGray300)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.colorGray400, lineWidth: 1)
            )

            Spacer()

            ZStack {
                Circle()
                    .fill(Color.colorGray400)
                Circle()
                    .fill(viewModel.isPowerOn ? Color.colorGreen : Color.colorApricot)
                    .padding(6)
            }
            .frame(width: 30, height: 30)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .frame(height: 90)
        .background(Color.colorGray100)
        .allowsHitTesting(false)
    }

    private var paperArea: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                Color.colorWhite

                ForEach(strips) { strip in
                    Image(stripImageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: strip.width, height: strip.height, alignment: .top)
                        .offset(
                            x: proxy.size.width * strip.xRatio - strip.width * 0.5,
                            y: paperOffset(in: proxy.size.height, stripHeight: strip.height)
                        )
                }
            }
            .clipped()
        }
    }

    private var shredButton: some View {
        Button {
            if viewModel.isShredEnabled {
                Task {
                    let succeeded = await viewModel.shred()
                    if succeeded {
                        onComplete()
                    } else {
                        withAnimation(.easeInOut(duration: 0.45)) {
                            viewModel.reset()
                        } completion: {
                            viewModel.showShredFailureToast()
                        }
                    }
                }
            } else {
                withAnimation(.easeInOut(duration: 0.45)) {
                    viewModel.advance()
                }
            }
        } label: {
            Text("파쇄하기")
                .typography(.title5)
                .foregroundStyle(Color.colorWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(viewModel.isShredEnabled ? Color.colorApricot : Color.colorGray900)
                .clipShape(RoundedRectangle(cornerRadius: Radius.radius200))
        }
        .disabled(viewModel.isSubmitting)
        .buttonStyle(.plain)
    }

    private func paperOffset(in areaHeight: CGFloat, stripHeight: CGFloat) -> CGFloat {
        let startY = -stripHeight + 28
        let endY = areaHeight + 20
        return startY + (endY - startY) * viewModel.progress
    }
}

private struct ShredStrip: Identifiable {
    let id = UUID()
    let xRatio: CGFloat
    let width: CGFloat
    let height: CGFloat
}

#Preview("단일 삭제") {
    CardShredView(
        viewModel: CardShredViewModel(
            cardId: 1,
            deleteCardUseCase: DeleteCardUseCase(
                cardRepository: DefaultCardRepository(networkManager: NetworkManager.shared)
            )
        ),
        stripImageName: "noteStrip",
        onBack: {},
        onComplete: {}
    )
}

#Preview("전체 삭제") {
    CardShredView(
        viewModel: CardShredViewModel(
            deleteAllCardUseCase: DefaultDeleteAllCardUseCase(
                cardRepository: DefaultCardRepository(networkManager: NetworkManager.shared)
            )
        ),
        stripImageName: "noteStrip",
        onBack: {},
        onComplete: {}
    )
}
