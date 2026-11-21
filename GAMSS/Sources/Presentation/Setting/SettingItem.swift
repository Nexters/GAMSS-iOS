//
//  SettingItem.swift
//  GAMSS
//
//  Created by LEEGEONJUN on 8/12/26.
//

import Foundation

enum SettingSection: CaseIterable, Identifiable {
    case account
    case service
    #if DEBUG
    case debug
    #endif

    var id: Self { self }

    var items: [SettingItem] {
        switch self {
        case .account:
            [.accountInfo]
        case .service:
            [.privacyPolicy, .appVersion]
        #if DEBUG
        case .debug:
            [.debugTokenPurchase]
        #endif
        }
    }
}

enum SettingItem: Identifiable {
    case accountInfo
    case privacyPolicy
    case appVersion
    #if DEBUG
    case debugTokenPurchase
    #endif

    var id: Self { self }

    var title: String {
        switch self {
        case .accountInfo:
            "계정 정보"
        case .privacyPolicy:
            "개인정보 처리방침"
        case .appVersion:
            "앱 버전"
        #if DEBUG
        case .debugTokenPurchase:
            "토큰 충전 (디버그)"
        #endif
        }
    }

    enum Action {
        case navigate
        case web(String)
        case none
    }

    var action: Action {
        switch self {
        case .accountInfo:
            .navigate
        case .privacyPolicy:
            .web(Environment.privacyPolicyURL)
        case .appVersion:
            .none
        #if DEBUG
        case .debugTokenPurchase:
            .navigate
        #endif
        }
    }

    var showsDividerBelow: Bool {
        switch self {
        case .accountInfo:
            true
        case .privacyPolicy, .appVersion:
            false
        #if DEBUG
        case .debugTokenPurchase:
            false
        #endif
        }
    }
}
