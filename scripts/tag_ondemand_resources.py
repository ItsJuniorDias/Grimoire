#!/usr/bin/env python3
"""Grava as tags de On-Demand Resources da narração e dos vídeos no pbxproj.

O alvo usa grupo sincronizado (PBXFileSystemSynchronizedRootGroup), então não
existe PBXBuildFile por arquivo onde pendurar ASSET_TAGS. As tags vão no
exception set do grupo, em `assetTagsByRelativePath`, e a lista de tags
conhecidas em `KnownAssetTags` nos atributos do projeto — as mesmas chaves que
o Xcode escreve quando se preenche "On Demand Resource Tags" no File Inspector.

    Content/audio/st-XXX-chN.mp3   ->  narration-st-XXX
    Content/videos/cover-nome.mp4  ->  video-cover-nome

Precisa bater com `ContentPack.tag` em Grimoire/Core/ContentPacks.swift, e o
nome do vídeo com `CoverArt.videoName(forAsset:)`.

Uso:
    python3 scripts/tag_ondemand_resources.py          # regrava o pbxproj
    python3 scripts/tag_ondemand_resources.py --check  # só confere (exit 1 se desatualizado)

Rode com o projeto fechado no Xcode, ou o Xcode pode sobrescrever a mudança
com a versão que tem em memória.
"""

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PBXPROJ = ROOT / "Grimoire.xcodeproj" / "project.pbxproj"
SOURCES = ROOT / "Grimoire"

CHAPTER_MP3 = re.compile(r"^(?P<story>st-\d+)-ch\d+\.mp3$")


def collect_tags() -> dict[str, str]:
    """Caminho relativo à pasta sincronizada -> tag."""
    tags: dict[str, str] = {}

    for mp3 in sorted((SOURCES / "Content" / "audio").glob("*.mp3")):
        match = CHAPTER_MP3.match(mp3.name)
        if not match:
            sys.exit(f"nome fora do padrão st-XXX-chN.mp3: {mp3.name}")
        tags[mp3.relative_to(SOURCES).as_posix()] = f"narration-{match['story']}"

    for mp4 in sorted((SOURCES / "Content" / "videos").glob("*.mp4")):
        tags[mp4.relative_to(SOURCES).as_posix()] = f"video-{mp4.stem}"

    return tags


def render_tags_by_path(tags: dict[str, str]) -> str:
    lines = ["\t\t\tassetTagsByRelativePath = {"]
    for path, tag in tags.items():
        lines += [
            f'\t\t\t\t"{path}" = (',
            f'\t\t\t\t\t"{tag}",',
            "\t\t\t\t);",
        ]
    lines.append("\t\t\t};")
    return "\n".join(lines) + "\n"


def render_known_tags(tags: dict[str, str]) -> str:
    lines = ["\t\t\t\tKnownAssetTags = ("]
    lines += [f'\t\t\t\t\t"{tag}",' for tag in sorted(set(tags.values()))]
    lines.append("\t\t\t\t);")
    return "\n".join(lines) + "\n"


def update(text: str, tags: dict[str, str]) -> str:
    # ── Exception set do grupo sincronizado ──────────────────────────────
    # Troca só o bloco de tags; as outras chaves do exception set (membership,
    # flags de compilação, atributos) ficam intactas.
    by_path = re.compile(r"\t\t\tassetTagsByRelativePath = \{\n.*?\n\t\t\t\};\n", re.S)
    if by_path.search(text):
        text = by_path.sub(lambda _: render_tags_by_path(tags), text, count=1)
    else:
        isa = "isa = PBXFileSystemSynchronizedBuildFileExceptionSet;\n"
        if text.count(isa) != 1:
            sys.exit("esperava exatamente um exception set de grupo sincronizado no pbxproj")
        text = text.replace(isa, isa + render_tags_by_path(tags), 1)

    # ── Tags conhecidas do projeto ───────────────────────────────────────
    known = re.compile(r"\t\t\t\tKnownAssetTags = \(\n.*?\t\t\t\t\);\n", re.S)
    if known.search(text):
        text = known.sub(lambda _: render_known_tags(tags), text, count=1)
    else:
        attrs = "isa = PBXProject;\n\t\t\tattributes = {\n"
        if attrs not in text:
            sys.exit("atributos do PBXProject não encontrados no pbxproj")
        text = text.replace(attrs, attrs + render_known_tags(tags), 1)

    return text


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="só confere, não grava")
    args = parser.parse_args()

    tags = collect_tags()
    current = PBXPROJ.read_text()
    updated = update(current, tags)

    narration = sum(t.startswith("narration-") for t in tags.values())
    videos = len(tags) - narration
    summary = f"{narration} mp3 + {videos} mp4 em {len(set(tags.values()))} tags"

    if updated == current:
        print(f"pbxproj em dia ({summary})")
        return
    if args.check:
        sys.exit(f"pbxproj desatualizado — rode scripts/tag_ondemand_resources.py ({summary})")

    PBXPROJ.write_text(updated)
    print(f"pbxproj atualizado ({summary})")


if __name__ == "__main__":
    main()
