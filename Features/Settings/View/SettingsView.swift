import SwiftUI

struct SettingsView: View {
    @StateObject private var manager = SettingsManager.shared
    @State private var showingDeleteConfirmation = false
    @EnvironmentObject private var authState: AuthState
    
    var body: some View {
        Form {
            voiceCommandsSection
            videoSettingsSection
            generalSettingsSection
            accountSection
        }
        .navigationTitle("Settings")
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
    
    private var videoSettingsSection: some View {
        Section(header: Text("Video Settings")) {
            Picker("Resolution", selection: resolution) {
                ForEach(VideoSettings.Resolution.allCases, id: \.self) { resolution in
                    Text(resolution.rawValue).tag(resolution)
                }
            }
            
            Picker("Framerate", selection: framerate) {
                ForEach(VideoSettings.Framerate.allCases, id: \.self) { framerate in
                    Text(framerate.rawValue).tag(framerate)
                }
            }
        }
    }
    
    private var generalSettingsSection: some View {
        Section(header: Text("General")) {
            TextField("File Name Format", text: fileNameFormat)
            TextField("Save Location", text: saveLocation)
        }
    }
    
    private var accountSection: some View {
        Section {
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
    
    private var resolution: Binding<VideoSettings.Resolution> {
        Binding(
            get: { manager.settings.videoSettings.resolution },
            set: { newValue in
                var settings = manager.settings
                settings.videoSettings.resolution = newValue
                manager.updateSettings(settings)
            }
        )
    }
    
    private var framerate: Binding<VideoSettings.Framerate> {
        Binding(
            get: { manager.settings.videoSettings.framerate },
            set: { newValue in
                var settings = manager.settings
                settings.videoSettings.framerate = newValue
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
}
