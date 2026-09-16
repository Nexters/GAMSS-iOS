//
//  ArchiveDetailView.swift
//  GAMSS
//
//  Created by 이건준 on 8/18/26.
//

import SwiftUI
import SpriteKit

struct ArchiveDetailView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ArchiveDetailViewModel
    @State private var scene = DropStackScene()
    @State private var isMonthPickerPresented = false
    @State private var shredMode: CardShredMode?
    @State private var selectedNote: DropNote?
    @State private var isEmptyNotesModalPresented = false
    
    private let title: String
    
    init(
        title: String,
        viewModel: ArchiveDetailViewModel
    ) {
        self.title = title
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                NavigationBarView(title: title, onBack: { dismiss() }) {
                    Button {
                        if viewModel.notes.isEmpty {
                            isEmptyNotesModalPresented = true
                        } else {
                            shredMode = .all
                        }
                    } label: {
                        Text("비우기")
                            .typography(.body5Medium)
                            .foregroundStyle(Color.colorGray900)
                    }
                }
                
                monthSelector
                    .padding(.horizontal, Spacing.spacing350)
                    .padding(.bottom, Spacing.spacing300)
                
                ZStack {
                    Color.colorWhite
                    
                    if viewModel.notes.isEmpty, !viewModel.isLoading {
                        Text("아직 남겨둔 이야기가 없어요.")
                            .typography(.body3Regular)
                            .foregroundStyle(Color.colorGray500)
                    } else {
                        GeometryReader { proxy in
                            SpriteView(scene: scene, options: [.allowsTransparency])
                                .onAppear {
                                    scene.scaleMode = .resizeFill
                                    scene.updateSize(proxy.size)
                                    scene.onSelectNote = { note in
                                        withAnimation(.easeOut(duration: 0.12)) {
                                            selectedNote = note
                                        }
                                    }
                                    scene.render(notes: viewModel.notes)
                                }
                                .onChange(of: proxy.size) { _, newSize in
                                    scene.updateSize(newSize)
                                }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.colorWhite)
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .alert(
                viewModel.errorMessage ?? "",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("확인", role: .cancel) {}
            }
            .task {
                await viewModel.load()
            }
            .onChange(of: viewModel.notes) { _, notes in
                scene.render(notes: notes)
            }
            .sheet(isPresented: $isMonthPickerPresented) {
                ArchiveDatePickerSheet(selectedMonth: viewModel.selectedMonth) { month in
                    Task {
                        await viewModel.selectMonth(month)
                    }
                }
            }
            .navigationDestination(item: $shredMode) { mode in
                CardShredView(
                    viewModel: makeShredViewModel(for: mode),
                    stripImageName: "noteStrip",
                    onBack: {
                        if case .single(let cardId) = mode {
                            selectedNote = viewModel.notes.first { $0.id == cardId }
                        }
                        shredMode = nil
                    },
                    onComplete: {
                        shredMode = nil
                        selectedNote = nil
                        scene.clear()
                        Task { await viewModel.load() }
                    }
                )
            }

            if let note = selectedNote {
                CardDetailView(
                    viewModel: CardDetailViewModel(
                        cardId: note.id,
                        getCardUseCase: GetCardUseCase(
                            cardRepository: DefaultCardRepository(networkManager: NetworkManager.shared)
                        )
                    ),
                    onClose: {
                        withAnimation(.easeOut(duration: 0.12)) {
                            selectedNote = nil
                        }
                        Task { await viewModel.load() }
                    },
                    onDiscard: {
                        let cardId = note.id
                        shredMode = .single(cardId: cardId)
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            selectedNote = nil
                        }
                    }
                )
                .id(note.id)
                .transition(.opacity)
                .zIndex(1)
            }

            if isEmptyNotesModalPresented {
                ModalContainerView(isPresented: $isEmptyNotesModalPresented) {
                    ModalContentView(
                        title: "비울 감정이 없어요",
                        actions: [
                            .init(title: "확인", style: .primary, action: {
                                isEmptyNotesModalPresented = false
                            })
                        ]
                    )
                }
                .zIndex(2)
            }
        }
        .animation(.easeOut(duration: 0.12), value: selectedNote?.id)
        .hidesTabBar()
    }

    private func makeShredViewModel(for mode: CardShredMode) -> CardShredViewModel {
        let cardRepository = DefaultCardRepository(networkManager: NetworkManager.shared)
        switch mode {
        case .single(let cardId):
            return CardShredViewModel(
                cardId: cardId,
                deleteCardUseCase: DeleteCardUseCase(cardRepository: cardRepository)
            )
        case .all:
            return CardShredViewModel(
                deleteAllCardUseCase: DefaultDeleteAllCardUseCase(cardRepository: cardRepository)
            )
        }
    }
    
    private var monthSelector: some View {
        Button {
            isMonthPickerPresented = true
        } label: {
            HStack {
                Text(DateFormatterFactory.dateWithDot.string(from: viewModel.selectedMonth))
                    .typography(.subtitle2)
                    .foregroundStyle(Color.colorGray900)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .frame(width: 32, height: 32)
                    .foregroundStyle(Color.colorGray900)
            }
            .padding(.horizontal, Spacing.spacing200)
            .frame(height: 48)
            .overlay {
                Rectangle()
                    .stroke(Color.colorGray900, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }
}
