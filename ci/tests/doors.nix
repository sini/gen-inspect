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
{
  genInspect,
  ...
}:
let
  # `deepSeq`, NOT `seq`: `graphSubject`'s checked bindings are read inside `register.${kind}` and
  # `relations`'s value, not the returned attrset's own (static) top-level names, so a bare `tryEval`
  # of the call answers `true` without ever forcing the check — measured on this door before this
  # comment was written. Forcing deeply is what makes the check meet the caller.
  refusesCatchably = e: !(builtins.tryEval (builtins.deepSeq e null)).success;
  answers = e: (builtins.tryEval (builtins.deepSeq e null)).success;

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

    # graphSubject — MIXED class (checkOptions composed over checkRequired).
    test-graphsubject-missing-required-field-refused-catchably = {
      expr = refusesCatchably (genInspect.graphSubject { nodes = [ "a" ]; });
      expected = true;
    };
    test-graphsubject-unknown-option-refused-catchably = {
      expr = refusesCatchably (genInspect.graphSubject (validArgs // { zzgi9k3qx = 1; }));
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
