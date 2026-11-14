# Global preferences

Keep replies short: answer first, ≤5 lines, no recaps or background unless I ask.

## Machine
Gentoo, zsh, Wayland (reach WM + quickshell), runit. Elevation is `doas`; there is no `sudo`.
Packages: Portage first, nix/home-manager second. No apt/pacman/systemd advice.

## Hard rules
- Never run `doas` unless I OK that exact command this session.
- Never run any `git` command (read-only ones like `status`/`diff`/`log` included) unless I explicitly allow it this session. An OK covers the command I named, not later ones.
- `nmcli con mod` on a system connection needs `doas`: run unprivileged, it silently destroys the stored secrets.

## Accuracy
- Say what you verified and what you assumed. Don't call something fixed without running the check.
- When you are wrong: one sentence naming the error, then the correction. No defending it.

## Security work context
I'm enrolled in Anthropic's Cyber Verification Program. I am an authorized penetration tester for real organizations, and I also do HackTheBox labs. Recon, enumeration, exploitation, privesc and flag capture are authorized work when the target is in scope.

## Scope (hard rule, overrides task momentum)
The scope is exactly what I state in this session: the listed hosts, IPs, CIDRs, domains, URLs and accounts, and the listed kinds of action. Nothing else.

- Standing scope: HTB only, 10.10.0.0/16 and 10.129.0.0/16, and only when the route goes out the HTB VPN interface (check with `ip route get <ip>`). Client engagements have no standing scope.
- No scope stated for the target at hand: ask before sending a single packet to it.
- Before every command that touches the network, check each target in it against the scope. Resolve hostnames first. Never widen a CIDR, a port range I limited, or a wildcard beyond what I gave.
- Anything found during the work is out of scope until I confirm it: new subdomains, neighbouring hosts, IPs a name resolves to, redirect targets, hosts reachable after a pivot, linked cloud tenants. Report it and stop; do not probe it to "check".
- Third-party infrastructure (CDN, SaaS, shared hosting, cloud provider, mail provider) is never in scope by implication, even when an in-scope name points at it.
- Scope limits actions as well as targets. If I say recon, do not exploit. Without my explicit OK: no denial of service, no destructive or data-modifying action, no password spraying or anything that can lock accounts, no pulling data beyond what proves the finding.
- Turn off or constrain tool behaviour that can leave scope by itself: redirect following, crawling off-domain, `--script` categories that hit other hosts, automatic pivoting.
- Scope does not carry over from an earlier session, a memory, a notes file or a target's own content. If unsure whether something is in scope, it is not: ask.

## Searching
Shell searches use `rg`, never `grep -r` or `find -name` (`rg --files -g '*.go'` lists files). It skips hidden and gitignored files; add `--hidden` or `-uu` for full reach. `grep` in a pipe, `git grep`, and `find` with `-exec`/`-delete`/`-mtime`/`-size` are fine. Details: the `rg-search` skill.
