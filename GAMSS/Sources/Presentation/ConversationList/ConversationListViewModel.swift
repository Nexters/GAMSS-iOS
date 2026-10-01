//
//  ConversationListViewModel.swift
//  GAMSS
//
//  Created by cchanmi on 8/8/26.
//

import Combine
import Foundation

@MainActor
final class ConversationListViewModel: ObservableObject {
    @Published private var conversations: [ConversationSummary] = []
    @Published private var searchResults: [ConversationSummary] = []
    var displayedConversations: [ConversationSummary] {
        isSearchExecuted
            ? searchResults
            : conversations
    }
    
    @Published private(set) var currentMode: ConversationMode = .normal
    @Published private(set) var isLoading = false
    @Published var alertMessage: String?
    @Published var editedText: String = ""
    @Published var isSearching: Bool = false
    @Published private(set) var isSearchExecuted = false
    @Published private(set) var isNetworkUnreachable = false
    
    @Published private var selectedConversations = Set<Int>()
    var isDeleteButtonEnabled: Bool {
        !selectedConversations.isEmpty
    }
    
    private let pageSize = 10
    private let loadMorePrefetchCount = 5
    private var searchPage = 0
    private var hasMoreSearchResults = false
    private var searchQuery = ""
    
    private let getIncompleteConversationsUseCase: GetIncompleteConversationsUseCase
    private let deleteConversationsUseCase: DeleteConversationsUseCase
    private let searchConversationUseCase: SearchConversationUseCase
    
    init(getIncompleteConversationsUseCase: GetIncompleteConversationsUseCase, deleteConversationsUseCase: DeleteConversationsUseCase, searchConversationUseCase: SearchConversationUseCase) {
        self.getIncompleteConversationsUseCase = getIncompleteConversationsUseCase
        self.deleteConversationsUseCase = deleteConversationsUseCase
        self.searchConversationUseCase = searchConversationUseCase
    }
    
    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            conversations = try await getIncompleteConversationsUseCase.execute()
            isNetworkUnreachable = false
        } catch NetworkError.noConnection {
            isNetworkUnreachable = true
        } catch {
            alertMessage = "채팅방 목록을 불러오지 못했어요"
        }
    }

    /// 네트워크 끊김 화면의 "재시도" 버튼에서 호출한다. 검색 중이었으면 검색을, 아니면 목록 조회를 다시 시도한다.
    func retryAfterNetworkFailure() async {
        if isSearching, !editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await searchText()
        } else {
            await load()
        }
    }
    
    func isSelected(id: Int) -> Bool {
        selectedConversations.contains(id)
    }
    
    func selectConversation(id: Int) {
        if isSelected(id: id) {
            selectedConversations.remove(id)
        } else {
            selectedConversations.insert(id)
        }
    }
    
    func deleteConversations() async {
        let selectedConversationList = Array(selectedConversations)
        do {
            try await deleteConversationsUseCase.execute(
                conversationIDs: selectedConversationList
            )
            
            conversations.removeAll { conversation in
                selectedConversations.contains(conversation.id)
            }
            
            searchResults.removeAll { conversation in
                selectedConversations.contains(conversation.id)
            }
            
            selectedConversations.removeAll()
        } catch {
            alertMessage = "채팅방을 삭제하지 못했어요"
        }
    }
    
    func updateMode(_ updatedMode: ConversationMode) {
        currentMode = updatedMode
        
        if updatedMode == .normal {
            selectedConversations.removeAll()
        }
    }
    
    func startSearching() {
        isSearching = true
        isSearchExecuted = false
    }
    
    func stopSearching() {
        isSearching = false
        isSearchExecuted = false
        editedText = ""
        searchQuery = ""
        searchResults.removeAll()
        searchPage = 0
        hasMoreSearchResults = false
    }
    
    func searchText() async {
        let query = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let page = try await searchConversationUseCase.execute(
                query,
                page: 0,
                size: pageSize
            )
            searchQuery = query
            searchPage = page.page
            hasMoreSearchResults = page.hasNextPage
            searchResults = page.items
            isSearchExecuted = true
            isNetworkUnreachable = false
        } catch NetworkError.noConnection {
            isNetworkUnreachable = true
        } catch {
            alertMessage = error.localizedDescription
        }
    }
    
    func loadMoreIfNeeded(at index: Int) async {
        guard isSearchExecuted,
              hasMoreSearchResults,
              !isLoading,
              index >= searchResults.count - loadMorePrefetchCount
        else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let nextPage = searchPage + 1
            let page = try await searchConversationUseCase.execute(
                searchQuery,
                page: nextPage,
                size: pageSize
            )
            searchPage = page.page
            hasMoreSearchResults = page.hasNextPage
            searchResults.append(contentsOf: page.items)
        } catch NetworkError.noConnection {
            isNetworkUnreachable = true
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
