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

// 1. Manages the camera session and converts frames to CGImage
class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var currentFrame: CGImage?
    private let captureSession = AVCaptureSession()
    private let context = CIContext()
    
    override init() {
        super.init()
        setupCamera()
    }
    
    private func setupCamera() {
        captureSession.sessionPreset = .high
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        
        let output = AVCaptureVideoDataOutput()
        // Ensure CoreImage can easily read the pixel format
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }
        
        // Ensure the video is portrait and acts like a mirror
        if let connection = output.connection(with: .video) {
            if #available(iOS 17.0, *) {
                connection.videoRotationAngle = 90
            } else {
                connection.videoOrientation = .portrait
            }
            connection.isVideoMirrored = true
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }
    
    // 2. This delegate method runs every time the camera captures a new frame
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        
        // Push the new image frame to the main thread so SwiftUI can display it
        DispatchQueue.main.async {
            self.currentFrame = cgImage
        }
    }
}

// 3. A pure SwiftUI View that displays our captured frames
struct CameraView: View {
    @StateObject private var camera = CameraManager()
    
    var body: some View {
        GeometryReader { proxy in
            if let cgImage = camera.currentFrame {
                // A standard SwiftUI Image can be flattened and distorted by Metal easily!
                Image(decorative: cgImage, scale: 1.0, orientation: .up)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            } else {
                // Background color while the camera is warming up
                Color(white: 0.1)
            }
        }
    }
}
