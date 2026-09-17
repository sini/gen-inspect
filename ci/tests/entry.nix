# CELL 2 — THE QUERY, ON BOTH DOCUMENTED HUB ENTRY PATHS.
#
# ★★ A DIFFERENCE BETWEEN THE TWO PATHS *IS* THE FAILURE. The hub publishes two ways in —
# `import <gen> { }`, the L1 standalone root a non-flake consumer reaches, and
# `(getFlake <gen>).lib.mkGenLibs { }`, the two-stage flake surface a flake consumer reaches — and
# they are two SUPPLIERS of one construction, not two constructions. A library composed through one
# and answering differently through the other is
# `den-hoag-hub-entry-paths-disagree-silently-oii6u`, and the word in that row's name is the reason
# this cell exists: nothing else in the suite would say so.
#
# The two paths are bound in `ci/flake.nix` and arrive here as `genInspect` (standalone) and
# `genInspectViaFlake`. Each is applied to its OWN path's substrate, so what is compared is the
# answer of two independently-wired libraries and not one library read twice.
#
# ★ THE NEGATIVE CONTROL IS ON THE SAME PREDICATE IN THE SAME RUN. `WHERE weight = 'NEGCTL'` is a
# well-formed query over a known column whose value nothing carries, so `[]` here is an ANSWER and
# not a broken instrument — and the positive arm beside it is what says the instrument fires.
{
  genInspect,
  genInspectViaFlake,
  genProgram,
  hubStandalone,
  hubFlake,
  ...
}:
let
  fleetOn =
    lib':
    (import ../../examples/fleet {
      genInspect = lib';
      inherit genProgram;
      silenced = false;
    }).inspector;

  viaStandalone = fleetOn genInspect;
  viaFlake = fleetOn genInspectViaFlake;

  theQuery = "SELECT src, dst FROM edge WHERE label = 'rings'";
  negControl = "SELECT name FROM tocsin WHERE weight = 'NEGCTL'";
in
{
  flake.tests.entry = {
    test-the-query-answers-through-the-standalone-root = {
      expr = viaStandalone.query theQuery;
      expected = [
        {
          src = "hemony";
          dst = "bourdon";
        }
      ];
    };

    test-the-query-answers-identically-through-the-flake-surface = {
      expr = viaFlake.query theQuery;
      expected = [
        {
          src = "hemony";
          dst = "bourdon";
        }
      ];
    };

    # THE DISAGREEMENT ITSELF, asserted as one equality rather than inferred from two cells passing.
    # Two cells against one literal both pass if the literal is what drifted; this one cannot.
    test-the-two-hub-entry-paths-agree = {
      expr = viaStandalone.query theQuery == viaFlake.query theQuery;
      expected = true;
    };

    test-negative-control-a-value-nothing-carries-answers-empty-on-both-paths = {
      expr = {
        standalone = viaStandalone.query negControl;
        flake = viaFlake.query negControl;
      };
      expected = {
        standalone = [ ];
        flake = [ ];
      };
    };

    # THE INSTRUMENT IS ARMED — the same shape of query, on the same table and column, returning
    # rows. Without this the empty answers above are indistinguishable from a dead query path.
    test-live-control-the-same-column-with-a-value-that-exists-fires = {
      expr = {
        standalone = viaStandalone.query "SELECT name FROM tocsin WHERE weight = 'heavy'";
        flake = viaFlake.query "SELECT name FROM tocsin WHERE weight = 'heavy'";
      };
      expected = {
        standalone = [
          { name = "angelus"; }
          { name = "bourdon"; }
        ];
        flake = [
          { name = "angelus"; }
          { name = "bourdon"; }
        ];
      };
    };

    # The two paths supply the same roster members. Stated here because if this is false, every
    # agreement above is an agreement about one value reached twice.
    test-the-two-paths-are-distinct-suppliers-of-the-same-roster = {
      expr = builtins.attrNames hubStandalone == builtins.attrNames hubFlake;
      expected = true;
    };
  };
}
