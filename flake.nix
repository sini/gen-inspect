{
  description = "gen-inspect — the library that interrogates a materialized gen graph: which nodes exist and of what kind, which edges are declared, which a policy program produced and why, and what reaches what";

  # DECLARED, NOT APPLIED (owner-ruled Arm A, 2026-09-16: `den-hoag-4dfsv` §4.2). The library takes
  # its whole substrate as INJECTED VALUES constructed inside the consumer's own evaluation — only
  # plain data crosses a gen↔gen boundary — and declaring an input is not applying one. What the
  # declaration buys is a ROOT LOCK for `nix flake lock` to write, so the standalone entry
  # (`default.nix`) has a pin source that is not `ci/flake.lock`; ADR-0037's 2026-09-15 amendment
  # forecloses staying there.
  #
  # ★ THE DESIGN'S FIVE DEPENDENCIES. `gen-prelude`, `gen-graph` and `gen-select` serve the selector
  # and executor routes. `gen-scope` and `gen-program` serve the PROGRAM ROUTE: `lib/compile.nix`
  # builds each reachability question as a gen-program declaration set and solves it on gen-scope's
  # engine. gen-program's `follows` put it on this lock's own gen-prelude and gen-scope, so the
  # standalone entry applies it to the same substrate the other four resolve to.
  #
  # The test runner lives in ./ci, which is a separate flake — the library's dependency graph and
  # its oracle graph are separate, and the second must not enter the first.
  #
  # ★ THE FLAKE OUTPUT IS THE ROOT, PUBLISHED UNAPPLIED. The hub applies this output verbatim
  # (`gen/lib/hubSubstrate.nix`), so an APPLIED output here would abort every hub evaluation with
  # `attempt to call something which is not a function but a set`.
  inputs = {
    gen-prelude.url = "github:sini/gen-prelude";

    gen-graph.url = "github:sini/gen-graph";
    gen-graph.inputs.gen-prelude.follows = "gen-prelude";

    gen-select.url = "github:sini/gen-select";

    gen-scope.url = "github:sini/gen-scope";
    gen-scope.inputs.gen-prelude.follows = "gen-prelude";
    gen-scope.inputs.gen-graph.follows = "gen-graph";

    gen-program.url = "github:sini/gen-program";
    gen-program.inputs.gen-prelude.follows = "gen-prelude";
    gen-program.inputs.gen-scope.follows = "gen-scope";
  };

  outputs = _: {
    lib = import ./.;
  };
}
