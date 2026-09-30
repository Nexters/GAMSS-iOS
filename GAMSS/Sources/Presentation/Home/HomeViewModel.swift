//
//  HomeViewModel.swift
//  GAMSS
//
//  Created by cchanmi on 8/8/26.
//

import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var input: String = ""
    @Published var alertMessage: String?
    @Published private(set) var toastMessage: String?
    @Published var pendingFirstMessage: PendingFirstMessage?
    @Published private(set) var selectedEmotions: Set<EmotionCharacter> = Set(EmotionCharacter.allCases)
    @Published var isEmotionPickerOpen = false
    @Published private(set) var isTokenExceeded = false
    @Published private(set) var isNetworkUnreachable = false

    private var toastDismissTask: Task<Void, Never>?

    let composerDisabledPlaceholder = "오늘의 토큰을 모두 사용했어요"
    static let emotionRequiredToastMessage = "감정은 최소 한 개 남겨 주세요."

    private let fetchMyProfileUseCase: FetchMyProfileUseCase
    private let getTokenUsageUseCase: GetTokenUsageUseCase
    private let userManager: UserManager

    init(
        fetchMyProfileUseCase: FetchMyProfileUseCase,
        getTokenUsageUseCase: GetTokenUsageUseCase,
        userManager: UserManager = .shared
    ) {
        self.fetchMyProfileUseCase = fetchMyProfileUseCase
        self.getTokenUsageUseCase = getTokenUsageUseCase
        self.userManager = userManager
    }

    /// 화면 진입 시 1회 호출한다. 이미 프로필이 있으면(다른 화면에서 이미 불러온 경우 등)
    /// 재조회하지 않는다 — 탭을 오갈 때마다 API를 다시 부르지 않기 위함.
    func loadProfileIfNeeded() async {
        guard userManager.user == nil else { return }
        do {
            userManager.user = try await fetchMyProfileUseCase.execute()
            isNetworkUnreachable = false
        } catch NetworkError.noConnection {
            isNetworkUnreachable = true
        } catch {
            alertMessage = "사용자 정보를 불러오지 못했어요"
        }
    }

    /// 네트워크 끊김 화면의 "재시도" 버튼에서 호출한다. 진입 시 하던 조회를 다시 시도한다.
    func retryAfterNetworkFailure() async {
        await loadProfileIfNeeded()
        await loadTokenUsage()
    }

    /// 입력창의 원시 입력값을 받아 정책에 맞게 정규화하고, 키보드를 내려야 하는지 돌려준다.
    /// 입력이 최대 길이에 걸려있는 시점에 맞춰 토스트도 같이 띄운다 — `isSendDisabled`가
    /// 보는 조건(`isAtLengthLimit`)과 완전히 같은 조건이라, 토스트가 뜨는 시점과 전송이
    /// 막히는 시점이 항상 일치한다.
    func updateInput(_ rawValue: String) -> Bool {
        let result = ConversationSummaryPolicy.normalizeInput(rawValue)
        input = result.value
        if isAtLengthLimit {
            showToast(ConversationSummaryPolicy.lengthLimitToastMessage)
        }
        return result.shouldDismissKeyboard
    }

    /// 토스트는 2초만 보여주고 자동으로 닫는다. 전송 가능 여부(`isSendDisabled`)는 이 토스트
    /// 타이머와 무관하게 조건(글자수 제한, 감정 전체 해제 등)을 직접 보고 판단하므로, 토스트가
    /// 사라진 뒤에도 그 조건이 여전하면 전송은 계속 막혀있다.
    private func showToast(_ message: String) {
        toastMessage = message
        toastDismissTask?.cancel()
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }

    private var isAtLengthLimit: Bool {
        input.count >= ConversationSummaryPolicy.maxMessageLength
    }

    var isSendDisabled: Bool {
        input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || selectedEmotions.isEmpty
            || isTokenExceeded
            || isAtLengthLimit
    }

    /// 화면 진입/재진입마다 호출한다. 채팅에서 토큰을 다 쓰고 돌아왔을 수 있어, 프로필과
    /// 달리 캐싱하지 않고 매번 최신 상태를 확인한다.
    func loadTokenUsage() async {
        do {
            let usage = try await getTokenUsageUseCase.execute()
            isTokenExceeded = usage.exceeded
            isNetworkUnreachable = false
        } catch NetworkError.noConnection {
            isNetworkUnreachable = true
        } catch {
            // 실패해도 조용히 무시한다 — 입력을 막을지 여부만 결정하는 부가 정보라, 홈 진입
            // 자체를 방해하는 얼럿까지는 띄우지 않는다.
        }
    }

    /// 감정 선택을 토글한다. 전체 해제(0개)도 허용한다 — 그 경우 `isSendDisabled`가 true가
    /// 되어 전송 버튼이 비활성화되는 방식으로 "최소 1개 선택" 제약을 강제하고, 마지막 1개를
    /// 해제하는 순간에는 토스트로도 안내한다.
    func toggleEmotion(_ emotion: EmotionCharacter) {
        if selectedEmotions.contains(emotion) {
            selectedEmotions.remove(emotion)
            if selectedEmotions.isEmpty {
                showToast(Self.emotionRequiredToastMessage)
            }
        } else {
            selectedEmotions.insert(emotion)
        }
    }

    /// 서버 응답을 기다리지 않고 채팅 화면으로 바로 넘어간다 — 실제 전송/제목 저장은
    /// ChatViewModel이 화면 진입 직후 pendingFirstMessage로 자동 시작한다.
    func send() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isTokenExceeded else { return }
        guard trimmed.count <= ConversationSummaryPolicy.maxMessageLength else {
            alertMessage = SendMessageValidationError.tooLong.errorDescription
            return
        }
        guard !selectedEmotions.isEmpty else { return }

        input = ""
        pendingFirstMessage = PendingFirstMessage(
            content: trimmed,
            excludedCharacters: Set(EmotionCharacter.allCases).subtracting(selectedEmotions)
        )
    }
}
