#!/usr/bin/env python3
"""Gera Grimoire/Localizable.xcstrings a partir das traduções aqui embaixo.

Por que um script e não editar o .xcstrings na mão: o catálogo é JSON com
quatro níveis de aninhamento por chave, e mexer nele no editor de texto é
como escrever XML a mão. Aqui a tradução é uma linha por idioma.

A CHAVE É A STRING EM INGLÊS, exatamente como ela aparece no código Swift.
É assim que o `LocalizedStringKey` do SwiftUI e o `String(localized:)`
resolvem, e é o que dá o fallback de graça: chave sem tradução num idioma
cai no inglês sozinha, sem `if` nenhum.

Strings com interpolação usam o especificador que o Xcode gera:
`Text("\\(n) min")` vira a chave `%lld min`.

CONTEÚDO (título, sinopse e corpo de capítulo) NÃO entra aqui — ver
`String.localizedContent` em Core/Stories.swift. Fora do inglês, capítulo
sem tradução humana é traduzido no aparelho (Core/ChapterTranslation.swift).

Uso:
    python3 scripts/build_strings_catalog.py          # regrava o catálogo
    python3 scripts/build_strings_catalog.py --check  # só confere (exit 1)
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
CATALOG = REPO / "Grimoire" / "Localizable.xcstrings"

SOURCE = "en"
LANGS = ["en", "pt-BR", "es", "fr", "de", "it", "ar"]

# chave (inglês) -> { idioma: tradução }
# Inglês é omitido: a chave já é o inglês.
T: dict[str, dict[str, str]] = {}


def add(key: str, pt: str, es: str, fr: str, de: str, it: str, ar: str) -> None:
    T[key] = {"pt-BR": pt, "es": es, "fr": fr, "de": de, "it": it, "ar": ar}


# ═══════════════════════════════════════════════════════════════════════
# Navegação / tabs
# ═══════════════════════════════════════════════════════════════════════
add("Home", "Início", "Inicio", "Accueil", "Start", "Home", "الرئيسية")
add("Favorites", "Favoritos", "Favoritos", "Favoris", "Favoriten", "Preferiti", "المفضلة")
add("Your Path", "Sua Jornada", "Tu Camino", "Votre Chemin", "Dein Weg", "Il Tuo Cammino", "مسارك")

# ═══════════════════════════════════════════════════════════════════════
# Onboarding
# ═══════════════════════════════════════════════════════════════════════
# Os kickers do onboarding são desenhados em caixa-alta por `.textCase`,
# não por chave: "YOUR PATH" e "Your Path" gerariam o MESMO símbolo Swift
# e o build do catálogo falha. Caixa-alta é estilo, não conteúdo — e em
# árabe, que não tem caixa, o uppercase é no-op de graça.
add("Welcome", "Bem-vindo", "Bienvenido", "Bienvenue", "Willkommen", "Benvenuto", "أهلاً")
add("How it works", "Como funciona", "Cómo funciona", "Comment ça marche",
    "So geht's", "Come funziona", "كيف يعمل")

add("Stories that\naren't afraid of the dark",
    "Histórias que\nnão temem o escuro",
    "Historias que\nno temen a la oscuridad",
    "Des histoires qui\nn'ont pas peur du noir",
    "Geschichten, die\nsich nicht vor dem Dunkeln fürchten",
    "Storie che\nnon temono il buio",
    "حكايات لا\nتخشى الظلام")
add("Every story,\nthree chapters",
    "Cada história,\ntrês capítulos",
    "Cada historia,\ntres capítulos",
    "Chaque histoire,\ntrois chapitres",
    "Jede Geschichte,\ndrei Kapitel",
    "Ogni storia,\ntre capitoli",
    "كل حكاية،\nثلاثة فصول")
add("From Apprentice\nto Archmage",
    "De Aprendiz\na Arquimago",
    "De Aprendiz\na Archimago",
    "D'Apprenti\nà Archimage",
    "Vom Lehrling\nzum Erzmagier",
    "Da Apprendista\nad Arcimago",
    "من متدرّب\nإلى كبير السحرة")

add("Rich, shadowy tales for anyone tired of silly stories. Courage, mystery, and worlds with rules of their own.",
    "Contos densos e sombrios para quem cansou de historinhas bobas. Coragem, mistério e mundos com regras próprias.",
    "Relatos densos y sombríos para quien se cansó de los cuentos bobos. Coraje, misterio y mundos con reglas propias.",
    "Des récits denses et sombres pour qui en a assez des histoires niaises. Courage, mystère et mondes aux règles bien à eux.",
    "Dichte, düstere Erzählungen für alle, die alberne Geschichten satthaben. Mut, Geheimnis und Welten mit eigenen Regeln.",
    "Racconti densi e cupi per chi è stanco delle storielle sciocche. Coraggio, mistero e mondi con regole proprie.",
    "حكايات كثيفة ومظلمة لمن ملّ القصص السخيفة. شجاعة وغموض وعوالم لها قوانينها الخاصة.")
add("You step in, learn how the world works, and discover how courage beats what force cannot. A ten-minute read that stays with you.",
    "Você entra, aprende como o mundo funciona e descobre como a coragem vence o que a força não vence. Dez minutos de leitura que ficam com você.",
    "Entras, aprendes cómo funciona el mundo y descubres cómo el coraje vence lo que la fuerza no puede. Diez minutos de lectura que se quedan contigo.",
    "Vous entrez, vous apprenez comment le monde fonctionne, et vous découvrez comment le courage vient à bout de ce que la force ne peut pas. Dix minutes de lecture qui vous restent.",
    "Du trittst ein, lernst, wie diese Welt funktioniert, und entdeckst, wie Mut schafft, woran Gewalt scheitert. Zehn Minuten Lesen, die bleiben.",
    "Entri, impari come funziona il mondo e scopri come il coraggio vince ciò che la forza non può. Dieci minuti di lettura che restano con te.",
    "تدخل، وتتعلّم كيف يسير هذا العالم، وتكتشف كيف تغلب الشجاعة ما تعجز عنه القوة. عشر دقائق من القراءة تبقى معك.")
add("Every story you read moves your journey forward. Save your favorites, pick up where you left off, and unlock the whole grimoire.",
    "Cada história lida avança sua jornada. Salve as favoritas, continue de onde parou e libere o grimório inteiro.",
    "Cada historia leída avanza tu camino. Guarda tus favoritas, sigue donde lo dejaste y desbloquea el grimorio entero.",
    "Chaque histoire lue fait avancer votre chemin. Gardez vos favorites, reprenez où vous en étiez, et débloquez le grimoire entier.",
    "Jede gelesene Geschichte bringt dich weiter. Sichere deine Favoriten, lies dort weiter, wo du aufgehört hast, und schalte das ganze Grimoire frei.",
    "Ogni storia letta fa avanzare il tuo cammino. Salva le preferite, riprendi da dove eri rimasto e sblocca l'intero grimorio.",
    "كل حكاية تقرؤها تمضي بمسارك قُدُماً. احفظ المفضّلة لديك، وتابع من حيث توقّفت، وافتح الكتاب كاملاً.")

add("Skip", "Pular", "Saltar", "Passer", "Überspringen", "Salta", "تخطٍّ")
add("Continue", "Continuar", "Continuar", "Continuer", "Weiter", "Continua", "متابعة")
add("Open the grimoire", "Abrir o grimório", "Abrir el grimorio",
    "Ouvrir le grimoire", "Das Grimoire öffnen", "Apri il grimorio", "افتح الكتاب")

# ═══════════════════════════════════════════════════════════════════════
# Home
# ═══════════════════════════════════════════════════════════════════════
add("Welcome back", "Bem-vindo de volta", "Bienvenido de vuelta",
    "Content de vous revoir", "Willkommen zurück", "Bentornato", "أهلاً بعودتك")
add("%lld free stories this week",
    "%lld histórias grátis esta semana", "%lld historias gratis esta semana",
    "%lld histoires gratuites cette semaine", "%lld kostenlose Geschichten diese Woche",
    "%lld storie gratis questa settimana", "%lld حكايات مجانية هذا الأسبوع")
add("Pro", "Pro", "Pro", "Pro", "Pro", "Pro", "برو")
add("FREE THIS WEEK", "GRÁTIS ESTA SEMANA", "GRATIS ESTA SEMANA",
    "GRATUIT CETTE SEMAINE", "DIESE WOCHE GRATIS", "GRATIS QUESTA SETTIMANA",
    "مجاناً هذا الأسبوع")
add("rotates weekly", "muda toda semana", "cambia cada semana",
    "change chaque semaine", "wechselt wöchentlich", "cambia ogni settimana",
    "تتغيّر أسبوعياً")
add("FREE", "GRÁTIS", "GRATIS", "GRATUIT", "GRATIS", "GRATIS", "مجاناً")
add("CONTINUE READING", "CONTINUAR LENDO", "SEGUIR LEYENDO",
    "REPRENDRE LA LECTURE", "WEITERLESEN", "CONTINUA A LEGGERE", "تابع القراءة")
add("Chapter %lld of 3", "Capítulo %lld de 3", "Capítulo %lld de 3",
    "Chapitre %lld sur 3", "Kapitel %lld von 3", "Capitolo %lld di 3",
    "الفصل %lld من ٣")
add("FEATURED", "EM DESTAQUE", "DESTACADO", "À LA UNE", "EMPFOHLEN",
    "IN PRIMO PIANO", "مختارة")
add("%lld min", "%lld min", "%lld min", "%lld min", "%lld Min.", "%lld min",
    "%lld د")

# ═══════════════════════════════════════════════════════════════════════
# Níveis das histórias
# ═══════════════════════════════════════════════════════════════════════
add("Apprentice", "Aprendiz", "Aprendiz", "Apprenti", "Lehrling", "Apprendista", "متدرّب")
add("Initiate", "Iniciado", "Iniciado", "Initié", "Eingeweihter", "Iniziato", "مُبتدئ")
add("Conjurer", "Conjurador", "Conjurador", "Conjureur", "Beschwörer", "Evocatore", "مُستحضِر")
add("Archmage", "Arquimago", "Archimago", "Archimage", "Erzmagier", "Arcimago", "كبير السحرة")
add("Grandmaster", "Grão-Mestre", "Gran Maestro", "Grand Maître",
    "Großmeister", "Gran Maestro", "الأستاذ الأكبر")

# ═══════════════════════════════════════════════════════════════════════
# Detalhe + leitor
# ═══════════════════════════════════════════════════════════════════════
add("CHAPTERS", "CAPÍTULOS", "CAPÍTULOS", "CHAPITRES", "KAPITEL", "CAPITOLI", "الفصول")
add("%lld words", "%lld palavras", "%lld palabras", "%lld mots",
    "%lld Wörter", "%lld parole", "%lld كلمة")
add("Start reading", "Começar a ler", "Empezar a leer", "Commencer la lecture",
    "Lesen beginnen", "Inizia a leggere", "ابدأ القراءة")
add("Continue · Chapter %lld", "Continuar · Capítulo %lld", "Seguir · Capítulo %lld",
    "Reprendre · Chapitre %lld", "Weiter · Kapitel %lld", "Continua · Capitolo %lld",
    "تابع · الفصل %lld")
add("Unlock with Pro", "Liberar com o Pro", "Desbloquear con Pro",
    "Débloquer avec Pro", "Mit Pro freischalten", "Sblocca con Pro", "افتحها مع برو")
add("Couldn't open this story.", "Não foi possível abrir esta história.",
    "No se pudo abrir esta historia.", "Impossible d'ouvrir cette histoire.",
    "Diese Geschichte ließ sich nicht öffnen.", "Non è stato possibile aprire questa storia.",
    "تعذّر فتح هذه الحكاية.")
add("CHAPTER %lld", "CAPÍTULO %lld", "CAPÍTULO %lld", "CHAPITRE %lld",
    "KAPITEL %lld", "CAPITOLO %lld", "الفصل %lld")
add("Previous", "Anterior", "Anterior", "Précédent", "Zurück", "Precedente", "السابق")
add("Next", "Próximo", "Siguiente", "Suivant", "Weiter", "Successivo", "التالي")
add("The End", "Fim", "Fin", "Fin", "Ende", "Fine", "النهاية")
add("Chapter %lld · %@", "Capítulo %lld · %@", "Capítulo %lld · %@",
    "Chapitre %lld · %@", "Kapitel %lld · %@", "Capitolo %lld · %@", "الفصل %lld · %@")

# ═══════════════════════════════════════════════════════════════════════
# Narração
# ═══════════════════════════════════════════════════════════════════════
add("Play narration", "Tocar narração", "Reproducir narración",
    "Lire la narration", "Erzählung abspielen", "Riproduci la narrazione",
    "تشغيل السرد")
add("Pause narration", "Pausar narração", "Pausar narración",
    "Mettre la narration en pause", "Erzählung pausieren", "Metti in pausa la narrazione",
    "إيقاف السرد مؤقتاً")
add("Downloading narration", "Baixando narração", "Descargando narración",
    "Téléchargement de la narration", "Erzählung wird geladen",
    "Download della narrazione", "جارٍ تنزيل السرد")
add("Couldn't download narration. Try again",
    "Não foi possível baixar a narração. Tente de novo",
    "No se pudo descargar la narración. Inténtalo de nuevo",
    "Impossible de télécharger la narration. Réessayez",
    "Erzählung konnte nicht geladen werden. Erneut versuchen",
    "Non è stato possibile scaricare la narrazione. Riprova",
    "تعذّر تنزيل السرد. حاول مجدداً")
# Narração só existe em inglês — ver ContentLanguage.narrated.
add("Narration is only available in English",
    "A narração só existe em inglês", "La narración solo existe en inglés",
    "La narration n'existe qu'en anglais", "Die Erzählung gibt es nur auf Englisch",
    "La narrazione esiste solo in inglese", "السرد متوفّر بالإنجليزية فقط")

# ═══════════════════════════════════════════════════════════════════════
# Tradução automática
# ═══════════════════════════════════════════════════════════════════════
add("Translated automatically", "Traduzido automaticamente", "Traducido automáticamente",
    "Traduit automatiquement", "Automatisch übersetzt", "Tradotto automaticamente",
    "تُرجم آلياً")
add("Translating this chapter…", "Traduzindo este capítulo…", "Traduciendo este capítulo…",
    "Traduction de ce chapitre…", "Kapitel wird übersetzt …",
    "Traduzione del capitolo…", "جارٍ ترجمة هذا الفصل…")
add("First time only — it's saved for next time.",
    "Só na primeira vez — fica salvo pra próxima.",
    "Solo la primera vez — queda guardado para la próxima.",
    "Uniquement la première fois — c'est enregistré pour la suite.",
    "Nur beim ersten Mal – es wird für später gespeichert.",
    "Solo la prima volta — resta salvato per la prossima.",
    "المرة الأولى فقط — سيُحفظ للمرات القادمة.")

# ═══════════════════════════════════════════════════════════════════════
# Favoritos
# ═══════════════════════════════════════════════════════════════════════
add("Nothing saved yet", "Nada salvo ainda", "Nada guardado aún",
    "Rien d'enregistré", "Noch nichts gespeichert", "Ancora niente di salvato",
    "لم تحفظ شيئاً بعد")
add("Tap the bookmark on a story to save it here and read whenever you like.",
    "Toque no marcador de uma história pra guardar aqui e ler quando quiser.",
    "Toca el marcador de una historia para guardarla aquí y leerla cuando quieras.",
    "Touchez le marque-page d'une histoire pour la garder ici et la lire quand vous voulez.",
    "Tippe auf das Lesezeichen einer Geschichte, um sie hier zu sichern und jederzeit zu lesen.",
    "Tocca il segnalibro di una storia per salvarla qui e leggerla quando vuoi.",
    "المس إشارة الحكاية لتحفظها هنا وتقرأها متى شئت.")
add("Explore stories", "Explorar histórias", "Explorar historias",
    "Explorer les histoires", "Geschichten entdecken", "Esplora le storie",
    "تصفّح الحكايات")

# ═══════════════════════════════════════════════════════════════════════
# Erros / estados vazios
# ═══════════════════════════════════════════════════════════════════════
add("Something went wrong", "Algo deu errado", "Algo salió mal",
    "Une erreur est survenue", "Etwas ist schiefgelaufen", "Qualcosa è andato storto",
    "حدث خطأ ما")
add("We couldn't load the stories. Please try again.",
    "Não foi possível carregar as histórias. Tente de novo.",
    "No se pudieron cargar las historias. Inténtalo de nuevo.",
    "Impossible de charger les histoires. Réessayez.",
    "Die Geschichten ließen sich nicht laden. Bitte erneut versuchen.",
    "Non è stato possibile caricare le storie. Riprova.",
    "تعذّر تحميل الحكايات. حاول مجدداً.")
add("Try again", "Tentar de novo", "Reintentar", "Réessayer",
    "Erneut versuchen", "Riprova", "حاول مجدداً")

# ═══════════════════════════════════════════════════════════════════════
# Perfil — rank e estatísticas
# ═══════════════════════════════════════════════════════════════════════
add("Your journey begins.", "Sua jornada começa.", "Tu camino empieza.",
    "Votre chemin commence.", "Dein Weg beginnt.", "Il tuo cammino inizia.",
    "مسارك يبدأ.")
add("The dark starts to open.", "O escuro começa a se abrir.",
    "La oscuridad empieza a abrirse.", "Le noir commence à s'ouvrir.",
    "Das Dunkel beginnt sich zu öffnen.", "Il buio comincia ad aprirsi.",
    "الظلام يبدأ بالانفتاح.")
add("You walk deeper now.", "Você caminha mais fundo agora.",
    "Ahora caminas más hondo.", "Vous avancez plus loin désormais.",
    "Du gehst jetzt tiefer.", "Ora cammini più a fondo.", "تمضي أعمق الآن.")
add("Few reach this far.", "Poucos chegam tão longe.", "Pocos llegan tan lejos.",
    "Peu vont aussi loin.", "Nur wenige kommen so weit.", "In pochi arrivano fin qui.",
    "قليلون يبلغون هذا المدى.")
add("The whole grimoire, read.", "O grimório inteiro, lido.",
    "El grimorio entero, leído.", "Le grimoire entier, lu.",
    "Das ganze Grimoire, gelesen.", "L'intero grimorio, letto.",
    "الكتاب كاملاً، مقروءاً.")
add("%lld more to become %@", "Faltam %lld pra virar %@", "Faltan %lld para ser %@",
    "Encore %lld pour devenir %@", "Noch %lld bis zum %@",
    "Ancora %lld per diventare %@", "بقي %lld لتصبح %@")
add("Unlock all 50 to keep climbing", "Libere as 50 pra continuar subindo",
    "Desbloquea las 50 para seguir subiendo",
    "Débloquez les 50 pour continuer à monter",
    "Schalte alle 50 frei, um weiter aufzusteigen",
    "Sblocca tutte e 50 per continuare a salire",
    "افتح الخمسين كلها لتواصل الصعود")
add("You've read the whole grimoire.", "Você leu o grimório inteiro.",
    "Has leído el grimorio entero.", "Vous avez lu le grimoire entier.",
    "Du hast das ganze Grimoire gelesen.", "Hai letto l'intero grimorio.",
    "قرأت الكتاب كاملاً.")
add("day streak", "dia seguido", "día seguido", "jour d'affilée",
    "Tag in Folge", "giorno di fila", "يوم متتالٍ")
add("days streak", "dias seguidos", "días seguidos", "jours d'affilée",
    "Tage in Folge", "giorni di fila", "أيام متتالية")
add("finished", "terminadas", "terminadas", "terminées", "gelesen", "finite", "مكتملة")
add("saved", "salvas", "guardadas", "gardées", "gesichert", "salvate", "محفوظة")

# ═══════════════════════════════════════════════════════════════════════
# Perfil — conquistas
# ═══════════════════════════════════════════════════════════════════════
add("ACHIEVEMENTS", "CONQUISTAS", "LOGROS", "SUCCÈS", "ERFOLGE", "OBIETTIVI", "الإنجازات")
add("First Light", "Primeira Luz", "Primera Luz", "Première Lueur",
    "Erstes Licht", "Prima Luce", "أول ضوء")
add("Finish your first story.", "Termine sua primeira história.",
    "Termina tu primera historia.", "Terminez votre première histoire.",
    "Lies deine erste Geschichte zu Ende.", "Finisci la tua prima storia.",
    "أنهِ أول حكاية لك.")
add("Well Read", "Bem Lido", "Bien Leído", "Grand Lecteur",
    "Belesen", "Ben Letto", "واسع الاطّلاع")
add("Finish five stories.", "Termine cinco histórias.", "Termina cinco historias.",
    "Terminez cinq histoires.", "Lies fünf Geschichten zu Ende.",
    "Finisci cinque storie.", "أنهِ خمس حكايات.")
add("Deep Reader", "Leitor Profundo", "Lector Profundo", "Lecteur Assidu",
    "Tiefer Leser", "Lettore Profondo", "قارئ عميق")
add("Finish ten stories.", "Termine dez histórias.", "Termina diez historias.",
    "Terminez dix histoires.", "Lies zehn Geschichten zu Ende.",
    "Finisci dieci storie.", "أنهِ عشر حكايات.")
add("Keeper of the Grimoire", "Guardião do Grimório", "Guardián del Grimorio",
    "Gardien du Grimoire", "Hüter des Grimoires", "Custode del Grimorio",
    "حارس الكتاب")
add("Finish all fifty stories.", "Termine as cinquenta histórias.",
    "Termina las cincuenta historias.", "Terminez les cinquante histoires.",
    "Lies alle fünfzig Geschichten zu Ende.", "Finisci tutte e cinquanta le storie.",
    "أنهِ الحكايات الخمسين كلها.")
add("Three Nights", "Três Noites", "Tres Noches", "Trois Nuits",
    "Drei Nächte", "Tre Notti", "ثلاث ليالٍ")
add("Read three days in a row.", "Leia três dias seguidos.",
    "Lee tres días seguidos.", "Lisez trois jours d'affilée.",
    "Lies an drei Tagen in Folge.", "Leggi per tre giorni di fila.",
    "اقرأ ثلاثة أيام متتالية.")
add("A Week by Lamplight", "Uma Semana à Luz da Lamparina",
    "Una Semana a la Luz del Candil", "Une Semaine à la Lampe",
    "Eine Woche im Lampenschein", "Una Settimana a Lume di Lampada",
    "أسبوع على ضوء المصباح")
add("Read seven days in a row.", "Leia sete dias seguidos.",
    "Lee siete días seguidos.", "Lisez sept jours d'affilée.",
    "Lies an sieben Tagen in Folge.", "Leggi per sette giorni di fila.",
    "اقرأ سبعة أيام متتالية.")
add("After Midnight", "Depois da Meia-Noite", "Después de Medianoche",
    "Après Minuit", "Nach Mitternacht", "Dopo Mezzanotte", "بعد منتصف الليل")
add("Read a story past midnight.", "Leia uma história depois da meia-noite.",
    "Lee una historia pasada la medianoche.", "Lisez une histoire après minuit.",
    "Lies eine Geschichte nach Mitternacht.", "Leggi una storia dopo mezzanotte.",
    "اقرأ حكاية بعد منتصف الليل.")
add("Collector", "Colecionador", "Coleccionista", "Collectionneur",
    "Sammler", "Collezionista", "جامع")
add("Save ten favorites.", "Salve dez favoritas.", "Guarda diez favoritas.",
    "Gardez dix favorites.", "Sichere zehn Favoriten.", "Salva dieci preferite.",
    "احفظ عشر حكايات مفضّلة.")
add("Apprentice's Path", "Caminho do Aprendiz", "Camino del Aprendiz",
    "Chemin de l'Apprenti", "Weg des Lehrlings", "Cammino dell'Apprendista",
    "طريق المتدرّب")
add("Finish every Apprentice story.", "Termine todas as histórias de Aprendiz.",
    "Termina todas las historias de Aprendiz.", "Terminez toutes les histoires Apprenti.",
    "Lies alle Lehrlings-Geschichten zu Ende.", "Finisci tutte le storie da Apprendista.",
    "أنهِ كل حكايات المتدرّب.")
add("Courage", "Coragem", "Coraje", "Courage", "Mut", "Coraggio", "شجاعة")
add("Finish five stories tagged courage.",
    "Termine cinco histórias marcadas com coragem.",
    "Termina cinco historias etiquetadas coraje.",
    "Terminez cinq histoires marquées courage.",
    "Lies fünf Geschichten mit dem Tag Mut zu Ende.",
    "Finisci cinque storie con il tag coraggio.",
    "أنهِ خمس حكايات موسومة بالشجاعة.")

# ═══════════════════════════════════════════════════════════════════════
# Perfil — lembretes
# ═══════════════════════════════════════════════════════════════════════
add("REMINDERS", "LEMBRETES", "RECORDATORIOS", "RAPPELS", "ERINNERUNGEN",
    "PROMEMORIA", "التذكيرات")
add("Reading reminders", "Lembretes de leitura", "Recordatorios de lectura",
    "Rappels de lecture", "Lese-Erinnerungen", "Promemoria di lettura",
    "تذكيرات القراءة")
add("Blocked by system. Tap below to enable.",
    "Bloqueado pelo sistema. Toque abaixo pra ativar.",
    "Bloqueado por el sistema. Toca abajo para activar.",
    "Bloqué par le système. Touchez ci-dessous pour activer.",
    "Vom System blockiert. Unten tippen, um zu aktivieren.",
    "Bloccato dal sistema. Tocca qui sotto per attivare.",
    "محظور من النظام. المس أدناه للتفعيل.")
add("Choose when to be reminded.", "Escolha quando ser lembrado.",
    "Elige cuándo quieres el recordatorio.", "Choisissez quand être rappelé.",
    "Wähle, wann du erinnert wirst.", "Scegli quando ricevere il promemoria.",
    "اختر وقت التذكير.")
add("You'll be nudged to keep the ritual.",
    "Você vai receber um toque pra manter o ritual.",
    "Te daremos un empujoncito para mantener el ritual.",
    "Un petit rappel pour tenir le rituel.",
    "Ein sanfter Stups, damit das Ritual bleibt.",
    "Riceverai una spinta gentile per tenere vivo il rito.",
    "سنذكّرك برفق لتحافظ على الطقس.")
add("Off — no reminders will be sent.", "Desligado — nenhum lembrete será enviado.",
    "Apagado — no se enviará ningún recordatorio.",
    "Désactivé — aucun rappel ne sera envoyé.",
    "Aus – es werden keine Erinnerungen gesendet.",
    "Spento — non verrà inviato alcun promemoria.",
    "مُعطَّل — لن تُرسل أي تذكيرات.")
add("Enable in Settings", "Ativar nos Ajustes", "Activar en Ajustes",
    "Activer dans Réglages", "In den Einstellungen aktivieren",
    "Attiva in Impostazioni", "فعّلها في الإعدادات")
add("Daily reminder", "Lembrete diário", "Recordatorio diario",
    "Rappel quotidien", "Tägliche Erinnerung", "Promemoria quotidiano",
    "تذكير يومي")
add("New week alert", "Aviso de semana nova", "Aviso de semana nueva",
    "Alerte nouvelle semaine", "Hinweis zur neuen Woche",
    "Avviso di nuova settimana", "تنبيه الأسبوع الجديد")
add("Monday morning, when 3 stories refresh.",
    "Segunda de manhã, quando 3 histórias mudam.",
    "Lunes por la mañana, cuando cambian 3 historias.",
    "Lundi matin, quand 3 histoires changent.",
    "Montagmorgen, wenn 3 Geschichten wechseln.",
    "Lunedì mattina, quando cambiano 3 storie.",
    "صباح الاثنين، حين تتغيّر ٣ حكايات.")
add("Streak protection", "Proteção da sequência", "Protección de la racha",
    "Protection de la série", "Serien-Schutz", "Protezione della serie",
    "حماية التتابع")
add("A gentle nudge at 9pm if your streak is at risk.",
    "Um toque leve às 21h se sua sequência estiver em risco.",
    "Un aviso suave a las 21:00 si tu racha está en riesgo.",
    "Un rappel discret à 21 h si votre série est menacée.",
    "Ein sanfter Stups um 21 Uhr, wenn deine Serie in Gefahr ist.",
    "Una spinta gentile alle 21 se la tua serie è a rischio.",
    "تنبيه لطيف عند التاسعة مساءً إذا كان تتابعك مهدَّداً.")

# ═══════════════════════════════════════════════════════════════════════
# Perfil — idioma
# ═══════════════════════════════════════════════════════════════════════
add("LANGUAGE", "IDIOMA", "IDIOMA", "LANGUE", "SPRACHE", "LINGUA", "اللغة")
add("App language", "Idioma do app", "Idioma de la app",
    "Langue de l'app", "App-Sprache", "Lingua dell'app", "لغة التطبيق")
add("Follow system", "Seguir o sistema", "Seguir el sistema",
    "Suivre le système", "System folgen", "Segui il sistema", "اتبع النظام")
add("Reopen Grimoire to finish switching.",
    "Reabra o Grimoire pra concluir a troca.",
    "Vuelve a abrir Grimoire para completar el cambio.",
    "Rouvrez Grimoire pour terminer le changement.",
    "Öffne Grimoire neu, um den Wechsel abzuschließen.",
    "Riapri Grimoire per completare il cambio.",
    "أعد فتح Grimoire لإتمام التبديل.")
add("Stories are translated on your device the first time you open a chapter.",
    "As histórias são traduzidas no seu aparelho na primeira vez que você abre um capítulo.",
    "Las historias se traducen en tu dispositivo la primera vez que abres un capítulo.",
    "Les histoires sont traduites sur votre appareil à la première ouverture d'un chapitre.",
    "Geschichten werden beim ersten Öffnen eines Kapitels auf deinem Gerät übersetzt.",
    "Le storie vengono tradotte sul tuo dispositivo alla prima apertura di un capitolo.",
    "تُترجم الحكايات على جهازك عند أول فتح لأي فصل.")

# ═══════════════════════════════════════════════════════════════════════
# Paywall
# ═══════════════════════════════════════════════════════════════════════
add("Grimoire Pro", "Grimoire Pro", "Grimoire Pro", "Grimoire Pro",
    "Grimoire Pro", "Grimoire Pro", "Grimoire Pro")
add("Unlock the whole grimoire", "Libere o grimório inteiro",
    "Desbloquea el grimorio entero", "Débloquez le grimoire entier",
    "Schalte das ganze Grimoire frei", "Sblocca l'intero grimorio",
    "افتح الكتاب كاملاً")
add("All 50 stories", "As 50 histórias", "Las 50 historias",
    "Les 50 histoires", "Alle 50 Geschichten", "Tutte e 50 le storie",
    "الحكايات الخمسون")
add("The whole grimoire, always unlocked", "O grimório inteiro, sempre liberado",
    "El grimorio entero, siempre desbloqueado",
    "Le grimoire entier, toujours débloqué",
    "Das ganze Grimoire, dauerhaft frei",
    "L'intero grimorio, sempre sbloccato",
    "الكتاب كاملاً، مفتوحاً دوماً")
add("Made for the night", "Feito para a noite", "Hecho para la noche",
    "Fait pour la nuit", "Für die Nacht gemacht", "Fatto per la notte",
    "صُنع لليل")
add("Rich ten-minute tales, perfect before bed",
    "Contos densos de dez minutos, perfeitos antes de dormir",
    "Relatos densos de diez minutos, perfectos antes de dormir",
    "Des récits denses de dix minutes, parfaits avant de dormir",
    "Dichte Zehn-Minuten-Erzählungen, perfekt vor dem Schlafen",
    "Racconti densi da dieci minuti, perfetti prima di dormire",
    "حكايات كثيفة من عشر دقائق، مثالية قبل النوم")
add("Favorites and progress", "Favoritos e progresso", "Favoritos y progreso",
    "Favoris et progression", "Favoriten und Fortschritt",
    "Preferiti e progressi", "المفضلة والتقدّم")
add("Save what you love and pick up where you left off",
    "Guarde o que você ama e continue de onde parou",
    "Guarda lo que te gusta y sigue donde lo dejaste",
    "Gardez ce que vous aimez et reprenez où vous en étiez",
    "Sichere, was du liebst, und lies dort weiter, wo du aufgehört hast",
    "Salva ciò che ami e riprendi da dove eri rimasto",
    "احفظ ما تحب وتابع من حيث توقّفت")
add("No ads", "Sem anúncios", "Sin anuncios", "Sans publicité",
    "Keine Werbung", "Nessuna pubblicità", "بلا إعلانات")
add("Nothing interrupts the reading", "Nada interrompe a leitura",
    "Nada interrumpe la lectura", "Rien n'interrompt la lecture",
    "Nichts unterbricht das Lesen", "Niente interrompe la lettura",
    "لا شيء يقطع القراءة")
add("Loading plans…", "Carregando planos…", "Cargando planes…",
    "Chargement des formules…", "Tarife werden geladen …",
    "Caricamento dei piani…", "جارٍ تحميل الخطط…")
add("Plans unavailable", "Planos indisponíveis", "Planes no disponibles",
    "Formules indisponibles", "Tarife nicht verfügbar", "Piani non disponibili",
    "الخطط غير متوفرة")
add("Check your connection and try again.",
    "Verifique sua conexão e tente de novo.",
    "Revisa tu conexión e inténtalo de nuevo.",
    "Vérifiez votre connexion et réessayez.",
    "Prüfe deine Verbindung und versuche es erneut.",
    "Controlla la connessione e riprova.",
    "تحقّق من اتصالك وحاول مجدداً.")
add("Annual", "Anual", "Anual", "Annuel", "Jährlich", "Annuale", "سنوي")
add("Monthly", "Mensal", "Mensual", "Mensuel", "Monatlich", "Mensile", "شهري")
add("%@/mo · billed once a year", "%@/mês · cobrado uma vez por ano",
    "%@/mes · se cobra una vez al año", "%@/mois · facturé une fois par an",
    "%@/Mon. · einmal jährlich abgerechnet", "%@/mese · addebitato una volta l'anno",
    "%@/شهرياً · يُحصَّل مرة في السنة")
add("billed monthly", "cobrado mensalmente", "se cobra cada mes",
    "facturé mensuellement", "monatlich abgerechnet", "addebitato ogni mese",
    "يُحصَّل شهرياً")
add("Start free trial", "Começar teste grátis", "Empezar prueba gratis",
    "Démarrer l'essai gratuit", "Gratis testen", "Inizia la prova gratuita",
    "ابدأ التجربة المجانية")
add("Subscribe now", "Assinar agora", "Suscribirse ahora", "S'abonner",
    "Jetzt abonnieren", "Abbonati ora", "اشترك الآن")
add("Processing…", "Processando…", "Procesando…", "Traitement…",
    "Wird verarbeitet …", "Elaborazione…", "جارٍ المعالجة…")
add("Restore purchases", "Restaurar compras", "Restaurar compras",
    "Restaurer les achats", "Käufe wiederherstellen", "Ripristina gli acquisti",
    "استعادة المشتريات")
add("Plans aren't ready yet. Please try again in a moment.",
    "Os planos ainda não carregaram. Tente de novo daqui a pouco.",
    "Los planes aún no están listos. Inténtalo en un momento.",
    "Les formules ne sont pas encore prêtes. Réessayez dans un instant.",
    "Die Tarife sind noch nicht bereit. Bitte gleich erneut versuchen.",
    "I piani non sono ancora pronti. Riprova tra un momento.",
    "الخطط ليست جاهزة بعد. حاول بعد لحظات.")
add("%lld day free", "%lld dia grátis", "%lld día gratis", "%lld jour gratuit",
    "%lld Tag gratis", "%lld giorno gratis", "يوم واحد مجاناً")
add("%lld days free", "%lld dias grátis", "%lld días gratis", "%lld jours gratuits",
    "%lld Tage gratis", "%lld giorni gratis", "%lld أيام مجاناً")
add("%lld month free", "%lld mês grátis", "%lld mes gratis", "%lld mois gratuit",
    "%lld Monat gratis", "%lld mese gratis", "شهر واحد مجاناً")
add("%lld months free", "%lld meses grátis", "%lld meses gratis", "%lld mois gratuits",
    "%lld Monate gratis", "%lld mesi gratis", "%lld أشهر مجاناً")
add("1 year free", "1 ano grátis", "1 año gratis", "1 an gratuit",
    "1 Jahr gratis", "1 anno gratis", "سنة مجاناً")
add("Free trial", "Teste grátis", "Prueba gratis", "Essai gratuit",
    "Gratis testen", "Prova gratuita", "تجربة مجانية")
add("The subscription renews automatically until canceled. Cancel anytime in Settings. By continuing, you accept the [Terms of Use](%1$@) and [Privacy Policy](%2$@).",
    "A assinatura renova automaticamente até ser cancelada. Cancele quando quiser nos Ajustes. Ao continuar, você aceita os [Termos de Uso](%1$@) e a [Política de Privacidade](%2$@).",
    "La suscripción se renueva automáticamente hasta que la canceles. Cancela cuando quieras en Ajustes. Al continuar, aceptas los [Términos de Uso](%1$@) y la [Política de Privacidad](%2$@).",
    "L'abonnement se renouvelle automatiquement jusqu'à résiliation. Résiliez quand vous voulez dans Réglages. En continuant, vous acceptez les [Conditions d'utilisation](%1$@) et la [Politique de confidentialité](%2$@).",
    "Das Abo verlängert sich automatisch bis zur Kündigung. Jederzeit in den Einstellungen kündbar. Mit dem Fortfahren akzeptierst du die [Nutzungsbedingungen](%1$@) und die [Datenschutzrichtlinie](%2$@).",
    "L'abbonamento si rinnova automaticamente fino alla disdetta. Disdici quando vuoi in Impostazioni. Continuando, accetti i [Termini d'uso](%1$@) e l'[Informativa sulla privacy](%2$@).",
    "يتجدّد الاشتراك تلقائياً حتى إلغائه. ألغِه متى شئت من الإعدادات. بالمتابعة، أنت توافق على [شروط الاستخدام](%1$@) و[سياسة الخصوصية](%2$@).")

# ═══════════════════════════════════════════════════════════════════════
# StoreKit — erros
# ═══════════════════════════════════════════════════════════════════════
add("Couldn't load the plans. Try again.", "Não foi possível carregar os planos. Tente de novo.",
    "No se pudieron cargar los planes. Inténtalo de nuevo.",
    "Impossible de charger les formules. Réessayez.",
    "Die Tarife ließen sich nicht laden. Erneut versuchen.",
    "Non è stato possibile caricare i piani. Riprova.",
    "تعذّر تحميل الخطط. حاول مجدداً.")
add("The purchase didn't go through.", "A compra não foi concluída.",
    "La compra no se completó.", "L'achat n'a pas abouti.",
    "Der Kauf ist nicht durchgegangen.", "L'acquisto non è andato a buon fine.",
    "لم تتم عملية الشراء.")
add("Couldn't restore. Try again.", "Não foi possível restaurar. Tente de novo.",
    "No se pudo restaurar. Inténtalo de nuevo.",
    "Impossible de restaurer. Réessayez.",
    "Wiederherstellung fehlgeschlagen. Erneut versuchen.",
    "Non è stato possibile ripristinare. Riprova.",
    "تعذّرت الاستعادة. حاول مجدداً.")

# ═══════════════════════════════════════════════════════════════════════
# Notificações locais
# ═══════════════════════════════════════════════════════════════════════
add("A story before sleep?", "Uma história antes de dormir?",
    "¿Una historia antes de dormir?", "Une histoire avant de dormir ?",
    "Eine Geschichte vor dem Schlafen?", "Una storia prima di dormire?",
    "حكاية قبل النوم؟")
add("Five quiet minutes with the grimoire.", "Cinco minutos quietos com o grimório.",
    "Cinco minutos tranquilos con el grimorio.",
    "Cinq minutes calmes avec le grimoire.",
    "Fünf stille Minuten mit dem Grimoire.",
    "Cinque minuti tranquilli con il grimorio.",
    "خمس دقائق هادئة مع الكتاب.")
add("Three new stories are free", "Três histórias novas estão grátis",
    "Tres historias nuevas están gratis", "Trois nouvelles histoires sont gratuites",
    "Drei neue Geschichten sind gratis", "Tre nuove storie sono gratis",
    "ثلاث حكايات جديدة مجاناً")
add("This week's selection has changed.", "A seleção desta semana mudou.",
    "La selección de esta semana cambió.", "La sélection de la semaine a changé.",
    "Die Auswahl dieser Woche hat gewechselt.", "La selezione di questa settimana è cambiata.",
    "تغيّرت مجموعة هذا الأسبوع.")
add("Your streak is at risk", "Sua sequência está em risco",
    "Tu racha está en riesgo", "Votre série est menacée",
    "Deine Serie ist in Gefahr", "La tua serie è a rischio",
    "تتابعك في خطر")
add("You're on a %lld-day streak. A chapter keeps it alive.",
    "Você está há %lld dias seguidos. Um capítulo mantém isso vivo.",
    "Llevas %lld días seguidos. Un capítulo lo mantiene vivo.",
    "Vous en êtes à %lld jours d'affilée. Un chapitre suffit à la garder.",
    "Du bist bei %lld Tagen in Folge. Ein Kapitel hält sie am Leben.",
    "Sei a %lld giorni di fila. Un capitolo la tiene viva.",
    "أنت في تتابع %lld يوماً. فصل واحد يبقيه حياً.")


# ═══════════════════════════════════════════════════════════════════════
# Emissão
# ═══════════════════════════════════════════════════════════════════════

def build() -> dict:
    strings: dict[str, dict] = {}
    for key in sorted(T):
        locs = {SOURCE: {"stringUnit": {"state": "translated", "value": key}}}
        for lang, value in T[key].items():
            locs[lang] = {"stringUnit": {"state": "translated", "value": value}}
        strings[key] = {"extractionState": "manual", "localizations": locs}
    return {"sourceLanguage": SOURCE, "strings": strings, "version": "1.0"}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="só confere, não grava")
    args = parser.parse_args()

    # Toda chave precisa dos 6 idiomas — uma faltando é fallback silencioso
    # pro inglês, que é exatamente o bug que a gente não vê em review.
    missing = {
        key: sorted(set(LANGS) - {SOURCE} - set(vals))
        for key, vals in T.items()
        if set(LANGS) - {SOURCE} - set(vals)
    }
    if missing:
        for key, langs in missing.items():
            print(f"  falta {','.join(langs)}: {key[:60]}", file=sys.stderr)
        sys.exit(f"{len(missing)} chave(s) incompleta(s)")

    payload = json.dumps(build(), ensure_ascii=False, indent=2,
                         sort_keys=True) + "\n"
    summary = f"{len(T)} chaves × {len(LANGS)} idiomas"

    current = CATALOG.read_text() if CATALOG.exists() else ""
    if payload == current:
        print(f"catálogo em dia ({summary})")
        return
    if args.check:
        sys.exit(f"catálogo desatualizado — rode scripts/build_strings_catalog.py ({summary})")

    CATALOG.parent.mkdir(parents=True, exist_ok=True)
    CATALOG.write_text(payload)
    print(f"catálogo gravado ({summary})")


if __name__ == "__main__":
    main()
