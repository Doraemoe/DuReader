//  Created 23/8/20.

import SwiftUI
import NotificationBannerSwift

struct ArchivePageContainer: View {
    @EnvironmentObject var store: AppStore

    let itemId: String
    var lastPage: String?

    init(itemId: String) {
        self.itemId = itemId
    }

    var body: some View {
        ArchivePage(item: self.store.state.archive.archiveItems[itemId],
                pages: self.store.state.archive.archivePages[itemId],
                loading: self.store.state.archive.loading,
                errorCode: self.store.state.archive.errorCode,
                dispatchError: self.dispatchError,
                reset: self.resetState)
                .onAppear(perform: self.load)
    }

    private func dispatchError(errorCode: ErrorCode) {
        self.store.dispatch(.archive(action: .error(error: errorCode)))
    }

    private func load() {
        if self.store.state.archive.archivePages[itemId]?.isEmpty ?? true {
            self.store.dispatch(.archive(action: .extractArchive(id: itemId)))
        }
    }

    private func resetState() {
        self.store.dispatch(.archive(action: .resetState))
    }
}

struct ArchivePage: View {
    @AppStorage(SettingsKey.tapLeftKey) var tapLeft: String = PageControl.next.rawValue
    @AppStorage(SettingsKey.tapMiddleKey) var tapMiddle: String = PageControl.navigation.rawValue
    @AppStorage(SettingsKey.tapRightKey) var tapRight: String = PageControl.previous.rawValue
    @AppStorage(SettingsKey.swipeLeftKey) var swipeLeft: String = PageControl.next.rawValue
    @AppStorage(SettingsKey.swipeRightKey) var swipeRight: String = PageControl.previous.rawValue
    @AppStorage(SettingsKey.splitPage) var splitPage: Bool = false
    @AppStorage(SettingsKey.splitPagePriorityLeft) var splitPagePriorityLeft: Bool = false
    @ObservedObject private var internalModel: InternalPageModel

    private let pages: [String]?
    private let item: ArchiveItem?
    private let loading: Bool
    private let errorCode: ErrorCode?
    private let reset: () -> Void

    init(item: ArchiveItem?,
         pages: [String]?,
         loading: Bool,
         errorCode: ErrorCode?,
         dispatchError: @escaping (ErrorCode) -> Void,
         reset: @escaping () -> Void) {
        self.item = item
        self.pages = pages
        self.loading = loading
        self.errorCode = errorCode
        self.reset = reset

        self.internalModel = InternalPageModel(dispatchError: dispatchError)
        self.loadStartImage()
    }

    var body: some View {
        handleError()
        return GeometryReader { geometry in
            ZStack {
                self.internalModel.currentImage
                        .resizable()
                        .scaledToFit()
                        .aspectRatio(contentMode: .fit)
                        .navigationBarHidden(self.internalModel.controlUiHidden)
                        .navigationBarTitle("")
                        .navigationBarItems(trailing: NavigationLink(destination: ArchiveDetails(item: self.item!)) {
                            Text("details")
                        })
                HStack {
                    Rectangle()
                            .opacity(0.0001) // opaque object does not response to tap event
                            .contentShape(Rectangle())
                            .onTapGesture(perform: { self.performAction(self.tapLeft) })
                    Rectangle()
                            .opacity(0.0001)
                            .contentShape(Rectangle())
                            .onTapGesture(perform: { self.performAction(self.tapMiddle) })
                    Rectangle()
                            .opacity(0.0001)
                            .contentShape(Rectangle())
                            .onTapGesture(perform: { self.performAction(self.tapRight) })
                }
                        .gesture(DragGesture(minimumDistance: 50, coordinateSpace: .global).onEnded { value in
                            if value.translation.width < 0 {
                                self.performAction(self.swipeLeft)
                            } else if value.translation.width > 0 {
                                self.performAction(self.swipeRight)
                            }
                        })
                VStack {
                    Spacer()
                    VStack {
                        Text(String(format: "%.0f/%d",
                                self.internalModel.currentIndex + 1,
                                self.pages?.count ?? 0))
                                .bold()
                        Slider(value: self.$internalModel.currentIndex,
                                in: self.getSliderRange(),
                                step: 1) { onSlider in
                            if !onSlider {
                                self.jumpToPage(self.internalModel.currentIndex, action: .jump)
                            }
                        }
                                .padding(.horizontal)
                    }
                            .padding()
                            .background(Color.primary.colorInvert()
                                    .opacity(self.internalModel.controlUiHidden ? 0 : 0.9))
                            .opacity(self.internalModel.controlUiHidden ? 0 : 1)
                }
                VStack {
                    Text("loading")
                    ProgressView()
                }
                        .frame(width: geometry.size.width / 3,
                                height: geometry.size.height / 5)
                        .background(Color.secondary)
                        .foregroundColor(Color.primary)
                        .cornerRadius(20)
                        .opacity(self.loading ? 1 : 0)
            }
        }
    }

    private func getIntPart(_ number: Double) -> Int {
        Int(exactly: number.rounded()) ?? 0
    }

    func loadStartImage() {
        if self.pages != nil {
            self.jumpToPage(self.internalModel.currentIndex, action: .next)
        }
    }

    func getSliderRange() -> ClosedRange<Double> {
        0...Double((self.pages?.count ?? 2) - 1)
    }

    func performAction(_ action: String) {
        switch action {
        case PageControl.next.rawValue:
            nextPage()
        case PageControl.previous.rawValue:
            previousPage()
        case PageControl.navigation.rawValue:
            self.internalModel.controlUiHidden.toggle()
        default:
            // This should not happen
            break
        }
    }

    func nextPage() {
        jumpToPage(self.internalModel.currentIndex + 1, action: .next)
    }

    func previousPage() {
        jumpToPage(self.internalModel.currentIndex - 1, action: .previous)
    }

    func jumpToPage(_ page: Double, action: PageFlipAction) {
        if UIDevice.current.orientation.isPortrait {
            if self.internalModel.isCurrentSplittingPage == .first && action == .next {
                nextInternalPage()
                return
            } else if self.internalModel.isCurrentSplittingPage == .last && action == .previous {
                previousInternalPage()
                return
            }
        }
        self.internalModel.isCurrentSplittingPage = .off
        let index = getIntPart(page)
        if (0..<(self.pages?.count ?? 1)).contains(index) {
            self.internalModel.load(page: pages![index],
                    split: self.splitPage && UIDevice.current.orientation.isPortrait,
                    priorityLeft: self.splitPagePriorityLeft,
                    action: action)
            self.internalModel.currentIndex = page.rounded()
            if index == (self.pages?.count ?? 0) - 1 {
                self.internalModel.clearNewFlag(id: item!.id)
            }
        }
    }

    func nextInternalPage() {
        if self.splitPagePriorityLeft {
            internalModel.setCurrentPageToRight()
        } else {
            internalModel.setCurrentPageToLeft()
        }
        self.internalModel.isCurrentSplittingPage = .last
    }

    func previousInternalPage() {
        if self.splitPagePriorityLeft {
            internalModel.setCurrentPageToLeft()
        } else {
            internalModel.setCurrentPageToRight()
        }
        self.internalModel.isCurrentSplittingPage = .first
    }

    func jumpToInternalPage(action: PageFlipAction) {
        switch action {
        case .next, .jump:
            if self.splitPagePriorityLeft {
                internalModel.setCurrentPageToLeft()
            } else {
                internalModel.setCurrentPageToRight()
            }
            self.internalModel.isCurrentSplittingPage = .first
        case .previous:
            if self.splitPagePriorityLeft {
                internalModel.setCurrentPageToRight()
            } else {
                internalModel.setCurrentPageToLeft()
            }
            self.internalModel.isCurrentSplittingPage = .last
        }
    }

    func handleError() {
        if let error = self.errorCode {
            switch error {
            case .archiveExtractError:
                let banner = NotificationBanner(title: NSLocalizedString("error", comment: "error"),
                        subtitle: NSLocalizedString("error.extract", comment: "list error"),
                        style: .danger)
                banner.show()
                reset()
            case .archiveFetchPageError:
                let banner = NotificationBanner(title: NSLocalizedString("error", comment: "error"),
                        subtitle: NSLocalizedString("error.load.page", comment: "list error"),
                        style: .danger)
                banner.show()
                reset()
            default:
                break
            }
        }
    }
}

//struct ArchivePage_Previews: PreviewProvider {
//    static var previews: some View {
//        let config = ["url": "http://localhost", "apiKey": "apiKey"]
//        UserDefaults.standard.set(config, forKey: "LANraragi")
//        return ArchivePage(item: ArchiveItem(id: "id", name: "name", tags: "tags", thumbnail: Image("placeholder")))
//    }
//}
