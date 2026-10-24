import QtQuick
import QtTest
import "../../de/.config/quickshell/Ansi.js" as Ansi

TestCase {
    name: "Ansi"

    function body(text) {
        var html = Ansi.toHtml(text, "F").html;
        return html.slice(html.indexOf(">") + 1, html.lastIndexOf("</pre>"));
    }

    function test_plainAndEscaping() {
        compare(body("a <b> & c"), "a &lt;b&gt; &amp; c");
    }

    function test_colours() {
        compare(body("\x1b[31mred\x1b[0m x"), '<span style="color:#f38ba8">red</span> x');
        compare(body("\x1b[38;5;196mx"), '<span style="color:#ff0000">x</span>');
        compare(body("\x1b[48;2;1;2;3mx"), '<span style="background-color:#010203">x</span>');
        compare(body("\x1b[1;7mx"), '<span style="color:#1e1e2e;background-color:#cdd6f4;font-weight:bold">x</span>');
    }

    function test_stateCarriesAcrossLines() {
        compare(body("\x1b[32ma\nb"), '<span style="color:#a6e3a1">a</span>\n<span style="color:#a6e3a1">b</span>');
    }

    function test_extentIgnoresEscapesAndTrailingBlanks() {
        var r = Ansi.toHtml("\x1b[31mabcd\x1b[0m\nab\n\n  \n", "F");
        compare(r.cols, 4);
        compare(r.rows, 2);
    }

    function test_otherEscapesDropped() {
        compare(body("\x1b]8;;http://x\x1b\\link\x1b]8;;\x1b\\ \x1b[?25hz"), "link z");
    }
}
