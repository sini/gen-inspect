# THE CLOSED DOOR (den-hoag-7gp66 P1) — `graphSubject` takes `prelude.checkOptions`/`checkRequired`
# instead of a native closed formal, so a missing or unknown field is a NAMED, CATCHABLE refusal
# naming the door, not an abort `tryEval` cannot see (ADR-0025 item 1).
#
# `graphSubject` is the library's ONLY closed door (census at `27efe736`, §v1.2/§v1.7 row 7-15;
# confirmed by reading every exported module's every argument position — `materialize`, `select`,
# `parseSql`/`tokenize`, `compile`, `door.check`, `evalQuery`/`astToSelector`, the three renderers and
# `mkInspector` all take positional formals, never a caller-facing attrset). It is MIXED (`nodes`,
# `perLabel` required; `kind` defaulted) and CLOSED on both axes — transitional per §v1.2, until P2
# moves the options off the record — so there is no "extra field admitted" cell here, unlike a RECORD
# door: an unknown field is always refused.
#
# WHICH refusal fired is a claim about the message and `tryEval` yields only `success`; the byte
# goldens naming the door (R6) live in `ci/tests-error.nix`'s `flake.testsError.door-checks`.
#
# TWO STRENGTHS OF "CATCHABLE" ARE PINNED, DELIBERATELY: `refusesCatchably` (`deepSeq`) is the general
# form used by this door's siblings across the roster; `refusesAtApplication` (`seq`, applied with no
# later args and no field read) is the sharper bar — the refusal must fire the moment the door is
# called, not only when a caller happens to force the one branch that reads the checked record.
{
  genInspect,
  ...
}:
let
  refusesCatchably = e: !(builtins.tryEval (builtins.deepSeq e null)).success;
  answers = e: (builtins.tryEval (builtins.deepSeq e null)).success;

  # ★ THE SHARPER BAR: the refusal must fire ON APPLICATION, not only when a caller happens to force
  # the one branch (`register`/`relations`) that reads `checked` — `program`/`model` are static and
  # never would have tripped it. Measured before `lib/materialize.nix`'s `builtins.seq checked { … }`
  # was added: `tryEval (seq (graphSubject bad) null)` answered `success` (a bad record silently
  # admitted under WHNF alone). `seq`, no later args, no field read, is the whole predicate.
  refusesAtApplication = e: !(builtins.tryEval (builtins.seq e null)).success;

  validArgs = {
    nodes = [
      "a"
      "b"
    ];
    perLabel.enrolled = id: if id == "a" then [ "b" ] else [ ];
  };
in
{
  flake.tests.doors = {
    # ★ LIVE CONTROL FOR THE WHOLE SUITE, first: `tryEval` catches an ORDINARY throw, and a
    # non-throwing value answers. Without this, every `refusesCatchably` cell below is equally
    # consistent with a broken helper that reads `false` no matter what it is handed.
    test-control-tryeval-catches-an-ordinary-throw = {
      expr = refusesCatchably (throw "control probe, not this suite's subject");
      expected = true;
    };
    test-control-tryeval-answers-a-non-throwing-value = {
      expr = answers 1;
      expected = true;
    };
    test-control-seq-catches-an-ordinary-throw = {
      expr = refusesAtApplication (throw "control probe, not this suite's subject");
      expected = true;
    };

    # graphSubject — MIXED class (checkOptions composed over checkRequired).
    test-graphsubject-missing-required-field-refused-catchably = {
      expr = refusesCatchably (genInspect.graphSubject { nodes = [ "a" ]; });
      expected = true;
    };
    test-graphsubject-unknown-option-refused-catchably = {
      expr = refusesCatchably (genInspect.graphSubject (validArgs // { zzgi9k3qx = 1; }));
      expected = true;
    };
    # The application-time bar (see `refusesAtApplication` above): `seq` alone, no field read.
    test-graphsubject-missing-required-field-refused-at-application = {
      expr = refusesAtApplication (genInspect.graphSubject { nodes = [ "a" ]; });
      expected = true;
    };
    test-graphsubject-unknown-option-refused-at-application = {
      expr = refusesAtApplication (genInspect.graphSubject (validArgs // { zzgi9k3qx = 1; }));
      expected = true;
    };
    test-graphsubject-valid-call-is-unchanged = {
      expr = builtins.attrNames (genInspect.graphSubject validArgs);
      expected = [
        "model"
        "program"
        "register"
        "relations"
      ];
    };
    # The valid call answers the same shape `fromGraph` (its own caller) already drives through
    # `./surface.nix`'s degenerate-case cells — this pins `graphSubject` itself, one curry layer in.
    test-graphsubject-valid-call-kind-default-and-override = {
      expr = {
        default = builtins.attrNames (genInspect.graphSubject validArgs).register;
        overridden =
          builtins.attrNames
            (genInspect.graphSubject (validArgs // { kind = "node"; })).register;
      };
      expected = {
        default = [ "vertex" ];
        overridden = [ "node" ];
      };
    };
  };
}
