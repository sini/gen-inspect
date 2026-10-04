# CELL 6 — THE DOORS. SIX SHAPES, ALL LOUD, EVERY REFUSAL ASSERTED BY ITS MESSAGE.
#
# ★★ WHY THESE ARE THE COMPONENT AND NOT A NICETY. Against a raw row source EVERY one of these
# shapes reads `[]` or a row of `null`s AT EXIT 0 — an unknown table yields no rows, a typo'd column
# projects `null`, a label value nothing publishes yields the empty answer. All three are
# indistinguishable from "the rule produced nothing", which is the one reading this library exists
# to make impossible. A door that refuses is what turns an owner's wrong answer into a question.
#
# ★ WHY A SECOND OUTPUT RATHER THAN A SECOND SUITE. The batch asserter behind `checks.default`
# evaluates every cell's `expr` UNCONDITIONALLY and quantifies over `config.flake.tests`, so a cell
# with a throwing `expr` CRASHES that gate rather than failing it. Hosting these on
# `flake.testsError` puts them outside that quantifier while keeping them live on the nix-unit path,
# and being outside `./tests` is what keeps the split structural rather than conventional.
#
#   nix-unit --flake ./ci#tests        # the suites
#   nix-unit --flake ./ci#testsError   # these cells
#
# ★★ `expectedError.msg` IS SEARCHED, NOT WHOLE-MATCHED, so a pattern naming a PREFIX of the message
# passes against a message that says something else after it — which would make these cells agree
# with the very rewording they exist to catch. Every pattern below is anchored at both ends and
# built by ESCAPING THE LITERAL TEXT rather than by hand.
{
  genInspect,
  genProgram,
  genScope,
  genPrelude,
  admitted,
  ...
}:
let
  exactly = msg: "^" + genPrelude.escapeRegex msg + "$";
  contains = msg: genPrelude.escapeRegex msg;

  q = admitted.inspector.query;

  # `reaches` is known without being an IR table: the program route computes it.
  knownTables = "belfry, chime, edge, peal, reaches, ringer, tocsin";

  # ── THE FIXTURE FOR THE IR DOOR ──
  # A reached edge that no rule derives and no relation declares: a labelled FACT at the published
  # label `housed`. gen-program reaches it, and nothing gives it an IR key. This is the defect a
  # hand-written dynamic-label list creates, driven here WITHOUT touching `lib/materialize.nix`.
  strayDeclarations = [
    {
      head = "housed:bourdon:campanile";
      relata = [
        "bourdon"
        "campanile"
      ];
      label = "housed";
    }
  ];
  strayModel = genProgram.model {
    prior = null;
    program = genProgram.program [
      "bourdon"
      "campanile"
    ] strayDeclarations;
    complete = true;
    interpretation = [ ];
  };
  strayIr = genInspect.materialize {
    register.tocsin.bourdon = { };
    relations.housed.bourdon = [ ];
    declarations = strayDeclarations;
    model = strayModel;
  };

  # ── THE FIXTURE FOR THE UNDEFINED HEAD ──
  # A negative cycle, `reach:a:b :- not held:a:b` and `held:a:b :- not reach:a:b`: the well-founded
  # model leaves `reach:a:b` UNDEFINED (ADR-0020). Its control, the same fixture without `held`, is in
  # `./tests/ir.nix`.
  cycleDeclarations = [
    {
      head = "reach:a:b";
      neg = [ "held:a:b" ];
      relata = [
        "a"
        "b"
      ];
      label = "reach";
    }
    {
      head = "held:a:b";
      neg = [ "reach:a:b" ];
      relata = [
        "a"
        "b"
      ];
    }
  ];
  cycleIr = genInspect.materialize {
    register.v = {
      a = { };
      b = { };
    };
    relations = { };
    declarations = cycleDeclarations;
    model = genProgram.model {
      program = genProgram.program [
        "a"
        "b"
      ] cycleDeclarations;
      interpretation = [ ];
      prior = null;
      complete = true;
    };
  };

  # ── THE FIXTURE FOR THE PROMOTED HEAD ──
  # A bodied labelled edge and a promoted head under one guard (gen-program's `promote`, den-hoag-2quxu):
  # both included. The IR draws a rule head only as an edge, so without the refusal the promoted head
  # had no node, no edge and no origin at exit 0. Its control is the same subject without the
  # promoted declaration, which materializes its edge.
  promotingDeclarations =
    promoted:
    [
      {
        head = "go";
        relata = [ ];
      }
      {
        head = "reach:a:b";
        pos = [ "go" ];
        relata = [
          "a"
          "b"
        ];
        label = "reach";
      }
    ]
    ++ (
      if promoted then
        [
          {
            head = "seam:a:b";
            pos = [ "go" ];
            relata = {
              left = "a";
              right = "b";
            };
            promote = "seam";
          }
        ]
      else
        [ ]
    );
  promotingIr =
    promoted:
    let
      declarations = promotingDeclarations promoted;
    in
    genInspect.materialize {
      register.v = {
        a = { };
        b = { };
      };
      relations = { };
      inherit declarations;
      model = genProgram.model {
        program = genProgram.program [
          "a"
          "b"
        ] declarations;
        interpretation = [ ];
        prior = null;
        complete = true;
      };
    };

  # ── THE FIXTURE FOR THE MODEL'S FORM ──
  # `./tests/ir.nix`'s `uncontested` subject with gen-scope's `solve` record in place of gen-program's
  # result record. The subject's `model` is gen-program's record: it is what binds the verdicts to
  # the declarations they were solved from, and a bare solve record carries no such binding.
  solveRecordDeclarations = [
    {
      head = "reach:a:b";
      neg = [ "held:a:b" ];
      relata = [
        "a"
        "b"
      ];
      label = "reach";
    }
  ];
  solveRecordIr = genInspect.materialize {
    register.v = {
      a = { };
      b = { };
    };
    relations = { };
    declarations = solveRecordDeclarations;
    model = genScope.solve [ ] (
      genProgram.program [
        "a"
        "b"
      ] solveRecordDeclarations
    );
  };
in
{
  flake.testsError = {
    # ── DOOR 11: A gen-scope SOLVE RECORD AS THE MODEL IS REFUSED BY NAME ──
    # Its control is `./tests/ir.nix`'s `test-an-uncontested-head-is-true-and-its-edge-is-a-rule-edge`.
    # The pinned text is GEN-PROGRAM's whole message, `(in prelude.checkRequired)` included, so a
    # gen-program reword reds this cell at the next relock, as Door 10 does.
    test-a-gen-scope-solve-record-as-the-model-is-refused-by-name = {
      expr = builtins.deepSeq solveRecordIr.edges solveRecordIr;
      expectedError.msg = exactly "gen-program.ruleEdges: the `model` operand (a gen-program result record): required field 'complete' is missing (required: 'complete', 'resolve', 'rules') (in prelude.checkRequired)";
    };

    # ── DOOR 1: an unknown table, refused by name WITH THE KNOWN SET ──
    test-an-unknown-table-is-refused-by-name-with-the-known-set = {
      expr = q "SELECT name FROM anvils";
      expectedError.msg = exactly "gen-inspect: unknown name 'anvils'; known: ${knownTables}";
    };

    # A PLURAL of a real table. The copied executor's origin carried a 23-entry alias table that made
    # this work by accident; `lib/executor.nix` strips it to the identity under ADR-0035, so the
    # plural is now an unknown name and says so.
    test-a-plural-of-a-real-table-is-refused = {
      expr = q "SELECT name FROM tocsins";
      expectedError.msg = exactly "gen-inspect: unknown name 'tocsins'; known: ${knownTables}";
    };

    # ── DOOR 2: an unknown column, refused against that table's own projection ──
    test-a-typo-in-a-column-is-refused-with-the-columns-that-exist = {
      expr = q "SELECT name FROM tocsin WHERE wieght = 'heavy'";
      expectedError.msg = exactly "gen-inspect: unknown name 'wieght'; known: belfry, kind, name, weight";
    };

    test-an-unknown-projected-column-is-refused = {
      expr = q "SELECT belfrey FROM tocsin";
      expectedError.msg = exactly "gen-inspect: unknown name 'belfrey'; known: belfry, kind, name, weight";
    };

    # ── DOOR 3: the parser, with position ──
    test-a-reserved-word-at-column-position-is-a-parse-error = {
      expr = q "SELECT from, to FROM edge";
      expectedError.msg = contains "sql-parser: expected column reference, got keyword";
    };

    # ── DOOR 4: ★ AN UNKNOWN LABEL VALUE ──
    # `WHERE label = 'anvils'` is a WELL-FORMED query over a KNOWN column. Without this door it
    # returns `[]` at exit 0 and reads as "the rule produced nothing" — the same hazard class the
    # dynamic-edge cell closes for the graph answer. The label set is in hand; refusing costs
    # nothing.
    test-an-unknown-label-value-is-refused-off-the-label-set = {
      expr = q "SELECT src FROM edge WHERE label = 'anvils'";
      expectedError.msg = exactly "gen-inspect: unknown label 'anvils'; known: absorbs, admits, enrolled, housed, hung, rings";
    };

    # The same door on `kind`, which the IR contract names for exactly this: `kinds` is "what a
    # `WHERE kind = '…'` resolves against".
    test-an-unknown-kind-value-is-refused-off-the-kind-set = {
      expr = q "SELECT name FROM tocsin WHERE kind = 'anvil'";
      expectedError.msg = exactly "gen-inspect: unknown kind 'anvil'; known: belfry, chime, peal, ringer, tocsin";
    };

    # ── DOOR 5: ★ PATH ENUMERATION, refused at compile BY NAME, PERMANENTLY ──
    # On a cyclic graph the set of paths is infinite, so no gate serves it; the message says so and
    # names what to ask instead. (`reaches` and `why` were refused here until the program route
    # landed; they answer now, in `./tests/program.nix`.)
    test-path-enumeration-is-refused-as-permanent = {
      expr = q "SELECT dst FROM paths WHERE src = 'hemony'";
      expectedError.msg = exactly "gen-inspect: unsupported construct 'paths' (path enumeration); a cyclic graph has infinitely many paths, so no finite answer exists and no gate adds one. Ask `reaches` for what a path reaches and `why` for the edge that carries it.";
    };

    # `reachable` and `closure` are not aliases: one relation has one name, and the known set names it.
    test-a-synonym-of-reaches-is-an-unknown-name = {
      expr = q "SELECT dst FROM reachable";
      expectedError.msg = exactly "gen-inspect: unknown name 'reachable'; known: ${knownTables}";
    };

    # ── DOOR 9: ★ THE PROGRAM ROUTE'S VALUES ──
    # Without the `via` door an unknown label grounds no edge and answers the reflexive row alone at
    # exit 0 — "hemony reaches nothing".
    test-an-unknown-via-is-refused-off-the-label-set = {
      expr = q "SELECT dst FROM reaches WHERE src = 'hemony' AND via = 'anvils'";
      expectedError.msg = exactly "gen-inspect: unknown via 'anvils'; known: absorbs, admits, enrolled, housed, hung, rings, *";
    };

    # The door refuses an unknown source before gen-program's frozen-set door would.
    test-an-unknown-reaches-source-is-refused-off-the-relata-domain = {
      expr = q "SELECT dst FROM reaches WHERE src = 'anvil' AND via = '*'";
      expectedError.msg = exactly "gen-inspect: unknown src 'anvil'; known: campanile, lantern, compline, evensong, matins, chiming, full-circle, hemony, mears, rudhall, angelus, bourdon, sanctus, tenor";
    };

    # `why` on something that is neither an IR key nor a reaches atom.
    test-why-refuses-an-atom-it-cannot-derive = {
      expr = admitted.inspector.why "rings:hemony";
      expectedError.msg = exactly "gen-inspect: 'rings:hemony' is neither an IR edge key nor a reaches atom";
    };

    # ── DOOR 6: ★ A REACHED EDGE WITH NO IR EDGE ──
    # THE DOOR THAT MAKES THE DERIVED LABEL SET SELF-CHECKING. Driven from a subject rather than by
    # editing the library: an edge gen-program reaches at a PUBLISHED label that nothing gives an IR
    # key. Without this the build reads its full edge count at exit 0 and answers a question about
    # that label with a true edge missing and nothing said.
    test-a-reached-edge-with-no-ir-edge-is-refused-by-name = {
      expr = builtins.deepSeq strayIr.origins strayIr;
      expectedError.msg = exactly "gen-inspect: reached edge(s) with neither a firing rule nor a declared relation: housed:bourdon:campanile";
    };

    # ── DOOR 10: ★ AN UNDEFINED HEAD IS REFUSED BY NAME, NOT DROPPED ──
    # Read off `trueAtoms`, this fixture's IR had no edge and forced at exit 0: an undefined atom is
    # in no list of true atoms. gen-program's `reached` refuses it, naming the head.
    test-an-undefined-head-is-refused-by-name = {
      expr = builtins.deepSeq cycleIr.edges cycleIr;
      expectedError.msg = exactly "gen-program.ruleEdges: 'reach:a:b' is UNDEFINED (U); an edge has no third value, so the membership can be carried into the graph neither as an edge nor as its absence, and is refused rather than collapsed. Read its answer through the model's `resolve` and handle 'U'";
    };

    # ── DOOR 12: ★ A PROMOTED HEAD IS REFUSED BY NAME, NOT DROPPED ──
    # The live control runs inside the cell under `tryEval`, so a refuse-everything materialize reds
    # it with `assertion failed` instead of matching the pinned message.
    test-a-promoted-head-is-refused-by-name = {
      expr =
        let
          control = builtins.tryEval (
            builtins.deepSeq (promotingIr false).edges (map (e: e.origin.kind) (promotingIr false).edges)
          );
        in
        assert control.success && control.value == [ "rule" ];
        builtins.deepSeq (promotingIr true).edges (promotingIr true);
      expectedError.msg = exactly "gen-inspect: 'seam:a:b' is promoted to a node (gen-program's `promote`); the IR draws a rule head only as an edge, so a promoted head would be dropped from it, and materialize refuses it rather than drop it";
    };

    # ── DOOR 8: ★ A QUALIFIER NO FROM/JOIN ITEM DECLARES ──
    # The executor resolves a qualifier it does not know to the UNQUALIFIED row, so without this door
    # `x.name` below projected the JOINED table's `name` at exit 0 — a wrong answer, not an empty one.
    # The known set is each item's correlation name: its alias, else its table name.
    test-an-unknown-qualifier-is-refused-with-the-declared-qualifiers = {
      expr = q "SELECT x.name FROM tocsin t JOIN belfry b ON t.belfry = b.name";
      expectedError.msg = exactly "gen-inspect: unknown qualifier 'x'; known: t, b";
    };

    # An ALIASED table's own name is not a qualifier: the alias replaces it, as SQL's range-variable
    # rule says. Refused rather than resolved, so `tocsin` cannot mean two rows in a self-join.
    test-an-aliased-tables-own-name-is-not-a-qualifier = {
      expr = q "SELECT tocsin.name FROM tocsin t JOIN belfry b ON t.belfry = b.name";
      expectedError.msg = exactly "gen-inspect: unknown qualifier 'tocsin'; known: t, b";
    };

    # Two items with one correlation name make every reference to it ambiguous.
    test-a-duplicate-qualifier-is-refused-by-name = {
      expr = q "SELECT tocsin.name FROM tocsin JOIN tocsin ON tocsin.belfry = tocsin.name";
      expectedError.msg = exactly "gen-inspect: duplicate qualifier 'tocsin'; give each FROM/JOIN item a distinct alias";
    };

    # ── DOOR 7: mkInspector refuses a non-scope, NAMING THE MISSING FIELDS ──
    # The gen-graph case goes through an explicit wrapper rather than a shape probe, so everything
    # that is neither reaches this refusal.
    test-a-non-scope-is-refused-naming-every-missing-field = {
      expr = genInspect.mkInspector { register = { }; };
      expectedError.msg = exactly "gen-inspect: not an evaluated scope; missing field(s): relations, declarations, model";
    };

    test-a-partial-scope-names-only-what-is-missing = {
      expr = genInspect.mkInspector {
        register = { };
        relations = { };
        declarations = [ ];
      };
      expectedError.msg = exactly "gen-inspect: not an evaluated scope; missing field(s): model";
    };

    # ── DOOR-CHECKS (den-hoag-7gp66 P1): `graphSubject`'s two named, catchable refusals, verbatim ──
    # `./tests/doors.nix` already proves each one is CATCHABLE (`tryEval` + `deepSeq`); these two pin
    # WHICH message fired and that it names the door first (R6), matching this file's own idiom.
    test-graphsubject-missing-required-field-names-the-door = {
      expr = builtins.deepSeq (genInspect.graphSubject { nodes = [ "a" ]; }) null;
      expectedError.msg = exactly "gen-inspect.graphSubject: required field 'perLabel' is missing (required: 'nodes', 'perLabel') (in prelude.checkRequired)";
    };

    # Containment is a function, so the lift refuses a second `parent` target by name where the walk
    # reads it, rather than resolving over a graph the calculus cannot represent.
    test-a-node-with-two-parent-targets-is-refused-by-the-lift = {
      expr =
        let
          g = genInspect.fromGraph {
            nodes = [
              "a"
              "b"
              "c"
            ];
            perLabel.parent =
              id:
              if id == "a" then
                [
                  "b"
                  "c"
                ]
              else
                [ ];
          };
        in
        builtins.deepSeq (genScope.resolve {
          wf = genScope.wellFormed {
            alphabet = g.facts.labels;
            expression = "parent*";
          };
          dataFilter = _: true;
        } g.facts.graph "a") null;
      expectedError.msg = contains "gen-inspect: node 'a' has 2 'parent' targets";
    };

    test-graphsubject-unknown-option-names-the-door = {
      expr = builtins.deepSeq (genInspect.graphSubject {
        nodes = [ "a" ];
        perLabel = { };
        zzgi9k3qx = 1;
      }) null;
      expectedError.msg = exactly "gen-inspect.graphSubject: 'zzgi9k3qx' is not an option of this door; the options are closed (accepted: 'nodes', 'perLabel', 'kind') (in prelude.checkOptions)";
    };
  };
}
