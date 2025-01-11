import SwiftUI
import AVFoundation
import Photos

struct CameraView: View {
    @StateObject private var viewModel: CameraViewModel
    @Environment(\.scenePhase) private var scenePhase
    
    init(viewModel: CameraViewModel = CameraViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
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
                        .padding(.bottom, 20)
                    
                    // Bottom Controls
                    CameraBottomControls(
                        isRecording: $viewModel.isRecording,
                        currentTake: $viewModel.currentTake,
                        startRecording: {
                            viewModel.startRecording()
                        },
                        stopRecording: viewModel.stopRecording,
                        switchCamera: viewModel.cameraManager.switchCamera
                    )

                    // Add SpeechRecognizerStatusView
                    HStack {
                        Spacer()
                        SpeechRecognizerStatusView(speechRecognizer: viewModel.speechRecognizer, context: .camera)
                            .padding()
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                HStack {
                    if !viewModel.isRecording {
                        NavigationLink(destination: SettingsView()) {
                            Image(systemName: "gear")
                                .foregroundColor(.white)
                        }
                    }

                    Button(action: {
                        viewModel.isGridEnabled.toggle()
                    }) {
                        Image(systemName: viewModel.isGridEnabled ? "square.grid.2x2.fill" : "square.grid.2x2")
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
                            .font(.system(size: 18, weight: .bold))
                            .padding(8)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(5)
                        
                        Text("Take \(viewModel.currentTake)")
                            .foregroundColor(.white)
                    } else {
                        Text("Credits: \(viewModel.creditCount)")
                            .foregroundColor(.white)
                        
                        Image(systemName: "plus.circle")
                            .foregroundColor(.white)
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
            if newPhase == .active && !viewModel.showingSaveDialog {
                viewModel.speechRecognizer.startListening(context: .camera)
                print("App became active, started listening") // Debug print
            } else if newPhase == .background || newPhase == .inactive {
                viewModel.speechRecognizer.stopListening()
                print("App moved to background/inactive, stopped listening") // Debug print
            }
        }
    }
}
