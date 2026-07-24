//
//  AudioPlayerApp.swift
//  AudioPlayerUI
//
//  Created by William.Weng on 2026/6/26.
//

import SwiftUI

@main
struct AudioPlayerApp: App {
    
    var body: some Scene {
        
        WindowGroup {
            
            ZStack {
                ContentView()
                hiddenVolumeView
            }
            .preferredColorScheme(.light)
        }
    }
}

// MARK: - 私有屬性
private extension AudioPlayerApp {
    
    /// 隱藏系統音量HUD用
    var hiddenVolumeView: some View {
        
        HiddenVolumeView()
            .frame(width: 1, height: 1)
            .opacity(0.01)
    }
}
