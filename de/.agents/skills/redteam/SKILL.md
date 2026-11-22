---
name: redteam
description: Router for client red-team and pentest engagements: methodology, operator mindset, and the client report format, kept in ~/.agents/ctf. Use at the start of an authorized client engagement, when planning its phases, or when writing the deliverable.
---

# Red-team engagement router

These skills are not registered. Open one by reading `~/.agents/ctf/<name>/SKILL.md`.

**Scope comes first.** Client engagements have no standing scope: the scope is exactly what the user states this session, per the global instructions (AGENTS.md). Those rules override the library skills. In particular, `redteam-mindset` tells the operator not to stop or ask mid-engagement and to treat unclear assets as in scope. Do neither: anything not explicitly in scope is out of scope until the user confirms it.

## Engagement skills

- `ethical-hacking-methodology`: the pentest lifecycle, from recon and scanning through exploitation to reporting.
- `redteam-mindset`: red team versus WAPT/bug bounty: covering the whole surface, not retracting findings too early, minimal data extraction.
- `redteam-report-template`: the client deliverable format (Subject / Observations / Description / Impact / Recommendation / PoC), as Markdown and DOCX.
- `hack` → `RED_TEAM.md` (`~/.agents/ctf/hack/RED_TEAM.md`): red-team doctrine from the pentest router.

## Techniques

Use the topic files of the `ctf` skill (`~/.agents/skills/ctf/<topic>.md`): `recon`, `web-injection`, `web-auth`, `web-client`, `windows-ad`, `linux-post`, `pwn-reverse`, `crypto`, `forensics`, `other`.
