//
//  GameModel.swift
//  EmojiGo
//
//  Created by Tong Li on 12/13/24.
//

import Foundation

class GameModel {
    var isPlankOnScreen = false
    var countdownValue = 20
    var score = 0 // 游戏分数

    var matchingTime: TimeInterval = 0 // 匹配时间累计
    var currentPlankEmoji: String? // 当前木板上的表情
    var hasScoredOnCurrentPlank = false // 是否已经为当前木板计分

    func reset() {
        isPlankOnScreen = false
        countdownValue = 20
        score = 0
        matchingTime = 0
        currentPlankEmoji = nil
        hasScoredOnCurrentPlank = false
    }
}

