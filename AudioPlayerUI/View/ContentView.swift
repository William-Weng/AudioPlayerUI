//
//  AudioPlayerApp.swift
//  AudioPlayerUI
//
//  Created by William.Weng on 2026/6/26.
//
//  UIFileSharingEnabled = YES（啟用檔案共享）
//  LSSupportsOpeningDocumentsInPlace = YES（允許直接開啟與編輯檔案）
//  UISupportsDocumentBrowser = YES（讓 App 的 Documents 目錄可在 Files App 的「On My iPhone」中顯示）

import SwiftUI
import MediaPlayer
import WWNormalizeAudioPlayer
import WWFileService

/// 主畫面
struct ContentView: View {
    
    @State private var currentVolume: Float = 0.0                                                           // 目前播放器音量，範圍為 0.0 到 1.0 (此值變更時，會同步更新播放器的輸出音量)
    @State private var isShuffle: Bool = false                                                              // 是否啟用隨機播放 (開啟時會直接打亂目前清單順序；關閉時則恢復檔名排序)
    @State private var viewModel = PlayerViewModel()                                                        // 播放器畫面狀態與播放控制邏輯
    @State private var systemVolume: Float = AVAudioSession.sharedInstance().outputVolume                   // 目前系統輸出音量 (範圍為 0.0 到 1.0)
    @State private var currentTitle: String = ""                                                            // 目前顯示的音軌標題
    @State private var loopButtonSetting = ButtonSetting(iconName: "", title: "", color: .clear)            // 循環播放按鈕的顯示設定
    @State private var autoNextTrackButtonSetting = ButtonSetting(iconName: "", title: "", color: .clear)   // 自動播放下一首按鈕的顯示設定
    
    private let systemVolumeController = SystemVolumeController()                                           // 用來控制系統音量的控制器
    
    var body: some View {
        
        NavigationStack {
            
            VStack(spacing: 8) {
                
                List {
                    ForEach(viewModel.tracks.indices, id: \.self) { index in
                        HStack {
                            trackView(with: index)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Audio Player")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, content: {
                VStack {
                    systemVolumeSliderView
                    volumeSliderView
                    trackView
                    
                    HStack(spacing: 32) {
                        actionButtonView
                    }
                }
                .padding()
                .background(Color.init(hex: "#F3F4F6"))
            })
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    leadingToolbarItemView
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    trailingToolbarItemView
                }
            }.task {
                loadInitialSettings()
                functionButtonSetting(state: viewModel.functionState)
            }.onChange(of: viewModel.currentTrackIndex) { _, newValue in
                let hint = viewModel.trackHint(with: newValue)
                currentTitle = hint ?? ""
            }.onChange(of: isShuffle) { _, newValue in
                sortTracks(isShuffle: newValue)
            }.onChange(of: viewModel.functionState) { _, newValue in
                functionButtonSetting(state: newValue)
            }
        }
    }
}

// MARK: - 私有屬性
private extension ContentView {
    
    /// 音量滑桿，拖動時即時同步到播放器
    var volumeSliderView: some View {
        
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .foregroundStyle(.secondary)
            
            Slider(value: $currentVolume, in: 0...1)
                .onChange(of: currentVolume) { _, newValue in
                    viewModel.volume(newValue)
                }
            
            Image(systemName: "speaker.wave.3.fill")
                .foregroundStyle(.secondary)
        }
    }
    
    /// 系統音量滑桿，拖動時即時更新總音量
    var systemVolumeSliderView: some View {
        
        HStack(spacing: 12) {
            Image(systemName: "music.note")
                .foregroundStyle(.secondary)
            
            Slider(value: $systemVolume, in: 0...1)
                .onChange(of: systemVolume) { _, newValue in
                    systemVolumeController.setVolume(newValue)
                }
            
            Image(systemName: "speaker.wave.3.fill")
                .foregroundStyle(.secondary)
        }
    }
    
    /// 顯示目前播放曲名；尚未選取時顯示預設文字
    var trackView: some View {
        
        if !currentTitle.isEmpty {
            Text(currentTitle)
                .font(.title3)
                .lineLimit(1)
        } else {
            Text("尚未載入")
                .font(.title3)
                .lineLimit(1)
        }
    }
    
    /// 左上角工具列按鈕：切換隨機播放模式
    var leadingToolbarItemView: some View {
        
        Button {
            isShuffle.toggle()
        } label: {
            Image(systemName: "shuffle")
                .foregroundStyle(isShuffle ? .red : Color(.systemGray3))
        }
        .accessibilityLabel("隨機播放")
        .accessibilityValue(isShuffle ? "隨機播放已開啟" : "隨機播放已關閉")
    }

    /// 右上角工具列按鈕群：循環播放與連續播放
    @ViewBuilder
    var trailingToolbarItemView: some View {
        loopItemButton
        autoNextTrackButton
    }
    
    /// 播放控制按鈕群：上一首、播放/暫停、下一首
    @ViewBuilder
    var actionButtonView: some View {
        
        Button(action: viewModel.previousTrack) {
            Image(systemName: "backward.fill")
                .font(.system(size: 32))
        }.disabled(!viewModel.hasPrevious)
        
        Button(action: viewModel.togglePlay) {
            Image(systemName: viewModel.playerState == .playing ? "stop.circle.fill" : "play.circle.fill")
                .font(.system(size: 64))
        }
        
        Button(action: viewModel.nextTrack) {
            Image(systemName: "forward.fill")
                .font(.system(size: 32))
        }.disabled(!viewModel.hasNext)
    }
    
    /// 循環播放按鈕
    ///
    /// 點擊後會依照目前的功能狀態切換循環播放相關設定，並同步更新按鈕圖示、顏色與輔助功能顯示內容
    var loopItemButton: some View {
                
        Button {
            switch viewModel.functionState {
            case .loop: viewModel.functionState = .none
            case .loopAndAutoNextTrack: viewModel.functionState = .autoNextTrack
            case .none: viewModel.functionState = .loop
            case .autoNextTrack: viewModel.functionState = .loopAndAutoNextTrack
            }
        } label: {
            Image(systemName: loopButtonSetting.iconName)
                .foregroundStyle(loopButtonSetting.color)
        }
        .accessibilityLabel("循環播放")
        .accessibilityValue(loopButtonSetting.title)
    }
    
    /// 連續播放按鈕
    ///
    /// 點擊後會依照目前的功能狀態切換自動播放下一首相關設定，並同步更新按鈕圖示、顏色與輔助功能顯示內容
    var autoNextTrackButton: some View {
        
        Button {
            switch viewModel.functionState {
            case .autoNextTrack: viewModel.functionState = .none
            case .loopAndAutoNextTrack: viewModel.functionState = .loop
            case .none: viewModel.functionState = .autoNextTrack
            case .loop: viewModel.functionState = .loopAndAutoNextTrack
            }
        } label: {
            Image(systemName: autoNextTrackButtonSetting.iconName)
                .foregroundStyle(autoNextTrackButtonSetting.color)
        }
        .accessibilityLabel("連續播放")
        .accessibilityValue(autoNextTrackButtonSetting.title)
    }
}

// MARK: - 私有API
private extension ContentView {
    
    /// 初始化播放器畫面設定 => 讀取文件目錄中的音訊檔，依檔名排序後載入，並設定預設音量
    func loadInitialSettings() {
        
        let tracks = try? WWFileService.allFileItems(at: .documentsDirectory, skipsHiddenFiles: true).compactMap(\.url)
        
        viewModel.prepare(tracks: tracks ?? [])
        currentVolume = 0.1
        resetTitle()
    }
    
    /// 將目前的音軌清單排序
    ///
    /// 當 `isShuffle` 為 `true` 時，會隨機打亂音軌順序
    /// 否則會依照檔名的本地化標準順序進行排序
    /// 排序完成後，會將目前音軌索引重設為第一筆，並同步更新標題
    func sortTracks(isShuffle: Bool) {
        
        defer {
            viewModel.refreshTracks()
            resetTitle()
        }
        
        if isShuffle { viewModel.tracks.shuffle(); return }
        
        viewModel.tracks.sort {
            $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
        }
    }
    
    /// 根據目前音軌索引重新設定標題
    func resetTitle() {
        let hint = viewModel.trackHint(with: viewModel.currentTrackIndex)
        currentTitle = hint ?? ""
    }
    
    /// 根據功能鍵狀態設定外觀
    /// - Parameter state: 功能鍵狀態
    func functionButtonSetting(state: FunctionState) {
        
        switch state {
        case .none:
            loopButtonSetting = .init(iconName: "repeat", title: "循環播放已關閉", color: Color(.systemGray3))
            autoNextTrackButtonSetting = .init(iconName: "play.square.stack", title: "連續播放已關閉", color: Color(.systemGray3))
        case .loop:
            loopButtonSetting = .init(iconName: "repeat.1", title: "循環播放已開啟", color: .red)
            autoNextTrackButtonSetting = .init(iconName: "play.square.stack", title: "連續播放已關閉", color: Color(.systemGray3))
        case .autoNextTrack:
            loopButtonSetting = .init(iconName: "repeat", title: "循環播放已關閉", color: Color(.systemGray3))
            autoNextTrackButtonSetting = .init(iconName: "play.square.stack.fill", title: "連續播放已開啟", color: .red)
        case .loopAndAutoNextTrack:
            loopButtonSetting = .init(iconName: "repeat.1", title: "循環播放已開啟", color: .red)
            autoNextTrackButtonSetting = .init(iconName: "play.square.stack.fill", title: "連續播放已開啟", color: .red)
        }
    }
    
    /// 建立單一音軌列
    /// - Parameter index: 音軌在清單中的索引
    /// - Returns: 可點擊的音軌列，點擊後會更新目前選取曲目
    func trackView(with index: Int) -> some View {
        
        HStack {
            
            Text((viewModel.trackHint(with: index)) ?? "")
                .foregroundColor(viewModel.currentTrackIndex == index ? .blue : .primary)
            
            Spacer()
            
            if viewModel.currentTrackIndex == index {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            let hint = viewModel.trackHint(with: index)
            currentTitle = hint ?? ""
            viewModel.currentTrackIndex = index
            viewModel.stop()
        }
    }
}

