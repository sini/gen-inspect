# THE STANDALONE ENTRY'S FETCH RULE: `default.nix`'s `src` default loads every locked node through the
# fixed-output form, and refuses by name any node it has no such form for.
#
# Every other cell here takes this library from `ci/flake.nix`, built with `import ../lib` from ci's own
# flake inputs, so the root shim is never evaluated. These cells read the shim itself: C1 and C2 as
# text, C3 and C4 through the record its body hands `wire`.
#
# ★★ THE APPLICATION IS STUBBED, AND THAT IS WHAT MAKES IT HERMETIC. `dep = segs: segs` stops every
# routed default at its path, and `wire = args: args` publishes the record `{ deps, fetch, lock }`. The
# formals `program` bypass `dep` (`import (src [ … ]) { … }`, so that one
# evaluation holds one instance of each), so `dep` cannot stop them; they are supplied as stubs, and
# the application fetches nothing.
{ ... }:
let
  pathArgs = {
    dep = segs: segs;
    wire = args: args;
    program = "stub";
  };
  seam = import ../.. pathArgs;
  lock = seam.lock;

  # ★★★ THE FIXED-OUTPUT FETCH RULE, COUNTED AS TEXT. `default.nix`'s `fetch` binding is the one place
  # this library fetches, and Nix publishes no default, so the reading that `src` takes that rule is
  # textual. COMMENTS ARE STRIPPED, then EVERY whitespace character is deleted, so a formatter's
  # line breaking cannot move the reading. Bound once and read by both cells below.
  fetchRule = ''
    fetch = {
      inherit resolve;
      node = resolve lock;
      locked =
        locked:
        if builtins.attrNames locked == [ "lastModified" "narHash" "owner" "repo" "rev" "type" ] && locked.type == "github" then
          builtins.fetchTarball { url = "https://github.com/''${locked.owner}/''${locked.repo}/archive/''${locked.rev}.tar.gz"; sha256 = locked.narHash; }
        else
          throw "gen-inspect: a locked node of type `''${toString (locked.type or null)}` with attributes ''${toString (builtins.attrNames locked)} has no fixed-output form here; refusing rather than falling back to fetchTree";
    };
  '';
  # The comment marker, spelled as a JSON escape so that no `#` stands inside a string literal on any
  # line here: a line-wise comment strip cuts at the first `#` and would truncate live code there.
  commentMarker = builtins.fromJSON ''"\u0023"'';
  fetchSrcLine = "src ? segs: fetch.locked lock.nodes.\${fetch.node segs}.locked,";
  countFetch =
    text:
    let
      dense =
        s:
        builtins.replaceStrings [ " " "\n" "\t" ] [ "" "" "" ] (
          builtins.concatStringsSep "\n" (
            map (l: builtins.head (builtins.split commentMarker l)) (
              builtins.filter builtins.isString (builtins.split "\n" s)
            )
          )
        );
      occurrences =
        needle: hay:
        (builtins.stringLength hay - builtins.stringLength (builtins.replaceStrings [ needle ] [ "" ] hay))
        / builtins.stringLength needle;
      d = dense text;
    in
    {
      fetchTree = occurrences "builtins.fetchTree" d;
      rule = occurrences (dense fetchRule) d;
      src = occurrences (dense fetchSrcLine) d;
    };

  # ★ ONE REAL SIX-KEY `github` NODE, so that in C3's `extraKey` arm the added `host` key is the ONLY
  # difference from an admitted node: a fixture missing `lastModified` lets a rule that ignores `host`
  # pass. The arm is not named for the key, which is no word of this library's vocabulary (ADR-0035).
  githubNode = {
    lastModified = 0;
    narHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    owner = "sini";
    repo = "gen-prelude";
    rev = "0000000000000000000000000000000000000000";
    type = "github";
  };
  refusesFetch =
    locked: !(builtins.tryEval (builtins.deepSeq (seam.fetch.locked locked) true)).success;
in
{
  # ★★★ C1: `src` TAKES THE FIXED-OUTPUT RULE, AND `builtins.fetchTree` IS GONE FROM `default.nix`.
  # Upstream Nix's `fetchTree` of a locked `github` node looks its revision up in the git tarball
  # cache per process even when the store path is valid; `fetchTarball` keyed on the node's `narHash`
  # does not. This cell is also the one that sees a URL-template typo: C4 cannot on a warm store,
  # because the URL is read only on a miss.
  flake.tests.entry.test-the-fetch-rule-is-the-fixed-output-rule = {
    expr = countFetch (builtins.readFile ../../default.nix);
    expected = {
      fetchTree = 0;
      rule = 1;
      src = 1;
    };
  };

  # ★★ C2: `countFetch` SHOWN ABLE TO FIRE, at inputs the main arm does not use. `planted` is the
  # shipped `fetchTree` line, `commented` proves the comment strip is live, and `urltypo` is the
  # template typo C1 exists to catch.
  flake.tests.entry.test-control-the-fetch-rule-check-discriminates = {
    expr = {
      exact = countFetch (fetchRule + fetchSrcLine);
      planted = countFetch ''src ? segs: "''${builtins.fetchTree lock.nodes.''${fetch segs}.locked}",'';
      commented = countFetch (
        builtins.concatStringsSep "\n" (
          map (l: commentMarker + " " + l) (
            builtins.filter builtins.isString (builtins.split "\n" (fetchRule + fetchSrcLine))
          )
        )
      );
      urltypo = countFetch (builtins.replaceStrings [ ".tar.gz" ] [ ".tar" ] fetchRule + fetchSrcLine);
    };
    expected = {
      exact = {
        fetchTree = 0;
        rule = 1;
        src = 1;
      };
      planted = {
        fetchTree = 1;
        rule = 0;
        src = 0;
      };
      commented = {
        fetchTree = 0;
        rule = 0;
        src = 0;
      };
      urltypo = {
        fetchTree = 0;
        rule = 0;
        src = 1;
      };
    };
  };

  # ★★★ C3: `fetch.locked` REFUSES BY NAME OUTSIDE ITS FORM, and never falls back to `fetchTree`.
  # HERMETIC: each fixture is refused before anything is fetched. A rule blind to a key would instead
  # try to download the all-zero revision, and the cell would red on the network.
  flake.tests.entry.test-fetch-locked-refuses-outside-its-form = {
    expr = {
      git = refusesFetch (
        builtins.removeAttrs githubNode [
          "owner"
          "repo"
        ]
        // {
          type = "git";
          url = "https://github.com/sini/gen-prelude";
        }
      );
      tarball = refusesFetch (
        builtins.removeAttrs githubNode [
          "owner"
          "repo"
        ]
        // {
          type = "tarball";
          url = "https://example.invalid/x.tar.gz";
        }
      );
      extraKey = refusesFetch (githubNode // { host = "ghe.example.invalid"; });
    };
    expected = {
      git = true;
      tarball = true;
      extraKey = true;
    };
  };

  # ★★★ C4: `fetch.locked` IS `fetchTree`, PATH FOR PATH, ON EVERY LOCKED NODE OF THIS LIBRARY'S OWN
  # LOCK. NOT HERMETIC, for the reason `…-forces-every-dependency` is not: it fetches every node. The
  # domain is the lock's node set minus its root, total by construction: `src` is a function over
  # paths in this lock, and the record's `deps` cannot enumerate what it reaches. A rule that always
  # throws passes C3 and reds here; one that names its store path differently reds every node.
  #
  # ★★ BOTH SIDES ARE COPIED by `builtins.path`, each under its own store-path name, never compared as
  # strings: under Determinate's lazy trees `fetchTree`'s string is a virtual path, and so is
  # `fetchTarball`'s on a store miss, and `==` reads a virtual path unequal to the very store path it
  # denotes. The copy is that store path on every evaluator, and keeping each side's own name keeps
  # the name in the identity.
  flake.tests.entry.test-fetch-locked-is-fetchTree-on-every-lock-node =
    let
      nodes = builtins.removeAttrs lock.nodes [ lock.root ];
      nameOf =
        p:
        builtins.head (
          builtins.match "${builtins.storeDir}/[^-]*-(.*)" (builtins.unsafeDiscardStringContext p)
        );
      copied =
        p:
        builtins.path {
          path = p;
          name = nameOf p;
        };
    in
    {
      expr = builtins.mapAttrs (
        _: n: copied (seam.fetch.locked n.locked) == copied (builtins.fetchTree n.locked)
      ) nodes;
      expected = builtins.mapAttrs (_: _: true) nodes;
    };
}
