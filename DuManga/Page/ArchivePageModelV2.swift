//
// Created on 14/4/21.
//

import Foundation
import Combine

class ArchivePageModelV2: ObservableObject {
    @Published var currentIndex: Double = 0.0
    @Published var controlUiHidden = true

    @Published private(set) var loading = false
    @Published private(set) var archiveItems = [String: ArchiveItem]()
    @Published private(set) var archivePages = [String: [String]]()
    @Published private(set) var errorCode: ErrorCode?

    private let service = LANraragiService.shared
    private let prefetch = PrefetchService.shared

    private var cancellables: Set<AnyCancellable> = []

    func load(state: AppState, progress: Int) {
        loading = state.page.loading
        archiveItems = state.archive.archiveItems
        archivePages = state.page.archivePages
        errorCode = state.page.errorCode
        if currentIndex == 0 {
            currentIndex = Double(progress)
        }

        state.page.$loading.receive(on: DispatchQueue.main)
                .assign(to: \.loading, on: self)
                .store(in: &cancellables)

        state.archive.$archiveItems.receive(on: DispatchQueue.main)
                .assign(to: \.archiveItems, on: self)
                .store(in: &cancellables)

        state.page.$archivePages.receive(on: DispatchQueue.main)
                .assign(to: \.archivePages, on: self)
                .store(in: &cancellables)

        state.page.$errorCode.receive(on: DispatchQueue.main)
                .assign(to: \.errorCode, on: self)
                .store(in: &cancellables)
    }

    func unload() {
        cancellables.forEach({ $0.cancel() })
        prefetch.unload()
    }

    func verifyArchiveExists(id: String) -> Bool {
        archiveItems[id] != nil
    }

    func prefetchImages(ids: [String]) {
        var firstHalf = ids[..<currentIndex.int]
        let secondHalf = ids[currentIndex.int...]
        firstHalf.reverse()
        let array = Array(secondHalf + firstHalf)
        prefetch.preloadImages(ids: array)
    }

    func clearNewFlag(id: String) {
        service.clearNewFlag(id: id)
                .replaceError(with: "NOOP")
                .sink(receiveValue: { _ in
                    // NOOP
                })
                .store(in: &cancellables)
    }
}
