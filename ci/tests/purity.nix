# PURITY INVARIANT — the library source reaches NO nixpkgs `lib`, and the copied parser is the
# reason this cell is sharper here than it is elsewhere in the roster.
#
# ★ THE COPY ARRIVED NEEDING nixpkgs. `lib/sql.nix` and `lib/executor.nix` are copies of an EXAMPLE
# that took nixpkgs `lib`; twelve distinct `lib.*` names between them, SIX of which gen-prelude does
# not publish. The resolution was `lib/extras.nix` — the prelude extended by seven definitions over
# `builtins` — and NOT a nixpkgs input, because every gen roster member's `lib/` is nixpkgs-lib-free
# and a framework-stratum member declaring nixpkgs as a LIBRARY input would hand its whole closure to
# every consumer of this one. This cell is what keeps that resolution from quietly reverting the
# first time someone reaches for a missing name.
#
# Scope: `lib/**.nix` + the root `flake.nix` and `default.nix`. NOT `ci/` — the harness legitimately
# uses nixpkgs `lib`, including to run this scan.
{ lib, ... }:
let
  libDir = ../../lib;

  # Comment-stripped source: drop everything from the first `#` on each line, so documentation may
  # freely NAME a forbidden token without tripping the invariant. This file's own header says
  # "nixpkgs" repeatedly and `lib/extras.nix` names it in every paragraph.
  stripComments =
    text:
    lib.concatStringsSep "\n" (
      map (line: lib.head (lib.splitString "#" line)) (lib.splitString "\n" text)
    );

  # ★ THE STRIP'S PREMISE, ASSERTED RATHER THAN ASSUMED. The cut is sound only while the `#` it cuts
  # at stands OUTSIDE a string literal; where it does not, live code is truncated to the end of that
  # line and every cell below goes blind on what was removed, with no signal at all. The predicate
  # asks the strip ITSELF where it cut, then asks whether that text closed every double quote it
  # opened — an odd count meaning the cut stands inside a string.
  countQuotes = s: (lib.length (lib.splitString "\"" s)) - 1;
  cutIsInString =
    line:
    let
      kept = stripComments line;
    in
    kept != line && lib.mod (countQuotes kept) 2 == 1;

  nixFiles =
    dir: prefix:
    builtins.concatLists (
      lib.mapAttrsToList (
        name: type:
        if type == "regular" && lib.hasSuffix ".nix" name then
          [
            {
              name = "${prefix}${name}";
              text = builtins.readFile (dir + "/${name}");
            }
          ]
        else
          [ ]
      ) (builtins.readDir dir)
    );

  sources = nixFiles libDir "lib/" ++ [
    {
      name = "flake.nix";
      text = builtins.readFile ../../flake.nix;
    }
    {
      name = "default.nix";
      text = builtins.readFile ../../default.nix;
    }
  ];

  stripped = map (s: s // { text = stripComments s.text; }) sources;

  premiseBreaches = builtins.concatMap (
    src:
    lib.concatLists (
      lib.imap1 (i: line: lib.optional (cutIsInString line) "${src.name}:${toString i}") (
        lib.splitString "\n" src.text
      )
    )
  ) sources;

  # The tokens. A nixpkgs reference in a gen library arrives as an INPUT declaration or as the
  # module-system vocabulary that only nixpkgs' lib supplies.
  forbidden = [
    "nixpkgs"
    "evalModules"
    "mkOption"
    "mkOptionType"
    "mkMerge"
    "mkDefault"
    "mkForce"
  ];

  hits = builtins.concatMap (
    src:
    builtins.concatMap (tok: lib.optional (lib.hasInfix tok src.text) "${src.name}: ${tok}") forbidden
  ) stripped;

  # The nested nixpkgs accessor paths the copy carried, which `lib/extras.nix` replaced with flat
  # prelude names. They are listed separately because their absence is what says the substitution
  # actually happened rather than being described in a comment.
  nestedPaths = [
    "lib.lists."
    "lib.strings."
    "lib.attrsets."
  ];
  nestedHits = builtins.concatMap (
    src: builtins.concatMap (p: lib.optional (lib.hasInfix p src.text) "${src.name}: ${p}") nestedPaths
  ) stripped;
in
{
  flake.tests.purity = {
    test-the-comment-strip-never-cut-inside-a-string = {
      expr = premiseBreaches;
      expected = [ ];
    };

    test-the-library-source-reaches-no-nixpkgs = {
      expr = hits;
      expected = [ ];
    };

    test-no-nested-nixpkgs-accessor-path-survives-in-the-copies = {
      expr = nestedHits;
      expected = [ ];
    };

    # ★ THE CONTROL. Same predicate, same run, over a body that DOES carry the tokens — the
    # UNSTRIPPED source, whose comments name every one of them. A scan reading 0 on both would be a
    # broken predicate rather than a pure library.
    test-positive-control-the-unstripped-source-carries-the-tokens = {
      expr =
        builtins.length (
          builtins.concatMap (
            src: builtins.concatMap (tok: lib.optional (lib.hasInfix tok src.text) tok) forbidden
          ) sources
        ) > 0;
      expected = true;
    };

    # The domain, so a zero is not "the walk found no files".
    test-the-scan-reached-every-library-file = {
      expr = map (s: s.name) sources;
      expected = [
        "lib/compile.nix"
        "lib/default.nix"
        "lib/door.nix"
        "lib/executor.nix"
        "lib/extras.nix"
        "lib/inspector.nix"
        "lib/materialize.nix"
        "lib/render.nix"
        "lib/select.nix"
        "lib/sql.nix"
        "flake.nix"
        "default.nix"
      ];
    };
  };
}
