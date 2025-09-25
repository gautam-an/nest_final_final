import SwiftUI

class AppState: ObservableObject {
    // Stored app state variables for authentication
    @Published var username: String = ""
    @Published var password: String = ""
}
