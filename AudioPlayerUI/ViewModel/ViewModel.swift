//
//  ViewModel.swift
//  AudioPlayerUI
//
//  Created by William.Weng on 2026/6/26.
//

import SwiftUI
import WWNormalizeAudioPlayer
internal import AVFAudio

/// 播放器畫面的狀態與控制邏輯 => 負責管理播放狀態、曲目切換，以及播放完成後的後續行為
@Observable
final class PlayerViewModel {
    
    var isPlaying: Bool = false                     // 目前是否正在播放中
    var isPause: Bool = false                       // 目前是否為暫停狀態 => 用來區分「暫停」與「播放結束」兩種不同情境
    var isFinished: Bool = false                    // 目前音軌是否已播放完成
    var isAutoPlayNextTrack: Bool = false           // 是否在播放完成後自動播放下一首
    var isLoop: Bool = false                        // 是否啟用單曲或清單循環播放邏輯
    
    var hasPrevious: Bool = true                    // 目前是否可切換到上一首
    var hasNext: Bool = true                        // 目前是否可切換到下一首
    
    var tracks: [URL] = []                          // 目前載入的音軌清單
    var currentTitle: String?                       // 目前顯示在畫面上的曲名提示文字
    var currentTrackIndex: Int = 0                  // 目前選取的音軌索引
    
    private let player = WWNormalizeAudioPlayer()   // 實際負責音訊播放的播放器實例
    
    /// 載入播放清單並初始化播放器狀態。
    /// - Parameter tracks: 要載入的音軌 URL 清單
    @MainActor
    func load(tracks: [URL]) {
        
        self.tracks = tracks
        self.currentTrackIndex = !tracks.isEmpty ? 0 : -1
        
        player.configure(delegate: self, options: [.duckOthers])
        currentTitle = try? trackHint(with: currentTrackIndex)
        checkTrackRange()
    }
    
    /// 更新播放器音量
    /// - Parameter volume: 音量值，範圍 0 ~ 1
    func volume(_ volume: Float) {
        player.volume = volume
    }
    
    /// 開始播放目前選取的音軌 => 若目前只是暫停，則直接恢復播放，不重新載入音軌
    func play() async {
        
        if isPause { resume(); return }
        
        guard let track = tracks[safe: currentTrackIndex] else { return }
        await player.play(with: [track], targetDB: -2.0, loop: false)
    }
    
    /// 切換播放或暫停狀態 => 若目前正在播放則暫停，否則開始播放或從暫停狀態恢復
    func togglePlay() {
        Task { isPlaying ? pause() : await play() }
    }
    
    /// 播放器停止播放
    func stop() {
        player.stop()
        isPlaying = false
        isPause = false
        isFinished = true
    }
    
    /// 暫停目前播放內容，並同步更新狀態旗標
    func pause() {
        player.pause()
        isPlaying = false
        isPause = true
    }
    
    /// 切換到上一首，並更新當前曲名與可切換狀態
    func previousTrack() {
        
        currentTrackIndex -= 1
        checkTrackRange()
        currentTitle = try? trackHint(with: currentTrackIndex)
    }
    
    /// 切換到下一首，並更新當前曲名與可切換狀態
    func nextTrack() {
        
        currentTrackIndex += 1
        checkTrackRange()
        currentTitle = try? trackHint(with: currentTrackIndex)
    }
    
    /// 將目前音軌重設為第一首
    func resetTrack() {
        
        currentTrackIndex = 0
        checkTrackRange()
        currentTitle = try? trackHint(with: currentTrackIndex)
    }
    
    /// 依索引產生音軌提示文字
    /// - Parameter index: 音軌索引
    /// - Returns: 格式化後的提示文字，例如 `[00:02] demo.m4a`
    /// - Throws: 取得音軌時間失敗時拋出錯誤
    func trackHint(with index: Int?) throws -> String? {
        
        guard let index = index,
              let track = tracks[safe: index]
        else {
            return nil
        }
        
        return try trackHint(track)
    }
    
    deinit {
        print("\(Self.self) deinit")
    }
}

// MARK: - WWNormalizeAudioPlayer.Delegate
extension PlayerViewModel: WWNormalizeAudioPlayer.Delegate {
    
    /// 播放開始時同步更新播放狀態
    func audioPlayer(_ player: WWNormalizeAudioPlayer, didStartTracks tracks: [URL], totalDuration: TimeInterval) {
        isPlaying = true
        isPause = false
        isFinished = false
    }
    
    /// 單一音軌播放完成時更新狀態，並依目前設定決定後續播放行為
    func audioPlayer(_ player: WWNormalizeAudioPlayer, didFinishTrackIndex trackIndex: Int, callbackType: AVAudioPlayerNodeCompletionCallbackType) {
        isPlaying = false
        isPause = false
        isFinished = true
        handlePlaybackFinished()
    }
    
    /// 播放進度回呼，目前未使用，保留給進度條或播放時間顯示
    func audioPlayer(_ player: WWNormalizeAudioPlayer, trackIndex: Int, currentTime: TimeInterval, trackTime: TimeInterval) {}
    
    /// 播放錯誤回呼，目前未使用，後續可接錯誤提示或除錯紀錄
    func audioPlayer(_ player: WWNormalizeAudioPlayer, error: Error) {}
}

// MARK: - 私有API
private extension PlayerViewModel {
    
    /// 從暫停狀態恢復播放
    @MainActor
    func resume() {
        player.resume()
        isPlaying = true
        isPause = false
    }
    
    /// 檢查目前音軌索引是否在合法範圍內，並同步更新上一首 / 下一首按鈕是否可用
    func checkTrackRange() {
        
        guard !tracks.isEmpty else {
            hasPrevious = false
            hasNext = false
            currentTrackIndex = 0
            return
        }
        
        if currentTrackIndex < 0 {
            currentTrackIndex = 0
        } else if currentTrackIndex >= tracks.count {
            currentTrackIndex = tracks.count - 1
        }
        
        hasPrevious = currentTrackIndex > 0
        hasNext = currentTrackIndex < (tracks.count - 1)
    }
    
    /// 將音軌 URL 轉成畫面顯示用提示文字
    /// - Parameter track: 音軌 URL
    /// - Returns: 格式化後的提示文字
    /// - Throws: 取得音軌時間失敗時拋出錯誤
    func trackHint(_ track: URL?) throws -> String? {
        
        guard let track = track else { return nil }
        
        let trackTime = try player.trackTime(with: track)
        let time = trackTime.time(unitsStyle: .positional, allowedUnits: [.minute, .second], behavior: .pad) ?? "--:--"
        let hint: String = "[\(time)] \(track.lastPathComponent)"
        
        return hint
    }
    
    /// 處理播放完成後的行為 => 依照「連續播放」與「循環播放」組合，決定是否重播、播放下一首，或回到第一首
    func handlePlaybackFinished() {
        
        guard isFinished else { return }
        
        Task {
            
            switch (isAutoPlayNextTrack, isLoop) {
            
            case (true, true):
                
                if currentTrackIndex < (tracks.count - 1) {
                    nextTrack()
                } else {
                    resetTrack()
                }
                
                togglePlay()
                
            case (true, false):
                
                guard currentTrackIndex < (tracks.count - 1) else { return }
                
                nextTrack()
                togglePlay()
                
            case (false, true):
                togglePlay()
                
            case (false, false): break
            }
        }
    }
}
