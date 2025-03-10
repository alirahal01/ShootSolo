import SwiftUI

struct SettingsView: View {
    @StateObject private var manager = SettingsManager.shared
    @State private var showingDeleteConfirmation = false
    @EnvironmentObject private var authState: AuthState
    @State private var fileNameError: String?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
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
                        do {
                            // First update UI state
                            await MainActor.run {
                                withAnimation {
                                    authState.isLoggedIn = false
                                    authState.isGuestUser = false  // Make sure to reset guest state
                                }
                            }
                            
                            // Then perform sign out
                            try await manager.signOut()
                        } catch {
                            print("Sign out error: \(error)")
                            // Revert UI state if sign out failed
                            await MainActor.run {
                                withAnimation {
                                    authState.isLoggedIn = true
                                }
                            }
                        }
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
                    do {
                        // First delete the account (which includes deleting credits)
                        try await manager.deleteAccount()
                        
                        // Then update the UI state
                        await MainActor.run {
                            withAnimation {
                                // Update auth state to trigger navigation
                                authState.isLoggedIn = false
                                authState.isGuestUser = false
                                
                                // Reset any other necessary state
                                manager.settings = SettingsModel.defaultSettings
                            }
                        }
                        
                        // Post notification for other parts of the app that need to know
                        NotificationCenter.default.post(
                            name: .userDidBecomeUnauthenticated,
                            object: nil
                        )
                    } catch {
                        print("Failed to delete account: \(error)")
                        await MainActor.run {
                            errorMessage = error.localizedDescription
                            showErrorAlert = true
                        }
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
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
