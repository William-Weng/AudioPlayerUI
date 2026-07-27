//
//  Constant.swift
//  AudioPlayerUI
//
//  Created by William.Wng on 2026/7/24.
//

import SwiftUI

enum PlayerState: String, CaseIterable {
    case none
    case playing
    case paused
    case finished
}

enum FunctionState: String, CaseIterable {
    case none
    case loop
    case autoNextTrack
    case loopAndAutoNextTrack
}
