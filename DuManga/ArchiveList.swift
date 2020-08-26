//  Created 23/8/20.

import SwiftUI

struct ArchiveList: View {
    @State var archiveItems = [String: ArchiveItem]()
    @State var isLoading = false
    @Binding var navBarTitle: String
    
    private let config: [String: String]
    private let client: LANRaragiClient
    
    init(navBarTitle: Binding<String>) {
        self.config = UserDefaults.standard.dictionary(forKey: "LANraragi") as? [String: String] ?? [String: String]()
        self.client = LANRaragiClient(url: config["url"]!, apiKey: config["apiKey"]!)
        self._navBarTitle = navBarTitle
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                List(Array(self.archiveItems.values)) { (item: ArchiveItem) in
                    NavigationLink(destination: ArchivePage(id: item.id)) {
                        ArchiveRow(archiveItem: item)
                            .onAppear(perform: { self.loadArchiveThumbnail(id: item.id)
                            })
                    }
                }
                .onAppear(perform: { self.navBarTitle = "library" })
                .onAppear(perform: self.loadData)
                
                VStack {
                    Text("loading")
                    ActivityIndicator(isAnimating: self.$isLoading, style: .large)
                }
                .frame(width: geometry.size.width / 3,
                       height: geometry.size.height / 5)
                    .background(Color.secondary.colorInvert())
                    .foregroundColor(Color.primary)
                    .cornerRadius(20)
                    .opacity(self.isLoading ? 1 : 0)
            }
        }
    }
    
    func loadData() {
        if (self.archiveItems.count > 0) {
            return
        }
        self.isLoading = true
        client.getArchiveIndex {(items: [ArchiveIndexResponse]?) in
            items?.forEach { item in
                if self.archiveItems[item.arcid] == nil {
                    self.archiveItems[item.arcid] = (ArchiveItem(id: item.arcid, name: item.title, thumbnail: Image("placeholder")))
                }
            }
            self.isLoading = false
        }
    }
    
    func loadArchiveThumbnail(id: String) {
        if self.archiveItems[id]?.thumbnail == Image("placeholder") {
            client.getArchiveThumbnail(id: id) { (image: UIImage?) in
                if let img = image {
                    self.archiveItems[id]?.thumbnail = Image(uiImage: img)
                }
            }
        }
    }
    
}

struct ArchiveList_Previews: PreviewProvider {
    static var previews: some View {
        let config = ["url": "http://localhost", "apiKey": "apiKey"]
        UserDefaults.standard.set(config, forKey: "LANraragi")
        return ArchiveList(navBarTitle: Binding.constant("library"))
    }
}
