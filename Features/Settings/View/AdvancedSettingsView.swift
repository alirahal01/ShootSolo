//import SwiftUI
//
//struct AdvancedSettingsView: View {
//    @StateObject private var settingsManager = SettingsManager()
//    @State private var isGridEnabled = false
//    
//    var body: some View {
//        List {
//            // Voice Settings
//            Section {
//                HStack {
//                    Text("App voice:")
//                    Spacer()
//                    Text("Suzan")
//                }
//            }
//            
//            // Camera Settings
//            Section {
//                HStack {
//                    Text("Framerate")
//                    Spacer()
//                    Text("30fps")
//                }
//                
//                HStack {
//                    Text("Resolution")
//                    Spacer()
//                    Text("4k")
//                }
//                
//                Toggle("Grid", isOn: $isGridEnabled)
//            }
//            
//            // Account Actions
//            Section {
//                Button("Log Out") {
//                    settingsManager.logout()
//                }
//                
//                Button("Delete Account") {
//                    settingsManager.deleteAccount()
//                }
//                .foregroundColor(.red)
//            }
//        }
//        .navigationTitle("Settings")
//    }
//}
//
//#Preview {
//    NavigationView {
//        AdvancedSettingsView()
//    }
//} 
