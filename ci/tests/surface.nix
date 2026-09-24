# THE PUBLISHED SURFACE, THE EXECUTOR ROUTE, AND THE DEGENERATE CASE.
#
# ★ THE EXECUTOR ROUTE IS ASSERTED AS A CONTROL, NOT DESCRIBED. The compile rule sends `JOIN`,
# projection, `ORDER BY` and `LIMIT` to this library's own fold because gen-select has NEITHER a join
# NOR a comprehension — measured, its constructors yield nine tags and `sel ? join` is false. A
# builder told to compile a join into selectors is told to use a layer that has none. The cells below
# are what say those constructs ANSWER rather than refuse: without them, "a JOIN is not in the
# refused set" is a claim about a list rather than a fact about the library.
{
  genInspect,
  genGraph,
  genSelect,
  admitted,
  ...
}:
let
  i = admitted.inspector;
  q = i.query;

  # THE DEGENERATE CASE: any gen-graph labeled value, through the EXPLICIT wrapper.
  plain = genInspect.fromGraph {
    nodes = [
      "hemony"
      "rudhall"
      "chiming"
    ];
    perLabel.enrolled =
      id:
      if id == "hemony" then
        [ "chiming" ]
      else if id == "rudhall" then
        [ "chiming" ]
      else
        [ ];
  };
in
{
  flake.tests.surface = {
    test-the-published-surface = {
      expr = builtins.attrNames genInspect;
      expected = [
        "astToSelector"
        "compile"
        "door"
        "evalQuery"
        "fromGraph"
        "graphSubject"
        "materialize"
        "mkInspector"
        "parseSql"
        "render"
        "reservedNames"
        "select"
        "tokenize"
      ];
    };

    test-an-inspector-publishes-facts-select-query-and-render = {
      expr = builtins.attrNames i;
      expected = [
        "facts"
        "parse"
        "query"
        "render"
        "select"
        "why"
      ];
    };

    test-the-renderers = {
      expr = builtins.attrNames i.render;
      expected = [
        "dot"
        "json"
        "mermaid"
      ];
    };

    # ── THE EXECUTOR ROUTE. Each of these is a construct gen-select cannot express. ──
    #
    test-control-a-join-is-not-refused-it-routes-to-the-executor = {
      expr = q "SELECT t.name FROM tocsin t JOIN belfry b ON t.belfry = b.name WHERE t.weight = 'heavy'";
      expected = [
        { name = "angelus"; }
        { name = "bourdon"; }
      ];
    };

    # ★ THE SAME JOIN QUALIFIED BY TABLE NAME ANSWERS THE SAME ROWS. The copied executor's alias map
    # took an explicit alias only, so this form resolved both qualifiers to the unqualified fallback
    # and answered `[ ]` at exit 0. A table with no alias is now qualified by its own name.
    test-a-join-qualified-by-table-name-answers-as-the-aliased-form = {
      expr = q "SELECT tocsin.name FROM tocsin JOIN belfry ON tocsin.belfry = belfry.name WHERE tocsin.weight = 'heavy'";
      expected = [
        { name = "angelus"; }
        { name = "bourdon"; }
      ];
    };

    test-control-order-by-and-limit-route-to-the-executor = {
      expr = q "SELECT name FROM tocsin ORDER BY name LIMIT 2";
      expected = [
        { name = "angelus"; }
        { name = "bourdon"; }
      ];
    };

    # A LEFT JOIN whose ON condition matches nothing: every left row survives, which is the whole
    # difference between LEFT JOIN and JOIN and is why the count is the fixture's tocsin count.
    test-control-a-left-join-keeps-the-unmatched-row = {
      expr = q "SELECT t.name FROM tocsin t LEFT JOIN chime c ON c.name = t.name";
      expected = [
        { name = "angelus"; }
        { name = "bourdon"; }
        { name = "sanctus"; }
        { name = "tenor"; }
      ];
    };

    test-control-a-boolean-closure-in-where-routes-to-gen-select = {
      expr = q "SELECT name FROM tocsin WHERE weight = 'heavy' AND belfry = 'lantern'";
      expected = [ { name = "angelus"; } ];
    };

    test-control-or-and-in-route-to-gen-select = {
      expr = {
        disjunction = builtins.length (
          q "SELECT name FROM tocsin WHERE weight = 'heavy' OR weight = 'light'"
        );
        membership = q "SELECT name FROM tocsin WHERE name IN ('bourdon', 'sanctus') ORDER BY name";
      };
      expected = {
        disjunction = 4;
        membership = [
          { name = "bourdon"; }
          { name = "sanctus"; }
        ];
      };
    };

    # THE RESERVED SET, published so a reader can see what no route serves. `reaches` and `why` left
    # it when the program route landed; path enumeration stays, permanently.
    test-the-reserved-constructs-are-published = {
      expr = genInspect.reservedNames;
      expected = [
        "path"
        "paths"
      ];
    };

    # ── THE DEGENERATE CASE ──
    # A gen-graph value is a subject with no policy half, reached through an EXPLICIT wrapper so the
    # missing-field refusal stays named for everything that is neither.
    test-a-plain-labeled-graph-materializes-with-no-policy-half = {
      expr = {
        nodes = builtins.length plain.facts.nodes;
        edges = builtins.length plain.facts.edges;
        policy = builtins.length (builtins.filter (e: e.origin.kind == "policy") plain.facts.edges);
        inherit (plain.facts) labels;
        kinds = builtins.attrNames plain.facts.kinds;
      };
      expected = {
        nodes = 3;
        edges = 2;
        policy = 0;
        labels = [ "enrolled" ];
        kinds = [ "vertex" ];
      };
    };

    test-the-degenerate-case-is-queryable-and-walkable = {
      expr = {
        rows = plain.query "SELECT src, dst FROM edge ORDER BY src";
        walk = plain.facts.graph.labeledEdges "hemony";
      };
      expected = {
        rows = [
          {
            src = "hemony";
            dst = "chiming";
          }
          {
            src = "rudhall";
            dst = "chiming";
          }
        ];
        walk = [
          {
            label = "enrolled";
            target = "chiming";
          }
        ];
      };
    };

    # gen-select is reached as a VALUE, never re-exported. The nine tags are the measurement the
    # compile rule rests on, asserted here so a change to that algebra shows up as a figure.
    test-the-selector-algebra-has-no-fixpoint-and-no-comprehension = {
      expr = {
        join = genSelect ? join;
        comprehension = genSelect ? comprehension;
        fix = genSelect ? fix;
        star = genSelect ? star;
      };
      expected = {
        join = false;
        comprehension = false;
        fix = false;
        star = true;
      };
    };

    test-gen-graph-supplies-the-enumerations-not-gen-view = {
      expr = genGraph ? labeledFrom;
      expected = true;
    };
  };
}
