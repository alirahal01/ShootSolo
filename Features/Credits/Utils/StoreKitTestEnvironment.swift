import SwiftUI

private struct StoreKitTestKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isStoreKitTest: Bool {
        get { self[StoreKitTestKey.self] }
        set { self[StoreKitTestKey.self] = newValue }
    }
} 