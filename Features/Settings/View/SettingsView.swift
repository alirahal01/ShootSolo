import SwiftUI

struct SettingsView: View {
    @StateObject private var manager = SettingsManager.shared
    @State private var showingDeleteConfirmation = false
    @EnvironmentObject private var authState: AuthState
    @State private var fileNameError: String?
    
    var body: some View {
        Form {
            voiceCommandsSection
            accountSection
        }
        .navigationTitle("Settings")
        .alert("Session Expired", isPresented: $authState.showAuthAlert) {
            Button("Sign In") {
                authState.isLoggedIn = false
            }
        } message: {
            Text("Your session has expired. Please sign in again to continue.")
        }
    }
    
    private var voiceCommandsSection: some View {
        Section(header: Text("Voice Commands")) {
            Picker("Start Recording", selection: startKeyword) {
                ForEach(RecordingKeywords.allCases, id: \.self) { keyword in
                    Text(keyword.rawValue).tag(keyword)
                }
            }
            
            Picker("Stop Recording", selection: stopKeyword) {
                ForEach(StopKeywords.allCases, id: \.self) { keyword in
                    Text(keyword.rawValue).tag(keyword)
                }
            }
        }
    }
    
    private var accountSection: some View {
        Section(header: Text("Account")) {
            if authState.isGuestUser {
                NavigationLink(destination: LoginView(
                    onLoginStart: {},
                    onLoginSuccess: { authState.isLoggedIn = true },
                    showGuestOption: false
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sign up / Login")
                            .foregroundColor(.red)
                        Text("to save and sync your credits across all your devices.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            } else {
                if let email = manager.authService.currentUser?.email {
                    HStack {
                        Text("User")
                        Spacer()
                        Text(email)
                            .foregroundColor(.gray)
                    }
                }
                
                Button("Sign Out", role: .destructive) {
                    Task {
                        try? await manager.signOut()
                        authState.isLoggedIn = false
                    }
                }
                
                Button("Delete Account", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    try? await manager.deleteAccount()
                }
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
    }
    
    // MARK: - Bindings
    private var startKeyword: Binding<RecordingKeywords> {
        Binding(
            get: { manager.settings.selectedStartKeyword },
            set: { newValue in
                var settings = manager.settings
                settings.selectedStartKeyword = newValue
                manager.updateSettings(settings)
            }
        )
    }
    
    private var stopKeyword: Binding<StopKeywords> {
        Binding(
            get: { manager.settings.selectedStopKeyword },
            set: { newValue in
                var settings = manager.settings
                settings.selectedStopKeyword = newValue
                manager.updateSettings(settings)
            }
        )
    }
    
    private var fileNameFormat: Binding<String> {
        createBinding(for: \.fileNameFormat)
    }
    
    private var saveLocation: Binding<String> {
        createBinding(for: \.saveLocation)
    }
    
    private func createBinding<T>(for keyPath: WritableKeyPath<SettingsModel, T>) -> Binding<T> {
        Binding(
            get: { manager.settings[keyPath: keyPath] },
            set: { newValue in
                var settings = manager.settings
                settings[keyPath: keyPath] = newValue
                manager.updateSettings(settings)
            }
        )
    }
    
    private func validateFileName(_ name: String) {
        // Clear previous error
        fileNameError = nil
        
        // Check if empty
        if name.isEmpty {
            fileNameError = "File name cannot be empty"
            return
        }
        
        // Check for invalid characters
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
        if name.rangeOfCharacter(from: invalidCharacters) != nil {
            fileNameError = "File name contains invalid characters"
            return
        }
    }
}
