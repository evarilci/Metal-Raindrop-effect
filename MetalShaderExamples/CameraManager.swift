//
//  CameraManager.swift
//  MetalShaderExamples
//
//  Created by Eymen Varilci on 3.03.2026.
//

import SwiftUI
import AVFoundation
import CoreImage
import Combine  // <--- Add this missing line!


class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var currentFrame: CGImage?
    private let captureSession = AVCaptureSession()
    private let context = CIContext()
    private var currentInput: AVCaptureDeviceInput?
    
    // Configures and starts the camera based on the requested position
    func start(position: AVCaptureDevice.Position) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.configureSession(for: position)
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }
    
    // Safely stops the camera to save battery when viewing the static image
    func stop() {
        DispatchQueue.global(qos: .userInitiated).async {
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }
    
    // Swaps cameras on the fly without stopping the whole session
    func switchCamera(to position: AVCaptureDevice.Position) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.configureSession(for: position)
        }
    }
    
    private func configureSession(for position: AVCaptureDevice.Position) {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        
        // Remove the old camera input if it exists
        if let currentInput = currentInput {
            captureSession.removeInput(currentInput)
        }
        
        // Find the requested camera
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device) else {
            captureSession.commitConfiguration()
            return
        }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
            self.currentInput = input
        }
        
        // Setup video output if we haven't already
        if captureSession.outputs.isEmpty {
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            
            if captureSession.canAddOutput(output) {
                captureSession.addOutput(output)
            }
        }
        
        // Update orientation and mirroring (Only mirror the front camera!)
        if let output = captureSession.outputs.first as? AVCaptureVideoDataOutput,
           let connection = output.connection(with: .video) {
            if #available(iOS 17.0, *) {
                connection.videoRotationAngle = 90
            } else {
                connection.videoOrientation = .portrait
            }
            connection.isVideoMirrored = (position == .front)
        }
        
        captureSession.commitConfiguration()
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        DispatchQueue.main.async {
            self.currentFrame = cgImage
        }
    }
}

struct CameraView: View {
    @StateObject private var camera = CameraManager()
    var position: AVCaptureDevice.Position // Receives the selected camera
    
    var body: some View {
        GeometryReader { proxy in
            if let cgImage = camera.currentFrame {
                Image(decorative: cgImage, scale: 1.0, orientation: .up)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            } else {
                Color(white: 0.1)
            }
        }
        .onAppear {
            camera.start(position: position)
        }
        // If the user taps a different camera in the segmented control, swap it immediately
        .onChange(of: position, { oldValue, newValue in
            camera.switchCamera(to: newValue)
        })
        
        .onDisappear {
            camera.stop()
        }
    }
}
