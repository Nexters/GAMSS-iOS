//
//  ClickerGameView.swift
//  GAMSS
//
//  Created by 이건준 on 11/16/26.
//

import SwiftUI
import UIKit

struct ClickerGameView: View {
    @StateObject private var viewModel: ClickerGameViewModel
    @SwiftUI.Environment(\.dismiss) private var dismiss

    init(viewModel: ClickerGameViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            paperBackground

            VStack(spacing: 0) {
                NavigationBarView(leading: .backButton, onBack: { dismiss() })

                statsRow
                    .padding(.horizontal, NavigationBarMetrics.horizontalPadding)
                    .padding(.top, Spacing.spacing100)

                GeometryReader { geo in
                    let boardSize = min(geo.size.width - Spacing.spacing800, geo.size.height - Spacing.spacing800, 268)
                    ClickerPromptBoardView(prompt: viewModel.prompt, size: boardSize)
                        .id(viewModel.prompt.id)
                        .animation(.easeInOut(duration: 0.12), value: viewModel.prompt.id)
                        .frame(width: geo.size.width, height: geo.size.height)
                }

                keysRow
                    .padding(.bottom, Spacing.spacing700)
            }
        }
        .hidesTabBar()
        .onAppear(perform: viewModel.start)
        .onDisappear(perform: viewModel.stop)
    }

    private var paperBackground: some View {
        GeometryReader { geo in
            Image("homeBackgroundPaper")
                .resizable()
                .scaledToFill()
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
    }

    private var statsRow: some View {
        HStack(alignment: .center) {
            timerColumn
                .frame(maxWidth: .infinity)

            scoreBox

            restartColumn
                .frame(maxWidth: .infinity)
        }
    }

    private var timerColumn: some View {
        VStack(spacing: Spacing.spacing050) {
            Image(systemName: "clock")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(Color.colorGray900)
            Text(viewModel.formattedTime)
                .typography(.body5Medium)
                .monospacedDigit()
                .foregroundStyle(Color.colorGray900)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("남은 시간 \(viewModel.formattedTime)")
    }

    private var scoreBox: some View {
        Text("\(viewModel.formattedScore) 점")
            .typography(.title5)
            .monospacedDigit()
            .foregroundStyle(Color.colorGray950)
            .padding(.horizontal, Spacing.spacing400)
            .padding(.vertical, Spacing.spacing100)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.radius050)
                    .stroke(Color.colorGray900, lineWidth: 1.5)
            )
            .accessibilityLabel("점수 \(viewModel.score)점")
    }

    private var restartColumn: some View {
        Button(action: viewModel.restart) {
            VStack(spacing: Spacing.spacing050) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Color.colorGray900)
                Text("다시하기")
                    .typography(.body5Medium)
                    .foregroundStyle(Color.colorGray900)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("다시하기")
    }

    private var keysRow: some View {
        HStack {
            Spacer(minLength: 0)
            ClickerKeycapView(
                style: .pink,
                syllable: viewModel.prompt.syllable,
                isEnabled: viewModel.isPlaying,
                action: { handleTap(.pink) }
            )
            Spacer(minLength: Spacing.spacing400)
            ClickerKeycapView(
                style: .blue,
                syllable: viewModel.prompt.syllable,
                isEnabled: viewModel.isPlaying,
                action: { handleTap(.blue) }
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.spacing400)
    }

    private func handleTap(_ style: ClickerKeyStyle) {
        let isCorrect = viewModel.tap(style)
        let generator = UIImpactFeedbackGenerator(style: isCorrect ? .light : .rigid)
        generator.impactOccurred()
    }
}

#Preview {
    NavigationStack {
        ClickerGameView(viewModel: ClickerGameViewModel())
            .background(NavigationBarHider())
    }
}
