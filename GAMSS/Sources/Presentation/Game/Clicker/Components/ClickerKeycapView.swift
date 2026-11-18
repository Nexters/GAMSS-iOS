//
//  ClickerKeycapView.swift
//  GAMSS
//
//  Created by 이건준 on 11/16/26.
//

import SwiftUI
import UIKit

struct ClickerKeycapView: View {
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image("clicker")
                .resizable()
                .scaledToFit()
                .frame(width: 167, height: 179)
        }
        .buttonStyle(ClickerKeyButtonStyle())
        .disabled(!isEnabled)
        .onAppear {
            ClickerHaptic.prepare()
        }
    }
}

private enum ClickerHaptic {
    static let generator = UIImpactFeedbackGenerator(style: .rigid)

    static func prepare() {
        generator.prepare()
    }

    static func play() {
        generator.impactOccurred(intensity: 1)
        generator.prepare()
    }
}

private struct ClickerKeyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .offset(y: configuration.isPressed ? 5 : 0)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                guard isPressed else { return }
                ClickerHaptic.play()
            }
    }
}

#Preview {
    HStack(spacing: Spacing.spacing700) {
        ClickerKeycapView(isEnabled: true, action: {})
        ClickerKeycapView(isEnabled: true, action: {})
    }
    .padding()
}
