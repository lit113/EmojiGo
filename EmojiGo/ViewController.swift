//
//  ViewController.swift
//  EmojiGo
//
//  Created by Tong Li on 12/10/24.
//

import UIKit
import SceneKit
import ARKit
import Vision
import CoreVideo
import AVFoundation

// MARK: - ViewController
class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    private var gameModel = GameModel()
    private var gameView: GameView!
    private var countdownTimer: Timer?

    private var emotionModel: VNCoreMLModel!
    private var emotionRequest: VNCoreMLRequest!
    private let imagePreprocessor = ImagePreprocessor()
    private var audioPlayer: AVAudioPlayer?


    override func viewDidLoad() {
        super.viewDidLoad()

        // 初始化 AR 会话
        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.scene = SCNScene()

        if ARFaceTrackingConfiguration.isSupported {
            let configuration = ARFaceTrackingConfiguration()
            sceneView.session.run(configuration)
        } else {
            print("前置摄像头不支持人脸追踪功能。")
        }

        // 初始化模型和视图
        setupEmotionModel()
        gameView = GameView(frame: view.bounds)
        gameView.setupUI(in: view)

        // 初始化地板和木板
        setupInitialFloors()
        addDynamicWoodPlank()

        // 开始倒计时
        startCountdown()

        // 开始表情检测
        startFaceDetection()
    }

    private func setupEmotionModel() {
        do {
            // 加载 CoreML 模型
            emotionModel = try VNCoreMLModel(for: EmojiChallengeClassfier().model)
            
            // 创建 VNCoreMLRequest 使用新的构造器
            emotionRequest = VNCoreMLRequest(model: emotionModel, completionHandler: { [weak self] request, error in
                if let error = error {
                    print("Error during Vision request: \(error.localizedDescription)")
                    return
                }
                guard let results = request.results as? [VNClassificationObservation], let topResult = results.first else {
                    print("No results from model")
                    return
                }

                DispatchQueue.main.async {
                    self?.handleDetectedEmotion(topResult.identifier)
                }
            })
        } catch {
            fatalError("Failed to load CoreML model: \(error)")
        }
    }

    private func analyzeCurrentFrame() {
        guard let currentFrame = sceneView.session.currentFrame else { return }
        
        if let preprocessedBuffer = imagePreprocessor.process(pixelBuffer: currentFrame.capturedImage) {
            let handler = VNImageRequestHandler(cvPixelBuffer: preprocessedBuffer, options: [:])
            do {
                try handler.perform([emotionRequest])
            } catch {
                print("Failed to perform Vision request: \(error)")
            }
        } else {
            print("Warning: Failed to preprocess frame for emotion detection.")
        }

    }


    private func startFaceDetection() {
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.analyzeCurrentFrame()
        }
    }
    
    // 通用音效播放方法
    private func playSound(resourceName: String) {
        guard let soundURL = Bundle.main.url(forResource: resourceName, withExtension: "wav") else {
            print("Sound file \(resourceName) not found.")
            return
        }
        
        // 设置 AudioSession
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session: \(error.localizedDescription)")
        }
        
        // 播放音效
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.play()
        } catch {
            print("Failed to play sound: \(error.localizedDescription)")
        }
    }
    
    func playSuccessSound() {
        playSound(resourceName: "success")
    }

    // 播放失败音效
    func playFailureSound() {
        playSound(resourceName: "failure")
    }

    private func handleDetectedEmotion(_ detectedEmotion: String) {
        gameView.updateDetectedEmotionLabel(with: detectedEmotion)

        // 检查是否与当前木板的表情匹配
        if let currentPlankEmoji = gameModel.currentPlankEmoji,
           currentPlankEmoji == detectedEmotion,
           !gameModel.hasScoredOnCurrentPlank {

            gameModel.matchingTime += 0.5 // 增加匹配时间

            // 如果累计匹配时间超过1秒，则计分
            if gameModel.matchingTime >= 1.0 {
                gameModel.score += 100
                gameModel.matchingTime = 0 // 重置匹配时间
                gameModel.hasScoredOnCurrentPlank = true // 标记当前木板已得分
                playSuccessSound()
            }
        } else {
            // 如果不匹配，重置匹配时间
            gameModel.matchingTime = 0
        }
    }


    private func startCountdown() {
        gameModel.countdownValue = 30
        gameView.updateCountdownLabel(with: gameModel.countdownValue)
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateCountdown), userInfo: nil, repeats: true)
    }

    @objc private func updateCountdown() {
        gameModel.countdownValue -= 1
        gameView.updateCountdownLabel(with: gameModel.countdownValue)
        if gameModel.countdownValue <= 0 {
            endGame()
        }
    }

    private func endGame() {
        countdownTimer?.invalidate()
        gameView.showGameOverlay(in: view, score: gameModel.score) { [weak self] in
            self?.restartGame()
        }
    }

    @objc private func restartGame() {
        gameView.removeGameOverlay()
        gameModel.reset()
        startCountdown()
    }

    // MARK: 创建地板
    func createFloor(at position: SCNVector3) -> SCNNode {
        let floor = SCNPlane(width: 1.0, height: 1.0)
        floor.firstMaterial?.diffuse.contents = UIImage(named: "floorTexture")

        let floorNode = SCNNode(geometry: floor)
        floorNode.eulerAngles.x = -.pi / 2
        floorNode.position = position
        floorNode.name = "floor"
        return floorNode
    }

    func setupInitialFloors() {
        for i in 0..<5 {
            let floorNode = createFloor(at: SCNVector3(0, -0.5, Float(i) * -1.0))
            sceneView.scene.rootNode.addChildNode(floorNode)
        }
    }

    // MARK: 动态添加木板
    func addDynamicWoodPlank() {
        guard !gameModel.isPlankOnScreen else { return }

        let plank = SCNBox(width: 0.5, height: 0.3, length: 0.02, chamferRadius: 0.0)
        plank.firstMaterial?.diffuse.contents = UIImage(named: "woodTexture")

        let plankNode = SCNNode(geometry: plank)
        
        var farthestZ: Float = -1.0
        sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
            if node.name == "floor" && node.position.z < farthestZ {
                farthestZ = node.position.z
            }
        }

        plankNode.position = SCNVector3(0, -0.35, farthestZ)
        plankNode.name = "plank"

        let emojiTextures = ["anger", "surprise", "happy"]
        if let randomEmoji = emojiTextures.randomElement(), let emojiImage = UIImage(named: randomEmoji) {
            let emojiPlane = SCNPlane(width: 0.3, height: 0.2)
            emojiPlane.firstMaterial?.diffuse.contents = emojiImage

            let emojiNode = SCNNode(geometry: emojiPlane)
            emojiNode.position = SCNVector3(0, 0, 0.03)
            emojiNode.eulerAngles = SCNVector3(0, 0, 0)
            plankNode.addChildNode(emojiNode)

            // 设置当前木板表情
            gameModel.currentPlankEmoji = randomEmoji
            gameModel.hasScoredOnCurrentPlank = false // 重置得分标志
        }

        sceneView.scene.rootNode.addChildNode(plankNode)
        gameModel.isPlankOnScreen = true
    }


    func slideFloors() {
        sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
            if node.name == "floor" || node.name == "plank" {
                node.position.z += 0.036
                if node.position.z > 1.0 {
                    node.removeFromParentNode()
                    if node.name == "plank" {
                        gameModel.isPlankOnScreen = false
                        DispatchQueue.main.async {
                            self.addDynamicWoodPlank()
                        }
                    }
                }
            }
        }
    }

    func loadNewFloorsIfNeeded() {
        var farthestZ: Float = 0.0
        sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
            if node.name == "floor" && node.position.z < farthestZ {
                farthestZ = node.position.z
            }
        }

        if farthestZ > -4.0 {
            let newFloor = createFloor(at: SCNVector3(0, -0.5, farthestZ - 1.0))
            sceneView.scene.rootNode.addChildNode(newFloor)
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        slideFloors()
        loadNewFloorsIfNeeded()
    }
}
