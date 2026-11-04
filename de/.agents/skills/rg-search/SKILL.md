---
name: rg-search
description: Search code and files with ripgrep (rg) instead of grep. Use whenever searching file contents or finding files by name from the shell — rg is faster, respects .gitignore, and skips binary/.git files by default. Triggers on any request to grep, search, find text, or locate files.
---

# Prefer ripgrep (rg) for searching

Always reach for `rg` instead of `grep`/`find` when searching from the shell.
`rg` is faster, recursive by default, respects `.gitignore`, and skips binary
and `.git` files automatically.

Prefer the dedicated Grep tool when it fits; when you do drop to the shell for
search, use `rg`.

## Translations

| Instead of | Use |
| --- | --- |
| `grep -rn foo .` | `rg foo` |
| `grep -rn foo --include='*.go'` | `rg foo -g '*.go'` or `rg foo -tgo` |
| `grep -i foo` | `rg -i foo` |
| `grep -l foo -r .` | `rg -l foo` |
| `grep -c foo file` | `rg -c foo file` |
| `grep -w foo` | `rg -w foo` |
| `grep -A3 -B3 foo` | `rg -A3 -B3 foo` |
| `grep -v foo` | `rg -v foo` |
| `find . -name '*.go'` | `rg --files -g '*.go'` |
| `find . -type f` | `rg --files` |

## Handy flags

- `-t <type>` / `-T <type>` — include/exclude a file type (e.g. `-tgo`, `-tpy`, `-Tmd`).
- `-g '<glob>'` — filter by glob (repeatable; `-g '!vendor/**'` to exclude).
- `-l` list matching files only; `--files` list files rg would search.
- `-o` print only the match; `--json` for machine-readable output.
- `-. ` / `--hidden` search hidden files; `-u`/`-uu`/`-uuu` progressively ignore
  `.gitignore` and search more.
- `-F` treat the pattern as a literal (not a regex); `-w` whole word.
- `-C <n>` context lines around each match.

## Notes

- `rg` uses Rust regex syntax (no backreferences/lookaround); use `-P` for PCRE2
  if you truly need them.
- Only fall back to `grep` when `rg` is genuinely unavailable on the machine.
