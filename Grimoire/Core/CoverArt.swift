//
//  CoverArt.swift
//  Grimoire — capa da história (imagem + vídeo animado em foco)
//
//  Modo padrão: mostra a Image do asset (thumbnail estático, zero flicker).
//  Modo focused (`isFocused: true`): também carrega o teaser em vídeo em
//  loop e faz crossfade sobre a imagem quando o 1º frame estiver pronto.
//  Se o vídeo não existe no bundle, fica só a imagem — sem erro, sem log.
//
//  Fallback: se nem imagem nem vídeo existirem (ex: história sem arte
//  final), gera uma capa procedural no estilo Mignola (silhueta angular
//  + lua com eclipse), determinística pelo id.
//
//  Vídeos ficam em Content/videos/ (flat, nome único cover-XXX.mp4)
//  — mesma restrição do audio: File System Synchronized Groups fazem
//  resource copy sem preservar subdiretórios.
//

import SwiftUI
import UIKit

struct CoverArt: View {
    let story: StorySummary
    var height: CGFloat = 170
    /// Quando true, tenta carregar e tocar o teaser em vídeo por cima da
    /// imagem. Passe true nos cards em destaque (hero, featured, detail).
    /// Nos thumbnails deixe false (default) — cada player custa memória.
    var isFocused: Bool = false

    @State private var videoReady: Bool = false

    private var seed: Int { abs(story.id.hashValue) }
    private var accent: Color { story.cover.accentColor }

    /// true se existe uma imagem real no bundle com o nome do asset.
    private var hasArtwork: Bool {
        UIImage(named: story.cover.asset) != nil
    }

    /// URL do teaser em vídeo, se existir no bundle. Os arquivos ficam
    /// em Content/videos/ com nomes tipo cover-farol.mp4. O nome é
    /// derivado do asset: CoverFarol → cover-farol (kebab-case).
    private var videoURL: URL? {
        Self.videoURL(forAsset: story.cover.asset)
    }

    static func videoURL(forAsset asset: String) -> URL? {
        // "CoverFarol" -> "cover-farol"
        //   1. remove prefixo "Cover"
        //   2. CamelCase → kebab-case
        let bare = asset.hasPrefix("Cover") ? String(asset.dropFirst("Cover".count)) : asset
        var parts: [String] = []
        var current = ""
        for ch in bare {
            if ch.isUppercase && !current.isEmpty {
                parts.append(current)
                current = String(ch)
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty { parts.append(current) }
        let kebab = "cover-" + parts.map { $0.lowercased() }.joined(separator: "-")
        return Bundle.main.url(forResource: kebab, withExtension: "mp4",
                               subdirectory: "Content/videos")
            ?? Bundle.main.url(forResource: kebab, withExtension: "mp4")
    }

    var body: some View {
        ZStack {
            // Camada de baixo: imagem (ou capa procedural). Aparece
            // instantâneo, sem espera de carregamento.
            Group {
                if hasArtwork {
                    Image(story.cover.asset)
                        .resizable()
                        .scaledToFill()
                } else {
                    proceduralArt
                }
            }

            // Camada de cima: vídeo em loop, só se estamos "focused" e
            // temos o arquivo no bundle. Aparece com fade quando o 1º
            // frame carrega — evita jump feio de imagem pra vídeo.
            if isFocused, let url = videoURL {
                LoopingVideoView(url: url, onReady: {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        videoReady = true
                    }
                })
                .frame(maxWidth: .infinity, maxHeight: height)  // clamp — evita gap fantasma na List
                .opacity(videoReady ? 1 : 0)
                .allowsHitTesting(false)  // deixa o tap ir pro Button de trás
            }
        }
        .frame(height: height)
        .clipped()
    }

    // MARK: - Capa procedural (fallback pra histórias sem arte final)

    private var proceduralArt: some View {
        ZStack {
            LinearGradient(
                colors: [accent.opacity(0.35), DS.Palette.ink900],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            DS.Palette.ink900.opacity(0.2)

            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height

                Circle()
                    .fill(accent)
                    .frame(width: h * 0.5, height: h * 0.5)
                    .position(
                        x: w * (seed % 2 == 0 ? 0.72 : 0.28),
                        y: h * 0.34
                    )
                    .blur(radius: 0.5)
                    .overlay(
                        Circle()
                            .fill(DS.Palette.ink900)
                            .frame(width: h * 0.5, height: h * 0.5)
                            .offset(x: h * 0.12, y: -h * 0.06)
                            .position(
                                x: w * (seed % 2 == 0 ? 0.72 : 0.28),
                                y: h * 0.34
                            )
                    )

                MignolaSilhouette(seed: seed)
                    .fill(DS.Palette.black)
                    .frame(width: w, height: h * 0.55)
                    .position(x: w * 0.5, y: h * 0.78)

                LinearGradient(
                    colors: [.clear, DS.Palette.black.opacity(0.9)],
                    startPoint: .center, endPoint: .bottom
                )
            }
        }
    }
}

/// Silhueta angular estilo Mignola — picos duros, determinística por seed.
private struct MignolaSilhouette: Shape {
    let seed: Int

    func path(in rect: CGRect) -> Path {
        var p = Path()
        var rng = CoverRNG(seed: UInt64(seed))
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))

        let steps = 6
        let stepW = rect.width / CGFloat(steps)
        for i in 0...steps {
            let x = rect.minX + stepW * CGFloat(i)
            let jitter = CGFloat(rng.nextDouble()) * rect.height * 0.5
            let y = rect.midY - jitter + rect.height * 0.1
            p.addLine(to: CGPoint(x: x, y: y))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Gerador pseudo-aleatório determinístico (mesmo seed → mesma capa).
private struct CoverRNG {
    var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B9 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }
    mutating func nextDouble() -> Double {
        Double(next() % 1000) / 1000.0
    }
}
