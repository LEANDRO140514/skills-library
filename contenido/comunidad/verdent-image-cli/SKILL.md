---
name: verdent-image-cli
description: |
  Generate and edit images via the `verdent-image` tool. Use this skill
  whenever the user asks for image generation, image editing based on
  reference images, posters, illustrations, covers, UI mocks, social
  creatives, or style variations. The CLI returns a JSON payload; bash
  automatically decodes the base64 result, writes it to disk, and returns
  a short path-based text result to the model.
metadata:
  version: '1.0.3'
---

# Verdent Image CLI

Single skill for generating and editing images through the `verdent-image` tool. The bash layer automatically handles base64 decoding and file saving; you only need to craft a good prompt and pass reference image paths when editing.

## When to Use

Invoke this skill whenever the user wants to:

- generate a brand-new image from a description
- edit an existing image with one or more reference images
- produce posters, illustrations, hero images, covers, social creatives, UI mock visuals, or stylistic variants
- regenerate an image with changed style, composition, subject, or palette

Do **not** use this skill to analyze or describe an existing image. Use a vision-capable read path instead.

## CLI Shape

```bash
verdent-image <generate | edit> --model <model> --prompt "<prompt>" [--size <WxH>] [--n <count>] [--image <path> ...] [--mask <path>]
```

Two subcommands:

- `verdent-image generate` — create a new image from the prompt alone
- `verdent-image edit` — edit/transform based on reference images

`--model` is **always required**. The default model to use is `gpt-image-2` unless the user explicitly asks for a different one.

### Generate image

```bash
verdent-image generate --model gpt-image-2 --prompt "<agent-crafted prompt>" --size 1024x1024 --n 1
```

### Edit image

```bash
verdent-image edit --model gpt-image-2 --prompt "<agent-crafted prompt>" --image path1 --image path2 --image path3
```

Flags:

| Flag | Required | Purpose |
|------|----------|---------|
| `--model` | **yes** | Model id. Default to `gpt-image-2` unless the user specifies another one. |
| `--prompt` | **yes** | Agent-authored prompt string. |
| `--size` | optional | Image size, e.g. `1024x1024`, `1792x1024`. Default `1024x1024`. |
| `--n` | optional | Number of images to produce. Default `1`. |
| `--image` | **required for `edit`** | Absolute path to a reference image. Repeat the flag once per image (the CLI accepts multiple `--image` flags). |
| `--mask` | optional for `edit` | Absolute path to a mask image. When provided, edits are constrained to the masked region. Omit it for a normal image edit. |

## Prompt Authoring Rules

- **Do not parrot the user verbatim.** Translate intent into an image prompt: subject, composition, style, color, lighting, framing, camera or medium, quality cues when relevant.
- **Do not over-invent.** Preserve every concrete requirement the user gave (subject, scene, palette, aspect ratio, characters, text overlays, product details). Do not add subjects, brands, or style shifts the user never asked for.
- Keep the prompt focused and sentence-like. No bullet lists inside `--prompt`.
- Quote the prompt with double quotes and escape internal quotes if needed.
- Write the prompt in English by default. Match another language only if the user's creative explicitly requires it (for example, on-image text in that language).

## Reference Images Rules

Only applies to `verdent-image edit`:

- `--image` takes an **image file path**, not a URL and not base64.
- Pass one `--image` flag per reference image. The flag is repeatable. Do **not** pass a comma-separated list to a single `--image`.
  - Correct: `--image /a/b.png --image /a/c.jpg`
  - Wrong:   `--image /a/b.png,/a/c.jpg`
- Prefer absolute paths. If you only have a relative path, resolve it before calling.
- When the user dragged in or `@mentioned` images, use those exact paths as provided. They are surfaced by the preprocessor alongside the image content. Do not invent, rename, or summarize them.
- Do not embed base64 in `--image`. Bash only accepts paths here.
- `--mask` is optional and takes an **image file path**. Use it only when the user provides or asks to use a mask image.
- A mask tells `gpt-image-2` which region to modify. Areas outside the mask should be preserved as much as possible.
- Do not pass `--mask` unless you have an actual mask image path. Normal edits should use `--image` without `--mask`.

## Output Handling

`verdent-image` writes a JSON string to stdout. The raw CLI payload looks like:

```json
{
  "images": [
    {
      "image_media_type": "image/png",
      "size": "1024x1024",
      "quality": "high",
      "result": "<very large base64 string>"
    }
  ]
}
```

You do **not** parse this raw JSON yourself and you do **not** save the image yourself. Bash intercepts the command and does all of the following automatically:

1. Parse the CLI JSON.
2. Decode each `result` from base64.
3. Derive the file extension from `image_media_type`.
4. Write each image to the appropriate directory (see below).
5. Replace the tool result you see with a **fixed JSON schema** describing the saved files:

   ```json
   {
     "status": "ok",
     "operation": "generate",
     "count": 1,
     "images": [
       {
         "path": "/absolute/path/to/generate_20260101_120000_ab12cd34.png",
         "image_media_type": "image/png",
         "size": "1024x1024",
         "quality": "high"
       }
     ]
   }
   ```

   - `status` is `"ok"` on success or `"empty"` if no image came back.
   - `operation` is `"generate"` or `"edit"`.
   - `count` is the number of saved images (matches `len(images)`).
   - Each `images[i].path` is the absolute path on disk.

Treat this JSON as the ground truth. Parse `images[*].path` and tell the user the image was generated or edited and report the path(s). Do not attempt to dump base64 back to the user.

### Save directories

| Context | Directory |
|---------|-----------|
| Default (worker or global usage) | `~/.verdent/generate_images` |
| When invoked inside the Verdent manager or base workspace | `~/.verdent/workspace/base/generated_images` |

Bash chooses the directory automatically based on the current skill context. You do not need to specify it.

## End-to-End Patterns

### Pattern 1. Simple generation

User asks for a cyberpunk cat illustration.

```bash
verdent-image generate --model gpt-image-2 --prompt "A cyberpunk cat sitting on a rain-soaked rooftop at night, neon signs reflecting in puddles, cinematic lighting, shallow depth of field, high detail" --size 1024x1024 --n 1
```

Then tell the user the image was generated and show the saved path from the tool result.

### Pattern 2. Photorealistic product shot

User wants a glossy red apple product photo.

```bash
verdent-image generate --model gpt-image-2 --prompt "A giant gleaming red apple, hyper-realistic, dewdrops on glossy skin, vibrant saturated red with subtle yellow highlights, fresh green leaf still attached to the stem, dramatic studio lighting on pure white background, ultra detailed macro photography, 8k quality" --size 1024x1024 --n 1
```

### Pattern 3. Edit with a single reference

User dragged `cover.png` and asked to recolor it with warm tones and add subtle grain.

```bash
verdent-image edit --model gpt-image-2 --prompt "Recolor this cover with warm tones (amber, soft red, gold), add subtle film grain, preserve original composition and subjects" --image /Users/me/cover.png
```

### Pattern 4. Edit with multiple references

User `@mentioned` `ref1.jpg` and `ref2.jpg` and asked to keep the subject of the first image while using the color palette of the second.

```bash
verdent-image edit --model gpt-image-2 --prompt "Create a composite that keeps the subject and composition of the first image while adopting the color palette and mood of the second image" --image /path/to/ref1.jpg --image /path/to/ref2.jpg
```

### Pattern 5. Edit with a mask

User provided an indoor lounge photo and a mask image, then asked to add a pink flamingo only inside the masked pool area while preserving the original architecture.

```bash
verdent-image edit --model gpt-image-2 --prompt "A sunlit indoor lounge area with a pool containing a pink flamingo floating gracefully on the water surface, warm natural lighting, maintaining original architecture" --image /path/to/indoor-lounge.jpg --mask /path/to/pool-mask.png
```

## Do and Don't

**Do**

- Always include `--model`. Use `gpt-image-2` unless the user specifies another one.
- Craft a faithful, tight image prompt from the user's intent.
- Pass drag or `@`-mentioned image paths verbatim into `--image` (one `--image` per path).
- Use `--mask` only when the user provides a mask image path or explicitly asks for masked-region editing.
- Trust the bash short text result and forward the saved path to the user.

**Don't**

- Don't omit `--model`.
- Don't use the old flag form `--generate` / `--edit`. They are subcommands now: `verdent-image generate` / `verdent-image edit`.
- Don't decode or re-save the base64 yourself.
- Don't dump JSON or base64 back to the user.
- Don't spawn a subagent to call this CLI. Call it directly from bash.
- Don't invent unsupported flags. Only `--model`, `--prompt`, `--size`, `--n`, `--image`, and `--mask` are valid. In particular, **`--reference_images` does not exist** — use repeated `--image` flags instead.
- Don't copy `image_media_type`, `size`, or `quality` verbatim from an unrelated example. They come from the CLI response for the current call.

## Troubleshooting

- **Bash returned JSON text instead of the short saved-path message.** The command string was probably wrapped in a way that hid the `verdent-image generate` / `verdent-image edit` token (for example, inside a subshell with an alias). Call the top-level command directly.
- **`edit` appears to fail with exit code 1 and no error message, and no saved path is returned.** You probably used `--reference_images`. That flag does not exist; the CLI rejects it as an unknown argument without a friendly error. Switch to one or more `--image <path>` flags and retry.
- **Error about reference path not found.** Verify the path exists with a lightweight check (for example `ls <path>`) before retrying. Do not retry with the same path.
- **Very long edits.** The CLI call may take tens of seconds. Bash already uses an extended timeout for this command. Do not retry on the first wait.
- **Error about unknown model.** Fall back to `gpt-image-2`.
