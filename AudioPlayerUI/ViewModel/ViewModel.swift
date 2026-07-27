//
//  ViewModel.swift
//  AudioPlayerUI
//
//  Created by William.Weng on 2026/6/26.
//

import SwiftUI
import WWNormalizeAudioPlayer
internal import AVFAudio

/// 播放器畫面的狀態與控制邏輯 (負責管理播放狀態、曲目切換，以及播放完成後的後續行為)
@Observable
final class PlayerViewModel {
    
    var tracks: [WWNormalizeAudioPlayer.TrackInformation] = []  // 目前可播放的音軌清單
    
    var hasPrevious: Bool = true                                // 目前是否可切換到上一首
    var hasNext: Bool = true                                    // 目前是否可切換到下一首
    var currentTrackIndex: Int = 0                              // 目前選取的音軌索引
    
    var isStop: Bool = true                                     // 表示播放器目前是否為停止狀態
    var playerState: PlayerState = .none                        // 播放器目前的播放狀態
    var functionState: FunctionState = .none                    // 播放器目前的功能狀態，例如循環播放或自動播放下一首
    
    @ObservationIgnored
    private let player = WWNormalizeAudioPlayer()               // 實際負責音訊播放的播放器實例
    
    /// 載入播放清單並初始化播放器狀態。
    /// - Parameter tracks: 要載入的音軌 URL 清單
    @MainActor
    func prepare(tracks: [URL]) {
        self.currentTrackIndex = !tracks.isEmpty ? 0 : -1
        player.prepare(audioURLs: tracks, delegate: self, options: [.duckOthers])
        checkTrackRange()
    }
    
    /// 依目前音軌清單重新建立播放器內容
    ///
    /// 會將所有音軌網址提供給播放器進行預備，重設目前音軌索引為第一筆，並更新音軌切換狀態
    func refreshTracks() {
        player.prepare(audioURLs: tracks.compactMap(\.url), delegate: self, options: [.duckOthers])
        currentTrackIndex = 0
        checkTrackRange()
    }
    
    /// 更新播放器音量
    /// - Parameter volume: 音量值，範圍 0 ~ 1
    func volume(_ volume: Float) {
        player.volume = volume
    }
    
    /// 開始播放目前音軌
    ///
    /// 若播放器目前已處於播放狀態，則改為恢復播放，並直接返回。否則會先重設停止狀態、更新播放器狀態為 `.playing`，然後嘗試從目前音軌索引開始播放
    func play() async {
        
        if playerState == .playing { resume(); return }
        
        isStop = false
        playerState = .playing
        _ = try? await player.play(at: currentTrackIndex, targetDB: -2.0)
    }
    
    /// 切換播放狀態
    ///
    /// 當播放器目前正在播放時會停止播放；否則會啟動播放流程
    func togglePlay() {
        Task { playerState == .playing ? stop() : await play() }
    }
    
    /// 播放器停止播放
    func stop() {
        isStop = true
        player.stop()
        playerState = .finished
    }
    
    /// 切換到上一首，並更新當前曲名與可切換狀態
    func previousTrack() {
        currentTrackIndex -= 1
        checkTrackRange()
    }
    
    /// 切換到下一首，並更新當前曲名與可切換狀態
    func nextTrack() {
        currentTrackIndex += 1
        checkTrackRange()
    }
    
    /// 將目前音軌重設為第一首
    func resetTrack() {
        currentTrackIndex = 0
        checkTrackRange()
    }
    
    /// 依索引產生音軌提示文字
    /// - Parameter index: 音軌索引
    /// - Returns: 格式化後的提示文字，例如 `[00:02] demo.m4a`
    /// - Throws: 取得音軌時間失敗時拋出錯誤
    func trackHint(with index: Int?) -> String? {
        
        guard let index = index,
              let track = tracks[safe: index]
        else {
            return nil
        }
        
        return trackHint(track)
    }
    
    deinit {
        print("\(Self.self) deinit")
    }
}

// MARK: - WWNormalizeAudioPlayer.Delegate
extension PlayerViewModel: WWNormalizeAudioPlayer.Delegate {
    
    func audioPlayer(_ player: WWNormalizeAudioPlayer, prepare tracks: [WWNormalizeAudioPlayer.TrackInformation]) {
        self.tracks = tracks
    }
    
    func audioPlayer(_ player: WWNormalizeAudioPlayer, isPlaying currentTime: TimeInterval, trackTime: TimeInterval) {}
    
    func audioPlayer(_ player: WWNormalizeAudioPlayer, didFinished callbackType: AVAudioPlayerNodeCompletionCallbackType) {
        playerState = .finished
        handlePlaybackFinished(index: currentTrackIndex)
    }
    
    func audioPlayer(_ player: WWNormalizeAudioPlayer, error: Error) {}
}

// MARK: - 私有API
private extension PlayerViewModel {
    
    /// 從暫停狀態恢復播放
    @MainActor
    func resume() {
        player.resume()
        playerState = .playing
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
    
    /// 產生指定音軌的提示字串。
    ///
    /// 當 `track` 為 `nil` 時回傳 `nil`；否則會將音軌時長格式化為 `mm:ss`，
    /// 並組合成 `"[mm:ss] 檔名"` 的提示內容。
    ///
    /// - Parameter track: 要產生提示字串的音軌資訊。
    /// - Returns: 格式化後的提示字串；若沒有提供音軌則回傳 `nil`。
    /// - Throws: 此方法目前雖宣告為可拋出，但在現有實作中不會拋出錯誤。
    func trackHint(_ track: WWNormalizeAudioPlayer.TrackInformation?) -> String? {
        
        guard let track = track else { return nil }

        let time = track.duration.time(unitsStyle: .positional, allowedUnits: [.minute, .second], behavior: .pad) ?? "--:--"
        let hint: String = "[\(time)] \(track.url.lastPathComponent)"

        return hint
    }
    
    /// 處理播放完成後的行為 => 依照「連續播放」與「循環播放」組合，決定是否重播、播放下一首，或回到第一首
    func handlePlaybackFinished(index finishedIndex: Int) {

        if isStop { return }

        Task {
            switch functionState {
            case .autoNextTrack:
                guard finishedIndex < (tracks.count - 1) else { return }
                nextTrack()
                togglePlay()
            case .loopAndAutoNextTrack:
                if finishedIndex < (tracks.count - 1) {
                    nextTrack()
                } else {
                    resetTrack()
                }
                togglePlay()
            case .loop:
                togglePlay()
            default:
                break
            }
        }
    }
}
