//
//  GameModel.swift
//  EmojiGo
//
//  Created by Tong Li on 12/13/24.
//

class GameModel {
    var isPlankOnScreen = false
    var countdownValue = 20

    func reset() {
        isPlankOnScreen = false
        countdownValue = 20
    }
}
