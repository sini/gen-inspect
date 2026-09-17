# gen-inspect — THE LIBRARY THAT INTERROGATES A MATERIALIZED gen GRAPH.
#
# A person sits down in front of an assembled graph and asks it questions: which nodes exist and of
# what kind, which edges are declared, which a policy program produced and WHY, what reaches what. A
# picture of the same materialization, with the policy's edge visibly distinct, is one output of that
# pipeline — not the ask.
#
# ── WHY A LIBRARY AND NOT A DEMO ──
# Interrogating a materialized graph is a capability every gen consumer needs, so it is shipped
# end-user surface (ADR-0015's test) at the `framework` stratum — "above the stack rather than a
# layer of it", the bucket's own gloss. ★ That label is owner-flagged as not durable, so it is a
# placement note and not a binding.
#
# ── THREE LAYERS, ONE MODEL ──
#   (c) SELECTORS — gen-select combinators: the primary programmatic API, and the GUARD sublanguage.
#   (b) PROGRAMS  — gen-program declarations on gen-scope's engine: recursion, derivation, why.
#   (a) SQL       — text: the novice surface, compiled onto b + c.
# Layer (b) is load-bearing and is NOT reachable from (c): gen-select has no fixpoint and no
# comprehension, so reachability is not expressible there. `./compile.nix` carries the measurement
# and the three-route rule that follows from it.
#
# ── IT DEFINES NO SUBSTRATE VOCABULARY, AND IT NEVER EVALUATES ──
# ADR-0035: no den or fleet word sits at a kind, label, option or error position anywhere in this
# library's text. ADR-0006: every fixpoint goes through gen-scope, the sole evaluator — this library
# READS a model that an evaluator already produced and computes none of its own, which is what makes
# that conformance true by construction rather than by inspection.
#
# ── THE SUBSTRATE ARRIVES INJECTED ──
# Only plain data crosses a gen↔gen boundary. This library takes its dependencies as VALUES and
# constructs inside the consumer's own evaluation; it re-exports none of them.
{
  prelude,
  graph,
  select,
  # ★ THE GATE-2 SEAM. `scope` is the PROGRAM ROUTE's evaluator — the third row of `./compile.nix`'s
  # table, where reachability, transitive closure and `WHY` compile onto gen-scope's engine. At this
  # gate that route is a REFUSAL DOOR and the value is not read; it is a formal now rather than a
  # later widening because the design fixes the seam now (§4, "gate 2 replaces the body with the
  # program route and CHANGES NO CALLER").
  #
  # ★★ gen-program IS NOT A FORMAL HERE, AND THE REASON IS A MEASURED PROPERTY OF THE HUB. The design
  # names five dependencies; four are takeable and the fifth is not. `gen/lib/hubSubstrate.nix` is a
  # function of the hub's `members` binding, and `members` holds exactly the EIGHTEEN roster entries
  # whose flake `.lib` is published APPLIED — measured at the hub: algebra aspects bind class dispatch
  # graph identity link memo merge prelude product schema scope select settings types view. `program`
  # is one of the three UNAPPLIED members that the substrate fold itself produces, so it is not in
  # scope where a fourth substrate entry is written, and asking for it would mean rewriting that fold
  # to be self-referential — a hub architecture change the design did not specify. `prelude`, `graph`,
  # `select` and `scope` are all in `members`, so the other four arrive normally. Gate 2 adds this
  # formal in the same commit that replaces `compile`'s body.
  scope,
}:
let
  # gen-prelude plus the seven names the copied parser and executor need and the prelude does not
  # publish. NOT nixpkgs `lib` — see `./extras.nix` for the measurement and ADR-0014 for the ground.
  lib = import ./extras.nix prelude;

  sql = import ./sql.nix { inherit lib; };
  executor = import ./executor.nix {
    inherit lib;
    genSelect = select;
  };
  materialize = import ./materialize.nix { inherit lib graph; };
  selecting = import ./select.nix { inherit lib graph; };
  compile = import ./compile.nix { inherit lib; };
  door = import ./door.nix { inherit lib compile; };
  render = import ./render.nix { inherit lib; };
  inspector = import ./inspector.nix {
    inherit
      lib
      materialize
      selecting
      sql
      door
      compile
      executor
      render
      ;
    genSelect = select;
  };
in
{
  # ── MATERIALIZATION — the IR contract of `./materialize.nix` ──
  inherit (materialize) materialize graphSubject;

  # ── THE PROGRAMMATIC API — IR + gen-select selector → IR′ ──
  # It takes the selector library as its first argument rather than closing over the injected one, so
  # a caller composing selectors from their OWN gen-select instance matches against that instance.
  # Two instances of a selector algebra in one evaluation are two identity formulas for one position.
  select = selecting.select;

  # ── THE TEXT SURFACE ──
  inherit (sql) parseSql tokenize;
  inherit (compile) compile reservedNames;
  door = door.check;

  # ── THE EXECUTOR — join, projection, ORDER BY, LIMIT; selectors carry WHERE ──
  inherit (executor) evalQuery astToSelector;

  # ── RENDERERS — they read the IR and never the scope ──
  render = {
    inherit (render) mermaid dot json;
  };

  # ── THE CONSUMER'S ENTRY ──
  inherit (inspector) mkInspector fromGraph;
}
