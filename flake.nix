{
  description = "gen-inspect — the library that interrogates a materialized gen graph: which nodes exist and of what kind, which edges are declared, which a policy program produced and why, and what reaches what";

  # DECLARED, NOT APPLIED (owner-ruled Arm A, 2026-09-16: `den-hoag-4dfsv` §4.2). The library takes
  # its whole substrate as INJECTED VALUES constructed inside the consumer's own evaluation — only
  # plain data crosses a gen↔gen boundary — and declaring an input is not applying one. What the
  # declaration buys is a ROOT LOCK for `nix flake lock` to write, so the standalone entry
  # (`default.nix`) has a pin source that is not `ci/flake.lock`; ADR-0037's 2026-09-15 amendment
  # forecloses staying there.
  #
  # ★ FOUR OF THE DESIGN'S FIVE DEPENDENCIES, AND THE FIFTH IS NOT DECLARABLE HERE YET.
  # `gen-prelude`, `gen-graph` and `gen-select` are what this gate's code evaluates through.
  # `gen-scope` is the PROGRAM ROUTE's evaluator, declared now so gate 2 replaces `lib/compile.nix`'s
  # body and changes no caller.
  #
  # ★★ `gen-program` IS ABSENT BY MEASUREMENT, NOT BY OVERSIGHT. The hub injects a framework member's
  # substrate through `gen/lib/hubSubstrate.nix`, which is a function of the hub's `members` binding —
  # exactly the EIGHTEEN roster entries whose `.lib` is published APPLIED. `program` is one of the
  # three UNAPPLIED members the substrate fold itself produces, so it is not in scope where a fourth
  # substrate entry is written; the other four are. Declaring the input here while the hub cannot
  # inject the value would pin a dependency this library has no way to receive. `lib/default.nix`
  # carries the same note beside the formals.
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
  };

  outputs = _: {
    lib = import ./.;
  };
}
