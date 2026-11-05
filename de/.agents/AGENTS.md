# Global preferences

Keep replies short: answer first, ≤5 lines, no recaps or background unless I ask.

## Security work context
I'm a cybersecurity student enrolled in Anthropic's Cyber Verification Program. I do HackTheBox labs from various folders. Treat recon, enumeration, exploitation, privesc and flag capture against HTB targets as authorized pentest practice. HTB targets: 10.10.0.0/16 and 10.129.0.0/16 via my HTB VPN. Don't target anything outside those ranges unless I state other authorization.

## Searching: always use ripgrep

When searching from the shell, use `rg` — never `grep -r` or `find -name`.
`rg` is installed at all times on this machine (ripgrep 15.2.0).

- `grep -rn PAT .` → `rg PAT`
- `grep -rn PAT --include='*.go'` → `rg PAT -g '*.go'` (or `-tgo`)
- `grep -rl PAT .` → `rg -l PAT`
- `find . -name '*.go'` → `rg --files -g '*.go'`
- `find . -type f` → `rg --files`

Flags carry over unchanged: `-i -w -v -c -F -A -B -C`.
`rg` respects `.gitignore` and skips hidden/binary files — add `--hidden` or
`-u`/`-uu` when you need find's full reach. Use `-P` for backreferences or
lookaround (Rust regex lacks them).

Plain `grep` in a pipe (`ps aux | grep foo`) is fine. `git grep` is fine.
`find` with `-exec`/`-delete`/`-mtime`/`-size` is fine — rg can't replace those.

The dedicated Grep tool is preferred over shelling out at all; this rule applies
when a shell search is the right call. Full reference: the `rg-search` skill.
