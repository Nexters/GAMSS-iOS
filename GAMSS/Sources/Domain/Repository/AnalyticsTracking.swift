//
//  AnalyticsTracking.swift
//  GAMSS
//
//  Created by cchanmi on 11/7/26.
//

/// 분석 이벤트 트래킹 추상화. 구현체는 `Data/Repository/DefaultAnalyticsTracker.swift`.
protocol AnalyticsTracking {
    func track(_ event: AnalyticsEvent)
    func trackScreen(_ screen: AnalyticsScreen)
}
