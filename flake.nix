{
  description = "gen-inspect — the library that interrogates a materialized gen graph: which nodes exist and of what kind, which edges are declared, which a policy program produced and why, and what reaches what";

  # DECLARED, NOT APPLIED (owner-ruled Arm A, 2026-09-16: `den-hoag-4dfsv` §4.2). The library takes
  # its whole substrate as INJECTED VALUES constructed inside the consumer's own evaluation — only
  # plain data crosses a gen↔gen boundary — and declaring an input is not applying one. What the
  # declaration buys is a ROOT LOCK for `nix flake lock` to write, so the standalone entry
  # (`default.nix`) has a pin source that is not `ci/flake.lock`; ADR-0037's 2026-09-15 amendment
  # forecloses staying there.
  #
  # ★ THE FIVE ARE THE DESIGN'S DEPENDENCY SET, AND TWO OF THEM ARE THE GATE-2 SEAM.
  # `gen-prelude`, `gen-graph` and `gen-select` are what this gate's code evaluates through.
  # `gen-scope` and `gen-program` are the PROGRAM ROUTE's substrate: the design's compile rule sends
  # reachability, transitive closure and `WHY` to the program layer, and at gate 1 that route is a
  # refusal door rather than a stub precisely so gate 2 replaces the body and changes no caller
  # (`specs/2026-09-16-gen-inspect-design.md` §2.1, §4). Declaring them now is what makes that
  # replacement local to `lib/compile.nix`.
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
