import Foundation
import AVFoundation
import Combine

// MARK: - Audio Playback Engine
// Thin wrapper around AVAudioPlayer for audiobook chapter playback.
// Provides current time observation for driving karaoke highlighting.

@Observable
final class AudioPlaybackEngine: NSObject, AVAudioPlayerDelegate {
    
    // MARK: - State
    
    var isPlaying = false
    var currentTime: Double = 0.0
    var duration: Double = 0.0
    var playbackRate: Float = 1.0
    
    /// Called when a track finishes playing naturally (not paused/stopped).
    var onTrackFinished: (() -> Void)?
    
    private var player: AVAudioPlayer?
    private var displayLink: CADisplayLink?
    
    /// Seconds to skip at the start of each file (e.g., LibriVox disclaimer).
    var startOffset: Double = 0.0
    
    override init() {
        super.init()
    }
    
    // MARK: - Load
    
    func load(url: URL) throws {
        stop()
        
        // Configure audio session for playback
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true)
        
        player = try AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.enableRate = true
        player?.prepareToPlay()
        duration = player?.duration ?? 0
        currentTime = startOffset
        
        // Apply start offset
        if startOffset > 0 {
            player?.currentTime = startOffset
        }
    }
    
    // MARK: - Playback Controls
    
    func play() {
        player?.rate = playbackRate
        player?.play()
        isPlaying = true
        startDisplayLink()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        stopDisplayLink()
    }
    
    func toggle() {
        isPlaying ? pause() : play()
    }
    
    func stop() {
        player?.stop()
        isPlaying = false
        currentTime = 0
        stopDisplayLink()
    }
    
    /// Seek to a specific time (e.g., when user taps a word).
    func seek(to time: Double) {
        let clampedTime = max(startOffset, time)
        player?.currentTime = clampedTime
        currentTime = clampedTime
        if !isPlaying {
            play()
        }
    }
    
    /// Skip forward/backward by seconds.
    func skip(by seconds: Double) {
        let newTime = currentTime + seconds
        let clamped = max(startOffset, min(duration, newTime))
        seek(to: clamped)
    }
    
    /// Set playback speed (0.5x – 2.0x).
    func setRate(_ rate: Float) {
        playbackRate = max(0.5, min(2.0, rate))
        if isPlaying {
            player?.rate = playbackRate
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        stopDisplayLink()
        if flag {
            onTrackFinished?()
        }
    }
    
    // MARK: - Display Link (60fps time updates)
    
    private func startDisplayLink() {
        stopDisplayLink()
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: 30, maximum: 60, preferred: 60
        )
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func tick() {
        guard let player, player.isPlaying else {
            if isPlaying {
                isPlaying = false
                stopDisplayLink()
            }
            return
        }
        currentTime = player.currentTime
    }
    
    deinit {
        stopDisplayLink()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
