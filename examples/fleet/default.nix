# THE EXAMPLE SUBJECT — a campanology register, and every name in it is INVENTED.
#
# ★ ADR-0035 IS WHY THIS IS BELLS AND NOT MACHINES. No den or fleet word may sit at a kind, label,
# option or error position anywhere in this library's text, and an example's kinds are kind position.
# `tocsin`, `belfry`, `chime`, `ringer`, `peal` — and the labels `housed`, `hung`, `enrolled`,
# `absorbs`, `admits`, `rings` — are the invented vocabulary the ADR's worked-example clause admits.
#
# ★★ THE POINT OF THE FIXTURE IS ONE DERIVED EDGE THAT NO DECLARATION STATES. `hemony` reaches
# `bourdon` because a rule program derives `rings:hemony:bourdon` through two intermediate
# derivations, and no `relations` entry says so. That is the edge a picture must show as visibly
# distinct and a query must be able to find and explain.
#
# ★★ AND `enrolled` IS BOTH A DECLARED AND A DERIVED LABEL, WHICH IS THE SECOND POINT. `hemony` is
# DECLARED enrolled in `chiming` and DERIVED enrolled in `full-circle`; the IR carries both under one
# label, each with its own origin. A construction that filtered rule edges through a hand-written
# label list would drop the derived one WITH NO DIAGNOSTIC — the reason `materialize` takes the
# dynamic label set from the declarations' own labels and refuses a reached edge with no IR edge BY
# NAME.
#
# `silenced` is a CONTROL ATOM at a label this register does not publish. Asserting it withdraws the
# rule's conclusion, which is the fixture's second arm: the same subject with one edge gone.
{
  genInspect,
  genProgram,
  silenced ? false,
}:
let
  register = {
    tocsin = {
      bourdon = {
        belfry = "campanile";
        weight = "heavy";
      };
      tenor = {
        belfry = "campanile";
        weight = "light";
      };
      sanctus = {
        belfry = "lantern";
        weight = "light";
      };
      angelus = {
        belfry = "lantern";
        weight = "heavy";
      };
    };
    belfry = {
      campanile = { };
      lantern = { };
    };
    chime = {
      evensong = { };
      matins = { };
      compline = { };
    };
    ringer = {
      hemony = { };
      rudhall = { };
      mears = { };
    };
    peal = {
      full-circle = { };
      chiming = { };
    };
  };

  # The static half, as data.
  relations = {
    housed = {
      bourdon = [ "campanile" ];
      tenor = [ "campanile" ];
      sanctus = [ "lantern" ];
      angelus = [ "lantern" ];
    };
    hung = {
      evensong = [ "bourdon" ];
      matins = [ "tenor" ];
      compline = [ "sanctus" ];
    };
    enrolled = {
      hemony = [ "chiming" ];
      rudhall = [ "chiming" ];
    };
    absorbs = {
      full-circle = [ "chiming" ];
    };
    admits = {
      bourdon = [ "full-circle" ];
      tenor = [ "chiming" ];
    };
  };

  # ── THE RULE: A TRANSITIVE GRANT ──
  # Each declaration's `label` names the edge its head denotes, `{ from = relata[0]; to = relata[1];
  # }`: gen-program's `ruleEdges` reads it there, and the atom string is never split. The facts are
  # labelled too, because they are the same edges `relations` declares.
  declarations = [
    {
      head = "enrolled:hemony:chiming";
      label = "enrolled";
      relata = [
        "hemony"
        "chiming"
      ];
    }
    {
      head = "absorbs:full-circle:chiming";
      label = "absorbs";
      relata = [
        "full-circle"
        "chiming"
      ];
    }
    {
      head = "admits:bourdon:full-circle";
      label = "admits";
      relata = [
        "bourdon"
        "full-circle"
      ];
    }
    {
      head = "enrolled:hemony:full-circle";
      label = "enrolled";
      pos = [
        "enrolled:hemony:chiming"
        "absorbs:full-circle:chiming"
      ];
      relata = [
        "hemony"
        "full-circle"
      ];
    }
    {
      head = "rings:hemony:bourdon";
      label = "rings";
      pos = [
        "enrolled:hemony:full-circle"
        "admits:bourdon:full-circle"
      ];
      neg = [ "silenced:hemony:bourdon" ];
      relata = [
        "hemony"
        "bourdon"
      ];
    }
  ];

  # ★ `frozen` MUST NAME EVERY RELATUM, or the construction exits 1 (ADR-0033). A relatum is an
  #   IDENTIFIER resolved against the frozen set, and a rule's atoms are membership facts — two
  #   universes, and collapsing them would make an identifier derivable.
  program = genProgram.program [
    "hemony"
    "rudhall"
    "mears"
    "chiming"
    "full-circle"
    "bourdon"
    "tenor"
  ] declarations;

  model = genProgram.model {
    inherit program;
    complete = true;
    prior = null;
    # The caller-supplied interpretation — verdicts the caller asserts (gen-program's assertion
    # channel; a previous pass's record would arrive as `prior`). This is the withdrawn arm's
    # whole mechanism, and it is why an atom asserted at a dynamic label with no rule needs a
    # refusal BY NAME rather than an index abort.
    interpretation =
      if silenced then
        [
          {
            atom = "silenced:hemony:bourdon";
            verdict = "true";
          }
        ]
      else
        [ ];
  };

  subject = {
    inherit
      register
      relations
      declarations
      model
      ;
    # No declaration is promoted, so the caller's mint output is empty.
    minted = {
      nodes = { };
      edges = [ ];
    };
  };
in
{
  inherit
    subject
    register
    relations
    declarations
    program
    model
    ;
  inspector = genInspect.mkInspector subject;
}
