{
  inputs = {
    gen-harness.url = "github:sini/gen-harness";

    # nixpkgs is the CI runner's dependency (the nix-unit harness, treefmt) and supplies the `lib`
    # the test modules use. It enters ONLY in ci/, never as a `lib/` dep: the library is
    # nixpkgs-lib-free, which `ci/tests/purity.nix` enforces.
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

    # ★ THE HUB IS AN ORACLE INPUT, AND IT IS WHAT MAKES THE ENTRY-PATH CELL POSSIBLE AT ALL. This
    # library takes its substrate INJECTED and declares its five dependencies directly, so nothing
    # in `lib/` reaches the hub. The ACCEPTANCE RUN does: the design's cell 2 asserts one query's
    # answer on BOTH documented hub entry paths — `import <gen> { }` and
    # `(getFlake <gen>).lib.mkGenLibs { }` — because a DIFFERENCE between them is itself the failure
    # (`den-hoag-hub-entry-paths-disagree-silently-oii6u`), and a cell that read only one path could
    # never see it.
    #
    # THE DIRECTION IS SAFE AND THE DIRECTION IS THE POINT: the hub enters this repository's ORACLE
    # graph only. ADR-0037 keeps the library graph and the oracle graph separate, and the root
    # `flake.lock` beside this one declares the hub nowhere — so a consumer of gen-inspect gains no
    # edge to the aggregator that pins gen-inspect.
    gen.url = "github:sini/gen";
  };

  outputs =
    inputs@{
      gen-harness,
      gen,
      ...
    }:
    let
      # ENTRY PATH 1 — the L1 standalone root, which is what a non-flake consumer reaches.
      hubStandalone = import gen { };
      # ENTRY PATH 2 — the published two-stage flake surface, which is what a flake consumer reaches.
      hubFlake = gen.lib.mkGenLibs { };

      mkLib =
        hub:
        import ../lib {
          inherit (hub)
            prelude
            graph
            select
            scope
            ;
        };

      genInspect = mkLib hubStandalone;
      genInspectViaFlake = mkLib hubFlake;

      mkFleet =
        genInspect': silenced:
        import ../examples/fleet {
          genInspect = genInspect';
          genProgram = hubStandalone.program;
          inherit silenced;
        };
    in
    gen-harness.lib.mkCi {
      inherit inputs;
      name = "gen-inspect";
      testModules = ./tests;
      specialArgs = {
        inherit
          genInspect
          genInspectViaFlake
          hubStandalone
          hubFlake
          mkFleet
          ;
        genGraph = hubStandalone.graph;
        genSelect = hubStandalone.select;
        genProgram = hubStandalone.program;
        genPrelude = hubStandalone.prelude;
        # The two arms of the example fleet, built once and shared. `admitted` is the whole subject;
        # `withdrawn` asserts the control atom and loses the policy's conclusion.
        admitted = mkFleet genInspect false;
        withdrawn = mkFleet genInspect true;
      };
      # Cells whose subject is an error MESSAGE cannot live under `testModules`: the batch asserter
      # behind `checks.default` quantifies over `flake.tests` and forces every `expr`
      # UNCONDITIONALLY, so a cell with a throwing `expr` CRASHES that gate instead of failing it.
      # They get their own output, read by `nix-unit --flake ./ci#testsError`, and being outside
      # ./tests is what keeps that split structural rather than conventional.
      extraModules = [
        ./tests-error.nix
      ];
    };
}
