{
  inputs = {
    gen-harness.url = "github:sini/gen-harness";

    # nixpkgs is the CI runner's dependency (the nix-unit harness, treefmt) and supplies the `lib`
    # the test modules use. It enters ONLY in ci/, never as a `lib/` dep: the library is
    # nixpkgs-lib-free, which `ci/tests/purity.nix` enforces.
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";

    # ★ THE SUBSTRATE IS TAKEN DIRECTLY, NEVER THROUGH THE HUB. The hub pins this repository, so a
    # hub input here closes a cycle in the oracle graph (ADR-0037: there are no cycles; the hub is no
    # gen library's input except gen-demo and demos/examples). The four members the root flake
    # declares, with its `follows`; `gen-program` serves the library's program route and the fixture.
    # The entry-path agreement cell that once needed the hub is the hub's own property and lives in
    # its ci as `hub-entry-agreement` (den-hoag-mxbv4).
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

  outputs =
    inputs@{
      gen-harness,
      ...
    }:
    let
      prelude = inputs.gen-prelude.lib;
      graph = inputs.gen-graph.lib;
      select = inputs.gen-select.lib;
      scope = inputs.gen-scope.lib;
      # The application the hub's `lib/hubSubstrate.nix` performs for `program`, and the ONE
      # gen-program instance this oracle holds: the library's program route and the fleet fixture
      # both take it.
      genProgram = inputs.gen-program.lib { inherit prelude scope; };
      genInspect = import ../lib {
        inherit
          prelude
          graph
          select
          scope
          ;
        program = genProgram;
      };

      mkFleet =
        genInspect': silenced:
        import ../examples/fleet {
          genInspect = genInspect';
          inherit genProgram silenced;
        };
    in
    gen-harness.lib.mkCi {
      inherit inputs;
      name = "gen-inspect";
      testModules = ./tests;
      specialArgs = {
        inherit genInspect genProgram mkFleet;
        genGraph = graph;
        genSelect = select;
        genPrelude = prelude;
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
