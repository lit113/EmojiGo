//
//  GameView.swift
//  EmojiGo
//
//  Created by Tong Li on 12/13/24.
//

//
//  ViewController.swift
//  EmojiGo
//
//  Created by Tong Li on 12/10/24.
//

import UIKit
import SceneKit
import ARKit

// MARK: - GameView
class GameView {
    private(set) var countdownLabel: UILabel
    private(set) var gameOverlay: UIView?

    init(frame: CGRect) {
        countdownLabel = UILabel(frame: CGRect(x: 20, y: 50, width: 100, height: 50))
        countdownLabel.text = "20"
        countdownLabel.font = UIFont.boldSystemFont(ofSize: 24)
        countdownLabel.textColor = .white
        countdownLabel.backgroundColor = .black
        countdownLabel.textAlignment = .center
        countdownLabel.layer.cornerRadius = 5
        countdownLabel.layer.masksToBounds = true
    }

    func setupCountdown(in view: UIView) {
        view.addSubview(countdownLabel)
    }

    func updateCountdownLabel(with value: Int) {
        countdownLabel.text = "\(value)"
    }

    func showGameOverlay(in view: UIView, score: Int, restartHandler: @escaping () -> Void) {
        gameOverlay = UIView(frame: view.bounds)
        gameOverlay?.backgroundColor = UIColor.black.withAlphaComponent(0.8)

        let scoreLabel = UILabel(frame: CGRect(x: 50, y: 300, width: view.bounds.width - 100, height: 50))
        scoreLabel.text = "Score: \(score)"
        scoreLabel.font = UIFont.boldSystemFont(ofSize: 30)
        scoreLabel.textColor = .white
        scoreLabel.textAlignment = .center
        scoreLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        gameOverlay?.addSubview(scoreLabel)

        let playAgainImageView = UIImageView(frame: CGRect(x: (view.bounds.width - 200) / 2, y: 550, width: 200, height: 50))
        playAgainImageView.image = UIImage(named: "play_again")
        playAgainImageView.contentMode = .scaleAspectFit
        playAgainImageView.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(playAgainTapped(_:)))
        playAgainImageView.addGestureRecognizer(tapGesture)
        gameOverlay?.addSubview(playAgainImageView)

        view.addSubview(gameOverlay!)

        // Save handler for restart
        self.restartHandler = restartHandler
    }

    func removeGameOverlay() {
        gameOverlay?.removeFromSuperview()
        gameOverlay = nil
    }

    @objc private func playAgainTapped(_ sender: UITapGestureRecognizer) {
        restartHandler?()
    }

    private var restartHandler: (() -> Void)?
}
