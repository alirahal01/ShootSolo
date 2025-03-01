import SwiftUI
import AVFoundation
import Photos

struct CameraView: View {
    @StateObject private var viewModel: CameraViewModel
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var authState: AuthState
    
    init() {
        _viewModel = StateObject(wrappedValue: CameraViewModel())
    }
    
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreviewView(session: viewModel.cameraManager.session)
                .edgesIgnoringSafeArea(.all)
            
            // Grid Overlay
            if viewModel.isGridEnabled {
                GridOverlay()
                    .edgesIgnoringSafeArea(.all)
            }
            
            // Save Dialog
            if viewModel.showingSaveDialog {
                SaveTakeDialog(
                    takeNumber: viewModel.currentTake,
                    onSave: viewModel.saveTake,
                    onDiscard: viewModel.discardTake,
                    speechRecognizer: viewModel.speechRecognizer
                )
                .onAppear {
                    viewModel.speechRecognizer.stopListening()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        viewModel.speechRecognizer.startListening(context: .saveDialog)
                    }
                }
                .onDisappear {
                    viewModel.speechRecognizer.stopListening()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        viewModel.speechRecognizer.startListening(context: .camera)
                    }
                }
            } else {
                // UI Controls
                VStack {
                    Spacer()
                    
                    // Zoom Control
                    ZoomControlView(zoomFactor: $viewModel.zoomFactor)
                        .onChange(of: viewModel.zoomFactor) { newValue in
                            viewModel.setZoomFactor(newValue)
                        }
                        .padding(.bottom, 10)
                    
                    MessageHUDView(
                        speechRecognizer: viewModel.speechRecognizer,
                        context: .camera
                    )
                    .padding(.bottom, 10)
                    
                    // Bottom Controls
                    CameraBottomControls(
                        isRecording: $viewModel.isRecording,
                        currentTake: $viewModel.currentTake,
                        startRecording: {
                            Task {
                                await viewModel.startRecording()
                            }
                        },
                        stopRecording: viewModel.stopRecording,
                        switchCamera: viewModel.cameraManager.switchCamera
                    )
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 15) {
                    if !viewModel.isRecording {
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gear")
                                .foregroundColor(.white)
                        }
                    }
                    
                    Button(action: {
                        viewModel.isGridEnabled.toggle()
                    }) {
                        Image(systemName: viewModel.isGridEnabled ? "grid.circle.fill" : "grid.circle")
                            .foregroundColor(.white)
                    }
                    
                    Button(action: {
                        viewModel.toggleFlash()
                    }) {
                        Image(systemName: viewModel.isFlashOn ? "bolt.fill" : "bolt.slash.fill")
                            .foregroundColor(.white)
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if viewModel.isRecording {
                        Text(viewModel.timerText)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .fixedSize()
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.red)
                            )
                            .foregroundColor(.white)
                        
                        Text("Take \(viewModel.currentTake)")
                            .foregroundColor(.white)
                    } else {
                        Button {
                            viewModel.showingCreditsView = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("Credits: \(viewModel.creditCount)")
                                    .foregroundColor(.white)
                                Image(systemName: "plus.square.fill")
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if !viewModel.showingSaveDialog {
                viewModel.speechRecognizer.startListening(context: .camera)
            }
            print("CameraView appeared, started listening") // Debug print
        }
        .onDisappear {
            viewModel.speechRecognizer.stopListening()
            print("CameraView disappeared, stopped listening") // Debug print
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                if !viewModel.showingSaveDialog {
                    viewModel.speechRecognizer.startListening(context: .camera)
                }
                // Only restart timer if was recording
                if viewModel.isRecording {
                    viewModel.startTimer()
                }
            } else if newPhase == .background || newPhase == .inactive {
                viewModel.speechRecognizer.stopListening()
                viewModel.stopTimer()
            }
        }
        .sheet(isPresented: $viewModel.showingCreditsView) {
            CreditsView()
        }
        .alert("Session Expired", isPresented: $authState.showAuthAlert) {
            Button("Sign In", role: .destructive) {
                authState.isLoggedIn = false
            }
        } message: {
            Text("Your session has expired. Please sign in again to continue.")
        }
    }
}
