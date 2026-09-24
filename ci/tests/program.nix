# THE PROGRAM ROUTE — `reaches` AND `why` ON gen-program'S ENGINE.
#
# C1  recursion answers instead of being refused.
# C2  ★ recursion AGREES ACROSS FRAGMENTS, the design's recursion cell. Per question Q(via, src),
#     three arms in one run: E, the engine (`reaches`); G, gate 1's graph walk (`regex.star`); J_k,
#     the non-recursive fragment — `{src}` plus the 1..k-hop self-JOIN chains over `edge`. Asserted:
#     E = G, every J_k ⊆ E, and J_4 = E (Kleene iteration of the least fixpoint saturates; the
#     fleet's longest shortest path is 3).
#     ★ EVERY DEPTH-1 QUESTION IS BLIND TO A ROUTE WITH NO RECURSION, and so is (`*`, hemony) in the
#     WITHDRAWN state. The questions of depth 2 or more below are in the ADMITTED state, and they are
#     what makes the cell red against a one-hop stub.
#     ★ THE DANGLING ENDPOINT: an edge whose endpoint is no registered node. The IR admits it and the
#     walk follows it, so E must too — the relata domain is the node ids plus every edge endpoint.
# C3  `why`: one-step witnesses under the model, one construction shared with the edge's origin.
# C-1 PUSHDOWN PARITY on the two shapes where a per-table pushdown answered wrong at exit 0: the
#     answer through `query` equals the same text run over the UNPRUNED relation.
# C7  the gen-demo C25 shape: a two-hop chain the non-recursive fragment cannot see.
{
  admitted,
  withdrawn,
  genInspect,
  genGraph,
  genPrelude,
  ...
}:
let
  sort = genPrelude.sort builtins.lessThan;
  dsts = rows: sort (map (r: r.dst) rows);

  reachesOf =
    insp: via: src:
    dsts (insp.query "SELECT dst FROM reaches WHERE src = '${src}' AND via = '${via}'");

  walk =
    facts: via: src:
    sort (
      genGraph.query {
        graph = facts.graph;
        from = src;
        follow = genGraph.regex.star (
          if via == "*" then
            genGraph.regex.alt (map genGraph.regex.lit facts.labels)
          else
            genGraph.regex.lit via
        );
      }
    );

  chain =
    via: src: i:
    let
      a = n: "e${toString n}";
      idx = genPrelude.genList (n: n + 1) i;
      joins = genPrelude.concatMapStringsSep " " (
        n: "JOIN edge ${a n} ON ${a (n - 1)}.dst = ${a n}.src"
      ) (builtins.tail idx);
      labels =
        if via == "*" then
          ""
        else
          genPrelude.concatMapStringsSep "" (n: " AND ${a n}.label = '${via}'") idx;
    in
    "SELECT ${a i}.dst FROM edge e1 ${joins} WHERE e1.src = '${src}'${labels}";

  nonrec =
    insp: via: src: k:
    sort (
      genPrelude.unique (
        [ src ]
        ++ builtins.concatMap (i: builtins.concatMap builtins.attrValues (insp.query (chain via src i))) (
          genPrelude.genList (n: n + 1) k
        )
      )
    );

  agreement =
    insp: via: src:
    let
      E = reachesOf insp via src;
      J = map (nonrec insp via src) [
        1
        2
        3
        4
      ];
    in
    {
      inherit E;
      engineEqWalk = E == walk insp.facts via src;
      nonrecContained = builtins.all (j: builtins.all (x: builtins.elem x E) j) J;
      saturatesToEngine = genPrelude.last J == E;
      firstHopSaturated = builtins.head J == E;
    };

  agrees = E: firstHopSaturated: {
    inherit E firstHopSaturated;
    engineEqWalk = true;
    nonrecContained = true;
    saturatesToEngine = true;
  };

  # ── FIXTURES ──
  cycle = genInspect.fromGraph {
    nodes = [
      "second"
      "third"
      "treble"
    ];
    perLabel.changes =
      n:
      {
        treble = [ "second" ];
        second = [
          "treble"
          "third"
        ];
      }
      .${n} or [ ];
  };

  danglingDeclared = genInspect.fromGraph {
    nodes = [
      "a"
      "b"
    ];
    perLabel.l =
      n:
      {
        a = [ "b" ];
        b = [ "ghost" ];
      }
      .${n} or [ ];
  };

  # The same endpoint, derived by a policy rule rather than declared.
  danglingPolicy =
    let
      ta = [
        "l:a:b"
        "l:b:ghost"
      ];
    in
    genInspect.mkInspector {
      register.v = {
        a = { };
        b = { };
      };
      relations.l.a = [ "b" ];
      program.rules = [
        {
          head = "l:b:ghost";
          pos = [ "l:a:b" ];
        }
      ];
      model = {
        trueAtoms = ta;
        verdict = x: if builtins.elem x ta then "true" else "false";
      };
    };

  # gen-demo C25's three declared edges.
  c25 = genInspect.fromGraph {
    nodes = [
      "damask"
      "faille"
      "grosgrain"
      "pewter"
    ];
    perLabel = {
      tacks =
        n:
        {
          pewter = [ "grosgrain" ];
          grosgrain = [ "damask" ];
        }
        .${n} or [ ];
      gathers = n: { pewter = [ "damask" ]; }.${n} or [ ];
    };
  };

  i = admitted.inspector;
  whyRows = i.query "SELECT src, dst, why FROM reaches WHERE src = 'hemony' AND via = '*'";
  whyOf = dst: (builtins.head (builtins.filter (r: r.dst == dst) whyRows)).why;

  # ── C-1: THE UNPRUNED ARM ──
  # The whole relation, every `(via, src)`, handed to the executor as ONE table for every occurrence:
  # what the query means before any pushdown.
  unpruned =
    text:
    let
      full = builtins.listToAttrs (
        map (r: {
          name = "${r.via}:${r.src}:${r.dst}";
          value = r;
        }) (i.query "SELECT src, dst, via FROM reaches")
      );
    in
    genInspect.evalQuery (i.facts.tables // { reaches = full; }) (genInspect.parseSql text);
  selfJoin = "SELECT r2.dst FROM reaches r1 JOIN reaches r2 ON r1.dst = r2.src WHERE r1.src = 'evensong' AND r1.via = 'hung' AND r2.via = 'rings' ORDER BY r2.dst";
  unqualified = "SELECT r.src, r.dst FROM reaches r JOIN edge e ON r.dst = e.dst WHERE src = 'bourdon' AND via = '*'";
in
{
  flake.tests.program = {
    # ── C1 ──
    test-c1-recursion-answers-in-both-states = {
      expr = {
        admitted = dsts (i.query "SELECT dst FROM reaches WHERE src = 'hemony' AND via = '*' ORDER BY dst");
        withdrawn = dsts (
          withdrawn.inspector.query "SELECT dst FROM reaches WHERE src = 'hemony' AND via = '*' ORDER BY dst"
        );
        # The control, same run: a non-recursive query over the same IR.
        control = i.query "SELECT src, dst FROM edge WHERE label = 'rings'";
      };
      expected = {
        admitted = [
          "bourdon"
          "campanile"
          "chiming"
          "full-circle"
          "hemony"
        ];
        withdrawn = [
          "chiming"
          "full-circle"
          "hemony"
        ];
        control = [
          {
            dst = "bourdon";
            src = "hemony";
          }
        ];
      };
    };

    test-c1-reaches-joins-like-any-table = {
      expr = i.query "SELECT t.name, t.weight FROM reaches r JOIN tocsin t ON r.dst = t.name WHERE r.src = 'hemony' AND r.via = '*'";
      expected = [
        {
          name = "bourdon";
          weight = "heavy";
        }
      ];
    };

    # ── C2 ──
    test-c2-depth-one-questions-agree = {
      expr = {
        ringsAdmitted = agreement i "rings" "hemony";
        ringsWithdrawn = agreement withdrawn.inspector "rings" "hemony";
        anyWithdrawn = agreement withdrawn.inspector "*" "hemony";
        mears = agreement i "*" "mears";
      };
      expected = {
        ringsAdmitted = agrees [ "bourdon" "hemony" ] true;
        ringsWithdrawn = agrees [ "hemony" ] true;
        anyWithdrawn = agrees [ "chiming" "full-circle" "hemony" ] true;
        mears = agrees [ "mears" ] true;
      };
    };

    # ★ THE QUESTIONS A ONE-HOP ROUTE FAILS: depth ≥ 2, in the ADMITTED state. `firstHopSaturated`
    # false is what says the second hop is load-bearing here.
    test-c2-depth-two-or-more-questions-agree-in-the-admitted-state = {
      expr = {
        anyHemony = agreement i "*" "hemony";
        anyEvensong = agreement i "*" "evensong";
      };
      expected = {
        anyHemony = agrees [ "bourdon" "campanile" "chiming" "full-circle" "hemony" ] false;
        anyEvensong = agrees [ "bourdon" "campanile" "chiming" "evensong" "full-circle" ] false;
      };
    };

    # A cycle: the engine's answer is finite and agrees with the walk.
    test-c2-a-cycle-agrees = {
      expr = agreement cycle "changes" "treble";
      expected = agrees [ "second" "third" "treble" ] false;
    };

    # ★ C-2: the dangling endpoint, declared and policy-derived, on a named label and on `*`.
    test-c2-a-dangling-endpoint-agrees = {
      expr = {
        declaredL = agreement danglingDeclared "l" "a";
        declaredAny = agreement danglingDeclared "*" "a";
        policyAny = agreement danglingPolicy "*" "a";
      };
      expected = {
        declaredL = agrees [ "a" "b" "ghost" ] false;
        declaredAny = agrees [ "a" "b" "ghost" ] false;
        policyAny = agrees [ "a" "b" "ghost" ] false;
      };
    };

    # ── C3 ──
    test-c3-why-on-a-reaches-row-is-its-one-step-witness = {
      expr = whyOf "bourdon";
      expected = {
        kind = "query";
        derivations = [
          {
            rule = {
              head = "reaches:*:hemony:bourdon";
              pos = [
                "reaches:*:hemony:hemony"
                "rings:hemony:bourdon"
              ];
              neg = [ ];
            };
            fired = [
              {
                atom = "reaches:*:hemony:hemony";
                verdict = "true";
                sign = "pos";
              }
              {
                atom = "rings:hemony:bourdon";
                verdict = "true";
                sign = "pos";
              }
            ];
          }
        ];
      };
    };

    test-c3-several-witnesses-and-the-vacuous-base-case = {
      expr = {
        chiming = builtins.length (whyOf "chiming").derivations;
        self = (whyOf "hemony").derivations;
        viaEntry = i.why "reaches:*:hemony:chiming" == whyOf "chiming";
      };
      expected = {
        chiming = 2;
        self = [
          {
            rule = {
              head = "reaches:*:hemony:hemony";
              pos = [ ];
              neg = [ ];
            };
            fired = [ ];
          }
        ];
        viaEntry = true;
      };
    };

    # Parity: every row has a witness, and every fired literal re-derives its sign under the model.
    test-c3-every-reaches-witness-re-derives-under-the-model = {
      expr = builtins.all (
        r:
        r.why.derivations != [ ]
        && builtins.all (
          d: builtins.all (l: l.verdict == (if l.sign == "pos" then "true" else "false")) d.fired
        ) r.why.derivations
      ) whyRows;
      expected = true;
    };

    # The chain closes: every edge atom a reaches witness names is an IR key, whose own `why` is its
    # origin — so a reader goes from a reachability row, to the edge, to the policy rule.
    test-c3-the-why-chain-closes-onto-ir-origins = {
      expr =
        let
          atoms = genPrelude.unique (
            builtins.concatMap (
              r:
              builtins.concatMap (
                d: builtins.filter (a: builtins.match "[^:]*:[^:]*:[^:]*" a != null) (map (l: l.atom) d.fired)
              ) r.why.derivations
            ) whyRows
          );
        in
        {
          n = builtins.length atoms;
          allKeyed = builtins.all (a: i.facts.origins ? ${a}) atoms;
          rings = (i.why "rings:hemony:bourdon").kind;
          column = map (r: r.why) (i.query "SELECT why FROM edge WHERE label = 'rings'");
        };
      expected = {
        n = 6;
        allKeyed = true;
        rings = "policy";
        column = [ i.facts.origins."rings:hemony:bourdon" ];
      };
    };

    # ── C-1: PUSHDOWN PARITY, pruned = unpruned, with the values pinned ──
    test-c-1-a-self-join-of-reaches-is-grounded-per-occurrence = {
      expr = {
        pruned = i.query selfJoin;
        unpruned = unpruned selfJoin;
      };
      expected = {
        pruned = [
          { dst = "bourdon"; }
          { dst = "evensong"; }
        ];
        unpruned = [
          { dst = "bourdon"; }
          { dst = "evensong"; }
        ];
      };
    };

    test-c-1-an-unqualified-column-another-item-carries-is-not-pushed = {
      expr = {
        pruned = i.query unqualified;
        unpruned = unpruned unqualified;
        rows = builtins.length (i.query unqualified);
      };
      expected = {
        pruned = unpruned unqualified;
        unpruned = i.query unqualified;
        rows = 10;
      };
    };

    # ── C7: THE gen-demo C25 SHAPE ──
    test-c7-recursion-adds-the-second-hop-over-c25 = {
      expr = {
        E = dsts (c25.query "SELECT dst FROM reaches WHERE src = 'pewter' AND via = 'tacks' ORDER BY dst");
        G = walk c25.facts "tacks" "pewter";
        edgeOnly = map (r: r.dst) (
          c25.query "SELECT dst FROM edge WHERE src = 'pewter' AND label = 'tacks'"
        );
        failleFromOthers = builtins.filter (r: r.dst == "faille" && r.src != "faille") (
          c25.query "SELECT src, dst FROM reaches WHERE via = '*'"
        );
        damaskWhy = map (d: d.rule.pos) (c25.why "reaches:tacks:pewter:damask").derivations;
      };
      expected = {
        E = [
          "damask"
          "grosgrain"
          "pewter"
        ];
        G = [
          "damask"
          "grosgrain"
          "pewter"
        ];
        edgeOnly = [ "grosgrain" ];
        failleFromOthers = [ ];
        damaskWhy = [
          [
            "reaches:tacks:pewter:grosgrain"
            "tacks:grosgrain:damask"
          ]
        ];
      };
    };
  };
}
