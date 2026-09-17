# CELL 4 — REACHABILITY, THE GRAPH WALK IN TWO STATES.
#
# ★ IT IS ONE ARM AT THIS GATE, NOT TWO, AND SAYING OTHERWISE WOULD SPECIFY AN UNBUILDABLE CELL.
# The selector layer is the guard sublanguage and has NO fixpoint and NO comprehension — measured,
# gen-select's constructors yield nine tags and `sel ? fix` is false — so reachability is not
# expressible there and a selector arm does not exist to agree with. THE CROSS-FRAGMENT AGREEMENT
# PROPERTY BELONGS TO GATE 2, where the program layer supplies the genuine second arm.
#
# What makes the single arm safe is the SECOND STATE rather than a second fragment: the withdrawn
# answer `["hemony"]` is what an empty graph also returns, so the cell is only informative because
# the admitted arm sits beside it in the same run.
#
# `mears` is outside every path and must not appear. It is asserted rather than left implicit: a
# walk that returned every node would satisfy both figures above if only their lengths were read.
#
# ★ CELL 5's SUBJECT LIVES HERE TOO — THE WALK MUST BE APPLIED. `perLabel` is an attrset of
# ACCESSORS, label -> (id -> [targets]), and the wrong shape fails LAZILY: a flat edge list leaves
# `nodes` reading its full count at exit 0 and reds only at the first APPLICATION of `labeledEdges`.
# Every cell below therefore applies the walk rather than reading the graph's spine.
{
  admitted,
  withdrawn,
  genGraph,
  ...
}:
let
  reach =
    ir: from:
    genGraph.query {
      graph = ir.graph;
      inherit from;
      follow = genGraph.regex.star (genGraph.regex.lit "rings");
    };
  # `alt` takes a LIST of patterns, not two arguments — its own ACI normalization flattens nested
  # alternatives, dedups and sorts, which is only expressible over a list.
  ringers =
    ir:
    genGraph.query {
      graph = ir.graph;
      from = "hemony";
      follow = genGraph.regex.star (
        genGraph.regex.alt [
          (genGraph.regex.lit "enrolled")
          (genGraph.regex.lit "rings")
        ]
      );
    };
  irIn = admitted.inspector.facts;
  irOut = withdrawn.inspector.facts;
in
{
  flake.tests.reach = {
    test-the-policy-edge-is-walkable = {
      expr = reach irIn "hemony";
      expected = [
        "bourdon"
        "hemony"
      ];
    };

    test-withdrawing-the-policy-leaves-only-the-origin-node = {
      expr = reach irOut "hemony";
      expected = [ "hemony" ];
    };

    # THE NODE OUTSIDE EVERY PATH. Asserted by name, not by a count.
    test-a-node-outside-every-path-is-absent-from-the-walk = {
      expr = {
        admittedHasMears = builtins.elem "mears" (reach irIn "hemony");
        withdrawnHasMears = builtins.elem "mears" (reach irOut "hemony");
        mearsIsANode = builtins.elem "mears" (map (n: n.id) irIn.nodes);
      };
      expected = {
        admittedHasMears = false;
        withdrawnHasMears = false;
        # The live control on the same node: `mears` IS in the graph, so its absence from the walk
        # is a reachability answer and not a missing node.
        mearsIsANode = true;
      };
    };

    # ── THE APPLIED WALK (cell 5) ──
    # The wrong `perLabel` shape reds HERE and nowhere earlier.
    test-the-labeled-walk-applies = {
      expr = irIn.graph.labeledEdges "hemony";
      expected = [
        {
          label = "enrolled";
          target = "chiming";
        }
        {
          label = "enrolled";
          target = "full-circle";
        }
        {
          label = "rings";
          target = "bourdon";
        }
      ];
    };

    test-the-withdrawn-walk-applies-and-loses-one-edge = {
      expr = irOut.graph.labeledEdges "hemony";
      expected = [
        {
          label = "enrolled";
          target = "chiming";
        }
        {
          label = "enrolled";
          target = "full-circle";
        }
      ];
    };

    # ★★ ONE LABEL, TWO ORIGINS, BOTH WALKABLE. `hemony` is DECLARED enrolled in `chiming` and
    # DERIVED enrolled in `full-circle`; the walk crosses both without knowing the difference, which
    # is ADR-0012's single edge list doing its job — the dynamic edge joins the one list and is told
    # apart by its origin, never by living somewhere else.
    test-a-declared-and-a-derived-edge-at-one-label-are-both-walked = {
      expr = ringers irIn;
      expected = [
        "bourdon"
        "chiming"
        "full-circle"
        "hemony"
      ];
    };

    # The node set is carried, which is what makes the global half of gen-graph reachable at all.
    test-the-graph-carries-its-node-set = {
      expr = builtins.length irIn.graph.nodes;
      expected = 14;
    };
  };
}
