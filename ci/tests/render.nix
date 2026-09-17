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
# own fixture [D §3a.5]; this fleet carries TWELVE declared edges and TWO policy edges, so the
# figures here are 2 and 12. Inheriting the cited pair would have red against a correct build.
#
# THE RED ARM IS IN THIS FILE: the same renderer over an IR whose every edge has been relabelled
# `declaration`. The dotted count goes to 0 while the solid count RISES, which is what separates
# "the policy edge lost its style" from "the render produced nothing".
{ admitted, withdrawn, ... }:
let
  ir = admitted.inspector.facts;
  irOut = withdrawn.inspector.facts;

  # Occurrences, not lines: `builtins.split` returns the separators as singleton LISTS, so counting
  # them counts matches. A line count would read 1 for a renderer emitting every edge on one line.
  occ = needle: hay: builtins.length (builtins.filter builtins.isList (builtins.split needle hay));

  mermaid = admitted.inspector.render.mermaid;
  dot = admitted.inspector.render.dot;

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
    test-mermaid-dashes-exactly-the-policy-edges = {
      expr = {
        dotted = occ "-\\.->" (mermaid ir);
        solid = occ "-->" (mermaid ir);
      };
      expected = {
        dotted = 2;
        solid = 12;
      };
    };

    test-withdrawing-the-policy-leaves-one-dashed-edge = {
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

    test-the-policy-edge-is-dashed-by-name-not-by-position = {
      expr = builtins.filter (l: occ "-\\.->" l == 1) (
        builtins.filter builtins.isString (builtins.split "\n" (mermaid ir))
      );
      expected = [
        "  hemony -.->|enrolled| full_circle"
        "  hemony -.->|rings| bourdon"
      ];
    };

    test-dot-dashes-exactly-the-policy-edges = {
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
