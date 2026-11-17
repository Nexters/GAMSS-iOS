//
//  ClickerGameView.swift
//  GAMSS
//
//  Created by 이건준 on 11/16/26.
//

import SwiftUI

struct ClickerGameView: View {
    @StateObject private var viewModel: ClickerGameViewModel
    @SwiftUI.Environment(\.dismiss) private var dismiss

    init(viewModel: ClickerGameViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            NavigationBarView(leading: .backButton, onBack: { dismiss() })

            statsRow
                .padding(.horizontal, NavigationBarMetrics.horizontalPadding)
                .padding(.top, Spacing.spacing100)

            Spacer(minLength: 0)

            keysRow
                .padding(.bottom, Spacing.spacing700)
        }
        .hidesTabBar()
        .onAppear(perform: viewModel.start)
        .onDisappear(perform: viewModel.stop)
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
    }

    private var keysRow: some View {
        HStack {
            Spacer(minLength: 0)
            ClickerKeycapView(
                isEnabled: viewModel.isPlaying,
                action: handleTap
            )
            Spacer(minLength: Spacing.spacing400)
            ClickerKeycapView(
                isEnabled: viewModel.isPlaying,
                action: handleTap
            )
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.spacing400)
    }

    private func handleTap() {
        viewModel.tap()
    }
}

#Preview {
    NavigationStack {
        ClickerGameView(viewModel: ClickerGameViewModel())
            .background(NavigationBarHider())
    }
}
