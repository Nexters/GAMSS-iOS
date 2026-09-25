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
    
    var id: Self { self }
    
    var items: [SettingItem] {
        switch self {
        case .account:
            [.accountInfo, .notification]
        case .service:
            [.privacyPolicy, .appVersion]
        }
    }
}

enum SettingItem: Identifiable {
    case accountInfo
    case notification
    case privacyPolicy
    case appVersion
    
    var id: Self { self }
    
    var title: String {
        switch self {
        case .accountInfo:
            "계정 정보"
        case .notification:
            "알림 설정"
        case .privacyPolicy:
            "개인정보 처리방침"
        case .appVersion:
            "앱 버전"
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
        case .appVersion, .notification:
            .none
        }
    }
    
    var showsDividerBelow: Bool {
        switch self {
        case .accountInfo, .notification:
            true
        case .privacyPolicy, .appVersion:
            false
        }
    }
}
