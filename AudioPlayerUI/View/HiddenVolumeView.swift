//
//  HiddenVolumeView.swift
//  AudioPlayerUI
//
//  Created by William.Weng on 2026/7/24.
//

import SwiftUI
import MediaPlayer

// MARK: - 輔助元件：阻擋系統自帶 HUD 專用
struct HiddenVolumeView: UIViewRepresentable {
    
    func makeUIView(context: Context) -> MPVolumeView {
        .init(frame: .zero)
    }
    
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
