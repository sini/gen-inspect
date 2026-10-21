# CELL 7 — RENDER, AND THE ASSERTION IS SOURCE-SIDE.
#
# ★★ THE WHOLE-FILE SVG COUNT IS NOT A PREDICATE. mermaid emits `edge-pattern-dotted` in its
# STYLESHEET unconditionally, so an image cell asserting that the token occurs once REDS AGAINST A
# CORRECT BUILD and GREENS AT THE RED STATE — 2 versus 1, not 1 versus 0. And `stroke-dasharray`
# discriminates not at all: measured 16 in both fixtures. Picture fidelity needs an ELEMENT-scoped
# predicate and a build, and the design sequences it to the guarantee row; what is asserted HERE is
# the SOURCE this library produces, which is the thing this library is responsible for.
#
# ★ THE FIGURES ARE THIS FLEET'S, MEASURED. The design cites 1 dotted / 1 solid from the demo spec's
# own fixture [D §3a.5]; this fleet carries TWELVE declared edges and TWO rule edges, so the
# figures here are 2 and 12. Inheriting the cited pair would have red against a correct build.
#
# THE RED ARM IS IN THIS FILE: the same renderer over an IR whose every edge has been relabelled
# `declaration`. The dotted count goes to 0 while the solid count RISES, which is what separates
# "the rule edge lost its style" from "the render produced nothing".
{
  lib,
  admitted,
  withdrawn,
  ...
}:
let
  ir = admitted.inspector.facts;
  irOut = withdrawn.inspector.facts;

  # Occurrences, not lines: `builtins.split` returns the separators as singleton LISTS, so counting
  # them counts matches. A line count would read 1 for a renderer emitting every edge on one line.
  occ = needle: hay: builtins.length (builtins.filter builtins.isList (builtins.split needle hay));

  mermaid = admitted.inspector.render.mermaid;
  dot = admitted.inspector.render.dot;

  lines = s: builtins.filter (l: builtins.isString l && l != "") (builtins.split "\n" s);

  # ★ A PICTURE OF A GRAPH IS RIGHT WHEN IT CAN BE READ BACK AS THAT GRAPH. The source is parsed the
  # way mermaid reads it: a node line binds a handle to a label, an edge line joins two handles, and
  # a label's entities decode (`#quot;` and the rest; `\<b></b>n` is the two characters `\n`). Two
  # ids folded onto one handle read back as one node; an unescaped `"` reads back as nothing.
  # The sigil is built, never written: a `#` in a string literal blinds this repository's comment-strip scans.
  sigil = builtins.fromJSON "\"\\u0023\"";
  decodeMermaid =
    builtins.replaceStrings
      [
        "${sigil}35;"
        "${sigil}quot;"
        "${sigil}lt;"
        "${sigil}gt;"
        "${sigil}amp;"
        "${sigil}96;"
        "\\<b></b>n"
        "${sigil}37;"
        "<b></b>$"
        "<b></b>:"
      ]
      [
        sigil
        "\""
        "<"
        ">"
        "&"
        "`"
        "\\n"
        "%"
        "$"
        ":"
      ];
  readMermaid =
    src:
    let
      nodeHits = builtins.filter (m: m != null) (
        map (builtins.match "  ([^ ]+)\\[\"([^\"]*)\"]") (lines src)
      );
      # The id is the label's text before the `<br/>` that opens the kind; an id's own `<` is an entity.
      unquote =
        t:
        let
          q = builtins.match "\"(.*)\"" t;
        in
        if q == null then t else builtins.head q;
      idOf = label: builtins.head (builtins.split "<br/>" label);
      byHandle = builtins.listToAttrs (
        map (m: {
          name = builtins.elemAt m 0;
          value = decodeMermaid (idOf (builtins.elemAt m 1));
        }) nodeHits
      );
      edgeHits = builtins.filter (m: m != null) (
        map (builtins.match "  ([^ ]+) (-->|-\\.->)\\|(\"[^\"]*\"|[^|]*)\\| ([^ ]+)") (lines src)
      );
    in
    {
      handles = map (m: builtins.elemAt m 0) nodeHits;
      ids = builtins.attrValues byHandle;
      edges = map (
        m:
        "${
          byHandle.${builtins.elemAt m 0} or "?"
        } ${builtins.elemAt m 1}${decodeMermaid (unquote (builtins.elemAt m 2))} ${
          byHandle.${builtins.elemAt m 3} or "?"
        }"
      ) edgeHits;
    };

  # ★ EVERY ID MERMAID'S ID LEXER REFUSES OR RE-READS, AND EVERY PAIR THE OLD HANDLE FOLDED. Measured
  # against mermaid-cli 11.17: `/` is accepted, and `end`, `graph`, `style`, `"`, `@`, `|`, `(` are
  # not; `;` and a newline split one node into two. `ghost` is an endpoint no node record lists.
  hostileIds = [
    "a-b"
    "a_b"
    "a.b"
    "a:b"
    "a b"
    "root:r/box:b"
    "end"
    "a\"b"
    "a${sigil}quot;b"
    "p\\nq"
    "x<y>"
    "s;t"
    "a&amp;b"
    ""
  ];
  hostile = {
    nodes = map (id: {
      inherit id;
      kind = "k";
    }) hostileIds;
    edges = [
      {
        src = "a-b";
        dst = "a_b";
        label = "l|m";
        origin.kind = "declaration";
      }
      {
        src = "end";
        dst = "ghost";
        label = "l\"m";
        origin.kind = "rule";
      }
    ];
  };
  hostileAll = lib.sort builtins.lessThan (hostileIds ++ [ "ghost" ]);

  # DOT's quoted string reads `\"` and a LABEL reads every backslash escape (`\n` a line break, `\N`
  # the node's name); `\\` is one backslash. Graphviz then decodes HTML entities in the label.
  decodeDot =
    s:
    builtins.replaceStrings [ "&amp;" ] [ "&" ] (
      lib.concatStrings (
        map (
          p: if builtins.isList p then (if builtins.head p == "n" then "\n" else builtins.head p) else p
        ) (builtins.split "\\\\(.)" s)
      )
    );
  dotNodeLabels =
    src:
    map (m: decodeDot (builtins.elemAt m 2)) (
      builtins.filter (m: m != null) (
        map (builtins.match "  \"((\\\\.|[^\"\\\\])*)\" \\[label=\"((\\\\.|[^\"\\\\])*)\"];") (lines src)
      )
    );

  # THE RED ARM, BUILT: every edge claims a declaration origin.
  allSolid = ir // {
    edges = map (
      e:
      e
      // {
        origin = {
          kind = "declaration";
          site = "red-arm";
        };
      }
    ) ir.edges;
  };
in
{
  flake.tests.render = {
    test-mermaid-dashes-exactly-the-rule-edges = {
      expr = {
        dotted = occ "-\\.->" (mermaid ir);
        solid = occ "-->" (mermaid ir);
      };
      expected = {
        dotted = 2;
        solid = 12;
      };
    };

    test-withdrawing-the-rule-leaves-one-dashed-edge = {
      expr = {
        dotted = occ "-\\.->" (mermaid irOut);
        solid = occ "-->" (mermaid irOut);
      };
      expected = {
        dotted = 1;
        solid = 12;
      };
    };

    # ── THE RED ARM, IN THE SAME RUN ──
    test-red-arm-all-edges-solid-loses-every-dash = {
      expr = {
        dotted = occ "-\\.->" (mermaid allSolid);
        solid = occ "-->" (mermaid allSolid);
      };
      expected = {
        dotted = 0;
        # The solid count RISES to the whole edge set — a renderer that emitted nothing would read 0
        # here too, and this is what tells the two apart.
        solid = 14;
      };
    };

    # Read back through the handles, so the cell names nodes by id and never by a handle's spelling.
    test-the-rule-edge-is-dashed-by-name-not-by-position = {
      expr = builtins.filter (e: occ "-\\.->" e == 1) (readMermaid (mermaid ir)).edges;
      expected = [
        "hemony -.->enrolled full-circle"
        "hemony -.->rings bourdon"
      ];
    };

    # ── THE HANDLE AND THE LABEL (den-hoag-0w06f) — the picture reads back as the IR's graph ──
    test-mermaid-handles-are-injective = {
      expr =
        let
          r = readMermaid (mermaid hostile);
        in
        {
          handles = builtins.length (lib.unique r.handles);
          nodeLines = builtins.length r.handles;
        };
      expected = {
        handles = 15;
        nodeLines = 15;
      };
    };

    test-mermaid-labels-read-back-as-the-ids = {
      expr = lib.sort builtins.lessThan (readMermaid (mermaid hostile)).ids;
      expected = hostileAll;
    };

    test-mermaid-edges-read-back-as-the-ir-edges = {
      expr = (readMermaid (mermaid hostile)).edges;
      expected = [
        "a-b -->l|m a_b"
        "end -.->l\"m ghost"
      ];
    };

    # The fragment mermaid-cli 11.17 parses for every probed id: a handle `n<i>`, a label in `"…"`
    # holding no `"`. A line outside it is a line the parser may refuse or re-read.
    test-mermaid-every-line-is-in-the-accepted-fragment = {
      expr = builtins.filter (
        l:
        l != "flowchart LR"
        && builtins.match "  n[0-9]+\\[\"[^\"]*\"]" l == null
        && builtins.match "  n[0-9]+ (-->|-\\.->)\\|\"[^\"]*\"\\| n[0-9]+" l == null
      ) (lines (mermaid hostile));
      expected = [ ];
    };

    test-dot-labels-read-back-as-the-ids = {
      expr = dotNodeLabels (dot hostile);
      expected = map (id: "${id}\nk") hostileIds ++ [ "ghost" ];
    };

    test-dot-dashes-exactly-the-rule-edges = {
      expr = {
        dashed = occ "style=dashed" (dot ir);
        edges = occ "->" (dot ir);
      };
      expected = {
        dashed = 2;
        edges = 14;
      };
    };

    test-red-arm-dot-all-edges-solid = {
      expr = occ "style=dashed" (dot allSolid);
      expected = 0;
    };

    # ★ THE IR CARRIES A gen-graph VALUE AND A GRAPH HOLDS ACCESSORS, so `toJSON` of the whole IR
    # aborts with "cannot convert a function to JSON". The JSON renderer projects, which is what
    # makes it total over every IR this library produces.
    test-json-renders-and-round-trips-the-figures = {
      expr =
        let
          back = builtins.fromJSON (admitted.inspector.render.json ir);
        in
        {
          nodes = builtins.length back.nodes;
          edges = builtins.length back.edges;
          origins = builtins.length (builtins.attrNames back.origins);
          labels = back.labels;
        };
      expected = {
        nodes = 14;
        edges = 14;
        origins = 14;
        labels = [
          "absorbs"
          "admits"
          "enrolled"
          "housed"
          "hung"
          "rings"
        ];
      };
    };

    # The renderers read the IR and never the scope: a filtered IR renders, and renders SMALLER.
    test-a-filtered-ir-renders-without-a-scope = {
      expr = occ "-->" (
        mermaid (
          ir
          // {
            edges = [ ];
            nodes = [ ];
          }
        )
      );
      expected = 0;
    };
  };
}
