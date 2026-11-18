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
                .padding(.horizontal, Spacing.spacing600)
                .padding(.top, 30)

            Spacer(minLength: 0)

            keysRow
                .padding(.bottom, 42)
        }
        .hidesTabBar()
        .onAppear(perform: viewModel.start)
        .onDisappear(perform: viewModel.stop)
    }

    private var statsRow: some View {
        HStack(alignment: .center, spacing: 36) {
            timerColumn
                .frame(maxWidth: .infinity)

            scoreBox

            restartColumn
                .frame(maxWidth: .infinity)
        }
    }

    private var timerColumn: some View {
        VStack(spacing: Spacing.spacing025) {
            Image("clock")
                .frame(width: 24, height: 24)
                .foregroundStyle(Color.colorGray900)
            Text(viewModel.formattedTime)
                .typography(.subtitle3)
                .monospacedDigit()
                .foregroundStyle(Color.colorGray900)
        }
    }

    private var scoreBox: some View {
        Text("\(viewModel.formattedScore) 점")
            .typography(.title2)
            .monospacedDigit()
            .foregroundStyle(Color.colorGray900)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(Spacing.spacing300)
            .overlay(
                Rectangle()
                    .stroke(Color.colorGray950, lineWidth: 1.5)
            )
    }

    private var restartColumn: some View {
        Button(action: viewModel.restart) {
            VStack(spacing: Spacing.spacing025) {
                Image("arrow_clock_wise")
                    .frame(width: 24, height: 24)
                    .foregroundStyle(Color.colorGray900)
                Text("다시하기")
                    .typography(.subtitle3)
                    .foregroundStyle(Color.colorGray900)
            }
        }
        .buttonStyle(.plain)
    }

    private var keysRow: some View {
        HStack {
            ClickerKeycapView(
                isEnabled: viewModel.isPlaying,
                action: handleTap
            )
            Spacer()
            ClickerKeycapView(
                isEnabled: viewModel.isPlaying,
                action: handleTap
            )
        }
        .padding(.horizontal, Spacing.spacing350)
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
