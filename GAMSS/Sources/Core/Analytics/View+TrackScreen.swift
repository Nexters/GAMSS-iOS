//
//  View+TrackScreen.swift
//  GAMSS
//
//  Created by cchanmi on 11/7/26.
//

import SwiftUI

extension View {
    /// 화면 진입마다(뒤로가기로 재진입하는 경우 포함) `screen_view`를 기록한다.
    func trackScreen(
        _ screen: AnalyticsScreen,
        analyticsTracker: AnalyticsTracking = DefaultAnalyticsTracker.shared
    ) -> some View {
        onAppear {
            analyticsTracker.trackScreen(screen)
        }
    }
}
