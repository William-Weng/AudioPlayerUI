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

struct ContentView: View {
    
    @State var currentVolume: Float = 0.0   // 目前音量，範圍 0 ~ 1，會同步更新播放器音量
    @State var isShuffle: Bool = false      // 是否啟用隨機播放 => 開啟時會直接打亂目前清單順序；關閉時則恢復檔名排序
    
    /// 播放器畫面狀態與播放控制邏輯
    @State private var viewModel = PlayerViewModel()
    
    /// 取得系統總音量
    @State private var systemVolume: Float = AVAudioSession.sharedInstance().outputVolume
    
    private let systemVolumeController = SystemVolumeController()
    
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
                
                systemVolumeSliderView
                volumeSliderView
                trackView

                HStack(spacing: 32) {
                    actionButtonView
                }
            }
            .padding()
            .navigationTitle("播放器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    leadingToolbarItemView
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    trailingToolbarItemView
                }
            }.task {
                loadInitialSettings()
            }.onChange(of: isShuffle) { _, isShuffle in
                updateTrackOrder(isShuffle: isShuffle)
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
        
        if let currentTitle = viewModel.currentTitle, !currentTitle.isEmpty {
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
        .accessibilityValue(isShuffle ? "已開啟" : "已關閉")
    }
    
    /// 右上角工具列按鈕群：循環播放與連續播放
    @ViewBuilder
    var trailingToolbarItemView: some View {
        
        Button {
            viewModel.isLoop.toggle()
        } label: {
            Image(systemName: viewModel.isLoop ? "repeat.1" : "repeat")
                .foregroundStyle(viewModel.isLoop ? .red : Color(.systemGray3))
        }
        .accessibilityLabel("循環播放")
        .accessibilityValue(viewModel.isLoop ? "已開啟" : "已關閉")
        
        Button {
            viewModel.isAutoPlayNextTrack.toggle()
        } label: {
            Image(systemName: viewModel.isAutoPlayNextTrack ? "play.square.stack.fill" : "play.square.stack")
                .foregroundStyle(viewModel.isAutoPlayNextTrack ? .red : Color(.systemGray3))
        }
        .accessibilityLabel("連續播放")
        .accessibilityValue(viewModel.isAutoPlayNextTrack ? "已開啟" : "已關閉")
    }
    
    /// 播放控制按鈕群：上一首、播放/暫停、下一首
    @ViewBuilder
    var actionButtonView: some View {
        
        Button(action: viewModel.previousTrack) {
            Image(systemName: "backward.fill")
                .font(.system(size: 32))
        }.disabled(!viewModel.hasPrevious)
        
        Button(action: viewModel.togglePlay) {
            Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 64))
        }
        
        Button(action: viewModel.nextTrack) {
            Image(systemName: "forward.fill")
                .font(.system(size: 32))
        }.disabled(!viewModel.hasNext)
    }
}

// MARK: - 私有API
private extension ContentView {
    
    /// 初始化播放器畫面設定 => 讀取文件目錄中的音訊檔，依檔名排序後載入，並設定預設音量
    func loadInitialSettings() {
        
        let tracks = URL.documentsDirectory.searchAudios().sorted { $1.lastPathComponent > $0.lastPathComponent }
        
        print(URL.documentsDirectory)
        
        viewModel.load(tracks: tracks)
        currentVolume = 0.1
    }
    
    /// 依照是否啟用隨機播放來更新清單順序
    /// - Parameter isShuffle: `true` 時打亂目前播放清單；`false` 時恢復為檔名排序
    func updateTrackOrder(isShuffle: Bool) {
        isShuffle ? viewModel.tracks.shuffle() : viewModel.tracks.sort { $1.lastPathComponent > $0.lastPathComponent }
    }
    
    /// 建立單一音軌列
    /// - Parameter index: 音軌在清單中的索引
    /// - Returns: 可點擊的音軌列，點擊後會更新目前選取曲目
    func trackView(with index: Int) -> some View {
        
        HStack {
            
            Text((try? viewModel.trackHint(with: index)) ?? "")
                .foregroundColor(viewModel.currentTrackIndex == index ? .blue : .primary)
            
            Spacer()
            
            if viewModel.currentTrackIndex == index {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.currentTrackIndex = index
            viewModel.currentTitle = try? viewModel.trackHint(with: index)
        }
    }
}

