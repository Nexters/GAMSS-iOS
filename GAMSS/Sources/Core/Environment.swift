//
//  Environment.swift
//  GAMSS
//
//  Created by 이건준 on 7/14/26.
//

import Foundation

/**
 각종 환경 변수를 관리하기 위한 열거형
 - ***i.e.***
 `Environment.baseURL` 형식으로 사용
 - Note: `Info.plist` 파일에 값이 추가되거나, 이외의 공통 환경 변수가 추가되는 경우 enum의 Key 값을 추가한다.
 */
public enum Environment {
    
    /// ShowPot 프로젝트에 해당하는 bundleID
    static let bundleID: String = {
        return Bundle.main.bundleIdentifier ?? "undefined"
    }()
    
    /// 앱 이름
    static let appName: String = {
        return value(key: "APP_NAME")
    }()
    
    /// 앱 버전 (`MARKETING_VERSION` → `CFBundleShortVersionString`)
    static let appVersion: String = {
        guard let version = infoDictionary["CFBundleShortVersionString"] as? String,
              !version.isEmpty
        else {
            return "-"
        }
        return version
    }()
    
    /// 서버 Base URL
    static let baseURL: String = {
        return value(key: "BASE_URL")
    }()
    
    /// 서비스 이용약관 URL
    static let termsOfServiceURL: String = {
        return value(key: "TERMS_OF_SERVICE_URL")
    }()
    
    /// 개인정보 처리방침 URL
    static let privacyPolicyURL: String = {
        return value(key: "PRIVACY_POLICY_URL")
    }()

    /// Mixpanel 프로젝트 토큰
    static let mixpanelToken: String = {
        return value(key: "MIXPANEL_TOKEN")
    }()

    /// Mixpanel 이벤트에 붙는 환경 구분값 (`development`/`production`) — 개발/운영이 같은
    /// Mixpanel 프로젝트를 쓰기 때문에, 토큰이 아니라 이 값으로 데이터를 나눠본다.
    static let mixpanelEnvironment: String = {
        return value(key: "MIXPANEL_ENVIRONMENT")
    }()
}

// MARK: I/O 관련 코드
extension Environment {
    
    /// Info.plist 파일 Dictionary
    private static let infoDictionary: [String: Any] = {
        guard let dict = Bundle.main.infoDictionary else {
            fatalError("Plist file not found")
        }
        return dict
    }()
    
    /// 값 추출
    fileprivate static func value(key: String) -> String {
        guard let value = Environment.infoDictionary[key] as? String else {
            fatalError("No such file for key: \(key)")
        }
        
        return value
    }
}
