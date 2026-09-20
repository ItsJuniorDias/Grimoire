//
//  Narration.swift
//  Grimoire — narração por áudio pré-gerado (MP3)
//
//  Toca os MP3s narrados que ficam em Content/audio/st-XXX/chY.mp3.
//  Foi trocado de AVSpeechSynthesizer (TTS on-device) por AVAudioPlayer
//  (MP3 pré-gerado) pra ter voz consistente e de melhor qualidade em
//  qualquer aparelho.
//
//  A audio session usa `.playback` — o mesmo modo do sistema antigo —
//  então o áudio toca com o silencioso ligado e com a tela bloqueada,
//  que é o caso de uso central: apagar a luz e só ouvir a história.
//
//  O highlight de parágrafo no leitor continua funcionando: como o MP3
//  não sabe onde termina cada parágrafo, a gente estima usando word
//  count proporcional (parágrafos maiores levam mais tempo, é natural).
//
//  SETUP NO XCODE:
//    Os MP3s ficam em Content/audio/ (flat, sem subpastas) com nomes
//    únicos no formato `st-XXX-chY.mp3` — ex: `st-001-ch2.mp3`. Formato
//    flat é obrigatório porque o Xcode 16 File System Synchronized
//    Groups faz resource copy sem preservar subdiretórios: se tivesse
//    50 pastas com `ch1.mp3` dentro, o build falharia com "Multiple
//    commands produce .../Grimoire.app/ch1.mp3".
//    Como a pasta Content/ já é sincronizada, os arquivos são
//    detectados automaticamente pelo Xcode — nada pra arrastar.
//
//  ON-DEMAND RESOURCES:
//    Os MP3s não vêm no download da App Store (ver ContentPacks.swift).
//    O primeiro play de uma história baixa os capítulos dela de uma vez
//    (~4 MB): `isLoading` fica true enquanto baixa e, sem internet,
//    `loadFailed` vira true e o botão do leitor passa a tentar de novo.
//    MP3 novo precisa de tag: rode scripts/tag_ondemand_resources.py.
//

import SwiftUI
import AVFoundation
import MediaPlayer

@MainActor
@Observable
final class NarrationController: NSObject {

    // Índice do parágrafo sendo narrado (-1 = nada). O leitor observa isto
    // pra destacar o trecho atual e rolar até ele.
    private(set) var spokenParagraph: Int = -1
    private(set) var isSpeaking: Bool = false
    private(set) var isPaused: Bool = false
    /// Baixando o pacote de narração da história (On-Demand Resources).
    private(set) var isLoading: Bool = false
    /// O último download falhou — quase sempre falta de internet. O
    /// próximo `toggle` tenta de novo.
    private(set) var loadFailed: Bool = false

    /// Velocidade da reprodução. AVAudioPlayer aceita 0.5 (metade) até 2.0
    /// (dobro), com 1.0 = normal. Default calmo pra "história antes de dormir".
    var rate: Float = 1.0 {
        didSet {
            let clamped = max(0.5, min(2.0, rate))
            player?.rate = clamped
            defaults.set(clamped, forKey: rateKey)
        }
    }

    private var player: AVAudioPlayer?
    /// Segura no device o pacote de narração da história. Atravessa as
    /// trocas de capítulo e é solto junto com o controller, quando o leitor
    /// fecha.
    private var narrationAccess: ContentPackAccess?
    /// Download em andamento. Cancelado pelo `stop()`: trocar de capítulo
    /// ou fechar o leitor no meio do download não deve tocar nada depois.
    private var downloadTask: Task<Void, Never>?
    private var paragraphs: [String] = []
    /// Palavras acumuladas por parágrafo (para estimar timing).
    /// Ex: [0, 45, 120, 200] = parágrafo 0 vai do word 0 ao 45, etc.
    private var paragraphOffsets: [Int] = []
    private var totalWords: Int = 0
    private var tickTimer: Timer?

    private let defaults = UserDefaults.standard
    private let rateKey = "grimoire.narration.rate.v2"

    // Metadados pro player da tela de bloqueio / Central de Controle.
    private var nowPlayingTitle: String = ""
    private var nowPlayingSubtitle: String = ""
    private var nowPlayingArtwork: String?
    private var remoteCommandsSet = false

    override init() {
        super.init()
        if let saved = defaults.object(forKey: rateKey) as? Float {
            rate = saved
        }
    }

    // MARK: Controle

    /// Começa a narrar um capítulo. Carrega o MP3 correspondente — baixando
    /// antes o pacote da história, se ele ainda não estiver no device — e
    /// configura o painel da tela de bloqueio.
    ///
    /// - Parameters:
    ///   - storyID: id da história (ex. "st-001") — pra achar o MP3 no bundle.
    ///   - chapterIndex: número do capítulo (1, 2, 3).
    ///   - paragraphs: parágrafos do capítulo, na ordem — pro highlight na tela.
    ///   - title, subtitle, artwork: pro painel "Now Playing" do sistema.
    func start(storyID: String,
               chapterIndex: Int,
               paragraphs: [String],
               title: String = "",
               subtitle: String = "",
               artwork: String? = nil) {
        stop()

        // Outra história: devolve o pacote da anterior ao sistema.
        if narrationAccess?.pack != .narration(storyID: storyID) {
            narrationAccess = nil
        }

        if let url = Self.audioURL(storyID: storyID, chapterIndex: chapterIndex) {
            play(url: url, paragraphs: paragraphs, title: title, subtitle: subtitle, artwork: artwork)
            return
        }

        // Ainda não está no device: baixa o pacote da história e toca
        // quando chegar.
        isLoading = true
        downloadTask = Task {
            do {
                let access = try await ContentPackAccess.fetch(.narration(storyID: storyID), urgent: true)
                guard !Task.isCancelled else { return }
                narrationAccess = access
                isLoading = false
                guard let url = Self.audioURL(storyID: storyID, chapterIndex: chapterIndex) else {
                    #if DEBUG
                    print("[Narration] MP3 não encontrado: \(storyID)-ch\(chapterIndex).mp3")
                    #endif
                    loadFailed = true
                    return
                }
                play(url: url, paragraphs: paragraphs, title: title, subtitle: subtitle, artwork: artwork)
            } catch {
                guard !Task.isCancelled else { return }
                #if DEBUG
                print("[Narration] download da narração falhou (\(storyID)):", error)
                #endif
                isLoading = false
                loadFailed = true
            }
        }
    }

    /// Carrega e toca um MP3 já acessível.
    private func play(url: URL,
                      paragraphs: [String],
                      title: String,
                      subtitle: String,
                      artwork: String?) {
        self.paragraphs = paragraphs
        computeParagraphOffsets()
        nowPlayingTitle = title
        nowPlayingSubtitle = subtitle
        nowPlayingArtwork = artwork

        configureSession(active: true)
        setupRemoteCommands()

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.enableRate = true
            p.rate = rate
            p.prepareToPlay()
            p.play()
            player = p
            isSpeaking = true
            isPaused = false
            startTickTimer()
            updateNowPlaying()
        } catch {
            // Falha ao abrir o MP3 — libera a sessão e sai quieto.
            configureSession(active: false)
            isSpeaking = false
        }
    }

    func pause() {
        guard let p = player, p.isPlaying else { return }
        p.pause()
        isPaused = true
        stopTickTimer()
        updateNowPlaying()
    }

    func resume() {
        guard isPaused, let p = player else { return }
        p.play()
        isPaused = false
        startTickTimer()
        updateNowPlaying()
    }

    /// Play/pause conveniente pra um único botão. Se estava tocando o mesmo
    /// capítulo, pausa/retoma. Se era outro capítulo (ou nada), começa de novo.
    func toggle(storyID: String,
                chapterIndex: Int,
                paragraphs: [String],
                title: String = "",
                subtitle: String = "",
                artwork: String? = nil) {
        if isLoading {
            return      // já baixando — o play sai sozinho quando chegar
        } else if isSpeaking && !isPaused {
            pause()
        } else if isPaused {
            resume()
        } else {
            start(storyID: storyID,
                  chapterIndex: chapterIndex,
                  paragraphs: paragraphs,
                  title: title,
                  subtitle: subtitle,
                  artwork: artwork)
        }
    }

    func stop() {
        downloadTask?.cancel()
        downloadTask = nil
        isLoading = false
        loadFailed = false
        player?.stop()
        player = nil
        stopTickTimer()
        isSpeaking = false
        isPaused = false
        spokenParagraph = -1
        paragraphs = []
        paragraphOffsets = []
        totalWords = 0
        clearNowPlaying()
        configureSession(active: false)
    }

    // MARK: - Localização do arquivo

    /// URL do MP3 pra dado story + chapter, se estiver acessível agora:
    /// sem tag no bundle, ou num pacote baixado e seguro por um
    /// `ContentPackAccess`. nil não quer dizer que a narração não existe.
    /// Os MP3s ficam flat em Content/audio/ com nomes únicos
    /// no formato `st-XXX-chY.mp3` (ex: `st-001-ch2.mp3`).
    /// Formato flat é obrigatório porque com Xcode 16 File System
    /// Synchronized Groups o resource copy ignora subdiretórios.
    static func audioURL(storyID: String, chapterIndex: Int) -> URL? {
        let name = "\(storyID)-ch\(chapterIndex)"     // ex: "st-001-ch2"
        return Bundle.main.url(forResource: name,
                               withExtension: "mp3",
                               subdirectory: "Content/audio")
            ?? Bundle.main.url(forResource: name, withExtension: "mp3")
    }

    // MARK: - Highlight de parágrafo por tempo

    /// Calcula quantas palavras cada parágrafo tem e onde começa no total.
    /// Usado pra estimar qual parágrafo tá tocando agora baseado no
    /// currentTime do player.
    private func computeParagraphOffsets() {
        var offsets: [Int] = [0]
        var running = 0
        for para in paragraphs {
            let words = para.split(whereSeparator: { $0.isWhitespace }).count
            running += words
            offsets.append(running)
        }
        paragraphOffsets = offsets
        totalWords = running
    }

    /// Retorna o parágrafo atual (0..paragraphs.count-1) baseado no progresso
    /// do áudio. Estimativa proporcional por word count — não é perfeito, mas
    /// segue a narração bem o suficiente pro leitor rolar junto.
    private func currentParagraphIndex() -> Int {
        guard let p = player, p.duration > 0, totalWords > 0 else { return -1 }
        let progress = p.currentTime / p.duration                 // 0.0..1.0
        let wordsSpoken = Int(Double(totalWords) * progress)
        // Acha o maior i tal que offsets[i] <= wordsSpoken
        var idx = 0
        for i in 0..<paragraphs.count {
            if paragraphOffsets[i] <= wordsSpoken {
                idx = i
            } else {
                break
            }
        }
        return idx
    }

    private func startTickTimer() {
        stopTickTimer()
        // Timer a cada 0.4s atualiza o parágrafo atual e o Now Playing.
        // Grosso o suficiente pra não pesar, fino o suficiente pro highlight
        // não parecer que tá atrasado.
        // O `[weak self]` de fora vira uma var capturada; recapturar fraco
        // dentro da Task evita atravessar o limite de concorrência com ela
        // (erro no modo Swift 6).
        let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func stopTickTimer() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func tick() {
        let idx = currentParagraphIndex()
        if idx != spokenParagraph {
            spokenParagraph = idx
        }
        updateNowPlaying()
    }

    // MARK: - Audio session

    private func configureSession(active: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            if active {
                // .playback toca mesmo com o silencioso ligado e com a tela
                // bloqueada — essencial pra ouvir de olhos fechados.
                try session.setCategory(.playback, mode: .spokenAudio)
                try session.setActive(true)
            } else {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
            }
        } catch {
            // Falha de áudio não deve quebrar a leitura; apenas ignora.
        }
    }

    // MARK: - Player do sistema (tela de bloqueio / Central de Controle)

    /// Registra os botões remotos (play/pause) uma única vez. Sem isso, o
    /// player do sistema aparece mas os botões não respondem.
    private func setupRemoteCommands() {
        guard !remoteCommandsSet else { return }
        remoteCommandsSet = true
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if self.isPaused { self.resume(); return .success }
            return .commandFailed
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if self.isSpeaking && !self.isPaused { self.pause(); return .success }
            return .commandFailed
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            if self.isPaused { self.resume() }
            else if self.isSpeaking { self.pause() }
            return .success
        }
        // Skip forward/backward — 15s pra frente/trás, comum em audiobook.
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] _ in
            self?.skip(by: 15); return .success
        }
        center.skipBackwardCommand.addTarget { [weak self] _ in
            self?.skip(by: -15); return .success
        }

        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.skipForwardCommand.isEnabled = true
        center.skipBackwardCommand.isEnabled = true
    }

    /// Pula N segundos (positivo ou negativo) na reprodução atual.
    private func skip(by seconds: TimeInterval) {
        guard let p = player else { return }
        p.currentTime = max(0, min(p.duration - 0.1, p.currentTime + seconds))
        updateNowPlaying()
    }

    /// Preenche o painel "Now Playing" com título, autor, capa, tempo e estado.
    private func updateNowPlaying() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: nowPlayingTitle.isEmpty ? "Grimoire" : nowPlayingTitle,
            MPMediaItemPropertyArtist: nowPlayingSubtitle,
            MPNowPlayingInfoPropertyPlaybackRate: (isSpeaking && !isPaused) ? Double(rate) : 0.0,
        ]
        if let p = player {
            info[MPMediaItemPropertyPlaybackDuration] = p.duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = p.currentTime
        }
        if let name = nowPlayingArtwork, let img = UIImage(named: name) {
            let art = MPMediaItemArtwork(boundsSize: img.size) { _ in img }
            info[MPMediaItemPropertyArtwork] = art
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension NarrationController: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer,
                                                 successfully flag: Bool) {
        Task { @MainActor in
            // Chegou ao fim do MP3 — encerra tudo. O leitor pode reagir via
            // isSpeaking mudando pra false.
            stop()
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer,
                                                    error: Error?) {
        Task { @MainActor in
            stop()
        }
    }
}
