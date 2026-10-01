//
//  ArchiveDetailViewModel.swift
//  GAMSS
//
//  Created by 이건준 on 8/18/26.
//

import Combine
import Foundation

@MainActor
final class ArchiveDetailViewModel: ObservableObject {
    @Published var selectedMonth: Date
    @Published private(set) var notes: [DropNote] = []
    @Published private(set) var isLoading = true
    @Published var errorMessage: String?

    private let fetchCardsByDateUseCase: FetchCardsByDateUseCase
    private let deleteAllCardUseCase: DeleteAllCardUseCase

    init(
        fetchCardsByDateUseCase: FetchCardsByDateUseCase,
        deleteAllCardUseCase: DeleteAllCardUseCase,
        selectedMonth: Date = Date.now
    ) {
        self.fetchCardsByDateUseCase = fetchCardsByDateUseCase
        self.deleteAllCardUseCase = deleteAllCardUseCase
        self.selectedMonth = selectedMonth
    }

    var dropCount: Int { notes.count }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            notes = try await fetchCardsByDateUseCase.execute(yearMonth: selectedMonth).map { dailyEmotion in
                DropNote(id: dailyEmotion.id, imageName: "cardFoldStepTwo")
            }
        } catch {
            notes = []
            errorMessage = "노트 데이터를 불러오지 못했어요"
        }
    }

    func selectMonth(_ month: Date) async {
        selectedMonth = month
        notes = []
        await load()
    }

    func clearNotes() {
        notes = []
    }
    
    func deleteAll() async -> Bool {
        do {
            try await deleteAllCardUseCase.execute()
            return true
        } catch {
            return false
        }
    }
}
