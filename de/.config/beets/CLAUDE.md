# beets

Loaded when working in this directory. Moved out of the root `CLAUDE.md`, which keeps only an index.

- **beets** — `de/.config/beets/config.yaml`. Owns canonical MusicBrainz metadata **and** the on-disk layout of `~/Music` (`directory: ~/Music`, `import.move: yes`, incremental). Split of duties with the separate `~/mux` tool is written into the file's header and matters: **mux dedupes** (it hashes decoded audio — beets' `duplicates` plugin keys on tags/MBIDs, which is exactly what's inconsistent here) and owns `.lrc` sidecars; **beets** owns layout and the library db. Run `mux dedupe` **first**, and never `mux organize` — two owners of layout is how a library gets shredded. The unreleased/leaks `paths` rule must stay first or an import silently re-files what `mux unreleased` shelved.
