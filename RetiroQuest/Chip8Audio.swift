import AVFoundation

/// Sintetizador 8-bit: ondas quadrada/triângulo/ruído geradas em tempo real
/// num AVAudioSourceNode. Efeitos sonoros curtos + música chiptune em loop.
final class Chip8Audio {
    static let shared = Chip8Audio()

    enum Wave { case square, triangle, noise }
    enum SFX { case blip, tick, success, error, thud }

    private struct Voice {
        var freq: Double
        var wave: Wave
        var start: Double      // em segundos do relógio de amostras
        var dur: Double
        var vol: Double
        var phase: Double = 0
        var noise: UInt32 = 0x1234
        var lastNoise: Double = 0
    }

    private let engine = AVAudioEngine()
    private var sampleRate: Double = 44100
    private var voices: [Voice] = []
    private let lock = NSLock()
    private var clock: Double = 0        // avança no callback de render
    private var ready = false
    private var musicTimer: Timer?
    private var musicStep = 0

    var muted = UserDefaults.standard.bool(forKey: "rq.muted") {
        didSet {
            UserDefaults.standard.set(muted, forKey: "rq.muted")
            if muted { lock.lock(); voices.removeAll(); lock.unlock() }
        }
    }

    private init() {}

    func startIfNeeded() {
        guard !ready else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
        sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let source = AVAudioSourceNode { [weak self] _, _, frameCount, abl -> OSStatus in
            self?.render(frameCount: Int(frameCount), abl: abl)
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode,
                       format: AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        engine.mainMixerNode.outputVolume = 0.45
        do {
            try engine.start()
            ready = true
        } catch {}
    }

    // MARK: - Render (thread de áudio)

    private func render(frameCount: Int, abl: UnsafeMutablePointer<AudioBufferList>) {
        let buffers = UnsafeMutableAudioBufferListPointer(abl)
        guard let out = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return }
        lock.lock()
        var localVoices = voices
        lock.unlock()

        let dt = 1.0 / sampleRate
        for frame in 0..<frameCount {
            let t = clock + Double(frame) * dt
            var sample = 0.0
            for i in localVoices.indices {
                let age = t - localVoices[i].start
                guard age >= 0, age < localVoices[i].dur else { continue }
                let env = 1.0 - age / localVoices[i].dur          // decaimento linear
                var value = 0.0
                switch localVoices[i].wave {
                case .square:
                    value = localVoices[i].phase < 0.5 ? 1 : -1
                case .triangle:
                    value = 4 * abs(localVoices[i].phase - 0.5) - 1
                case .noise:
                    if localVoices[i].phase < 0.02 {              // segura o valor (ruído grave)
                        var seed = localVoices[i].noise
                        seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5
                        localVoices[i].noise = seed
                        localVoices[i].lastNoise = Double(seed % 2000) / 1000 - 1
                    }
                    value = localVoices[i].lastNoise
                }
                localVoices[i].phase += localVoices[i].freq * dt
                if localVoices[i].phase >= 1 { localVoices[i].phase -= 1 }
                sample += value * env * localVoices[i].vol
            }
            out[frame] = Float(max(-1, min(1, sample)))
        }
        clock += Double(frameCount) * dt

        let now = clock
        lock.lock()
        // preserva fases atualizadas e descarta vozes terminadas
        voices = localVoices.filter { now - $0.start < $0.dur }
        lock.unlock()
    }

    // MARK: - Notas e efeitos

    private func note(_ freq: Double, _ wave: Wave, dur: Double, vol: Double, delay: Double = 0) {
        guard ready, !muted else { return }
        lock.lock()
        voices.append(Voice(freq: freq, wave: wave, start: clock + delay, dur: dur, vol: vol))
        if voices.count > 24 { voices.removeFirst(voices.count - 24) }
        lock.unlock()
    }

    func play(_ sfx: SFX) {
        switch sfx {
        case .blip:
            note(760, .square, dur: 0.07, vol: 0.16)
        case .tick:
            note(1240, .square, dur: 0.045, vol: 0.1)
        case .success:
            note(660, .square, dur: 0.09, vol: 0.16)
            note(880, .square, dur: 0.09, vol: 0.16, delay: 0.08)
            note(1320, .square, dur: 0.14, vol: 0.16, delay: 0.16)
        case .error:
            note(170, .square, dur: 0.16, vol: 0.15)
            note(120, .square, dur: 0.22, vol: 0.15, delay: 0.1)
        case .thud:
            note(95, .triangle, dur: 0.12, vol: 0.3)
            note(60, .noise, dur: 0.08, vol: 0.12)
        }
    }

    // MARK: - Música (loop chiptune de 32 passos)

    private static let lead: [Double?] = {
        func f(_ n: Double) -> Double { 440 * pow(2, n / 12) }  // semitons a partir do lá4
        let C5 = f(3), D5 = f(5), E5 = f(7), F5 = f(8), G5 = f(10), A5 = f(12)
        let B4 = f(2), C6 = f(15)
        return [C5, E5, G5, E5, A5, G5, E5, C5,
                D5, F5, A5, F5, G5, F5, D5, B4,
                C5, E5, G5, C6, A5, G5, E5, G5,
                F5, A5, G5, E5, D5, E5, C5, nil]
    }()
    private static let bass: [Double?] = {
        func f(_ n: Double) -> Double { 440 * pow(2, n / 12) }
        let C3 = f(-21), A2 = f(-24), F2 = f(-28), G2 = f(-26)
        return [C3, nil, C3, nil, A2, nil, A2, nil,
                F2, nil, F2, nil, G2, nil, G2, nil,
                C3, nil, C3, nil, A2, nil, A2, nil,
                F2, nil, G2, nil, C3, nil, nil, nil]
    }()

    func startMusic() {
        guard musicTimer == nil else { return }
        musicStep = 0
        musicTimer = Timer.scheduledTimer(withTimeInterval: 0.21, repeats: true) { [weak self] _ in
            guard let self, self.ready, !self.muted else { return }
            if let n = Self.lead[self.musicStep] { self.note(n, .square, dur: 0.18, vol: 0.05) }
            if let b = Self.bass[self.musicStep] { self.note(b, .triangle, dur: 0.2, vol: 0.12) }
            self.musicStep = (self.musicStep + 1) % Self.lead.count
        }
    }

    func stopMusic() {
        musicTimer?.invalidate()
        musicTimer = nil
    }
}
