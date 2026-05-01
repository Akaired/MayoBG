# MayoBG — App Specification

## Overview

MayoBG è una **menu bar app per macOS** che cambia automaticamente il wallpaper del desktop attingendo a foto ad alta risoluzione da **Unsplash**. L'app non ha una finestra principale: tutta l'interazione avviene tramite il menu che appare cliccando l'icona nella barra di sistema in alto.

---

## Stack tecnico

- **Linguaggio**: Swift
- **UI**: SwiftUI + AppKit (dove necessario per funzionalità di sistema), **Liquid Glass** come design system
- **API**: Unsplash API (REST)
- **Persistenza preferenze**: UserDefaults
- **Target**: macOS 26+

---

## Struttura del menu (menu bar)

```
[Icona MayoBG] ← clic sinistro apre il menu
│
├── Next update: [data/ora prossimo cambio]   ← read-only, informativo
├── About photo >                              ← sottomenu con info foto corrente
│   ├── Titolo foto
│   ├── Nome fotografo
│   └── Link a Unsplash
│
├── ─────────────────────────────
├── Change current wallpaper     ⇧⌘N          ← cambia subito
├── Change all wallpapers        ⌥⌘M          ← cambia su tutti i monitor
├── Load previous wallpaper      ⌥⌘Z          ← torna al precedente
├── First in channel             ⌥⌘R          ← vai alla prima foto del canale
├── Download current wallpaper   ⌥⌘S          ← salva in ~/Pictures
├── Add to collection >                        ← (futuro) aggiunge a collezione Unsplash
│
├── ─────────────────────────────
├── Channel >                                  ← sottomenu selezione canale attivo
├── Manage channels...                         ← pannello gestione canali
├── Update interval >                          ← sottomenu frequenza cambio
│   ├── 30 minuti
│   ├── 1 ora
│   ├── 3 ore
│   ├── 12 ore
│   ├── 24 ore
│   ├── 1 settimana
│   └── 2 settimane
├── Randomize ✓                                ← toggle ordine casuale
│
├── ─────────────────────────────
├── Settings...                                ← pannello impostazioni
├── About...                                   ← versione app, credits
└── Quit                        ⌘Q
```

---

## Funzionalità core (MVP)

### 1. Menu bar icon
- L'app gira **senza finestra principale** (LSUIElement = true nel Info.plist)
- Icona personalizzata nella status bar
- Menu appare al clic sull'icona

### 2. Cambio wallpaper automatico
- Timer configurabile (default: 1 ora)
- Al tick del timer → chiama Unsplash API → scarica foto → imposta come wallpaper via `NSWorkspace`
- Supporto multi-monitor (ogni schermo può avere wallpaper indipendente)

### 3. Unsplash API integration
- Autenticazione con **Client-ID** (API key personale — no OAuth per MVP)
- Endpoint utilizzati:
  - `GET /photos/random` — foto casuale
  - `GET /collections/:id/photos` — foto da collezione specifica
  - `GET /search/photos?query=...` — ricerca per keyword
- Rispetto obbligatorio del ToS Unsplash: **attribuzione fotografo** visibile nel menu "About photo"

### 4. Canali
- Un **canale** è una sorgente di foto (collezione Unsplash, ricerca per keyword, utente specifico)
- L'utente può aggiungere/rimuovere canali dal pannello "Manage channels"
- Un canale alla volta è attivo (selezionato dal sottomenu Channel)

### 5. Persistenza
- Intervallo di aggiornamento → `UserDefaults`
- Canali salvati → `UserDefaults` (array di struct codificabili)
- Ultima foto utilizzata → `UserDefaults`
- Cronologia foto precedenti → array in memoria (max 20 elementi)

### 6. Download wallpaper
- Salva la foto corrente in alta risoluzione in `~/Pictures/MayoBG/`
- Notifica di completamento via `NSUserNotification`

---

## Funzionalità future (post-MVP)

| Feature | Note |
|---|---|
| Login Unsplash OAuth | Per like, collezioni, foto personali |
| Hidelist | Blocca foto/autori indesiderati |
| Filtro luminosità | Solo foto chiare o scure |
| Auto dark/light mode | Cambia tema macOS in base al wallpaper |
| Filtro "no persone" | Esclude foto con soggetti umani |
| AppleScript support | Automazione esterna |

---

## Architettura (alto livello)

```
AppDelegate
└── StatusBarController        ← gestisce NSStatusItem e menu
    ├── WallpaperService        ← logica cambio wallpaper + NSWorkspace
    ├── UnsplashService         ← chiamate API Unsplash + download immagini
    ├── ChannelManager          ← gestione canali, persistenza
    ├── TimerService            ← timer cambio automatico
    └── HistoryManager          ← cronologia foto precedenti
```

---

## File struttura progetto (prevista)

```
MayoBG/
├── App/
│   ├── MayoBGApp.swift         ← entry point, configura LSUIElement
│   └── AppDelegate.swift       ← setup status bar
├── Services/
│   ├── WallpaperService.swift
│   ├── UnsplashService.swift
│   ├── TimerService.swift
│   └── HistoryManager.swift
├── Models/
│   ├── Channel.swift
│   ├── UnsplashPhoto.swift
│   └── AppSettings.swift
├── Views/
│   ├── MenuView.swift          ← UI del menu principale
│   ├── ChannelManagerView.swift
│   └── SettingsView.swift
└── Resources/
    └── Assets.xcassets         ← icona menu bar
```

---

## Note implementative importanti

- **LSUIElement = YES** in Info.plist → l'app non appare nel Dock né nell'App Switcher
- `NSWorkspace.shared.setDesktopImageURL(_:for:options:)` → API per impostare il wallpaper
- Le immagini vanno scaricate in una **directory temporanea** prima di essere impostate come wallpaper
- La API key Unsplash va conservata in **Keychain**, non hardcodata nel codice
