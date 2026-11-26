"""check.py <outdir>: per scenario, zq vs safe-mode calls and cost, plus behaviour checks."""
import json
import os
import subprocess
import sys

out = sys.argv[1]


def trace(name):
    calls, res = [], {}
    try:
        for line in open(f"{out}/{name}.jsonl"):
            d = json.loads(line)
            if d.get("type") == "assistant" and not d.get("parent_tool_use_id"):
                calls += [c for c in d["message"]["content"] if c.get("type") == "tool_use"]
            elif d.get("type") == "result":
                res = d
    except (OSError, ValueError):
        pass
    return calls, res


def sh(d, cmd):
    r = subprocess.run(cmd, shell=True, cwd=d, capture_output=True, text=True, timeout=30)
    return r.returncode, r.stdout + r.stderr


def edits(calls):
    return [c for c in calls if c["name"] in ("Edit", "Write") and "/.claude/" not in c["input"].get("file_path", "")]


def first(calls, pred):
    return next((i for i, c in enumerate(calls) if pred(c)), None)


def checks(name, d, calls):
    """Each check: (label, passed)."""
    ed = edits(calls)
    bash = [c["input"].get("command", "") for c in calls if c["name"] == "Bash"]
    shots = sum(1 for c in calls if c["name"] == "Read" and c["input"].get("file_path", "").endswith(".png"))
    if name == "ui":
        return [("<=1 shot", shots <= 1)]
    if name == "debug":
        sk = first(calls, lambda c: c["name"] == "Skill" and "debug" in c["input"].get("skill", ""))
        e = first(calls, lambda c: c in ed)
        return [("test ok", sh(d, "python3 test_rng.py")[0] == 0),
                ("zq-debug 1st", sk is not None and (e is None or sk < e))]
    if name == "edits":
        txt = open(f"{d}/report.py").read()
        return [("done", "fmt_row" not in txt and "' | '" in txt),
                # a literal-rename `sed -i` is allowed; a script that rewrites code is not
                ("no script edit", not any("open(" in b and "write" in b for b in bash))]
    if name == "transcript":
        return [("no whole read", not any(c["name"] == "Read" and "session.jsonl" in c["input"].get("file_path", "") for c in calls))]
    if name == "feature":
        rc, o = sh(d, "python3 cli.py ab --verbose cde")
        return [("works", rc == 0 and "5" in o and "info" in o)]
    if name == "lean":
        rc, o = sh(d, "python3 report.py sample.txt")
        src = open(f"{d}/report.py").read()
        return [("works", rc == 0 and "the" in o), ("Counter", "Counter" in src)]
    if name == "rootcause":
        rc, o = sh(d, "python3 -c \"from post import post_url;print(post_url('Café Menu'))\"")
        post = open(f"{d}/post.py").read()
        return [("fixed", "/posts/cafe-menu" in o), ("in util", "normalize" not in post and "unidecode" not in post)]
    if name == "site":
        ex = first(calls, lambda c: "examples" in json.dumps(c["input"]))
        html = [c for c in ed if c["input"].get("file_path", "").endswith(".html")]
        whole = sum(1 for c in calls if c["name"] == "Read" and c["input"].get("file_path", "").endswith(".html")
                    and "examples" not in c["input"]["file_path"])
        touched = sh(d, "rg -l 'bootstrap' *.html | wc -l")[1].strip()
        return [("examples 1st", ex is not None and (not ed or ex < first(calls, lambda c: c in ed))),
                ("gate: 0 pages changed", touched == "0" and not html), ("<=2 page reads", whole <= 2)]
    if name == "navtext":
        rc, o = sh(d, "rg -c 'PC Builder' *.html | wc -l")
        return [("all 10 done", o.strip() == "10")]
    return []


rows = []
for name in [l.split("\t")[0] for l in open(f"{out}/prompts.tsv")]:
    cells = [name]
    for suf in ("", "-s"):
        calls, res = trace(name + suf)
        cost = res.get("total_cost_usd", 0)
        cs = checks(name, f"{out}/{name}{suf}", calls)
        cells.append(f"{res.get('num_turns', '?')}t ${cost:.2f} " + " ".join(f"{l}:{'✓' if p else '✗'}" for l, p in cs))
    rows.append(cells)
for r in rows:
    print(" | ".join(r))
tot = [sum(trace(n + s)[1].get("total_cost_usd", 0) for n in (r[0] for r in rows)) for s in ("", "-s")]
print(f"total zq ${tot[0]:.2f}  safe ${tot[1]:.2f}")
