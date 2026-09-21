//
//  ContentPacks.swift
//  Grimoire — On-Demand Resources (narração e vídeos das capas)
//
//  Narração e vídeos das capas não vêm no download da App Store. Ficam
//  hospedados pela Apple em pacotes que o app pede na hora em que precisa:
//
//      narration-<st-XXX>     os MP3 dos capítulos   ~4 MB cada   198 MB no total
//      video-<cover-nome>     o teaser da capa       ~7,6 MB cada 380 MB no total
//
//  Narração é um pacote por história, não por capítulo: quem ouve o
//  capítulo 1 e toca Next não espera outro download pra ouvir o 2.
//
//  Capas (imagens), JSONs e índice continuam no bundle — a Home e as
//  grades precisam deles na hora, sem rede.
//
//  As tags moram no project.pbxproj (`assetTagsByRelativePath`), gravadas
//  por `scripts/tag_ondemand_resources.py` a partir de Content/audio e
//  Content/videos. Rode de novo quando entrar arquivo novo. Esquecer não
//  quebra nada: o arquivo sem tag vai pro bundle principal, os lookups
//  acham ele lá — só volta a pesar no download.
//
//  DEPRECAÇÃO: o SDK do iOS 27 marca NSBundleResourceRequest como deprecado
//  em favor do Background Assets. Com o target em iOS 26.5, o substituto
//  hospedado pela Apple (AssetPackManager) já está disponível. Tudo que
//  toca na API está neste arquivo, pra migração ficar aqui dentro.
//

import Foundation

/// Um pacote de conteúdo sob demanda.
enum ContentPack: Hashable {
    /// Os MP3 de uma história. `storyID` no formato "st-001".
    case narration(storyID: String)
    /// O teaser de uma capa. `name` é o nome do arquivo sem extensão, ex.
    /// "cover-farol" — ver `CoverArt.videoName(forAsset:)`.
    case coverVideo(name: String)

    /// A tag no project.pbxproj. Precisa bater com o script que as grava.
    var tag: String {
        switch self {
        case .narration(let id):    return "narration-\(id)"
        case .coverVideo(let name): return "video-\(name)"
        }
    }
}

/// Segura um pacote no device enquanto este objeto viver.
///
/// O sistema pode apagar um pacote baixado sempre que o disco apertar e
/// nenhum pedido o estiver segurando. Por isso quem usa o arquivo guarda
/// este objeto pelo tempo em que usa: a narração enquanto o leitor está
/// aberto, a capa enquanto está montada. Soltar a referência não apaga
/// nada — o pacote fica no disco até faltar espaço, e o próximo pedido
/// sai sem download.
final class ContentPackAccess {

    let pack: ContentPack

    /// Guardado só pela vida útil: é a existência dele que protege o pacote.
    /// Desalocar encerra o acesso, não precisa de `endAccessingResources()`.
    private let request: NSBundleResourceRequest

    private init(pack: ContentPack, request: NSBundleResourceRequest) {
        self.pack = pack
        self.request = request
    }

    /// Garante o pacote no device, baixando se precisar. Depois que retorna,
    /// os arquivos do pacote aparecem no `Bundle.main` como qualquer outro.
    ///
    /// - Parameter urgent: alguém está parado esperando (tocou em play).
    ///   Passa à frente dos outros downloads do sistema.
    /// - Parameter onProgress: fração baixada, de 0 a 1, para quem quiser
    ///   desenhar. Chamado em thread arbitrária — quem usa salta pro ator
    ///   que precisar. Não é chamado quando o pacote já está no device, que
    ///   é o caminho que retorna sem tocar na rede.
    /// - Throws: erro de rede, de espaço ou de tag inexistente. Cancelar a
    ///   Task interrompe o download de verdade e também cai aqui.
    static func fetch(_ pack: ContentPack,
                      urgent: Bool = false,
                      onProgress: (@Sendable (Double) -> Void)? = nil) async throws -> ContentPackAccess {
        let request = NSBundleResourceRequest(tags: [pack.tag])
        if urgent {
            request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        }

        // Já no device: libera na hora, sem tocar na rede.
        if await request.conditionallyBeginAccessingResources() {
            return ContentPackAccess(pack: pack, request: request)
        }

        // A partir daqui há download de verdade, e ele pode levar minutos num
        // 3G ruim. O `Progress` do request já existe e é KVO-compliant; o que
        // faltava era alguém escutar.
        let progress = request.progress
        let token = onProgress.map { publicar in
            progress.observe(\.fractionCompleted, options: [.initial, .new]) { progresso, _ in
                publicar(progresso.fractionCompleted)
            }
        }
        // `invalidate` no defer: a observação não pode sobreviver ao download,
        // senão segura o `Progress` e continua publicando depois que a tela
        // já seguiu adiante.
        defer { token?.invalidate() }

        try await withTaskCancellationHandler {
            try await request.beginAccessingResources()
        } onCancel: {
            progress.cancel()
        }
        return ContentPackAccess(pack: pack, request: request)
    }
}
