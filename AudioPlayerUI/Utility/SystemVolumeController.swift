//
//  Extension.swift
//  AudioPlayerUI
//
//  Created by William.Weng on 2026/6/29.
//

import MediaPlayer

/// 取得系統音量調整功能
final class SystemVolumeController: Observable {
    
    private let volumeView = MPVolumeView(frame: .zero)
    private var volumeSlider: UISlider?
    
    init() {
        volumeSlider = volumeView.subviews.compactMap { $0 as? UISlider }.first
    }
    
    func setVolume(_ value: Float) {
        volumeSlider?.setValue(value, animated: false)
        volumeSlider?.sendActions(for: .touchUpInside)
    }
}
