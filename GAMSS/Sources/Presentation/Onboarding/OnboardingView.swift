//
//  OnboardingView.swift
//  GAMSS
//
//  Created by LEEGEONJUN on 8/14/26.
//

import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void
    
    @State private var currentPage: OnboardingPage = .talk
    
    var body: some View {
        VStack(spacing: 0) {
            NavigationBarView(
                showsBackButton: currentPage.showsBackButton,
                onBack: { goToPreviousPage() }
            ) {
                if currentPage.showsSkipButton {
                    Button {
                        onFinish()
                    } label: {
                        Text("건너뛰기")
                            .typography(.body5Medium)
                            .foregroundStyle(Color.colorGray500)
                    }
                }
            }
            
            Spacer()
            
            pageContent(currentPage)
                .id(currentPage)
                .padding(.horizontal, 31)
            
            Spacer()
            
            pageIndicator
                .padding(.bottom, Spacing.spacing400)
            
            actionButton
                .padding(.horizontal, Spacing.spacing350)
                .padding(.bottom, Spacing.spacing400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.colorWhite)
        .animation(.easeInOut(duration: 0.25), value: currentPage)
        .trackScreen(.onboarding)
    }
    
    private func pageContent(_ page: OnboardingPage) -> some View {
        VStack(spacing: Spacing.spacing600) {
            page.backgroundImage
                .resizable()
                .scaledToFit()
            
            Text(page.title)
                .typography(.subtitle2)
                .foregroundStyle(Color.colorGray900)
                .multilineTextAlignment(.center)
        }
    }
    
    private var pageIndicator: some View {
        HStack(spacing: Spacing.spacing100) {
            ForEach(OnboardingPage.allCases) { page in
                Circle()
                    .fill(page == currentPage ? Color.colorGray700 : Color.colorGray200)
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private var actionButton: some View {
        Button {
            goToNextPage()
        } label: {
            Text(currentPage.buttonTitle)
                .typography(.subtitle3)
                .foregroundStyle(Color.colorWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
        }
        .background(currentPage.buttonColor)
        .clipShape(RoundedRectangle(cornerRadius: Radius.radius200))
    }
    
    private func goToNextPage() {
        guard let next = OnboardingPage(rawValue: currentPage.rawValue + 1) else {
            onFinish()
            return
        }
        currentPage = next
    }
    
    private func goToPreviousPage() {
        guard let previous = OnboardingPage(rawValue: currentPage.rawValue - 1) else {
            return
        }
        currentPage = previous
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
