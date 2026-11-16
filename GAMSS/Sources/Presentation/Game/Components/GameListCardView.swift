//
//  GameListCardView.swift
//  GAMSS
//
//  Created by 이건준 on 11/16/26.
//

import SwiftUI

struct GameListCardView: View {
    let game: GameListItem

    private let cardSize: CGFloat = 148
    private let accessorySize: CGFloat = 52

    var body: some View {
        VStack(spacing: Spacing.spacing150) {
            ZStack(alignment: .bottomTrailing) {
                Image(game.illustrationImageName)
                    .resizable()
                    .scaledToFit()
                    .padding(Spacing.spacing200)
                    .frame(width: cardSize, height: cardSize)
                    .background(Color.colorWhite)
                    .overlay(
                        Rectangle()
                            .stroke(Color.colorGray100, lineWidth: 1)
                    )

                Image(game.accessoryImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: accessorySize, height: accessorySize)
                    .offset(x: 14, y: 18)
            }
            .frame(width: cardSize, height: cardSize)

            Text(game.title)
                .typography(.body4Medium)
                .foregroundStyle(Color.colorGray950)
                .frame(width: cardSize)
        }
        .padding(.trailing, 14)
        .padding(.bottom, 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(game.title)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview {
    GameListCardView(game: .clicker)
        .padding()
        .background(Color.colorGray025)
}
