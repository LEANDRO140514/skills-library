---
name: hermes-vps-multiperfil
description: "Desplegar Hermes en VPS con perfiles y skills compartidos."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [vps, perfiles, skills, multi-usuario, slashstack, despliegue]
---

# Hermes VPS Multi-Perfil

Despliega Hermes Agent en un VPS Linux y configúralo para **múltiples usuarios** (perfiles separados), con una **biblioteca de skills compartida** y SlashStack Pro opcional.

## When to Use

Usa este skill cuando:
- Instales Hermes en un VPS nuevo (o lo actualices)
- Quieras crear un segundo perfil (familiar/colega/cliente) en el mismo VPS
- Integres una biblioteca de skills (`skills-library`) para varios perfiles
- Instales SlashStack en un repo

## 1. Instalar Hermes en el VPS

```bash
# Instalación nueva
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash

# O actualizar una instalación existente
hermes update
```

### Pitfall: uv.lock desincronizado
Si el instalador falla con `error: The lockfile at uv.lock needs to be updated, but --locked was provided`, **NO canceles** — el instalador cae automáticamente a PyPI resolve. Solo espera 5-10 min.

### Pitfall: npm install / browser tools falla
No bloquea nada. Hermes funciona sin browser tools. Se pueden instalar después.

### Crear el launcher (si `hermes` no está en PATH)

```bash
ln -s ~/.hermes/hermes-agent/venv/bin/hermes ~/.local/bin/hermes
export PATH="$HOME/.local/bin:$PATH"
```

## 2. Crear perfiles

```bash
hermes profile list                                  # ver perfiles
hermes profile create valentina                      # crear perfil
# Nota: crea wrapper `valentina` en ~/.local/bin
```

Cada perfil vive en `~/.hermes/profiles/<nombre>/` con config, skills, sesiones y memoria propios.

### Configurar API key de un perfil (sin exponerla en chat)

```bash
nano ~/.hermes/profiles/valentina/.env
# PEGAR: OPENROUTER_API_KEY=sk-or-v1-...
```

Configurar modelo y provider:

```bash
valentina config set model.default google/gemini-2.5-flash
valentina config set model.provider openrouter
valentina config migrate          # migrar config v0 → actual (responder N a keys opcionales)
valentina doctor                  # verificar
```

## 3. Compartir skills-library entre perfiles

Clonar la biblioteca y enlazar los skills activos (categorías `mias/` y `comunidad/`, excluyendo `_archivo/`):

```bash
git clone https://github.com/USUARIO/skills-library.git ~/skills-library

# Leo / perfil default (skills globales)
find ~/skills-library -mindepth 3 -maxdepth 3 -type d \( -path '*/mias/*' -o -path '*/comunidad/*' \) | while read d; do
  [ -f "$d/SKILL.md" ] && ln -sfn "$d" ~/.hermes/skills/"$(basename "$d")"
done

# Valentina / perfil custom
find ~/skills-library -mindepth 3 -maxdepth 3 -type d \( -path '*/mias/*' -o -path '*/comunidad/*' \) | while read d; do
  [ -f "$d/SKILL.md" ] && ln -sfn "$d" ~/.hermes/profiles/valentina/skills/"$(basename "$d")"
done
```

Verificar:

```bash
hermes skills list                 # Leo
valentina skills list              # Valentina
```

### Nota: 0 builtin en perfil default
Es normal en instalación fresca — los builtin se sincronizan al primer uso del perfil. No romper nada.

### Sincronizar actualizaciones
- En Windows: editar skills → `git push` en `~/skills-library`
- En VPS: `cd ~/skills-library && git pull` — los symlinks apuntan automáticamente a las versiones nuevas

## 4. SlashStack Pro (opcional)

SlashStack = guardrails + skills para agentes de código. Pro = 19 skills + 6 guards (one-time $39).

```bash
cd ~/proyectos/<repo> && git init
npx slashstack@latest install --target hermes --key SSK-... --email tu@email.com
```

- Instala en `AGENTS.md` + `.agents/skills/` + `.agents/guards/` (no toca código de la app)
- Hermes detecta `AGENTS.md` automáticamente al abrir sesión en ese directorio
- Para que Valentina vea los skills de SlashStack desde el repo, enlazar:
  `ln -s ~/proyectos/<repo>/.agents/skills/* ~/.hermes/profiles/valentina/skills/`

### Prompt de activación (preflight)
Primer prompt al agente en el repo:

> "Use SlashStack's preflight workflow before editing this project. Explain what was installed, inspect the repo, flag risks in simple language, and give me one exact next prompt. Do not edit files yet."

## 5. Verificación final

```bash
hermes --version                   # versión (ideal: igual o mayor que escritorio)
hermes doctor                      # salud del perfil default
valentina doctor                   # salud del perfil hija
```

## Pitfalls

- **No compartir API keys en el chat** — si el usuario pega una key, avisarle de revocarla en openrouter.ai/keys
- **El agente dentro de la sesión interactiva interpreta comandos** — para ejecutar comandos de shell, salir del agente (`exit` / `/quit`) antes
- **Target de SlashStack:** `--target hermes` reporta "agents" en v0.4.0 — es comportamiento conocido, `AGENTS.md` funciona igual con Hermes
- **Sesión del agente sin salir**: los comandos pegados en `valentina ❯` se ejecutan como tareas del agente, no en shell
