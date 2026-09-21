.pragma library

// File-search data and ranking, independent of QML and subprocesses.
// createIndex() owns all precomputed arrays and the incremental candidate cache.
// Each index has its own cache; this shared library keeps no mutable global state.

// Stow gives every config two names — ~/.config/home-manager is a symlink
// to ~/dotfiles/de/.config/home-manager — and both show up as separate
// hits for the same directory. 89 of this tree's 115 symlinks are that
// kind of duplicate.
//
// The LINK is what gets dropped, not the target: fd never descends a
// symlink, so the link side has no indexed children while the target side
// has all of them. Keeping the target is what makes a parent and its
// contents agree about where they live.
function dropSet(lines, n, pairs) {
    if (pairs.length === 0) return null;

    var wanted = {}, k;
    for (k = 0; k < pairs.length; k++) wanted[pairs[k][1]] = false;

    // One cheap sweep: only the ~115 targets are ever looked up, so this
    // is a hash miss per line rather than a 46k-key set of the whole tree.
    for (var i = 0; i < n; i++) {
        var p = lines[i];
        if (p.charCodeAt(p.length - 1) === 47) p = p.slice(0, -1);
        if (wanted[p] === false) wanted[p] = true;
    }

    var drop = null;
    for (k = 0; k < pairs.length; k++) {
        if (wanted[pairs[k][1]] !== true) continue;   // target isn't indexed: keep the link
        if (drop === null) drop = {};
        drop[pairs[k][0]] = true;
    }
    return drop;
}

function createIndex(text, pairs, demoted) {
    var lines = text.split("\n");
    var n = lines.length;
    if (n > 0 && lines[n - 1] === "") n--;

    var drop = dropSet(lines, n, pairs);

    // Pushed rather than preallocated: dropped links make the output
    // shorter than the input, and every parallel array has to stay aligned.
    var path = [], base = [], lpath = [], pens = [], dirs = [];

    for (var i = 0; i < n; i++) {
        var p = lines[i], isDir = 0;
        if (p.charCodeAt(p.length - 1) === 47) {   // fd marks dirs with a trailing /
            p = p.slice(0, -1);
            isDir = 1;
        }
        if (drop !== null && drop[p] === true) continue;

        var lower = p.toLowerCase();
        var b = lower.slice(lower.lastIndexOf("/") + 1);
        if (b.charCodeAt(0) === 46) b = b.slice(1);   // ".zshrc" is found by "zshrc"

        var depth = 0;
        for (var j = 0; j < p.length; j++) if (p.charCodeAt(j) === 47) depth++;
        var pen = depth * 3;                          // shallower is likelier
        if (lower.indexOf("/.") >= 0) pen += 12;      // dotfile machinery
        for (var k = 0; k < demoted.length; k++)
            if (p.indexOf(demoted[k]) >= 0) { pen += 120; break; }

        path.push(p); lpath.push(lower); base.push(b);
        pens.push(pen); dirs.push(isDir);
    }

    var m = path.length;
    var penalty = new Int16Array(m), isDirs = new Uint8Array(m);
    for (var q = 0; q < m; q++) { penalty[q] = pens[q]; isDirs[q] = dirs[q]; }

    return {
        paths: path, bases: base, lowerPaths: lpath,
        penalties: penalty, directories: isDirs,
        lastQuery: "", lastCandidates: null
    };
}

// ── matching ───────────────────────────────────────────────────────

// Is `q` a subsequence of `hay`, and how far apart are its characters?
// Span is what separates "Bar.qml" from a query's letters scattered across
// a 90-character track title.
function subsequenceSpan(hay, q) {
    var i = 0, first = -1, last = -1;
    for (var j = 0; j < hay.length && i < q.length; j++) {
        if (hay.charCodeAt(j) === q.charCodeAt(i)) {
            if (first < 0) first = j;
            last = j;
            i++;
        }
    }
    return i === q.length ? last - first + 1 : -1;
}

function slashCount(str) {
    var n = 0;
    for (var i = 0; i < str.length; i++) if (str.charCodeAt(i) === 47) n++;
    return n;
}

// Score `q` against one haystack, literal tiers first, fuzzy last.
// Returns -1 for "not a candidate at all".
function matchTier(hay, q, maxSpan) {
    var idx = hay.indexOf(q);
    if (idx === 0) return hay.length === q.length ? 1000 : 800 - (hay.length - q.length);
    if (idx > 0) {
        var c = hay.charCodeAt(idx - 1);        // 45 - · 95 _ · 46 . · 32 space · 47 /
        var boundary = c === 45 || c === 95 || c === 46 || c === 32 || c === 47;
        return (boundary ? 600 : 400) - idx;
    }
    // Native indexOf on the first character before entering the JS scan:
    // nearly every one of 46k entries is a miss, and this is what makes the
    // cold scan a C++ memchr rather than a per-character interpreter loop.
    if (hay.indexOf(q.charAt(0)) < 0) return -1;
    var span = subsequenceSpan(hay, q);
    if (span < 0) return -1;
    if (q.length < 4 || span > maxSpan) return 0;   // candidate, but not shown
    return 150 - (span - q.length) * 4;
}

function search(index, rawq, limit, home) {
    if (index === null || rawq === "") return [];

    var q = rawq.toLowerCase();
    var cut = q.lastIndexOf("/");

    // A "/" in the query splits it: everything before the last slash must
    // appear in the directory, everything after is matched against the
    // basename as usual. NOT a fuzzy match over the whole path — that is
    // what makes a plain fzf return .../home-manager/po/tok.po for
    // "home-manager": the query matched the directory and the file it
    // handed back was unrelated. The directory half is a plain substring
    // for the same reason; subsequence-matching a path is all noise.
    var dirQ = cut >= 0 ? q.slice(0, cut) : "";
    var baseQ = cut >= 0 ? q.slice(cut + 1) : q;

    // Narrow only when extending the same basename query. Keep even unscored
    // subsequence candidates: a longer query can pass the fuzzy length/span
    // thresholds after its shorter prefix failed them. A new slash changes
    // which text is the directory filter and requires a full scan.
    var reuse = index.lastCandidates !== null
                && q.length > index.lastQuery.length
                && q.indexOf(index.lastQuery) === 0
                && slashCount(q) === slashCount(index.lastQuery);

    var pool = reuse ? index.lastCandidates : null;
    var n = pool ? pool.length : index.paths.length;
    var base = index.bases, lpath = index.lowerPaths, penalty = index.penalties;
    var maxSpan = baseQ.length * 2 + 4;
    var cand = [], scored = [];

    for (var k = 0; k < n; k++) {
        var i = pool ? pool[k] : k;

        var s;
        if (baseQ === "") {
            s = 700;                            // "dir/" — list what is under it
        } else {
            s = matchTier(base[i], baseQ, maxSpan);
            if (s < 0) continue;
            cand.push(i);
            if (s === 0) continue;
        }

        if (dirQ !== "") {
            var full = lpath[i];
            var at = full.indexOf(dirQ);
            // Must land in the directory half, not in the filename.
            if (at < 0 || at + dirQ.length > full.lastIndexOf("/")) continue;
            s += 60;
        }

        s -= penalty[i];
        // One number per hit rather than a {score, index} pair: object
        // allocation is most of the cost of a naive ranker at this size.
        if (s > 0) scored.push(s * 1000000 + i);
    }

    index.lastQuery = q;
    if (baseQ !== "") index.lastCandidates = cand;
    else index.lastCandidates = null;

    scored.sort(function (a, b) { return b - a; });

    var out = [], max = Math.min(limit, scored.length);
    for (var m = 0; m < max; m++) {
        var v = scored[m], id = v % 1000000, path = index.paths[id];
        var slash = path.lastIndexOf("/");
        out.push({
            path: path,
            name: path.slice(slash + 1),
            dir: path.slice(0, slash).replace(home, "~"),
            isDir: index.directories[id] === 1
        });
    }
    return out;
}
