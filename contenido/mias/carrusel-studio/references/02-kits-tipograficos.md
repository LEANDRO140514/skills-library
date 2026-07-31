# KB_02 - KITS TIPOGRAFICOS

## Decision tree rapido

| Arquetipo   | Kit recomendado       | Alternativa            |
|-------------|-----------------------|------------------------|
| Sabia       | KIT_04 SERIF CLASSIC  | KIT_01 EDITORIAL       |
| Amante      | KIT_01 EDITORIAL      | KIT_04 SERIF CLASSIC   |
| Maga        | KIT_01 EDITORIAL      | KIT_08 Y2K             |
| Heroina     | KIT_03 BRUTALIST      | KIT_02 MODERN CLEAN    |
| Forajida    | KIT_03 BRUTALIST      | KIT_08 Y2K             |
| Exploradora | KIT_03 BRUTALIST      | KIT_02 MODERN CLEAN    |
| Gobernante  | KIT_06 CORPORATE TECH | KIT_04 SERIF CLASSIC   |
| Inocente    | KIT_07 WARMTH         | KIT_02 MODERN CLEAN    |
| Cuidadora   | KIT_07 WARMTH         | KIT_05 PLAYFUL         |
| Complice    | KIT_05 PLAYFUL        | KIT_07 WARMTH          |
| Bromista    | KIT_05 PLAYFUL        | KIT_08 Y2K             |
| Creadora    | KIT_05 PLAYFUL        | KIT_01 EDITORIAL       |

## Los 8 kits

KIT_01 EDITORIAL
Mood: Elegante, refinado, magazine-style. Para: premium, fashion, lifestyle, branding studios.
Fuentes: Anton (display 400) | Instrument Serif (serif italic 400i) | Inter (body 400/500/600/700) | JetBrains Mono (mono 500/600)
Paleta: --black:#0A0A0A --cream:#F2EBDD --accent:#E94822 --neon:#E8FF00
CSS: --f-display:'Anton',sans-serif; --f-serif:'Instrument Serif',serif; --f-body:'Inter',sans-serif; --f-mono:'JetBrains Mono',monospace

KIT_02 MODERN CLEAN
Mood: Limpio, neutral, profesional sin ser corporativo. Para: SaaS, agencies, profesionales.
Fuentes: Space Grotesk (display 500/600/700) | Inter (body 400/500/600/700) | IBM Plex Mono (mono 400/500)
Paleta: --black:#111111 --cream:#F5F5F0 --accent:#5B5BFF --neon:#C5FF45
CSS: --f-display:'Space Grotesk',sans-serif; --f-body:'Inter',sans-serif; --f-mono:'IBM Plex Mono',monospace

KIT_03 BRUTALIST
Mood: Industrial, anti-establishment, raw. Para: marcas alternativas, musica, underground.
Fuentes: Archivo (display 800/900) | Archivo (body 400/500/600) | Space Mono (mono 400/700)
Paleta: --black:#000000 --cream:#EFEFEF --accent:#FF3B00 --neon:#00FF00
CSS: --f-display:'Archivo',sans-serif; --f-body:'Archivo',sans-serif; --f-mono:'Space Mono',monospace

KIT_04 SERIF CLASSIC
Mood: Sofisticado-clasico, libro de tapa dura. Para: educativas, editoriales, consultoria intelectual.
Fuentes: Playfair Display (display 400/700/900) | EB Garamond (body 400/500/600/700) | Courier Prime (mono 400/700)
Paleta: --black:#1A1411 --cream:#F5EFE3 --accent:#8B1A1A --neon:#D4A82B
CSS: --f-display:'Playfair Display',serif; --f-body:'EB Garamond',serif; --f-mono:'Courier Prime',monospace

KIT_05 PLAYFUL
Mood: Amigable, accesible, con personalidad. Para: creadores, food, marcas DTC fun.
Fuentes: Syne (display 500/600/700/800) | Manrope (body 400/500/600/700) | DM Mono (mono 400/500)
Paleta: --black:#1F1A2E --cream:#FFF4E0 --accent:#FF6B9D --neon:#FFE45E
CSS: --f-display:'Syne',sans-serif; --f-body:'Manrope',sans-serif; --f-mono:'DM Mono',monospace

KIT_06 CORPORATE TECH
Mood: Confiable, solido, tecnicamente competente. Para: fintech, B2B SaaS, consultoras tech.
Fuentes: Red Hat Display (display 500/600/700/900) | Red Hat Display (body 400/500) | Red Hat Mono (mono 400/500)
Paleta: --black:#0F1419 --cream:#F1F5F9 --accent:#0066FF --neon:#00D4FF
CSS: --f-display:'Red Hat Display',sans-serif; --f-body:'Red Hat Display',sans-serif; --f-mono:'Red Hat Mono',monospace

KIT_07 WARMTH
Mood: Acogedor, terroso, calmante. Para: wellness, terapia, marcas conscientes.
Fuentes: Fraunces (display 400/600/700/900) | Karla (body 400/500/600/700) | DM Mono (mono 400/500)
Paleta: --black:#2A1F18 --cream:#F5EAD7 --accent:#C77D2C --neon:#9CB071
CSS: --f-display:'Fraunces',serif; --f-body:'Karla',sans-serif; --f-mono:'DM Mono',monospace

KIT_08 Y2K NEO-RETRO
Mood: Retro-futurista, glitchy, gen-z. Para: marcas creativas, music, fashion juvenil.
Fuentes: Major Mono Display (display 400) | Work Sans (body 400/500/600/700) | Space Mono (mono 400/700)
Paleta: --black:#0D0D1A --cream:#F0E8FF --accent:#FF00AA --neon:#00FFAA
CSS: --f-display:'Major Mono Display',monospace; --f-body:'Work Sans',sans-serif; --f-mono:'Space Mono',monospace

## Reglas

- NUNCA mezcles fuentes entre kits sin razon clara.
- Si el usuario tiene colores propios: reemplaza --accent con su color principal.
- Siempre muestra la paleta con los hex antes de aplicar y pide confirmacion.
