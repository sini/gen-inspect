# Standalone (non-flake) entry — the L1 shim. Flake consumers should use the `.lib` output.
#
# THREE CHANNELS, ONE PRECEDENCE, AND NONE OF THEM IS A PROBE. A named formal per dependency wins;
# the `inputs` bag is next, tested by attrset membership so a supplied-but-throwing value throws as
# ITSELF rather than falling back; the default is resolved from `./flake.lock`, read as local data.
# There is NO `...`: an argument this root does not declare is a loud error, not a silent drop.
#
# THE PIN SOURCE IS THE ROOT `flake.lock`, NOT `ci/flake.lock` (ADR-0037 as amended 2026-09-15): a
# library's dependency graph and its test/oracle graph are SEPARATE, and the second must not enter
# the first.
#
# `src` AND `dep` ARE FORMALS, NOT `let` BINDINGS, AND THAT IS THE INJECTABLE RESOLVER SEAM. `src`
# is the only expression here that fetches; everything else reads the lock as data. A caller
# supplying `src = segs: throw "…"` therefore makes fetching IMPOSSIBLE for that application rather
# than merely absent. A `dep` bound in the `let` below would close over the `let`'s `src`, so the
# override would silently do nothing and the shim would fetch anyway, at rc 0.
#
# The `let` is OUTSIDE the lambda because a formal's default is evaluated in the FORMAL scope, which
# does not see a `let` in the body.
let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  # A direct edge IS the node key; a `follows` value is a PATH resolved segment by segment from this
  # lock's own root. Never by indexing `lock.nodes.<label>` — a last-segment shortcut reads a
  # different node wherever a lock aliases a key. IT TAKES ITS LOCK AS AN ARGUMENT so that the entry
  # cell can drive this exact binding on a fixture where the two rules disagree by construction; a
  # resolver closed over this library's own lock could only ever be compared against a second copy
  # of itself. This is the ONE declaration of the rule in this repository — `ci/tests/entry.nix`
  # reads this binding through the record the body hands `wire`, instead of transcribing the fold a
  # second time.
  resolve =
    lock:
    let
      following =
        node: inp:
        let
          v = (lock.nodes.${node}.inputs or { }).${inp};
        in
        if builtins.isString v then v else builtins.foldl' following lock.root v;
    in
    segs: builtins.foldl' following lock.root segs;
  fetch = resolve lock;
in
{
  inputs ? { },
  src ? segs: "${builtins.fetchTree lock.nodes.${fetch segs}.locked}",
  # `import p { }` is the ONE call text that answers every gen dependency alike (den-hoag-iev2q): a
  # zero-dependency member's root is a NULLARY FUNCTION and not a bare value, so there is no second
  # shape here to dispatch on.
  dep ? segs: import (src segs) { },
  # `wire` IS THE THIRD SEAM, AND IT IS THE ONLY CHANNEL THIS FILE HAS FOR PUBLISHING ANYTHING
  # OUTWARD. Nix publishes WHETHER a formal has a default and never WHAT it is — a formal is an
  # INPUT channel and cannot carry a value out — so the one place a formal NAME and its resolved
  # PATH are both in scope is this file's argument TO `wire`, and the same argument is what carries
  # `resolve` out. A cell injecting `dep = segs: segs` alongside `wire = args: args` reads this
  # shim's own formal-to-path map AND its own resolver, with nothing fetched and no path and no fold
  # restated by hand. The record destructures with no `...`, so a drifted body shape is a loud error
  # at the default rather than a silent drop.
  wire ? { deps, resolve }: import ./lib deps,
  prelude ? inputs.gen-prelude or (dep [ "gen-prelude" ]),
  graph ? inputs.gen-graph or (dep [ "gen-graph" ]),
  select ? inputs.gen-select or (dep [ "gen-select" ]),
  scope ? inputs.gen-scope or (dep [ "gen-scope" ]),
}:
# THE BODY IS EAGER, AND THAT IS WHAT MAKES THE ENTRY CELL TOTAL RATHER THAN PARTIAL. `forced` forces
# every wired dependency to WHNF before `./lib` sees it, so a default that cannot resolve is loud AT
# THE BOUNDARY rather than wherever a consumer first reaches an attribute. Without it a force of this
# root reaches only the dependencies the published surface happens to be derived from — and
# `builtins.deepSeq` cannot make up the difference, because it does not enter a lambda.
#
# THE FORCE STOPS AT WHNF DELIBERATELY: `builtins.seq` of an attrset does not force its members, so
# this reaches each dependency's root VALUE and never a member of it.
let
  deps = {
    inherit
      prelude
      graph
      select
      scope
      ;
  };
  forced = builtins.deepSeq (builtins.mapAttrs (_: builtins.typeOf) deps) null;
in
builtins.seq forced (wire {
  inherit deps resolve;
})
