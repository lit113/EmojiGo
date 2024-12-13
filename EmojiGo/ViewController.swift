//
//  ViewController.swift
//  EmojiGo
//
//  Created by Tong Li on 12/10/24.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    private var gameModel = GameModel()
    private var gameView: GameView!
    private var countdownTimer: Timer?

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

        // 初始化视图
        gameView = GameView(frame: view.bounds)
        gameView.setupCountdown(in: view)

        // 初始化地板和木板
        setupInitialFloors()
        addDynamicWoodPlank()

        // 开始倒计时
        startCountdown()
    }

    private func startCountdown() {
        gameModel.countdownValue = 20
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
        gameView.showGameOverlay(in: view, score: 1234) { [weak self] in
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

        let emojiTextures = ["happy", "neutral", "angry"]
        if let randomEmoji = emojiTextures.randomElement(), let emojiImage = UIImage(named: randomEmoji) {
            let emojiPlane = SCNPlane(width: 0.3, height: 0.2)
            emojiPlane.firstMaterial?.diffuse.contents = emojiImage

            let emojiNode = SCNNode(geometry: emojiPlane)
            emojiNode.position = SCNVector3(0, 0, 0.03)
            emojiNode.eulerAngles = SCNVector3(0, 0, 0)
            plankNode.addChildNode(emojiNode)
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
