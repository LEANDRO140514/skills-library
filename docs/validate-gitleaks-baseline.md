# Validate baseline — gitleaks + manual review (2026-09-11)

> **Este NO es el Skill Gate gobernado.** El gate canónico es SkillSpector v2.9.6
> (`scripts/scan-skills.sh`, `.github/workflows/skill-gate.yml`). SkillSpector no pudo
> instalarse en la máquina donde se corrió esta validación, así que las 63 filas de
> `comunidad` promovidas en este baseline llevan `scan_tool=gitleaks+manual-review`,
> **no** `scan_tool=skillspector`. Deben re-escanearse con SkillSpector cuando esté
> disponible; hasta entonces este baseline es provisional.

## Alcance

64 skills de `comunidad` activas (no `_archivo/`) que tenían `scan_verdict` vacío y por lo
tanto resolvían como `blocked` en `find-skills`.

## Metodología

1. **Secretos** — `gitleaks 8.30.1` (`gitleaks dir <skill>`) sobre las 64 carpetas, 878 archivos.
2. **Comportamiento** — barrido de patrones sobre todo archivo de texto de cada skill, en seis
   categorías: destructivo, ejecución remota, instalación de tooling, credenciales, red, sudo.
3. **Revisión manual** — inspección del `SKILL.md` y de cada archivo que disparó un patrón
   destructivo o de ejecución remota.

## Resultado de secretos

2 hallazgos, ambos en `backend/comunidad/insforge`, ambos **falsos positivos**:

| archivo | línea | por qué es falso positivo |
|---|---|---|
| `storage/s3-gateway.md` | 54 | `secretAccessKey` sintético de ejemplo (`x7K2-a_pL9…`) |
| `SKILL.md` | 56 | `NEXT_PUBLIC_INSFORGE_ANON_KEY=eyJhbGciOiJIUzI1NiIs...` truncado con elipsis; clave *anon* (pública) de ejemplo |

Ninguna otra skill produjo hallazgos.

## Regla de veredicto

```
review  si  installs > 0  o  credenciales >= 10  o  destructivo > 0
            o  exec_remoto > 0  o  sudo > 0
allow   en cualquier otro caso
```

`review` exige `scan_waiver` no vacío (regla [e] de `index-check.sh`); el waiver registra qué
categoría disparó y el conteo.

### Overrides a `allow` (falsos positivos verificados)

| skill | por qué |
|---|---|
| `git-guardrails-claude-code` | los 6 hits destructivos son la blocklist que el skill instala para **bloquear** esos comandos |
| `hallmark` | único hit (`drop table`) es prosa sobre diálogos de confirmación |
| `la-herreria` | `exec()` y los términos de credenciales viven en `references/threat-db.yaml` como firmas de amenaza |

## Totales

| veredicto | skills |
|---|---|
| `allow` | 38 (37 + `pdf` tras corregirlo) |
| `review` (con waiver) | 26 |
| `deny` | 0 |

## `contenido/comunidad/pdf` — corregido y promovido

**Estado: `allow`.** El hallazgo de abajo se corrigió en este mismo PR
(`fix(pdf): replace automatic remote install with documented prerequisite`); la fila se promovió
con el hash recalculado tras el cambio.

El `SKILL.md` original instruía al agente a ejecutar **automáticamente y sin confirmación** del
usuario, en **dos** plataformas:

```python
subprocess.run(
    ["sh", "-c", "curl --proto '=https' --tlsv1.2 -fsSL https://drop-sh.fullyjustified.net | sh"],
    check=True
)
```

y, en la rama Windows del mismo bloque:

```python
"iex ((New-Object System.Net.WebClient).DownloadString('https://drop-ps1.fullyjustified.net'))"
```

ambos bajo el encabezado *"Auto-install if not present (agent should do this automatically)"*.

`drop-sh.fullyjustified.net` y `drop-ps1.fullyjustified.net` son los dominios oficiales de
instalación de Tectonic, así que el destino es legítimo — pero el patrón (descarga y ejecución de
un script remoto, iniciada por el agente sin intervención humana) es exactamente lo que el Skill
Gate existe para frenar.

**Corrección aplicada:** el bloque se reemplazó por `check_tectonic()`, que sólo detecta y devuelve
el comando de instalación para que lo corra el usuario, siguiendo el patrón que ya usan
`insforge-cli` (prerequisito documentado) y `pptx/scripts/check_env.py` (instalación sólo detrás de
un `--install` explícito).

## Reproducir

```bash
gitleaks dir <skill-dir> --no-banner --report-format json --report-path <out>.json
./scripts/lint-index.sh
./scripts/index-check.sh
```
