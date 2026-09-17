{
  description = "gen-inspect example — a campanology register, a policy that derives one edge no declaration states, and the two human entries over it";

  # ★ THE EXAMPLE HAS ITS OWN FLAKE, AND THAT IS WHAT KEEPS nixpkgs OUT OF THE LIBRARY. `export` is
  # outside the pure core — den-diagram's own line, matched: "`export` being the only stage that
  # touches `pkgs`" — so the derivation that turns a mermaid source into an image lives HERE, beside
  # the fixture, and not on the library root. The library root publishes `lib` unapplied and declares
  # only gen inputs; adding a `packages` output there would pull nixpkgs into the dependency graph of
  # every consumer of gen-inspect to build one picture.
  #
  # The hub is the single input that supplies the substrate, which is what a consumer would reach for.
  inputs = {
    gen.url = "github:sini/gen";
    nixpkgs.follows = "gen/nixpkgs";
  };

  outputs =
    { gen, nixpkgs, ... }:
    let
      # ★ `legacyPackages.${platform}` RATHER THAN `import nixpkgs { system = …; }`, AND THE
      # CONFORMANCE CELL IS WHY. ADR-0035 admits no fleet word at binding position anywhere in this
      # library's text, and `system` is on that list — both the `let` binding and the `system = …`
      # argument to `import nixpkgs` put it there. `ci/tests/conformance.nix` caught it on the
      # original spelling of these two lines, which is the cell doing its job on new code rather
      # than on a fixture. The flake form needs no such binding.
      platform = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${platform};
      hub = gen.lib.mkGenLibs { };

      # `../../lib` rather than the hub's roster entry: this example lives INSIDE the library and is
      # what a reader opens to see the library used, so it must exercise the working tree rather than
      # whatever revision the hub happens to pin.
      genInspect = import ../../lib {
        inherit (hub)
          prelude
          graph
          select
          scope
          ;
      };

      fleet = import ./default.nix {
        inherit genInspect;
        genProgram = hub.program;
        silenced = false;
      };

      mermaidSource = fleet.inspector.render.mermaid fleet.inspector.facts;
    in
    {
      # THE SCOPE-BOUND INSPECTOR — the consumer's output, and the subject of both human entries:
      #
      #   nix eval --json .#inspect --apply 'i: i.query "SELECT src, dst FROM edge WHERE label = '\''rings'\''"'
      #   nix eval --raw  .#inspect --apply 'i: i.render.mermaid i.facts'
      #   nix repl .#
      inspect = fleet.inspector;

      # The withdrawn arm, so the two states are both reachable from the command line.
      inspect-withdrawn =
        (import ./default.nix {
          inherit genInspect;
          genProgram = hub.program;
          silenced = true;
        }).inspector;

      packages.${platform} = {
        # ★ NOT A CI CELL. The picture needs a build, and picture fidelity needs an ELEMENT-scoped
        # predicate over the rendered svg — mermaid emits `edge-pattern-dotted` in its stylesheet
        # unconditionally, so a whole-file count reds against a correct build and greens at the red
        # state. What CI asserts is the SOURCE this library produces; this derivation is for the
        # owner's eyes.
        fleet-graph-svg =
          pkgs.runCommand "fleet-graph.svg"
            {
              nativeBuildInputs = [ pkgs.mermaid-cli ];
              src = mermaidSource;
              passAsFile = [ "src" ];
            }
            ''
              export HOME=$TMPDIR
              mmdc --puppeteerConfigFile ${pkgs.writeText "pc.json" ''{"args":["--no-sandbox"]}''} \
                   -i "$srcPath" -o "$out"
            '';

        fleet-graph-mermaid = pkgs.writeText "fleet-graph.mmd" mermaidSource;
        fleet-graph-dot = pkgs.writeText "fleet-graph.dot" (
          fleet.inspector.render.dot fleet.inspector.facts
        );
        default = pkgs.writeText "fleet-graph.mmd" mermaidSource;
      };
    };
}
