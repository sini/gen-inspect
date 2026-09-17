# CELL 1 — THE IR, AND IT ASSERTS THE DOOR AS WELL AS THE FIGURES.
#
# ★★ THE LOAD-BEARING ASSERTION IS `trueAtoms ⊆ attrNames origins`, SCOPED TO EDGE LABELS. Every
# model-true atom at a label the subject publishes is an IR key, or `materialize` refuses BY NAME.
# It is CONTAINMENT and not equality because the IR also holds twelve declared edges the program
# never mentions, and it is SCOPED BY LABEL because an atom at a label the subject does not publish
# — the `silenced` control atom — names no edge.
#
# ★ FORCE THE WHOLE IR, DO NOT COUNT IT. `builtins.length` forces the list SPINE and not one origin,
# so a stray-atom build reads its full edge count at exit 0 under a count assertion; `deepSeq` is
# what makes it exit 1. Every cell below that names a figure therefore reads it off a `deepSeq`-ed
# IR rather than off an unforced one — `test-the-whole-ir-forces` is the cell that does the forcing
# and the rest read figures from the value it forced.
{ admitted, withdrawn, ... }:
let
  ir = admitted.inspector.facts;
  irOut = withdrawn.inspector.facts;

  # The serializable projection: the IR carries a gen-graph value, and a graph holds ACCESSORS, so a
  # deep force of the whole IR is a force of everything except what `deepSeq` cannot enter anyway.
  forced =
    x:
    builtins.deepSeq {
      inherit (x)
        nodes
        edges
        tables
        kinds
        labels
        origins
        ;
    } true;

  originKind = k: x: builtins.length (builtins.filter (e: e.origin.kind == k) x.edges);
  keysOf =
    x: map (e: "${e.label}:${e.src}:${e.dst}") (builtins.filter (e: e.origin.kind == "policy") x.edges);
in
{
  flake.tests.ir = {
    # THE FORCE. This is the cell the ★ above is about: it is not a figure, it is the reach.
    test-the-whole-ir-forces = {
      expr = forced ir;
      expected = true;
    };
    test-the-withdrawn-ir-forces = {
      expr = forced irOut;
      expected = true;
    };

    test-nodes-and-kinds = {
      expr = {
        nodes = builtins.length ir.nodes;
        kinds = builtins.attrNames ir.kinds;
      };
      expected = {
        nodes = 14;
        kinds = [
          "belfry"
          "chime"
          "peal"
          "ringer"
          "tocsin"
        ];
      };
    };

    test-edges-split-by-origin = {
      expr = {
        total = builtins.length ir.edges;
        declaration = originKind "declaration" ir;
        policy = originKind "policy" ir;
        origins = builtins.length (builtins.attrNames ir.origins);
      };
      expected = {
        total = 14;
        declaration = 12;
        policy = 2;
        origins = 14;
      };
    };

    # ★★ `enrolled` IS BOTH A DECLARED AND A DERIVED LABEL, AND THAT IS THE POINT. `hemony` is
    # declared enrolled in `chiming` and DERIVED enrolled in `full-circle`; the IR carries both under
    # one label, each with its own origin. A construction filtering policy edges through a
    # hand-written label list drops the derived one WITH NO DIAGNOSTIC — the defect this cell's red
    # arm reproduces, and `ci/tests-error.nix` holds the refusal that now catches it.
    test-the-policy-keys-include-a-derived-edge-at-a-declared-label = {
      expr = keysOf ir;
      expected = [
        "enrolled:hemony:full-circle"
        "rings:hemony:bourdon"
      ];
    };

    test-every-edge-carries-an-origin-kind = {
      expr = builtins.all (e: e ? origin && e.origin ? kind) ir.edges;
      expected = true;
    };

    # THE CONTAINMENT, ASSERTED RATHER THAN INFERRED FROM THE COUNTS. The counts above would agree
    # with a build whose origins keyed twelve declared edges and two arbitrary strings.
    test-every-model-true-atom-at-a-published-label-is-an-ir-key = {
      expr = builtins.filter (
        a:
        let
          e = admitted.inspector.facts;
          p = builtins.filter builtins.isString (builtins.split ":" a);
        in
        builtins.length p == 3 && builtins.elem (builtins.head p) e.labels && !(e.origins ? ${a})
      ) admitted.model.trueAtoms;
      expected = [ ];
    };

    test-labels-and-tables = {
      expr = {
        inherit (ir) labels;
        tables = builtins.attrNames ir.tables;
        tocsinColumns = builtins.attrNames ir.tables.tocsin.bourdon;
      };
      expected = {
        labels = [
          "absorbs"
          "admits"
          "enrolled"
          "housed"
          "hung"
          "rings"
        ];
        tables = [
          "belfry"
          "chime"
          "edge"
          "peal"
          "ringer"
          "tocsin"
        ];
        tocsinColumns = [
          "belfry"
          "kind"
          "name"
          "weight"
        ];
      };
    };

    # ── THE SECOND ARM. The policy's conclusion withdrawn, and the fixture is otherwise identical. ──
    test-withdrawing-the-policy-drops-exactly-one-edge = {
      expr = {
        total = builtins.length irOut.edges;
        declaration = originKind "declaration" irOut;
        policy = originKind "policy" irOut;
        origins = builtins.length (builtins.attrNames irOut.origins);
        keys = keysOf irOut;
        ringsPresent = irOut.origins ? "rings:hemony:bourdon";
        nodesUnchanged = builtins.length irOut.nodes;
        labelsUnchanged = irOut.labels;
      };
      expected = {
        total = 13;
        declaration = 12;
        policy = 1;
        origins = 13;
        keys = [ "enrolled:hemony:full-circle" ];
        ringsPresent = false;
        nodesUnchanged = 14;
        labelsUnchanged = [
          "absorbs"
          "admits"
          "enrolled"
          "housed"
          "hung"
          "rings"
        ];
      };
    };
  };
}
