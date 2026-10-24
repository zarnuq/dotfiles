.pragma library

// `tmux capture-pane -e` output (SGR escapes) → RichText HTML for the tmux
// menu's preview. Only colour/bold/italic/underline/reverse are kept; any
// other escape is dropped. The 16-colour palette is kitty's
// (kitty/current-theme.conf), so a preview matches the terminal.

var PALETTE = ["#45475a", "#f38ba8", "#a6e3a1", "#f9e2af", "#89b4fa", "#f5c2e7", "#94e2d5", "#bac2de",
               "#585b70", "#f38ba8", "#a6e3a1", "#f9e2af", "#89b4fa", "#f5c2e7", "#94e2d5", "#a6adc8"];
var FG = "#cdd6f4";
var BG = "#1e1e2e";

function hex(n) { return (n < 16 ? "0" : "") + n.toString(16); }

function color256(n) {
    if (n < 16) return PALETTE[n];
    if (n >= 232) { var g = 8 + 10 * (n - 232); return "#" + hex(g) + hex(g) + hex(g); }
    n -= 16;
    var lv = [0, 95, 135, 175, 215, 255];
    return "#" + hex(lv[Math.floor(n / 36)]) + hex(lv[Math.floor(n / 6) % 6]) + hex(lv[n % 6]);
}

function escape(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// Applies one SGR parameter list to `st`, in place.
function sgr(st, params) {
    var p = params === "" ? [0] : params.split(/[;:]/).map(Number);
    for (var i = 0; i < p.length; i++) {
        var c = p[i];
        if (c === 0) { st.fg = null; st.bg = null; st.b = st.i = st.u = st.r = false; }
        else if (c === 1) st.b = true;
        else if (c === 3) st.i = true;
        else if (c === 4) st.u = true;
        else if (c === 7) st.r = true;
        else if (c === 22) st.b = false;
        else if (c === 23) st.i = false;
        else if (c === 24) st.u = false;
        else if (c === 27) st.r = false;
        else if (c >= 30 && c <= 37) st.fg = PALETTE[c - 30];
        else if (c >= 90 && c <= 97) st.fg = PALETTE[c - 90 + 8];
        else if (c === 39) st.fg = null;
        else if (c >= 40 && c <= 47) st.bg = PALETTE[c - 40];
        else if (c >= 100 && c <= 107) st.bg = PALETTE[c - 100 + 8];
        else if (c === 49) st.bg = null;
        else if (c === 38 || c === 48) {
            var col = null;
            if (p[i + 1] === 5) { col = color256(p[i + 2] || 0); i += 2; }
            else if (p[i + 1] === 2) { col = "#" + hex(p[i + 2] || 0) + hex(p[i + 3] || 0) + hex(p[i + 4] || 0); i += 4; }
            if (c === 38) st.fg = col; else st.bg = col;
        }
    }
}

function open(st) {
    var fg = st.fg, bg = st.bg;
    if (st.r) { fg = st.bg || BG; bg = st.fg || FG; }
    var css = [];
    if (fg) css.push("color:" + fg);
    if (bg) css.push("background-color:" + bg);
    if (st.b) css.push("font-weight:bold");
    if (st.i) css.push("font-style:italic");
    if (st.u) css.push("text-decoration:underline");
    return css.length ? '<span style="' + css.join(";") + '">' : "";
}

// → { html, cols, rows }. Trailing blank lines are dropped, so cols/rows are
// the content's extent — what the preview sizes its font to.
function toHtml(text, family) {
    var lines = text.split("\n");
    var plain = lines.map(function (l) { return l.replace(/\x1b\[[0-9;:?]*[A-Za-z]|\x1b\][^\x07\x1b]*(\x07|\x1b\\)?/g, ""); });
    while (plain.length && plain[plain.length - 1].trim() === "") { plain.pop(); lines.pop(); }

    var cols = 0;
    plain.forEach(function (l) { cols = Math.max(cols, l.length); });

    // State carries across lines, as it does on the terminal.
    var st = { fg: null, bg: null, b: false, i: false, u: false, r: false };
    var out = lines.map(function (line) {
        var html = open(st), span = html !== "";
        var re = /\x1b\[([0-9;:?]*)([A-Za-z])|\x1b\][^\x07\x1b]*(\x07|\x1b\\)?/g;
        var last = 0, m;
        while ((m = re.exec(line)) !== null) {
            html += escape(line.slice(last, m.index));
            last = re.lastIndex;
            if (m[2] !== "m") continue;
            if (span) html += "</span>";
            sgr(st, m[1]);
            var o = open(st);
            html += o;
            span = o !== "";
        }
        html += escape(line.slice(last));
        return span ? html + "</span>" : html;
    });

    return {
        html: '<pre style="font-family:\'' + family + '\'; color:' + FG + '">' + out.join("\n") + "</pre>",
        cols: cols,
        rows: plain.length
    };
}
