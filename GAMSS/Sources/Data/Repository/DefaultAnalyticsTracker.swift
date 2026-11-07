//
//  DefaultAnalyticsTracker.swift
//  GAMSS
//
//  Created by cchanmi on 11/7/26.
//

import Mixpanel

final class DefaultAnalyticsTracker: AnalyticsTracking {
    static let shared = DefaultAnalyticsTracker()

    private let instance: MixpanelInstance

    private init() {
        instance = Mixpanel.initialize(
            token: Environment.mixpanelToken,
            trackAutomaticEvents: true
        )
        instance.useIPAddressForGeoLocation = false
    }

    func track(_ event: AnalyticsEvent) {
        instance.track(event: event.name, properties: mixpanelProperties(from: event.properties))
    }

    func trackScreen(_ screen: AnalyticsScreen) {
        var properties = screen.properties
        properties["screen"] = screen.name
        instance.track(event: "screen_view", properties: mixpanelProperties(from: properties))
    }

    /// Domain 레이어는 Mixpanel 타입을 모르므로 `[String: Any]`로 받고, 여기서만
    /// Mixpanel이 이해하는 `Properties`(`[String: MixpanelType]`)로 변환한다.
    private func mixpanelProperties(from properties: [String: Any]) -> Properties? {
        guard !properties.isEmpty else { return nil }
        var result: Properties = [:]
        for (key, value) in properties {
            switch value {
            case let value as String:
                result[key] = value
            case let value as Int:
                result[key] = value
            default:
                Log.error("Unsupported analytics property type for key \(key)")
            }
        }
        return result
    }
}
