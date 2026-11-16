//
//  GameListView.swift
//  GAMSS
//
//  Created by 이건준 on 11/16/26.
//

import SwiftUI

/// 나중에 탭으로 붙일 미니게임 목록. 탭바 등록은 하지 않고 화면만 둔다.
struct GameListView: View {
    @State private var isSettingPresented = false
    @State private var selectedGame: GameListItem?

    var body: some View {
        ZStack {
            paperBackground

            VStack(alignment: .leading, spacing: 0) {
                NavigationBarView(leading: .logo, trailing: {
                    Button {
                        isSettingPresented = true
                    } label: {
                        Image("gear")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(Color.colorGray900)
                    }
                })

                gameGrid
                    .padding(.top, Spacing.spacing300)
                    .padding(.horizontal, NavigationBarMetrics.horizontalPadding)

                Spacer(minLength: 0)
            }
        }
        .navigationDestination(item: $selectedGame) { game in
            destination(for: game)
        }
        .navigationDestination(isPresented: $isSettingPresented) {
            SettingView()
        }
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

    private var gameGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Spacing.spacing400, alignment: .topLeading),
                GridItem(.flexible(), spacing: Spacing.spacing400, alignment: .topLeading)
            ],
            alignment: .leading,
            spacing: Spacing.spacing500
        ) {
            ForEach(GameListItem.allCases) { game in
                Button {
                    selectedGame = game
                } label: {
                    GameListCardView(game: game)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func destination(for game: GameListItem) -> some View {
        switch game {
        case .clicker:
            ClickerGameView(viewModel: ClickerGameViewModel())
        }
    }
}

#Preview {
    NavigationStack {
        GameListView()
            .background(NavigationBarHider())
    }
}
