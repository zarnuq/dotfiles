"""trace.py <run.jsonl>: main-thread tool calls in order, one line each, plus totals."""
import json, sys

calls, result = [], {}
for line in open(sys.argv[1]):
    try:
        d = json.loads(line)
    except ValueError:
        continue
    if d.get("type") == "result":
        result = d
    if d.get("type") != "assistant" or d.get("parent_tool_use_id"):
        continue
    for c in d["message"].get("content") or []:
        if c.get("type") != "tool_use":
            continue
        i = c["input"]
        arg = (i.get("skill") or i.get("subagent_type") or i.get("file_path")
               or i.get("command") or i.get("pattern") or "")
        calls.append(f'{c["name"]:6} {len(json.dumps(i)):6} {str(arg)[:110]!r}')
for n, c in enumerate(calls):
    print(n, c)
u = result.get("usage", {})
print("turns", result.get("num_turns"), "cost", result.get("total_cost_usd"),
      "subtype", result.get("subtype"))
print("final:", (result.get("result") or "")[:600])
