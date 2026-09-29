//
//  CardResultView.swift
//  GAMSS
//
//  Created by cchanmi on 8/15/26.
//

import SwiftUI

struct CardResultView: View {
    let card: Card
    let onComplete: () -> Void

    @StateObject private var viewModel: CardResultViewModel
    @GestureState private var isDraggingPaper = false

    init(card: Card, viewModel: CardResultViewModel, onComplete: @escaping () -> Void) {
        self.card = card
        self.onComplete = onComplete
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private let foldGuideSize = CGSize(width: 190, height: 68)
    private let foldStepOneSize = CGSize(width: 353, height: 273)
    private let foldStepTwoSize = CGSize(width: 237, height: 253)
    private let discardArrowSize = CGSize(width: 101, height: 209)
    private let trashBinSize = CGSize(width: 402, height: 232)

    var body: some View {
        ZStack {
            Color.colorBlack.opacity(0.7)
                .ignoresSafeArea()

            switch viewModel.stage {
            case .unfolded:
                cardContent
            case .foldedOnce:
                foldStepImage("cardFoldStepOne", size: foldStepOneSize)
            case .readyToDiscard:
                discardableCard
            }
        }
    }

    private var cardContent: some View {
        ZStack(alignment: .topTrailing) {
            CardView(card: card) {
                foldGuideImage
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: viewModel.advanceStage)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("종이를 눌러 접어주세요")

            closeButton
                .padding([.top, .trailing], Spacing.spacing300)
        }
    }

    private var closeButton: some View {
        Button(action: onComplete) {
            Image("cardCloseButton")
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
        }
        .accessibilityLabel("닫기")
    }

    private var foldGuideImage: some View {
        Image("cardFoldGuide")
            .resizable()
            .frame(width: foldGuideSize.width, height: foldGuideSize.height)
    }

    private func foldStepImage(_ imageName: String, size: CGSize) -> some View {
        Button(action: viewModel.advanceStage) {
            Image(imageName)
                .resizable()
                .frame(width: size.width, height: size.height)
        }
        .accessibilityLabel("종이 접기")
    }

    private var discardableCard: some View {
        ZStack {
            draggablePaper

            trashBin
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea(edges: .bottom)

            Color.clear
                .frame(width: foldStepTwoSize.width, height: foldStepTwoSize.height)
                .overlay(alignment: .top) {
                    Text("내려서 버려주세요")
                        .typography(.body3Medium)
                        .foregroundStyle(Color.colorWhite)
                        .fixedSize()
                        .alignmentGuide(.top) { $0[.bottom] + 29 }
                }
        }
    }

    private var draggablePaper: some View {
        Image("cardFoldStepTwo")
            .resizable()
            .frame(width: foldStepTwoSize.width, height: foldStepTwoSize.height)
            .overlay(alignment: .top) {
                Image("cardDiscardArrow")
                    .resizable()
                    .frame(width: discardArrowSize.width, height: discardArrowSize.height)
                    .offset(y: 104)
                    .opacity(isDraggingPaper ? 0 : 1)
            }
            .offset(y: viewModel.dragOffset)
            .gesture(discardDragGesture)
    }

    private var trashBin: some View {
        Image("cardTrashBin")
            .resizable()
            .aspectRatio(trashBinSize.width / trashBinSize.height, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: trashBinSize.height)
    }

    private var discardDragGesture: some Gesture {
        DragGesture()
            .updating($isDraggingPaper) { _, isDraggingPaper, _ in
                isDraggingPaper = true
            }
            .onChanged { value in
                viewModel.updateDrag(translationHeight: value.translation.height)
            }
            .onEnded { value in
                if CardResultViewModel.shouldDiscard(dragOffset: max(0, value.translation.height)) {
                    withAnimation(.easeIn(duration: 0.3)) {
                        viewModel.drop()
                    } completion: {
                        onComplete()
                    }
                } else {
                    withAnimation(.spring()) {
                        viewModel.resetDrag()
                    }
                }
            }
    }
}

#Preview {
    CardResultView(
        card: Card(id: 1, conversationId: 1, emotion: .anger, summary: "오늘 비가 와서 짜증나고 찝찝하다", message: "얘 오늘 건들면 안 됨.", date: Date()),
        viewModel: CardResultViewModel(),
        onComplete: {}
    )
}
