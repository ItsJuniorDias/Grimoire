# Grimoire — Telas (Onboarding, Paywall, Home, Favoritos)

SwiftUI puro (sem dependências externas). Roda direto — só abrir e dar Run.

## O que entrou

```
Core/
  Stories.swift          modelos Codable + loader do bundle
  AppState.swift         estado global: favoritos, progresso, onboarding
  SubscriptionStore.swift  StoreKit 2 (mensal + anual)
  SharedUI.swift         WaxSeal (assinatura visual), tags, favorito, progresso
  CoverArt.swift         capa procedural estilo Mignola (placeholder)
Features/
  RootView.swift         tab bar custom + orquestra onboarding/paywall
  Onboarding/OnboardingView.swift
  Paywall/PaywallView.swift
  Home/HomeView.swift
  Favorites/FavoritesView.swift
  Reader/StoryDetailView.swift   detalhe + leitor de capítulos
Content/
  index.json + stories/st-001..003.json   (as 3 histórias)
Grimoire.storekit        config de teste da assinatura
```

## Fluxo

Primeira execução → **Onboarding** (3 páginas) → ao terminar, abre o
**Paywall** uma vez (se não for Pro) → **Home**. Tab bar custom alterna
Home / Favoritos. Cards abrem **Detalhe** → **Leitor**. Conteúdo premium
bloqueado chama o Paywall.

## Setup obrigatório (2 minutos)

### 1. StoreKit — testar assinatura no simulador
- Edit Scheme (⌘<) → Run → Options → **StoreKit Configuration** →
  selecione `Grimoire.storekit`.
- Sem isso o paywall carrega vazio (não acha os produtos).
- Product IDs: `grimoire.pro.monthly` e `grimoire.pro.annual`. Ambos com
  1 semana de teste grátis configurada. Replique no App Store Connect
  (mesmo subscription group) quando for pra produção.

### 2. Histórias no bundle
- A pasta `Content/` é sincronizada automaticamente (synchronized group).
- O loader tem fallback: acha os `.json` tanto em subpasta quanto achatados
  no bundle, então funciona sem configuração extra.
- Se um dia migrar pra grupos manuais, garanta que os `.json` estão em
  "Copy Bundle Resources".

## Decisões de UX/UI

- **Assinatura visual:** o selo de cera (`WaxSeal`) é o elemento memorável —
  aparece no onboarding, paywall e header. A ousadia mora só nele; o resto
  fica quieto e disciplinado (princípio "gaste a boldness num lugar só").
- **Motion orquestrado, não espalhado:** entradas escalonadas no onboarding,
  halo de acento que reage à página, pop no favoritar, tab ativa que desliza.
  Tudo respeita Reduce Motion.
- **Copy do lado do usuário:** "Continuar · Capítulo 2", "Nada guardado ainda"
  com convite à ação — estados vazios são direção, não enfeite.
- **Capa procedural:** enquanto não há arte final, `CoverArt` gera capas
  determinísticas no estilo Mignola (massa preta, lua de acento, silhueta).
  Troque por `Image(cover.asset)` quando tiver a arte.

## Próximos passos naturais

- Aba Perfil (nível/progresso/conquistas).
- Busca e filtro por tag.
- Player de áudio (o app original tinha narração).
- Arte de capa real substituindo o CoverArt procedural.
