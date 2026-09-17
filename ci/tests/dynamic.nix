# CELL 3 — THE DYNAMIC EDGE. TWO ASSERTIONS, AND THE SECOND IS ORIGIN/MODEL PARITY.
#
# (a) THE EDGE IS FOUND BY ITS LABEL, and its origin says a policy produced it and which rule fired.
#
# (b) ★★ EVERY DERIVATION'S `fired` TUPLE RE-DERIVES ITS HEAD'S VERDICT, in the same run that
#     produced the edge: each positive literal reads `"true"` and each negative `"false"` under the
#     model. THIS IS AN ACCEPTANCE CELL AND NOT A GUARANTEE, because it is not a property OF the
#     construction — it is whether the construction is CORRECT. An origin naming a rule that did not
#     fire is nothing to look at, and "why is this edge here" is the whole component.
#
# ★★ A WITNESS IS BODY-CHECKED, NEVER HEAD-MATCHED. Van Gelder, Ross & Schlipf 1991 Def 3.3: p is
# derived iff some rule has head p AND EVERY body literal is true in the model. A head match alone
# reports a rule whose body is FALSE in a field named `fired` — Def 3.1 calls that a WITNESS OF
# UNUSABILITY. The red arm is in this file, built as a real second rule rather than described.
#
# ★ THE WITHDRAWN ARM'S GRAPH ANSWER IS WHAT AN EMPTY GRAPH ALSO RETURNS, so the cell is safe only
# because it carries both arms — which is why the admitted arm sits beside every withdrawn figure.
{
  admitted,
  withdrawn,
  genInspect,
  genProgram,
  ...
}:
let
  ir = admitted.inspector.facts;
  origin = ir.origins."rings:hemony:bourdon";
  derivation = builtins.head origin.derivations;

  verdict = admitted.model.verdict;

  # (b) THE PARITY PREDICATE, over EVERY derivation of EVERY policy edge rather than the one the
  # cell above names. A parity check on a single hand-picked edge is satisfied by a construction
  # that is right once.
  parityBreaches = builtins.concatMap (
    e:
    builtins.concatMap (
      d: builtins.filter (f: f.verdict != (if f.sign == "pos" then "true" else "false")) d.fired
    ) ir.origins."${e.label}:${e.src}:${e.dst}".derivations
  ) (builtins.filter (e: e.origin.kind == "policy") ir.edges);

  # ── THE RED ARM, BUILT. ──
  # A second rule deriving the same head, whose body is FALSE under the model: its negative literal
  # `silenced:hemony:bourdon` is asserted true. A HEAD MATCH reports this rule in a field named
  # `fired`; the body check does not. The two arms are run over the same program in the same
  # evaluation, so what separates them is the predicate and nothing else.
  headMatchProgram = genProgram.program {
    frozen = [
      "hemony"
      "bourdon"
      "full-circle"
      "chiming"
      "rudhall"
      "mears"
      "tenor"
    ];
    declarations = [
      {
        head = "admits:bourdon:full-circle";
        relata = [
          "bourdon"
          "full-circle"
        ];
      }
      {
        head = "silenced:hemony:bourdon";
        relata = [
          "hemony"
          "bourdon"
        ];
      }
      # FIRES: body true under the model.
      {
        head = "rings:hemony:bourdon";
        pos = [ "admits:bourdon:full-circle" ];
        relata = [
          "hemony"
          "bourdon"
        ];
      }
      # DOES NOT FIRE: its negative literal is true, so the body is false. A head match reports it.
      {
        head = "rings:hemony:bourdon";
        pos = [ "admits:bourdon:full-circle" ];
        neg = [ "silenced:hemony:bourdon" ];
        relata = [
          "hemony"
          "bourdon"
        ];
      }
    ];
  };
  headMatchModel = genProgram.model {
    program = headMatchProgram;
    complete = true;
    interpretation = [ ];
  };

  bodied = r: (r.pos or [ ]) != [ ] || (r.neg or [ ]) != [ ];
  headMatched = builtins.filter (
    r: r.head == "rings:hemony:bourdon" && bodied r
  ) headMatchProgram.rules;
  bodyChecked = builtins.filter (
    r:
    r.head == "rings:hemony:bourdon"
    && bodied r
    && builtins.all (a: headMatchModel.verdict a == "true") (r.pos or [ ])
    && builtins.all (a: headMatchModel.verdict a == "false") (r.neg or [ ])
  ) headMatchProgram.rules;
in
{
  flake.tests.dynamic = {
    # ── (a) ──
    test-the-dynamic-edge-is-found-by-its-label = {
      expr = admitted.inspector.query "SELECT src, dst, origin FROM edge WHERE label = 'rings'";
      expected = [
        {
          src = "hemony";
          dst = "bourdon";
          origin = "policy";
        }
      ];
    };

    test-the-origin-names-the-rule-that-fired = {
      expr = {
        kind = origin.kind;
        derivations = builtins.length origin.derivations;
        inherit (derivation) rule;
        fired = derivation.fired;
      };
      expected = {
        kind = "policy";
        derivations = 1;
        rule = {
          head = "rings:hemony:bourdon";
          pos = [
            "enrolled:hemony:full-circle"
            "admits:bourdon:full-circle"
          ];
          neg = [ "silenced:hemony:bourdon" ];
        };
        fired = [
          {
            atom = "enrolled:hemony:full-circle";
            sign = "pos";
            verdict = "true";
          }
          {
            atom = "admits:bourdon:full-circle";
            sign = "pos";
            verdict = "true";
          }
          {
            atom = "silenced:hemony:bourdon";
            sign = "neg";
            verdict = "false";
          }
        ];
      };
    };

    # ★ THE NEGATIVE LITERAL IS CARRIED, AND THE WITHDRAWN ARM IS EXACTLY WHERE `sign = "neg"` EARNS
    # ITS PLACE. Dropping negatives at this gate would make why-not unbuildable at gate 3 without an
    # IR change.
    test-the-fired-tuple-carries-its-negative-literal = {
      expr = builtins.filter (f: f.sign == "neg") derivation.fired;
      expected = [
        {
          atom = "silenced:hemony:bourdon";
          sign = "neg";
          verdict = "false";
        }
      ];
    };

    test-withdrawing-the-policy-removes-the-row = {
      expr = withdrawn.inspector.query "SELECT src, dst FROM edge WHERE label = 'rings'";
      expected = [ ];
    };

    # ── (b) ORIGIN/MODEL PARITY ──
    test-every-derivation-re-derives-its-heads-verdict = {
      expr = parityBreaches;
      expected = [ ];
    };

    test-the-parity-predicate-quantifies-over-something = {
      expr = builtins.length (
        builtins.concatMap (d: d.fired) (
          builtins.concatMap (e: ir.origins."${e.label}:${e.src}:${e.dst}".derivations) (
            builtins.filter (e: e.origin.kind == "policy") ir.edges
          )
        )
      );
      expected = 5;
    };

    # ── THE RED ARM, BOTH ARMS EXHIBITED IN ONE RUN ──
    # Head-matching reports TWO rules, one of whose bodies is false. The body check reports ONE.
    test-head-matching-reports-a-rule-whose-body-is-false = {
      expr = {
        matched = builtins.length headMatched;
        verdictOfTheNegativeLiteral = headMatchModel.verdict "silenced:hemony:bourdon";
      };
      expected = {
        matched = 2;
        verdictOfTheNegativeLiteral = "true";
      };
    };

    test-the-body-check-reports-only-the-rule-that-fires = {
      expr = map (r: {
        pos = r.pos or [ ];
        neg = r.neg or [ ];
      }) bodyChecked;
      expected = [
        {
          pos = [ "admits:bourdon:full-circle" ];
          neg = [ ];
        }
      ];
    };
  };
}
