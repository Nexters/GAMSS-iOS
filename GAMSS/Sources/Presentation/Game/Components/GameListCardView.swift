//
//  GameListCardView.swift
//  GAMSS
//
//  Created by 이건준 on 11/16/26.
//

import SwiftUI

struct GameListCardView: View {
    let game: GameListItem
    
    var body: some View {
        VStack(spacing: Spacing.spacing200) {
            Image(game.illustrationImageName)
                .resizable()
                .scaledToFit()
                .background(Color.colorWhite)
            
            Text(game.title)
                .typography(.body3Medium)
                .foregroundStyle(Color.colorGray950)
        }
    }
}

#Preview {
    GameListCardView(game: .clicker)
        .padding()
        .background(Color.colorGray025)
}
