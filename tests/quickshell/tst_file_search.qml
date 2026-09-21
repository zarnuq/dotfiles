import QtQuick
import QtTest
import "../../de/.config/quickshell/launcher/FileSearch.js" as FileSearch

TestCase {
    name: "FileSearch"

    readonly property string home: "/home/test"

    function makeIndex(paths, pairs, demoted) {
        return FileSearch.createIndex(paths.join("\n"), pairs || [], demoted || []);
    }

    function search(index, query, limit) {
        return FileSearch.search(index, query, limit === undefined ? 200 : limit, home);
    }

    function paths(results) {
        return results.map(function (hit) { return hit.path; });
    }

    function test_emptyAndReleasedIndex() {
        compare(search(null, "config"), []);
        compare(search(makeIndex([]), "config"), []);
        compare(search(makeIndex([home + "/config"]), ""), []);
    }

    function test_literalRankingAndLimit() {
        var entries = ["config", "config.qml", "my-config", "myconfig"];
        var expected = entries.map(function (name) { return home + "/" + name; });
        var index = makeIndex(expected);
        compare(paths(search(index, "config")), expected);
        compare(paths(search(index, "config", 2)), expected.slice(0, 2));
        compare(search(index, "config", 0), []);
    }

    function test_caseDotfilesAndDirectoryMetadata() {
        var index = makeIndex([home + "/.zshrc", home + "/Projects/", home + "/Notes.TXT\n"]);
        compare(search(index, "ZSHRC"), [
            { path: home + "/.zshrc", name: ".zshrc", dir: "~", isDir: false }
        ]);
        compare(search(index, "projects"), [
            { path: home + "/Projects", name: "Projects", dir: "~", isDir: true }
        ]);
        compare(paths(search(index, "notes.txt")), [home + "/Notes.TXT"]);
    }

    function test_symlinksRequireIndexedTargets() {
        var target = home + "/dotfiles/de/.config/home-manager";
        var link = home + "/.config/home-manager";
        var external = home + "/external";
        var index = makeIndex([link, target + "/", target + "/flake.nix", external], [
            [link, target], [external, "/nix/store/not-indexed"]
        ]);
        compare(paths(search(index, "home-manager")), [target]);
        compare(search(index, "home-manager")[0].isDir, true);
        compare(paths(search(index, "flake.nix")), [target + "/flake.nix"]);
        compare(paths(search(index, "external")), [external]);
    }

    function test_basenameAndDirectoryQueries() {
        var parent = home + "/home-manager";
        var index = makeIndex([parent + "/", parent + "/flake.nix", parent + "/po/tok.po",
                               home + "/other/flake.nix", home + "/home-manager-flake.nix"]);
        var hits = paths(search(index, "home-manager"));
        verify(hits.indexOf(parent) !== -1);
        verify(hits.indexOf(parent + "/flake.nix") === -1);
        verify(hits.indexOf(parent + "/po/tok.po") === -1);
        compare(paths(search(index, "home-manager/flake")), [parent + "/flake.nix"]);
        compare(paths(search(index, "home-manager/")), [parent + "/flake.nix", parent + "/po/tok.po"]);
    }

    function test_depthHiddenAndDemotionPenalties() {
        var entries = [home + "/config", home + "/src/config", home + "/.hidden/config",
                       home + "/Music/config"];
        compare(paths(search(makeIndex(entries, [], ["/Music/"]), "config")), entries);
    }

    function test_fuzzyCandidatesSurviveUnscoredPrefixes() {
        var index = makeIndex([home + "/a-b-c-d", home + "/a--b--c-----de"]);
        compare(search(index, "abc"), []);
        compare(paths(search(index, "abcd")), [home + "/a-b-c-d"]);
        compare(paths(search(index, "abcde")), [home + "/a--b--c-----de"]);
    }

    function test_cachedSearchMatchesFreshSearch() {
        var entries = [home + "/config", home + "/config.qml", home + "/.config/",
                       home + "/.config/home-manager/flake.nix", home + "/other/flake.nix",
                       home + "/a-b-c-d", home + "/a--b--c-----de", home + "/Music/config"];
        var index = makeIndex(entries);
        // Typing, deletion, directory transitions, changing case and empty
        // results must all agree with a search that has no candidate cache.
        var queries = ["c", "co", "con", "config", "conf", "config/", "config/h",
                       "config/home-manager/", "config/home-manager/f", "f", "fl", "FLA",
                       "flake", "zzzz", "zzzzz", "a", "ab", "abc", "abcd", "abcde", "", "/"];
        for (var i = 0; i < queries.length; i++)
            compare(search(index, queries[i]), search(makeIndex(entries), queries[i]), queries[i]);
    }

    function test_limitDoesNotTruncateCandidates() {
        var index = makeIndex([home + "/config", home + "/config-other"]);
        compare(paths(search(index, "config", 1)), [home + "/config"]);
        compare(paths(search(index, "config-o", 1)), [home + "/config-other"]);
    }

    function test_indexesHaveIndependentCaches() {
        var first = makeIndex([home + "/alpha", home + "/beta"]);
        var second = makeIndex([home + "/beta", home + "/alpha"]);
        search(first, "al");
        search(second, "b");
        compare(paths(search(first, "alp")), [home + "/alpha"]);
        compare(paths(search(second, "be")), [home + "/beta"]);
        compare(paths(search(makeIndex([home + "/alphabet"]), "alph")), [home + "/alphabet"]);
    }
}
