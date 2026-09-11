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
| `allow` | 37 |
| `review` (con waiver) | 26 |
| candidato a `deny` — **no promovido** | 1 |

## Candidato a `deny` — `contenido/comunidad/pdf`

`SKILL.md:413` instruye al agente a ejecutar **automáticamente y sin confirmación** del usuario:

```python
subprocess.run(
    ["sh", "-c", "curl --proto '=https' --tlsv1.2 -fsSL https://drop-sh.fullyjustified.net | sh"],
    check=True
)
```

bajo el encabezado *"Auto-install if not present (agent should do this automatically)"*.

`drop-sh.fullyjustified.net` es el dominio oficial de instalación de Tectonic, así que el destino
es legítimo — pero el patrón (descarga y ejecución de un script remoto, iniciada por el agente sin
intervención humana) es exactamente lo que el Skill Gate existe para frenar.

**Su fila quedó con `scan_verdict` vacío**: sigue resolviendo como `blocked` y no fue promovida.
Registrar `deny` exige además mover la skill a `_archivo/` (regla [d] de `index-check.sh`), que es
una decisión de gobernanza humana, no automática.

## Reproducir

```bash
gitleaks dir <skill-dir> --no-banner --report-format json --report-path <out>.json
./scripts/lint-index.sh
./scripts/index-check.sh
```
