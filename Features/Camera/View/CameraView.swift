import SwiftUI
import AVFoundation
import Photos

struct CameraView: View {
    @StateObject private var viewModel: CameraViewModel

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
                    onDiscard: viewModel.discardTake
                )
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
            viewModel.speechRecognizer.startListening()
            print("CameraView appeared, started listening") // Debug print
        }
        .onDisappear {
            viewModel.speechRecognizer.stopListening()
            print("CameraView disappeared, stopped listening") // Debug print
        }
    }
}
