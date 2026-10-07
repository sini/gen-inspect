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
  # gen-prelude's refusal text, composed with this library's own literal door, field and accepted
  # set (den-hoag-7jltk): every assertion kept, none of gen-prelude's wording copied.
  inherit (genPrelude) refusals;

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
    minted = emptyMint;
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
    minted = emptyMint;
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
  # both included. The promoted head is a node only the caller's mint can give an identity, so the
  # subject carries the mint's output as `minted`, and every mint that is not exactly the included
  # promoted heads, well-formed, is refused by name. The live control of every mint door is the
  # caller's real mint, which materializes the node and its two rule-origin edges.
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
  # The caller's mint for `seam:a:b`: the relata's emitters at pass 0 and the promoted record at
  # pass 1, in one closed run (ADR-0016 rulings 5, 7).
  promotingMinted =
    let
      m = promotingModel true;
      p = genProgram.ruleEdges m (promotingDeclarations true);
      entity = i: {
        pass = 0;
        identifier = i;
        kind = "v";
        relata = { };
        content = { };
        site = "t:${i}";
      };
      all = genScope.mintStrata { } (
        [
          (entity "a")
          (entity "b")
        ]
        ++ map (r: r // { pass = 1; }) p.promoted
      );
    in
    {
      nodes = { inherit (all.nodes) "seam:a:b"; };
      edges = builtins.filter (e: e.from == "seam:a:b") all.edges;
    };
  promotingModel =
    promoted:
    genProgram.model {
      program = genProgram.program [
        "a"
        "b"
      ] (promotingDeclarations promoted);
      interpretation = [ ];
      prior = null;
      complete = true;
    };
  emptyMint = {
    nodes = { };
    edges = [ ];
  };
  promotingIrOf =
    {
      promoted ? true,
      register ? {
        v = {
          a = { };
          b = { };
        };
      },
      minted,
    }:
    genInspect.materialize {
      inherit register minted;
      relations = { };
      declarations = promotingDeclarations promoted;
      model = promotingModel promoted;
    };
  withNode = n: promotingMinted // { nodes."seam:a:b" = n; };
  realNode = promotingMinted.nodes."seam:a:b";
  # Under `tryEval`, so a refuse-everything materialize reds every mint door with `assertion failed`
  # instead of matching its pinned message.
  mintControl =
    let
      good = promotingIrOf { minted = promotingMinted; };
      control = builtins.tryEval (
        builtins.deepSeq good.edges {
          node = builtins.filter (n: n.id == "seam:a:b") good.nodes;
          edges = map (e: "${e.label}:${e.src}:${e.dst}:${e.origin.kind}") (
            builtins.filter (e: e.src == "seam:a:b") good.edges
          );
        }
      );
    in
    control.success
    &&
      control.value == {
        node = [
          {
            id = "seam:a:b";
            kind = "seam";
            attrs = {
              inherit (realNode) identity;
              content = { };
            };
          }
        ];
        edges = [
          "left:seam:a:b:a:rule"
          "right:seam:a:b:b:rule"
        ];
      };
  refusedUnderControl =
    bad:
    assert mintControl;
    builtins.deepSeq bad.edges bad;
  mintRefusal =
    fault:
    exactly "gen-inspect: the subject's `minted` does not match the model's promoted heads: ${fault}";

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
    minted = emptyMint;
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
      expectedError.msg = exactly (
        refusals.missingField "gen-program.ruleEdges: the `model` operand (a gen-program result record)" [
          "complete"
          "resolve"
          "rules"
        ] "complete"
      );
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
      expectedError.msg =
        "^" + genPrelude.escapeRegex "gen-program.ruleEdges: 'reach:a:b' is UNDEFINED (U)";
    };

    # ── DOOR 12: ★ AN INCLUDED PROMOTED HEAD WITH NO MINTED NODE IS REFUSED, NOT DROPPED ──
    # Each mint door's live control is `mintControl`, the caller's real mint, under `tryEval`.
    test-an-included-promoted-head-with-no-minted-node-is-refused-by-name = {
      expr = refusedUnderControl (promotingIrOf {
        minted = emptyMint;
      });
      expectedError.msg = mintRefusal "'seam:a:b' is an included promoted head with no minted node";
    };

    # ── DOOR 13: A MINTED NODE WITHOUT A NON-EMPTY STRING IDENTITY ──
    test-a-minted-node-with-no-identity-is-refused-by-name = {
      expr = refusedUnderControl (promotingIrOf {
        minted = withNode (removeAttrs realNode [ "identity" ]);
      });
      expectedError.msg = mintRefusal "minted node 'seam:a:b' carries no identity";
    };

    # A present `identity` is not an identity: `null` was admitted at exit 0 by a presence test.
    test-a-minted-node-with-a-null-identity-is-refused-by-name = {
      expr = refusedUnderControl (promotingIrOf {
        minted = withNode (realNode // { identity = null; });
      });
      expectedError.msg = mintRefusal "minted node 'seam:a:b' carries no identity";
    };

    # ── DOOR 14: A MINTED NODE OF ANOTHER KIND ──
    # Without it the IR drew `seam/hem:0`: the record's kind beside another kind's identity.
    test-a-minted-node-of-another-kind-is-refused-by-name = {
      expr = refusedUnderControl (promotingIrOf {
        minted = withNode (
          realNode
          // {
            kind = "hem";
            identity = "hem:0";
          }
        );
      });
      expectedError.msg = mintRefusal "minted node 'seam:a:b' is of kind 'hem', not its promotion's kind 'seam'";
    };

    # ── DOOR 15: A MINTED HEAD THAT IS ALREADY A REGISTERED NODE ──
    # Under its own kind the register's attrs were overwritten; under another kind the IR held two
    # nodes of one id. Both at exit 0.
    test-a-minted-head-already-registered-is-refused-by-name = {
      expr = refusedUnderControl (promotingIrOf {
        register = {
          v = {
            a = { };
            b = { };
            "seam:a:b" = { };
          };
          seam."seam:a:b".stale = true;
        };
        minted = promotingMinted;
      });
      expectedError.msg = mintRefusal "minted node 'seam:a:b' is already a registered node, of kind(s) seam, v";
    };

    # ── DOOR 16: A MINTED EDGE FROM NO MINTED NODE ──
    # Drawn per minted node, such an edge was in no node's set and was silently absent from the IR.
    test-a-minted-edge-from-no-minted-node-is-refused-by-name = {
      expr = refusedUnderControl (promotingIrOf {
        minted = promotingMinted // {
          edges = promotingMinted.edges ++ [
            {
              from = "seam:ghost";
              to = "a";
              label = "left";
            }
          ];
        };
      });
      expectedError.msg = mintRefusal "minted edge 'left:seam:ghost:a' is from 'seam:ghost', which is no minted node";
    };

    # ── DOOR 17: A MINT CARRIED BY A SUBJECT THAT PROMOTES NOTHING ──
    # `minted` is required, so the door always runs; read only when a declaration was promoted, this
    # mint was ignored at exit 0.
    test-a-mint-on-a-subject-that-promotes-nothing-is-refused-by-name = {
      expr = refusedUnderControl (promotingIrOf {
        promoted = false;
        minted = promotingMinted;
      });
      expectedError.msg = mintRefusal "minted node 'seam:a:b' is not a promoted head this model includes";
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
      expectedError.msg = exactly "gen-inspect: not an evaluated scope; missing field(s): relations, declarations, model, minted";
    };

    test-a-partial-scope-names-only-what-is-missing = {
      expr = genInspect.mkInspector {
        register = { };
        relations = { };
        declarations = [ ];
      };
      expectedError.msg = exactly "gen-inspect: not an evaluated scope; missing field(s): model, minted";
    };

    # ── DOOR-CHECKS (den-hoag-7gp66 P2): `graphSubject`'s three named, catchable refusals, verbatim ──
    # `./tests/doors.nix` already proves each one is CATCHABLE at its own step's application; these
    # pin WHICH message fired and that it names the door first (R6), matching this file's own idiom.
    test-graphsubject-missing-required-field-names-the-door = {
      expr = builtins.deepSeq (genInspect.graphSubject { } { nodes = [ "a" ]; }) null;
      expectedError.msg = exactly (
        refusals.missingField "gen-inspect.graphSubject" [ "nodes" "perLabel" ] "perLabel"
      );
    };

    # Containment is a function, so the lift refuses a second `parent` target by name where the walk
    # reads it, rather than resolving over a graph the calculus cannot represent.
    test-a-node-with-two-parent-targets-is-refused-by-the-lift = {
      expr =
        let
          g = genInspect.fromGraph { } {
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
      expr = builtins.seq (genInspect.graphSubject { zzgi9k3qx = 1; }) null;
      expectedError.msg = exactly (
        refusals.unknownOption "gen-inspect.graphSubject" [ "kind" ] "zzgi9k3qx"
      );
    };
    # G10: the option given on the graph record is refused by name, naming the options step.
    test-graphsubject-option-on-the-record-names-the-door = {
      expr = builtins.seq (genInspect.graphSubject { } {
        nodes = [ "a" ];
        perLabel = { };
        kind = "node";
      }) null;
      expectedError.msg = exactly (
        refusals.guardedField "gen-inspect.graphSubject" "gen-inspect.graphSubject" "kind"
      );
    };
  };
}
