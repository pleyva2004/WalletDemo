import AVFoundation

// MARK: - Spoken "Siri" lines
//
// One shared AVSpeechSynthesizer that voices the scripted Siri prompts in the resell flow.
// Audible on the Simulator (routes to the Mac's output); silent/irrelevant in screenshots.
// ponytail: add an AVAudioSession .playback category only if a real device goes silent.

final class SiriVoice {
    static let shared = SiriVoice()
    private let synth = AVSpeechSynthesizer()

    func speak(_ text: String?) {
        guard let text, !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synth.speak(utterance)
    }

    func stop() { synth.stopSpeaking(at: .immediate) }
}
