//
//  ConversationSummaryPolicyTests.swift
//  GAMSS
//
//  Created by cchanmi on 8/10/26.
//

import XCTest
@testable import GAMSS

final class ConversationSummaryPolicyTests: XCTestCase {
    func test_normalizeInput_trailingNewline_keepsNewlineAndDoesNotSignalKeyboardDismiss() {
        let result = ConversationSummaryPolicy.normalizeInput("안녕\n")

        XCTAssertEqual(result.value, "안녕\n")
        XCTAssertFalse(result.shouldDismissKeyboard)
        XCTAssertFalse(result.didExceedLimit)
    }

    func test_normalizeInput_withinMaxLength_returnsUnchanged() {
        let raw = String(repeating: "가", count: ConversationSummaryPolicy.maxMessageLength)

        let result = ConversationSummaryPolicy.normalizeInput(raw)

        XCTAssertEqual(result.value, raw)
        XCTAssertFalse(result.shouldDismissKeyboard)
        XCTAssertFalse(result.didExceedLimit)
    }

    func test_normalizeInput_overMaxLength_truncatesToMaxLengthAndSignalsExceeded() {
        let raw = String(repeating: "가", count: ConversationSummaryPolicy.maxMessageLength + 10)

        let result = ConversationSummaryPolicy.normalizeInput(raw)

        XCTAssertEqual(result.value.count, ConversationSummaryPolicy.maxMessageLength)
        XCTAssertFalse(result.shouldDismissKeyboard)
        XCTAssertTrue(result.didExceedLimit)
    }
}
