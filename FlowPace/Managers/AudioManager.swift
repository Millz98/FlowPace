import Foundation
import AVFoundation
import AudioToolbox

@MainActor
class AudioManager: ObservableObject {
    @Published var isAudioEnabled = true
    @Published var volume: Float = 0.7

    private let userDefaults = UserDefaults.standard

    init() {
        loadSettings()
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    func prepareAudio() {}

    func playStepChangeSound() {
        guard isAudioEnabled else { return }
        playSystemSound(SystemSoundID(1005))
    }

    func playCompletionSound() {
        guard isAudioEnabled else { return }
        playSystemSound(SystemSoundID(1006))
    }

    private func playSystemSound(_ soundID: SystemSoundID) {
        AudioServicesPlaySystemSound(soundID)
    }

    func toggleAudio() {
        isAudioEnabled.toggle()
        saveSettings()
    }

    func setVolume(_ newVolume: Float) {
        volume = max(0.0, min(1.0, newVolume))
        saveSettings()
    }

    private func loadSettings() {
        isAudioEnabled = userDefaults.bool(forKey: "isAudioEnabled")
        volume = userDefaults.float(forKey: "audioVolume")

        if userDefaults.object(forKey: "isAudioEnabled") == nil {
            isAudioEnabled = true
        }
        if userDefaults.object(forKey: "audioVolume") == nil {
            volume = 0.7
        }
    }

    private func saveSettings() {
        userDefaults.set(isAudioEnabled, forKey: "isAudioEnabled")
        userDefaults.set(volume, forKey: "audioVolume")
    }

    func stopAllAudio() {}
}
