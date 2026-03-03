//
//  CameraPreview.swift
//  MetalShaderExamples
//
//  Created by Eymen Varilci on 3.03.2026.
//

import SwiftUI
import AVFoundation

// Custom UIView to host the AV Preview Layer so it resizes perfectly
class CameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}
