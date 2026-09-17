# THE PROGRAMMATIC API — IR + a gen-select selector → IR′, AND THE RESULT IS AN IR.
#
# ★ THE PROVENANCE-PROPAGATION SEAM IS WHAT THIS CELL GUARDS. `origins` is a FIELD of the IR rather
# than a derived accessor precisely so a filter can carry it forward without recomputing from the
# model; gate 3 needs provenance to survive `select` and `compile`. An IR′ that dropped origins — or
# that rebuilt them from a model it no longer carries — closes that seam, and nothing else in the
# suite would notice.
#
# THE VOCABULARY IS NOT FILTERED. `labels` and `kinds` are the subject's published vocabulary and the
# door's known sets. Narrowing them with the node set would make a query's own result the authority
# on which names exist, so a `WHERE label = 'rings'` over an IR′ that kept no `rings` edge would
# refuse the name it had just been asked about. That is asserted, not assumed.
{
  admitted,
  genSelect,
  ...
}:
let
  i = admitted.inspector;
  ir = i.facts;

  ringersOnly = i.select (genSelect.attrs { kind = "ringer"; });
  heavy = i.select (genSelect.attrs { weight = "heavy"; });
  everything = i.select genSelect.star;
in
{
  flake.tests.select = {
    test-a-selector-narrows-the-node-set = {
      expr = map (n: n.id) ringersOnly.nodes;
      expected = [
        "hemony"
        "mears"
        "rudhall"
      ];
    };

    # AN EDGE SURVIVES IFF BOTH ENDPOINTS DO. A dangling edge would make the IR′ describe a graph
    # whose target is not in it, and gen-graph's labeled contract is node-set-total.
    test-an-edge-survives-only-with-both-endpoints = {
      expr = {
        edges = builtins.length ringersOnly.edges;
        origins = builtins.length (builtins.attrNames ringersOnly.origins);
      };
      expected = {
        edges = 0;
        origins = 0;
      };
    };

    # ★ ORIGINS ARE CARRIED FORWARD, NOT RECOMPUTED — the gate-3 seam. A selection that keeps the
    # policy edge keeps its derivation, whole.
    test-a-kept-policy-edge-keeps-its-whole-origin = {
      expr =
        let
          keep = i.select (
            genSelect.when (
              id: _:
              builtins.elem id [
                "hemony"
                "bourdon"
                "full-circle"
                "chiming"
              ]
            )
          );
          o = keep.origins."rings:hemony:bourdon";
        in
        {
          kind = o.kind;
          derivations = builtins.length o.derivations;
          fired = builtins.length (builtins.head o.derivations).fired;
          identicalToTheSourceIr = o == ir.origins."rings:hemony:bourdon";
        };
      expected = {
        kind = "policy";
        derivations = 1;
        fired = 3;
        identicalToTheSourceIr = true;
      };
    };

    test-the-vocabulary-is-not-narrowed-by-a-selection = {
      expr = {
        labels = ringersOnly.labels == ir.labels;
        kinds = builtins.attrNames ringersOnly.kinds == builtins.attrNames ir.kinds;
      };
      expected = {
        labels = true;
        kinds = true;
      };
    };

    # THE RESULT IS AN IR, so it renders and it walks.
    test-the-result-is-an-ir-and-renders = {
      expr =
        let
          out = i.render.mermaid ringersOnly;
        in
        builtins.length (builtins.filter builtins.isList (builtins.split "flowchart LR" out));
      expected = 1;
    };

    test-the-result-is-an-ir-and-walks = {
      expr = ringersOnly.graph.labeledEdges "hemony";
      expected = [ ];
    };

    # THE IDENTITY ARM. Without it, every figure above is equally satisfied by a `select` that
    # returns the empty IR for any selector.
    test-the-universal-selector-keeps-everything = {
      expr = {
        nodes = builtins.length everything.nodes;
        edges = builtins.length everything.edges;
        origins = builtins.length (builtins.attrNames everything.origins);
      };
      expected = {
        nodes = 14;
        edges = 14;
        origins = 14;
      };
    };

    # An attribute selector reaching the SPLATTED attrs, not just the injected `kind`/`name`.
    test-a-selector-reads-the-splatted-attributes = {
      expr = map (n: n.id) heavy.nodes;
      expected = [
        "angelus"
        "bourdon"
      ];
    };
  };
}
