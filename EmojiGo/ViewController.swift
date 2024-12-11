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
    private var isPlankOnScreen = false // 用于跟踪当前是否有木板
    private var countdownLabel: UILabel!
    private var countdownTimer: Timer?
    private var countdownValue: Int = 20
    private var gameOverlay: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()

        // 初始化 AR 会话
        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.scene = SCNScene()

        // 启动 AR 会话并使用前置摄像头
        if ARFaceTrackingConfiguration.isSupported {
            let configuration = ARFaceTrackingConfiguration()
            sceneView.session.run(configuration)
        } else {
            print("前置摄像头不支持人脸追踪功能。")
        }

        // 初始化地板
        setupInitialFloors()

        // 首次添加木板
        addDynamicWoodPlank()

        // 添加倒计时
        setupCountdown()
    }

    private func setupCountdown() {
        countdownLabel = UILabel(frame: CGRect(x: 20, y: 50, width: 100, height: 50))
        countdownLabel.text = "20"
        countdownLabel.font = UIFont.boldSystemFont(ofSize: 24)
        countdownLabel.textColor = .white
        countdownLabel.backgroundColor = .black
        countdownLabel.textAlignment = .center
        countdownLabel.layer.cornerRadius = 5
        countdownLabel.layer.masksToBounds = true
        view.addSubview(countdownLabel)

        startCountdown()
    }

    private func startCountdown() {
        countdownValue = 20
        countdownLabel.text = "20"
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateCountdown), userInfo: nil, repeats: true)
    }

    @objc private func updateCountdown() {
        countdownValue -= 1
        countdownLabel.text = "\(countdownValue)"
        if countdownValue <= 0 {
            endGame()
        }
    }

    private func endGame() {
        countdownTimer?.invalidate()

        // 停止场景交互
        sceneView.scene.rootNode.enumerateChildNodes { node, _ in
            node.removeAllActions()
        }

        // 显示结束界面
        showGameOverlay()
    }

    private func showGameOverlay() {
        gameOverlay = UIView(frame: view.bounds)
        gameOverlay?.backgroundColor = UIColor.black.withAlphaComponent(0.8)

        // 显示分数
        let scoreLabel = UILabel(frame: CGRect(x: 50, y: 300, width: view.bounds.width - 100, height: 50))
        scoreLabel.text = "Score: 1234" // 假分数
        scoreLabel.font = UIFont.boldSystemFont(ofSize: 30)
        scoreLabel.textColor = .white
        scoreLabel.textAlignment = .center
        scoreLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        gameOverlay?.addSubview(scoreLabel)

        
        // 显示重新开始图片
        let playAgainImageView = UIImageView(frame: CGRect(x: (view.bounds.width - 200) / 2, y: 550, width: 200, height: 50))
        playAgainImageView.image = UIImage(named: "play_again")
        playAgainImageView.contentMode = .scaleAspectFit
        playAgainImageView.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(restartGame))
        playAgainImageView.addGestureRecognizer(tapGesture)
        gameOverlay?.addSubview(playAgainImageView)

        view.addSubview(gameOverlay!)
    }

    @objc private func restartGame() {
        gameOverlay?.removeFromSuperview()
        gameOverlay = nil

        // 重置场景
        sceneView.scene.rootNode.enumerateChildNodes { node, _ in
            node.removeFromParentNode()
        }
        setupInitialFloors()

        // 重置木板状态并添加木板
        isPlankOnScreen = false
        DispatchQueue.main.async {
            self.addDynamicWoodPlank() // 确保立即生成新的木板
        }

        // 重新开始倒计时
        startCountdown()
    }


    // MARK: 创建地板
    func createFloor(at position: SCNVector3) -> SCNNode {
        let floor = SCNPlane(width: 1.0, height: 1.0) // 地板大小
        floor.firstMaterial?.diffuse.contents = UIImage(named: "floorTexture") // 地板纹理

        let floorNode = SCNNode(geometry: floor)
        floorNode.eulerAngles.x = -.pi / 2 // 将地板旋转为水平
        floorNode.position = position // 设置地板位置
        floorNode.name = "floor"
        return floorNode
    }

    func setupInitialFloors() {
        // 初始化多个地板，排列在前方
        for i in 0..<5 {
            let floorNode = createFloor(at: SCNVector3(0, -0.5, Float(i) * -1.0))
            sceneView.scene.rootNode.addChildNode(floorNode)
        }
    }

    // MARK: 动态添加木板
    func addDynamicWoodPlank() {
        guard !isPlankOnScreen else { return } // 确保屏幕上只有一个木板

        let plank = SCNBox(width: 0.5, height: 0.3, length: 0.02, chamferRadius: 0.0)
        plank.firstMaterial?.diffuse.contents = UIImage(named: "woodTexture") // 木板纹理

        let plankNode = SCNNode(geometry: plank)
        
        // 找到最远的地板位置
        var farthestZ: Float = -1.0
        sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
            if node.name == "floor" && node.position.z < farthestZ {
                farthestZ = node.position.z
            }
        }

        plankNode.position = SCNVector3(0, -0.35, farthestZ) // 将木板插在最远地板上
        plankNode.name = "plank"

        // 随机选择一个 emoji 作为纹理
        let emojiTextures = ["happy", "neutral", "angry"] // 在项目中添加对应的图片
        if let randomEmoji = emojiTextures.randomElement(), let emojiImage = UIImage(named: randomEmoji) {
            let emojiPlane = SCNPlane(width: 0.3, height: 0.2)
            emojiPlane.firstMaterial?.diffuse.contents = emojiImage

            let emojiNode = SCNNode(geometry: emojiPlane)
            emojiNode.position = SCNVector3(0, 0, 0.03) // 贴在木板表面
            emojiNode.eulerAngles = SCNVector3(0, 0, 0) // 确保方向正确
            plankNode.addChildNode(emojiNode)
        }

        // 添加到场景
        sceneView.scene.rootNode.addChildNode(plankNode)
        isPlankOnScreen = true
    }

    // MARK: 动态更新界面
    func slideFloors() {
        sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
            if node.name == "floor" || node.name == "plank" {
                node.position.z += 0.036 // 减慢每帧移动速度
                if node.position.z > 1.0 { // 当超出屏幕后移除
                    node.removeFromParentNode()
                    if node.name == "plank" {
                        isPlankOnScreen = false // 更新状态
                        DispatchQueue.main.async {
                            self.addDynamicWoodPlank() // 立即添加新的木板
                        }
                    }
                }
            }
        }
    }

    func loadNewFloorsIfNeeded() {
        // 找到最远的地板
        var farthestZ: Float = 0.0
        sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
            if node.name == "floor" && node.position.z < farthestZ {
                farthestZ = node.position.z
            }
        }

        // 如果最远地板距离摄像机超过一定距离，则添加新地板
        if farthestZ > -4.0 {
            let newFloor = createFloor(at: SCNVector3(0, -0.5, farthestZ - 1.0))
            sceneView.scene.rootNode.addChildNode(newFloor)
        }
    }

    // MARK: ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        slideFloors()
        loadNewFloorsIfNeeded()
    }
}
