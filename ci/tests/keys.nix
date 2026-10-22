# THE EDGE KEY IS INJECTIVE — an id containing the old separator forges no other edge.
#
# The key was `"${label}:${src}:${dst}"`, so `("a:b", "c", "d")` and `("a", "b:c", "d")` both keyed as
# `a:b:c:d`: dedup dropped one edge and `select` kept the wrong one, silently. The key is now
# `builtins.toJSON [ label src dst ]`, and `why` parses only a JSON-list atom.
#
# The pair below is the whole fixture: two edges that collide under the colon key and differ under
# the JSON one. Each cell reads a different consumer of the key (origins, the edge table, the
# `reaches` fixpoint, `select`, `why`); the first is the control that the fixture really holds two
# edges, so a later cell reading one cannot be a fixture that never had the second.
{ genInspect, ... }:
let
  refuses = e: !(builtins.tryEval (builtins.deepSeq e null)).success;
  answers = e: (builtins.tryEval (builtins.deepSeq e null)).success;

  i = genInspect.fromGraph { } {
    nodes = [
      "c"
      "b:c"
      "d"
    ];
    perLabel = {
      "a:b" = n: if n == "c" then [ "d" ] else [ ];
      a = n: if n == "b:c" then [ "d" ] else [ ];
    };
  };

  keyOf =
    label: src: dst:
    builtins.toJSON [
      label
      src
      dst
    ];
  forgedA = keyOf "a:b" "c" "d";
  forgedB = keyOf "a" "b:c" "d";
  reachesAtom =
    via: s: d:
    builtins.toJSON [
      "reaches"
      via
      s
      d
    ];
in
{
  flake.tests.keys = {
    test-control-the-fixture-declares-two-edges = {
      expr = builtins.length i.facts.edges;
      expected = 2;
    };

    test-two-edges-that-collide-under-a-colon-key-keep-two-origins = {
      expr = builtins.sort builtins.lessThan (builtins.attrNames i.facts.origins);
      expected = builtins.sort builtins.lessThan [
        forgedA
        forgedB
      ];
    };

    test-control-reaches-reads-both-colliding-edges = {
      expr = builtins.sort (a: b: a < b) (
        map (r: "${r.src}>${r.dst}") (i.query "SELECT src, dst FROM reaches WHERE via = '*'")
      );
      expected = [
        "b:c>b:c"
        "b:c>d"
        "c>c"
        "c>d"
        "d>d"
      ];
    };

    test-why-answers-a-json-atom = {
      expr = (i.why (reachesAtom "*" "c" "d")).kind;
      expected = "query";
    };

    # `fromJSON` aborts uncatchably on these, so each is refused before it is parsed.
    test-why-refuses-a-malformed-list-atom-catchably = {
      expr = {
        notJson = refuses (i.why "[x");
        unclosed = refuses (i.why ''["reaches","*","c","d"'');
        shortEscape = refuses (i.why ''["reaches","*","c","d\u"]'');
        rawNewline = refuses (i.why "[\"reaches\",\"*\",\"c\",\"d\n\"]");
        control = answers (i.why (reachesAtom "*" "c" "d"));
      };
      expected = {
        notJson = true;
        unclosed = true;
        shortEscape = true;
        rawNewline = true;
        control = true;
      };
    };

    test-why-refuses-a-colon-string-atom = {
      expr = {
        colon = refuses (i.why "reaches:*:c:d");
        control = answers (i.why (reachesAtom "*" "c" "d"));
      };
      expected = {
        colon = true;
        control = true;
      };
    };
  };
}
