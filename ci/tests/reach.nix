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
# the node set reading its full count at exit 0 and reds only at the first APPLICATION of an
# accessor. Every cell below therefore applies the walk rather than reading the graph's spine.
{
  admitted,
  withdrawn,
  genInspect,
  genScope,
  reachFrom,
  ...
}:
let
  inherit (genScope) wfl;
  reach = ir: reachFrom ir (wfl.star (wfl.lit "rings"));
  # `alt` takes a LIST of patterns, not two arguments — its own ACI normalization flattens nested
  # alternatives, dedups and sorts, which is only expressible over a list.
  ringers =
    ir:
    reachFrom ir (wfl.star (
      wfl.alt [
        (wfl.lit "enrolled")
        (wfl.lit "rings")
      ]
    )) "hemony";
  irIn = admitted.inspector.facts;
  irOut = withdrawn.inspector.facts;
  # One step from `from` under each of the walk's two labels, resolved over the lifted scope.
  step =
    ir: from:
    builtins.listToAttrs (
      map
        (l: {
          name = l;
          value = reachFrom ir (wfl.lit l) from;
        })
        [
          "enrolled"
          "rings"
        ]
    );
in
{
  flake.tests.reach = {
    test-the-rule-edge-is-walkable = {
      expr = reach irIn "hemony";
      expected = [
        "bourdon"
        "hemony"
      ];
    };

    test-withdrawing-the-rule-leaves-only-the-origin-node = {
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
    # The wrong `perLabel` shape reds HERE and nowhere earlier: one step per label, resolved.
    test-the-labeled-walk-applies = {
      expr = step irIn "hemony";
      expected = {
        enrolled = [
          "chiming"
          "full-circle"
        ];
        rings = [ "bourdon" ];
      };
    };

    test-the-withdrawn-walk-applies-and-loses-one-edge = {
      expr = step irOut "hemony";
      expected = {
        enrolled = [
          "chiming"
          "full-circle"
        ];
        rings = [ ];
      };
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

    # The lifted scope's node set is the IR's: every edge endpoint here is a registered node.
    # THE FACADE IS GONE (den-hoag-gayc U2d). The lifted scope carried the IR's `nodes` and a
    # `labeledEdges` accessor beside it for gen-demo's pre-migration readers; it carries neither now,
    # so a reader of the gen-graph record shape fails at the read rather than being served.
    test-the-lifted-scope-carries-no-labeled-record = {
      expr = {
        nodes = irIn.graph ? nodes;
        labeledEdges = irIn.graph ? labeledEdges;
      };
      expected = {
        nodes = false;
        labeledEdges = false;
      };
    };

    test-the-lifted-scope-holds-the-ir-node-set = {
      expr = builtins.length irIn.graph.allNodeIds;
      expected = 14;
    };

    # ── LIFT EQUIVALENCE, WITH ITS PLANTED CONTROL (design §5.4) ──
    # The calculus's answer over the lifted scope equals an independent closure of the IR's own edge
    # list, from every node. The closure is `genericClosure` over `ir.edges` and shares nothing with
    # the lift. The planted arm lifts the same IR with the `rings` edge out of `hemony` dropped and
    # must DIFFER from that closure, so the equality is shown to discriminate rather than to hold of
    # any pair of answers.
    test-the-lifted-walk-equals-the-ir-edge-closure-and-a-planted-edge-differs = {
      expr =
        let
          anyLabel = wfl.star (wfl.alt (map wfl.lit irIn.labels));
          closure =
            ir: from:
            builtins.sort builtins.lessThan (
              map (x: x.key) (
                builtins.genericClosure {
                  startSet = [ { key = from; } ];
                  operator = x: map (e: { key = e.dst; }) (builtins.filter (e: e.src == x.key) ir.edges);
                }
              )
            );
          ids = map (n: n.id) irIn.nodes;
          planted = genInspect.fromGraph { } {
            nodes = ids;
            perLabel = builtins.listToAttrs (
              map (l: {
                name = l;
                value =
                  id:
                  map (e: e.dst) (
                    builtins.filter (
                      e: e.label == l && e.src == id && !(e.src == "hemony" && e.label == "rings")
                    ) irIn.edges
                  );
              }) irIn.labels
            );
          };
        in
        {
          lifted = builtins.all (n: reachFrom irIn anyLabel n == closure irIn n) ids;
          planted = reachFrom planted.facts anyLabel "hemony" == closure irIn "hemony";
        };
      expected = {
        lifted = true;
        planted = false;
      };
    };

    # `parent` and `imports` are the calculus's own letters, so a label spelled either way is lifted
    # onto containment and the import relation. An `edges-parent` attribute would be read by nothing
    # and the walk would answer `[ "a" ]` at exit 0.
    test-a-label-spelled-parent-or-imports-is-walked = {
      expr =
        let
          g = genInspect.fromGraph { } {
            nodes = [
              "a"
              "b"
              "c"
            ];
            perLabel = {
              parent = id: if id == "a" then [ "b" ] else [ ];
              imports =
                id:
                if id == "b" then
                  [
                    "c"
                  ]
                else
                  [ ];
            };
          };
        in
        {
          parent = reachFrom g.facts (wfl.star (wfl.lit "parent")) "a";
          imports = reachFrom g.facts (wfl.star (wfl.lit "imports")) "b";
          both = reachFrom g.facts (wfl.star (
            wfl.alt [
              (wfl.lit "parent")
              (wfl.lit "imports")
            ]
          )) "a";
        };
      expected = {
        parent = [
          "a"
          "b"
        ];
        imports = [
          "b"
          "c"
        ];
        both = [
          "a"
          "b"
          "c"
        ];
      };
    };
  };
}
