//
//  AnalyticsScope.swift
//  GAMSS
//
//  Created by cchanmi on 11/7/26.
//

/// 카드 파쇄 범위 — 분석 이벤트 속성 전용. `single`은 카드 한 장, `emotionAll`은 감정 칸 전체.
enum AnalyticsScope: String {
    case single
    case emotionAll = "emotion_all"
}
