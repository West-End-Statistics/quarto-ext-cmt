# quarto-ext-cmt

A Quarto shortcode extension for inline review comments. In **docx** output the comment appears as a native Word comment bubble (with author and timestamp); in all other formats it renders as visible styled text so annotations are never silently lost.

## Installation

```bash
quarto add West-End-Statistics/quarto-ext-cmt
```

This copies the extension into `_extensions/West-End-Statistics/cmt/` in your project. No `filters:` entry is needed — Quarto discovers shortcodes automatically.

## Usage

```
{{< cmt "comment text" >}}
{{< cmt "comment text" highlight="text to annotate" >}}
{{< cmt "comment text" highlight="text to annotate" author="Name" >}}
```

| Argument | Position | Description |
|---|---|---|
| `comment` | 1st | The comment text shown in the Word bubble (or inline for non-docx). Required. |
| `highlight` | 2nd / named | Document text to visually anchor the comment to. Optional. |
| `author` | named only | Override the comment author for this call. Optional. |

### Examples

```markdown
The primary endpoint {{< cmt "Confirm this is still the agreed endpoint" highlight="reduction in HbA1c" >}} will be analysed using a mixed model.

Alpha is set to {{< cmt "Check with biostatistics" highlight="0.05" >}}.

{{< cmt "This whole section needs updating before submission" >}}
```

## Setting the default author

Author resolution follows this priority order (highest wins):

1. **Per-comment** — `author=` argument in the shortcode call
2. **Per-document** — `cmt-author` key in the document YAML front matter
3. **Per-directory** — `cmt-author` key in `_metadata.yml` alongside the `.qmd` files
4. **Fallback** — the literal string `"Author"`

### Directory-level default (`_metadata.yml`)

```yaml
cmt-author: "Vitaly Druker"
```

### Document-level override (front matter)

```yaml
---
title: My Document
cmt-author: "Jane Smith"
---
```

### Per-call override

```
{{< cmt "Double-check this" highlight="n = 42" author="Jane Smith" >}}
```

## Output by format

**docx** — produces a native Word comment via pandoc's tracked-change markup. The comment text appears in the bubble; the `highlight` text is underlined in the document body as the anchor.

**HTML / PDF / other** — renders as *highlighted text* **[Comment id N by Author at timestamp: comment text]** so annotations remain readable in any format.

## Development

See [tests/](tests/) for the test suite. Run it with:

```bash
bash tests/run-tests.sh
```

Requirements: Quarto ≥ 1.2, pandoc (bundled with Quarto).
