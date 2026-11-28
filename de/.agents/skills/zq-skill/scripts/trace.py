"""trace.py <session.jsonl>: main-thread tool calls in order, one line each, plus totals.

Reads both headless stream-json runs (run.sh) and interactive transcripts
(~/.claude/projects/<dir>/<id>.jsonl), which have no result record, so tokens
come from the per-message usage blocks instead.
"""
import json, sys

calls, result, usage, final = [], {}, {}, ""
for line in open(sys.argv[1]):
    try:
        d = json.loads(line)
    except ValueError:
        continue
    if d.get("type") == "result":
        result = d
    if d.get("type") != "assistant" or d.get("parent_tool_use_id") or d.get("isSidechain"):
        continue
    m = d.get("message") or {}
    # one API response is split across several records that repeat its usage
    if m.get("usage"):
        usage[m.get("id")] = m["usage"]
    for c in m.get("content") or []:
        if c.get("type") == "text":
            final = c["text"]
        if c.get("type") != "tool_use":
            continue
        i = c["input"]
        arg = (i.get("skill") or i.get("subagent_type") or i.get("file_path")
               or i.get("command") or i.get("pattern") or i.get("url") or "")
        calls.append(f'{c["name"]:6} {len(json.dumps(i)):6} {str(arg)[:110]!r}')
for n, c in enumerate(calls):
    print(n, c)
ctx = [sum(u.get(k, 0) for k in ("input_tokens", "cache_read_input_tokens",
                                 "cache_creation_input_tokens")) for u in usage.values()]
print("api calls", len(usage), "peak context", max(ctx, default=0),
      "output", sum(u.get("output_tokens", 0) for u in usage.values()),
      "cache written", sum(u.get("cache_creation_input_tokens", 0) for u in usage.values()))
if result:
    print("turns", result.get("num_turns"), "cost", result.get("total_cost_usd"),
          "subtype", result.get("subtype"))
print("final:", (result.get("result") or final)[:600])
