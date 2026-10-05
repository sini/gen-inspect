# THE DOORS (den-hoag-7gp66 P2 — `prelude.door`, R7 argument structure / R5 field closure) — every
# published step of gen-inspect that takes a RECORD catches its own violations, at its own
# application, catchably.
#
# `graphSubject { kind?; } { nodes; perLabel; }` and `fromGraph`, the same two steps with `materialize`
# behind them, are the library's only record-taking doors (census by reading every exported module's
# every argument position: `materialize` takes the subject record and refuses its own missing fields by
# name; `select`, `parseSql`/`tokenize`, `compile`, `door`, `evalQuery`/`astToSelector`, the three
# renderers and `mkInspector` are positional). The options step is closed; the graph record behind it
# is an accessor record (rule 3), open, and guarded against its options step (`optionsStep`), so
# `kind` given on the record is refused by name rather than silently dropped (G10).
#
# WHICH refusal fired is a claim about the message and `tryEval` yields only `success`; the byte
# goldens naming the door (R6) live in `ci/tests-error.nix`'s `flake.testsError.door-checks`.
#
# TWO STRENGTHS OF "CATCHABLE" ARE PINNED, DELIBERATELY: `refusesCatchably` (`deepSeq`) is the general
# form; `refusesAtApplication` (`seq`, applied with no later args and no field read) is the sharper
# bar — the refusal must fire the moment the step is applied (P2 premise 5).
{
  genInspect,
  genPrelude,
  ...
}:
let
  refusesCatchably = e: !(builtins.tryEval (builtins.deepSeq e null)).success;
  answers = e: (builtins.tryEval (builtins.deepSeq e null)).success;
  refusesAtApplication = e: !(builtins.tryEval (builtins.seq e null)).success;

  graph = {
    nodes = [
      "a"
      "b"
    ];
    perLabel.enrolled = id: if id == "a" then [ "b" ] else [ ];
  };
  doors = {
    inherit (genInspect) graphSubject fromGraph;
  };
  perDoor = f: builtins.mapAttrs f doors;

  # A field name neither step declares, generated per evaluation from the door names, never listed.
  stranger = "not-a-field-of-" + builtins.concatStringsSep "-" (builtins.attrNames doors);
in
{
  flake.tests.doors = {
    # ★ LIVE CONTROLS, first: `tryEval` catches an ORDINARY throw, and a non-throwing value answers.
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
    test-control-seq-does-not-read-an-unread-field = {
      expr = refusesAtApplication { culprit = throw "control probe, not this suite's subject"; };
      expected = false;
    };

    # ── THE OPTIONS STEP (G1/G4): refused at `f opts`'s WHNF, before the graph ──
    test-an-unknown-option-is-refused-at-the-options-application = {
      expr = perDoor (
        _: d:
        refusesAtApplication (d {
          ${stranger} = 1;
        })
      );
      expected = perDoor (_: _: true);
    };
    test-a-non-set-options-argument-is-refused-at-the-application = {
      expr = perDoor (_: d: refusesAtApplication (d 1));
      expected = perDoor (_: _: true);
    };
    # The old one-record shape is refused by name at its first application: `nodes` is not an option.
    test-the-old-one-record-shape-is-refused-at-the-application = {
      expr = perDoor (_: d: refusesAtApplication (d graph));
      expected = perDoor (_: _: true);
    };
    test-control-the-empty-options-answer = {
      expr = perDoor (_: d: answers (builtins.attrNames (d { } graph)));
      expected = perDoor (_: _: true);
    };
    # D3: the published contract, read as data, and the functor-aware reader agree.
    test-each-door-publishes-its-contract = {
      expr = perDoor (
        _: d: {
          inherit (d.__contract) optional open required;
          next = { inherit (d.__contract.next) required open; };
          args = genPrelude.functionArgs d;
        }
      );
      expected = perDoor (
        _: _: {
          optional = [ "kind" ];
          open = false;
          required = [ ];
          next = {
            required = [
              "nodes"
              "perLabel"
            ];
            open = true;
          };
          args.kind = true;
        }
      );
    };
    # G3: the non-default `kind` reaches the result (`differ`), and the partially applied door agrees
    # with the full call (`agree`).
    test-a-non-default-option-reaches-the-result = {
      expr =
        let
          asNode = genInspect.graphSubject { kind = "node"; };
          kinds = s: builtins.attrNames s.register;
        in
        {
          agree = kinds (asNode graph) == kinds (genInspect.graphSubject { kind = "node"; } graph);
          differ = kinds (asNode graph) != kinds (genInspect.graphSubject { } graph);
          inherit (genInspect.graphSubject { } graph) declarations;
          default = kinds (genInspect.graphSubject { } graph);
          overridden = kinds (asNode graph);
        };
      expected = {
        agree = true;
        differ = true;
        declarations = [ ];
        default = [ "vertex" ];
        overridden = [ "node" ];
      };
    };

    # ── THE GRAPH RECORD (R5: open, all fields required) ──
    test-a-missing-graph-field-is-refused-at-the-record-application = {
      expr = perDoor (
        _: d:
        map (f: refusesAtApplication (d { } (builtins.removeAttrs graph [ f ]))) [
          "nodes"
          "perLabel"
        ]
      );
      expected = perDoor (
        _: _: [
          true
          true
        ]
      );
    };
    # G2: an extra field is admitted, answer unchanged.
    test-an-extra-graph-field-is-admitted-and-the-answer-is-unchanged = {
      expr =
        builtins.attrNames (genInspect.graphSubject { } (graph // { ${stranger} = 1; })).register
        == builtins.attrNames (genInspect.graphSubject { } graph).register;
      expected = true;
    };
    # G10: `kind`, an option of the door's own options step, given on the record is refused by name —
    # where R5 would otherwise admit it and silently answer as if it were omitted.
    test-an-option-given-on-the-record-is-refused-at-the-record-application = {
      expr = perDoor (_: d: refusesAtApplication (d { } (graph // { kind = "node"; })));
      expected = perDoor (_: _: true);
    };
    test-control-an-unrelated-extra-field-on-the-same-record-is-admitted = {
      expr = perDoor (_: d: refusesAtApplication (d { } (graph // { ${stranger} = 1; })));
      expected = perDoor (_: _: false);
    };
    # Composition: `graphSubject opts` is a value mapped over graphs.
    test-a-partially-applied-door-maps-over-graphs = {
      expr = map (s: builtins.attrNames s.register) (
        map (genInspect.graphSubject { kind = "node"; }) [
          graph
          (graph // { nodes = [ "c" ]; })
        ]
      );
      expected = [
        [ "node" ]
        [ "node" ]
      ];
    };
  };
}
