//  Created 23/8/20.

import Foundation
import SwiftUI

struct ArchiveItem: Identifiable, Equatable {
    let id: String
    let name: String
    let tags: String
}

struct CategoryItem: Identifiable, Equatable {
    let id: String
    let name: String
    let archives: [String]
    let search: String
    let pinned: String
}
