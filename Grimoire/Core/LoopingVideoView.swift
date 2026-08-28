//
//  LoopingVideoView.swift
//  Grimoire — reprodução de vídeo em loop, silencioso, sem controles
//
//  Uso interno pra animar as capas (CoverArt). Não usa o VideoPlayer da
//  SwiftUI porque ele traz controles de UI que atrapalham; aqui a gente
//  quer só o frame animado, tipo um "GIF de qualidade".
//
//  Loop infinito via seek pra 0 no AVPlayerItemDidPlayToEndTime.
//  Muted por default (os teasers foram gerados sem áudio; mesmo assim
//  garantimos que não vai brigar com o AVAudioSession do Narration).
//  Pausa automaticamente quando some da tela (ciclo do UIView).
//

import SwiftUI
import AVFoundation

/// Wrap SwiftUI de um AVPlayerLayer com loop infinito.
/// Reporta via `onReady` quando o primeiro frame está pronto pra desenhar,
/// pra o CoverArt fazer fade in do vídeo sobre a imagem.
struct LoopingVideoView: UIViewRepresentable {
    let url: URL
    /// Chamado no main thread quando o vídeo carregou o primeiro frame.
    /// Use pra revelar o vídeo com animação.
    var onReady: (() -> Void)? = nil

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        view.configure(url: url, onReady: onReady)
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        // Se a URL trocar (raro pra capa fixa), recarrega
        if uiView.currentURL != url {
            uiView.configure(url: url, onReady: onReady)
        }
    }

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: ()) {
        uiView.teardown()
    }
}

/// UIView que hospeda o AVPlayerLayer e mantém o player vivo.
final class PlayerContainerView: UIView {
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var playerLayer: AVPlayerLayer?
    private var statusObserver: NSKeyValueObservation?
    private var loopObserver: NSObjectProtocol?
    private(set) var currentURL: URL?

    override class var layerClass: AnyClass { CALayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
    }
    required init?(coder: NSCoder) { fatalError("no storyboard") }

    // Sem esses dois, o SwiftUI dentro de List pode reservar espaço maior
    // do que o `.frame(height:)` do CoverArt, criando um gap fantasma
    // abaixo do card (visualmente cortado por `.clipped()`, mas ainda
    // contando na altura da célula).
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        // Aceita qualquer tamanho proposto pelo container.
        size
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }

    // Pausa quando some da hierarquia, retoma quando volta.
    // Isso evita o player rodando fora da tela drenando bateria.
    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil {
            player?.pause()
        } else {
            player?.play()
        }
    }

    func configure(url: URL, onReady: (() -> Void)?) {
        teardown()
        currentURL = url

        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.isMuted = true
        // .none evita que o player influencie a AVAudioSession
        // (que fica reservada pra narração dos MP3s do NarrationController).
        p.actionAtItemEnd = .none

        let layer = AVPlayerLayer(player: p)
        layer.videoGravity = .resizeAspectFill    // equivale a scaledToFill
        layer.frame = bounds
        self.layer.addSublayer(layer)

        // Observar status → dispara onReady quando 1º frame pronto
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .readyToPlay else { return }
            DispatchQueue.main.async {
                self?.player?.play()
                onReady?()
            }
        }

        // Loop: quando termina, volta pro início e continua
        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak p] _ in
            p?.seek(to: .zero)
            p?.play()
        }

        self.player = p
        self.playerItem = item
        self.playerLayer = layer
    }

    func teardown() {
        statusObserver?.invalidate()
        statusObserver = nil
        if let obs = loopObserver {
            NotificationCenter.default.removeObserver(obs)
            loopObserver = nil
        }
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        player = nil
        playerItem = nil
        playerLayer = nil
        currentURL = nil
    }

    deinit {
        // deinit não é @MainActor, então só limpa o que é seguro fora do main
        statusObserver?.invalidate()
        if let obs = loopObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }
}
