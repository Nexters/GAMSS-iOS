//
//  ModalContainerView.swift
//  GAMSS
//
//  Created by 이건준 on 8/4/26.
//

import SwiftUI

struct ModalContainerView<Content: View>: View {
    @Binding private var isPresented: Bool
    @State private var isAppeared = false
    
    private let dismissOnBackgroundTap: Bool
    private let content: () -> Content
    
    init(
        isPresented: Binding<Bool>,
        dismissOnBackgroundTap: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isPresented = isPresented
        self.dismissOnBackgroundTap = dismissOnBackgroundTap
        self.content = content
    }
    
    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .fullScreenCover(isPresented: $isPresented) {
                ZStack {
                    Color.colorBlack
                        .opacity(isAppeared ? 0.7 : 0)
                        .ignoresSafeArea()
                        .onTapGesture {
                            guard dismissOnBackgroundTap else { return }
                            isPresented = false
                        }
                    
                    content()
                        .padding(.horizontal, 28)
                        .scaleEffect(isAppeared ? 1 : 0.9)
                        .opacity(isAppeared ? 1 : 0)
                }
                .presentationBackground(.clear)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.25)) {
                        isAppeared = true
                    }
                }
                .onDisappear {
                    isAppeared = false
                }
            }
            .transaction { $0.disablesAnimations = true }
    }
}
