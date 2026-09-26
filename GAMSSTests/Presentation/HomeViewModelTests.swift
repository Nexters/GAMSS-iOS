//
//  HomeViewModelTests.swift
//  GAMSS
//
//  Created by cchanmi on 8/10/26.
//

import XCTest
@testable import GAMSS

private final class MockFetchMyProfileUseCase: FetchMyProfileUseCase {
    var stubbedResult: Result<User, Error> = .failure(SummaryError.inferenceFailed())
    private(set) var executeCallCount = 0

    func execute() async throws -> User {
        executeCallCount += 1
        return try stubbedResult.get()
    }
}

private final class MockMemberRepository: MemberRepository {
    var stubbedTokenUsageResult: Result<TokenUsage, Error> = .failure(SummaryError.inferenceFailed())
    private(set) var fetchTokenUsageCallCount = 0

    func deleteMember() async throws { fatalError("not used in this test") }
    func fetchMyProfile() async throws -> User { fatalError("not used in this test") }
    func updateNickname(_ nickname: String) async throws -> User { fatalError("not used in this test") }

    func fetchTokenUsage() async throws -> TokenUsage {
        fetchTokenUsageCallCount += 1
        return try stubbedTokenUsageResult.get()
    }
}

@MainActor
final class HomeViewModelTests: XCTestCase {
    private func makeViewModel(
        fetchMyProfileUseCase: MockFetchMyProfileUseCase = MockFetchMyProfileUseCase(),
        memberRepository: MockMemberRepository = MockMemberRepository(),
        userManager: UserManager = UserManager()
    ) -> HomeViewModel {
        HomeViewModel(
            fetchMyProfileUseCase: fetchMyProfileUseCase,
            getTokenUsageUseCase: GetTokenUsageUseCase(memberRepository: memberRepository),
            userManager: userManager
        )
    }

    func test_send_onSuccess_setsPendingFirstMessageAndClearsInput() {
        let viewModel = makeViewModel()
        viewModel.input = "안녕"

        viewModel.send()

        XCTAssertEqual(viewModel.pendingFirstMessage?.content, "안녕")
        XCTAssertEqual(viewModel.input, "")
    }

    func test_send_contentTooLong_setsValidationAlertAndDoesNotSetPendingFirstMessage() {
        let viewModel = makeViewModel()
        viewModel.input = String(repeating: "가", count: ConversationSummaryPolicy.maxMessageLength + 1)

        viewModel.send()

        XCTAssertNil(viewModel.pendingFirstMessage, "최종 검증에 걸리면 채팅 화면으로 넘어가면 안 됨")
        XCTAssertEqual(viewModel.alertMessage, SendMessageValidationError.tooLong.errorDescription)
    }

    func test_updateInput_trailingNewline_keepsNewlineAndDoesNotSignalKeyboardDismiss() {
        let viewModel = makeViewModel()

        let shouldDismiss = viewModel.updateInput("안녕\n")

        XCTAssertFalse(shouldDismiss)
        XCTAssertEqual(viewModel.input, "안녕\n")
    }

    func test_updateInput_overMaxLength_truncatesToMaxLength() {
        let viewModel = makeViewModel()
        let overLong = String(repeating: "가", count: ConversationSummaryPolicy.maxMessageLength + 10)

        let shouldDismiss = viewModel.updateInput(overLong)

        XCTAssertFalse(shouldDismiss)
        XCTAssertEqual(viewModel.input.count, ConversationSummaryPolicy.maxMessageLength)
    }

    func test_updateInput_overMaxLength_showsLengthLimitToast() {
        let viewModel = makeViewModel()
        let overLong = String(repeating: "가", count: ConversationSummaryPolicy.maxMessageLength + 10)

        _ = viewModel.updateInput(overLong)

        XCTAssertEqual(viewModel.toastMessage, ConversationSummaryPolicy.lengthLimitToastMessage)
    }

    func test_updateInput_withinMaxLength_doesNotShowToast() {
        let viewModel = makeViewModel()

        _ = viewModel.updateInput("안녕")

        XCTAssertNil(viewModel.toastMessage)
    }

    func test_isSendDisabled_matchesToastMessage_atLengthLimit() {
        let viewModel = makeViewModel()
        let overLong = String(repeating: "가", count: ConversationSummaryPolicy.maxMessageLength + 10)

        _ = viewModel.updateInput(overLong)

        XCTAssertNotNil(viewModel.toastMessage)
        XCTAssertTrue(viewModel.isSendDisabled)
    }

    /// 토스트는 2초 타이머로 자동으로 닫히지만(시간 기반이라 여기선 검증하지 않음),
    /// 전송 가능 여부는 그 타이머와 무관하게 글자수만 보고 즉시 갱신된다.
    func test_isSendDisabled_clearsImmediatelyBelowLimit() {
        let viewModel = makeViewModel()
        let overLong = String(repeating: "가", count: ConversationSummaryPolicy.maxMessageLength + 10)
        _ = viewModel.updateInput(overLong)

        _ = viewModel.updateInput(String(overLong.prefix(ConversationSummaryPolicy.maxMessageLength - 1)))

        XCTAssertFalse(viewModel.isSendDisabled)
    }

    func test_isSendDisabled_trueWhenInputAtMaxLength() {
        let viewModel = makeViewModel()
        viewModel.input = String(repeating: "가", count: ConversationSummaryPolicy.maxMessageLength)

        XCTAssertTrue(viewModel.isSendDisabled, "글자수가 최대 길이인 동안은 전송을 막아야 함")
    }

    func test_isSendDisabled_falseWhenInputBelowMaxLength() {
        let viewModel = makeViewModel()
        viewModel.input = String(repeating: "가", count: ConversationSummaryPolicy.maxMessageLength - 1)

        XCTAssertFalse(viewModel.isSendDisabled)
    }

    func test_isSendDisabled_trueWhenInputBlank() {
        let viewModel = makeViewModel()
        viewModel.input = "   "

        XCTAssertTrue(viewModel.isSendDisabled)
    }

    func test_isSendDisabled_falseWhenInputHasContent() {
        let viewModel = makeViewModel()
        viewModel.input = "안녕"

        XCTAssertFalse(viewModel.isSendDisabled)
    }

    func test_selectedEmotions_defaultsToAllSixCharacters() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.selectedEmotions, Set(EmotionCharacter.allCases))
    }

    func test_toggleEmotion_deselectsWhenMoreThanOneRemainsSelected() {
        let viewModel = makeViewModel()

        viewModel.toggleEmotion(.joy)

        XCTAssertFalse(viewModel.selectedEmotions.contains(.joy))
        XCTAssertEqual(viewModel.selectedEmotions.count, 5)
    }

    func test_toggleEmotion_reselectsAfterBeingDeselected() {
        let viewModel = makeViewModel()
        viewModel.toggleEmotion(.joy)

        viewModel.toggleEmotion(.joy)

        XCTAssertTrue(viewModel.selectedEmotions.contains(.joy))
        XCTAssertEqual(viewModel.selectedEmotions.count, 6)
    }

    func test_toggleEmotion_lastRemainingSelection_isAllowed_resultsInEmptySelection() {
        let viewModel = makeViewModel()
        for emotion in EmotionCharacter.allCases where emotion != .joy {
            viewModel.toggleEmotion(emotion)
        }
        XCTAssertEqual(viewModel.selectedEmotions, [.joy], "사전 조건: 마지막 1개(joy)만 남아있어야 함")

        viewModel.toggleEmotion(.joy)

        XCTAssertTrue(viewModel.selectedEmotions.isEmpty, "전체 해제가 허용되어야 함")
    }

    func test_toggleEmotion_deselectingLast_showsEmotionRequiredToast() {
        let viewModel = makeViewModel()
        for emotion in EmotionCharacter.allCases where emotion != .joy {
            viewModel.toggleEmotion(emotion)
        }

        viewModel.toggleEmotion(.joy)

        XCTAssertEqual(viewModel.toastMessage, HomeViewModel.emotionRequiredToastMessage)
    }

    func test_toggleEmotion_deselectingNonLast_doesNotShowToast() {
        let viewModel = makeViewModel()

        viewModel.toggleEmotion(.joy)

        XCTAssertNil(viewModel.toastMessage)
    }

    func test_isEmotionPickerOpen_defaultsToFalse() {
        let viewModel = makeViewModel()

        XCTAssertFalse(viewModel.isEmotionPickerOpen)
    }

    func test_loadProfileIfNeeded_whenUserAlreadySet_doesNotCallUseCase() async {
        let useCase = MockFetchMyProfileUseCase()
        let userManager = UserManager()
        userManager.user = User(id: 1, email: "a@b.com", name: "기존", nickname: "기존닉네임")
        let viewModel = makeViewModel(fetchMyProfileUseCase: useCase, userManager: userManager)

        await viewModel.loadProfileIfNeeded()

        XCTAssertEqual(useCase.executeCallCount, 0, "이미 값이 있으면 재조회하면 안 됨")
        XCTAssertEqual(userManager.user?.nickname, "기존닉네임")
    }

    func test_loadProfileIfNeeded_whenUserNil_fetchesAndSetsUserManagerUser() async {
        let useCase = MockFetchMyProfileUseCase()
        useCase.stubbedResult = .success(User(id: 1, email: "a@b.com", name: "햄스터", nickname: "햄스터"))
        let userManager = UserManager()
        let viewModel = makeViewModel(fetchMyProfileUseCase: useCase, userManager: userManager)

        await viewModel.loadProfileIfNeeded()

        XCTAssertEqual(useCase.executeCallCount, 1)
        XCTAssertEqual(userManager.user?.nickname, "햄스터")
    }

    func test_loadProfileIfNeeded_onFailure_setsAlertMessage() async {
        let useCase = MockFetchMyProfileUseCase()
        useCase.stubbedResult = .failure(SummaryError.inferenceFailed())
        let userManager = UserManager()
        let viewModel = makeViewModel(fetchMyProfileUseCase: useCase, userManager: userManager)

        await viewModel.loadProfileIfNeeded()

        XCTAssertNotNil(viewModel.alertMessage)
        XCTAssertNil(userManager.user)
    }

    func test_send_excludesDeselectedEmotionsOnly() {
        let viewModel = makeViewModel()
        viewModel.input = "안녕"
        viewModel.toggleEmotion(.anger)
        viewModel.toggleEmotion(.quirky)

        viewModel.send()

        XCTAssertEqual(viewModel.pendingFirstMessage?.excludedCharacters, [.anger, .quirky])
    }

    func test_isSendDisabled_trueWhenAllEmotionsDeselected_evenWithInput() {
        let viewModel = makeViewModel()
        viewModel.input = "안녕"
        for emotion in EmotionCharacter.allCases {
            viewModel.toggleEmotion(emotion)
        }

        XCTAssertTrue(viewModel.selectedEmotions.isEmpty, "사전 조건: 전체 해제 상태여야 함")
        XCTAssertTrue(viewModel.isSendDisabled, "감정을 전체 제외하면 입력이 있어도 전송은 막혀야 함")
    }

    func test_loadTokenUsage_whenNotExceeded_doesNotDisableSend() async {
        let memberRepository = MockMemberRepository()
        memberRepository.stubbedTokenUsageResult = .success(TokenUsage(usedTokens: 10, dailyLimit: 100, exceeded: false))
        let viewModel = makeViewModel(memberRepository: memberRepository)
        viewModel.input = "안녕"

        await viewModel.loadTokenUsage()

        XCTAssertFalse(viewModel.isTokenExceeded)
        XCTAssertFalse(viewModel.isSendDisabled)
    }

    func test_loadTokenUsage_whenExceeded_disablesSend() async {
        let memberRepository = MockMemberRepository()
        memberRepository.stubbedTokenUsageResult = .success(TokenUsage(usedTokens: 100, dailyLimit: 100, exceeded: true))
        let viewModel = makeViewModel(memberRepository: memberRepository)
        viewModel.input = "안녕"

        await viewModel.loadTokenUsage()

        XCTAssertTrue(viewModel.isTokenExceeded)
        XCTAssertTrue(viewModel.isSendDisabled, "토큰을 다 쓰면 입력이 있어도 전송이 막혀야 함")
    }

    func test_loadTokenUsage_onFailure_leavesExceededStateUnchanged() async {
        let memberRepository = MockMemberRepository()
        memberRepository.stubbedTokenUsageResult = .failure(SummaryError.inferenceFailed())
        let viewModel = makeViewModel(memberRepository: memberRepository)

        await viewModel.loadTokenUsage()

        XCTAssertFalse(viewModel.isTokenExceeded, "조회 실패 시 조용히 무시하고 입력을 막지 않아야 함")
    }

    func test_send_whenTokenExceeded_doesNotSetPendingFirstMessage() async {
        let memberRepository = MockMemberRepository()
        memberRepository.stubbedTokenUsageResult = .success(TokenUsage(usedTokens: 100, dailyLimit: 100, exceeded: true))
        let viewModel = makeViewModel(memberRepository: memberRepository)
        await viewModel.loadTokenUsage()
        viewModel.input = "안녕"

        viewModel.send()

        XCTAssertNil(viewModel.pendingFirstMessage, "토큰을 다 쓰면 전송 자체가 막혀야 함")
    }
}
