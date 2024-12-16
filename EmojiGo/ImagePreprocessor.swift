//
//  ImagePreprocessor.swift
//  EmojiGo
//
//  Created by Tong Li on 12/15/24.
//

import UIKit
import SceneKit
import ARKit
import Vision
import CoreImage
import CoreVideo

class ImagePreprocessor {
    private let ciContext = CIContext()
    
    /// 对输入的 PixelBuffer 进行灰度处理
    func process(pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // 创建灰度滤镜
        let filter = CIFilter(name: "CIPhotoEffectMono") // Mono 滤镜将彩色图像转换为黑白灰
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        
        guard let outputImage = filter?.outputImage else {
            print("Failed to process image with CIPhotoEffectMono.")
            return nil
        }
        
        // 渲染输出为新的 PixelBuffer
        var newPixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         CVPixelBufferGetWidth(pixelBuffer),
                                         CVPixelBufferGetHeight(pixelBuffer),
                                         kCVPixelFormatType_32BGRA,
                                         nil,
                                         &newPixelBuffer)
        guard status == kCVReturnSuccess, let outputBuffer = newPixelBuffer else {
            print("Failed to create output PixelBuffer.")
            return nil
        }
        
        ciContext.render(outputImage, to: outputBuffer)
        return outputBuffer
    }
}
