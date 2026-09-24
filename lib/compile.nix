# THE COMPILE RULE — THREE ROUTES BY EXECUTOR, NOT TWO BY RECURSION.
#
# | construct                              | executor              | why                            |
# |----------------------------------------|-----------------------|--------------------------------|
# | `WHERE` predicate                      | gen-select            | `astToSelector`                |
# | `JOIN`, projection, `ORDER BY`, `LIMIT`| this library's fold   | gen-select has neither         |
# | `reaches`, `why`                       | the program layer     | the fixpoint, and only here    |
# | `paths`/`path` (path enumeration)      | none — refused        | infinite on a cyclic graph     |
#
# ★★ THE SELECTOR LAYER IS THE GUARD SUBLANGUAGE, NOT "THE NON-RECURSIVE FRAGMENT", AND THE
# DISTINCTION IS WHY THE THIRD COLUMN HAS THREE ROWS. Measured at the hub: gen-select's constructors
# yield exactly nine tags — `star` `attrs` `and` `any` `not` `has` `when` `within` `parentMatches`,
# with `star` the CONSTANT universal selector and not a Kleene star — and `sel ? join`,
# `sel ? comprehension`, `sel ? fix` are ALL FALSE. Datafun (Arntzenius & Krishnaswami 2016) frames
# Datalog as relational algebra plus fixed points and carries the algebra by SET COMPREHENSION OVER
# MULTIPLE GENERATORS, with `fix` supplying recursion. gen-select has neither the comprehension nor
# the fixpoint: it is σ and its boolean closure. So a `JOIN` has no selector to compile to — a
# builder told to compile one into selectors is told to use a layer that has none — and it routes to
# the executor's fold instead. A `JOIN` IS THEREFORE NOT REFUSED.
#
# ── THE PROGRAM ROUTE: `reaches` IS A TABLE THE ENGINE COMPUTES AND THE FOLD CONSUMES ──
# A row `(src, dst, via)` says `dst` is reachable from `src` along edges labelled `via`, reflexively
# and transitively; `via = '*'` is any label — the Kleene star gen-graph's `regex.star` computes. Each
# constrained `(via, src)` is a gen-program declaration set over the IR's edges `E_via`:
#
#   one fact per edge     `<label>:<src>:<dst>`               (the IR key itself)
#   one fact per source   `reaches:<via>:<s>:<s>`             (the base case)
#   one rule per edge e   `reaches:<via>:<s>:<e.dst>` ← `reaches:<via>:<s>:<e.src>`, `<key e>`
#
# and it is solved by gen-scope's engine through gen-program — the SOLE evaluator (ADR-0006); nothing
# here computes a fixpoint. The program has no negative literal, so it is Horn, and Van Gelder, Ross
# & Schlipf 1991 Theorem 3.7 gives "Every Horn program has a well-founded model I^∞, which is the
# minimum model": the reflexive-transitive closure of the edges it is given, total, with no `U`.
#
# The relation is handed to the executor AS A TABLE, so `WHERE`, `JOIN`, projection, `ORDER BY` and
# `LIMIT` serve it unchanged — Datafun's "relational algebra plus fixed points", with the fixed point
# in the engine and the algebra where it already was. A `reaches` row is a QUERY relation and never
# an IR edge. The atom namespaces are disjoint by segment count: an edge atom has three segments and
# a `reaches` atom four, and `./materialize.nix`'s `atomEdge` reads only the first.
#
# ── `why` ──
# On `edge`, `why` is the IR's own `origin` record. On `reaches` it is `{ kind = "query";
# derivations; }`: every rule of the query program whose body is true in the model (VGRS91 Def 3.3),
# built by the same construction `./materialize.nix` uses for an edge's origin. It is ONE STEP and is
# never unfolded: on a cycle one witness of `reaches:v:a:a` leads back to itself through the cycle,
# and choosing a well-founded proof tree needs stage information the engine does not publish.
{
  lib,
  program,
  witnesses,
  qualifierOf,
}:
let
  # ★ PATH ENUMERATION IS REFUSED PERMANENTLY, NOT BY GATE. On a cyclic graph the set of paths is
  #   infinite, and Datafun's `fix` "may only be used at finite semilattice eqtypes". `reachable` and
  #   `closure` are not reserved: they are unknown names, and the door's known list names `reaches`.
  reserved = {
    path = "path enumeration";
    paths = "path enumeration";
  };

  isReserved = name: builtins.isString name && reserved ? ${name};

  refuse =
    name:
    throw "gen-inspect: unsupported construct '${name}' (${reserved.${name}}); a cyclic graph has infinitely many paths, so no finite answer exists and no gate adds one. Ask `reaches` for what a path reaches and `why` for the edge that carries it.";

  whereNames =
    expr:
    if expr == null || !(builtins.isAttrs expr) then
      [ ]
    else if expr ? op && (expr.op == "AND" || expr.op == "OR") then
      whereNames expr.left ++ whereNames expr.right
    else
      (
        if expr ? left && builtins.isAttrs expr.left && expr.left ? column then
          [ expr.left.column ]
        else
          [ ]
      )
      ++ (
        if expr ? right && builtins.isAttrs expr.right && expr.right ? column then
          [ expr.right.column ]
        else
          [ ]
      );

  names =
    ast:
    [ ast.from.kind ]
    ++ map (j: j.kind) (ast.joins or [ ])
    ++ map (c: c.column) (ast.select or [ ])
    ++ whereNames (ast.where or null)
    ++ lib.optional (ast.orderBy or null != null) ast.orderBy.column;

  # ── THE DECLARED SHAPE ──
  # `reaches`'s columns are DECLARED, never read off rows: reading rows would force the closure before
  # pushdown could prune it. `why` is a column of `edge` too, carrying the IR's `origin` record.
  any = "*";
  reachesColumns = [
    "src"
    "dst"
    "via"
    "why"
  ];

  columnsOf =
    ir: table:
    if table == "reaches" then
      reachesColumns
    else
      lib.unique (
        builtins.concatMap (row: builtins.attrNames row) (builtins.attrValues ir.tables.${table})
        ++ lib.optional (table == "edge") "why"
      );

  # ★ THE RELATA DOMAIN IS THE NODE IDS PLUS EVERY EDGE ENDPOINT, not the node ids alone. The IR
  #   contract does not require an edge's endpoints to be registered nodes, and gate 1's walk follows
  #   such an edge. A domain of node ids only refuses a question whose closure crosses one — naming an
  #   earlier-pass timing law for something that is not a timing fault — and leaves its endpoint out
  #   of the rows.
  domain =
    ir:
    lib.unique (
      map (n: n.id) ir.nodes
      ++ builtins.concatMap (e: [
        e.src
        e.dst
      ]) ir.edges
    );

  # A subject label spelled `*` would be read as the wildcard, so it is refused rather than shadowed.
  vias =
    ir:
    if builtins.elem any ir.labels then
      throw "gen-inspect: the subject declares a label named '*', which `reaches` reads as any label; rename the label"
    else
      ir.labels ++ [ any ];

  atom =
    via: s: d:
    "reaches:${via}:${s}:${d}";
  keyOf = e: "${e.label}:${e.src}:${e.dst}";

  # ONE ground program per `reaches` occurrence, over the `(via, src)` pairs it is constrained to.
  # ponytail: O(|E|) rules per (via, src) pair, O(|N|·|E|·(|L|+1)) unconstrained; a demand-driven
  # (magic-set) rewrite is the upgrade if an unconstrained `reaches` over a large graph is ever asked.
  ground =
    ir:
    { viaSet, srcSet }:
    let
      over = via: builtins.filter (e: via == any || e.label == via) ir.edges;
      byKey = es: builtins.attrValues (lib.listToAttrs (map (e: lib.nameValuePair (keyOf e) e) es));
      edgeFacts = map (e: {
        head = keyOf e;
        relata = [
          e.src
          e.dst
        ];
      }) (byKey (builtins.concatMap over viaSet));
      perSource =
        via: s:
        [
          {
            head = atom via s s;
            relata = [ s ];
          }
        ]
        ++ map (e: {
          head = atom via s e.dst;
          pos = [
            (atom via s e.src)
            (keyOf e)
          ];
          relata = [
            s
            e.src
            e.dst
          ];
        }) (over via);
      prog = program.program {
        frozen = domain ir;
        declarations =
          edgeFacts ++ builtins.concatMap (via: builtins.concatMap (perSource via) srcSet) viaSet;
      };
      model = program.model {
        program = prog;
        interpretation = [ ];
        complete = true;
      };
      # A query program's fact IS a witness: the base case `reaches:v:s:s` fires vacuously.
      derivationsOf = witnesses {
        inherit (prog) rules;
        inherit (model) verdict;
      } (_: true);
      rows = builtins.concatMap (
        via:
        builtins.concatMap (
          s:
          map (d: {
            name = "${via}:${s}:${d}";
            value = {
              src = s;
              dst = d;
              inherit via;
              why = {
                kind = "query";
                derivations = derivationsOf (atom via s d);
              };
            };
          }) (builtins.filter (d: model.verdict (atom via s d) == "true") (domain ir))
        ) srcSet
      ) viaSet;
    in
    lib.listToAttrs rows;

  # ── PUSHDOWN: PRUNING, NEVER SEMANTICS ──
  # Only top-level `AND` equalities `src = 'c'` / `via = 'c'` prune, and the whole `WHERE` still runs
  # over the result, so an unconstrained column ranges over its full domain.
  #
  # ★ PER OCCURRENCE, KEYED BY `qualifierOf`. The executor binds each FROM/JOIN item separately, so a
  #   self-join `reaches r1 JOIN reaches r2` is two relations; pruning both by `r1.src` loses r2's
  #   rows at exit 0. Each occurrence is grounded by its OWN constraints and handed to the executor
  #   under its own table key.
  # ★ AN UNQUALIFIED COLUMN IS PUSHED ONLY WHEN NO OTHER ITEM CARRIES IT. The executor merges a joined
  #   row as `left // right`, so an unqualified `src` binds to the right-hand item's `src`; in
  #   `reaches r JOIN edge e … WHERE src = 'x'` it is `e.src`, and pushing it into `r` loses rows.
  conjuncts =
    expr:
    if expr == null || !(builtins.isAttrs expr) || !(expr ? op) then
      [ ]
    else if expr.op == "AND" then
      conjuncts expr.left ++ conjuncts expr.right
    else
      [ expr ];

  equalities =
    ast:
    builtins.filter (
      c:
      c.op == "="
      && builtins.isAttrs (c.left or null)
      && c.left ? column
      && builtins.isString (c.right or null)
    ) (conjuncts (ast.where or null));

  route =
    ir: ast:
    let
      items = [ ast.from ] ++ (ast.joins or [ ]);
      carries = col: item: builtins.elem col (columnsOf ir item.kind);
      constrained =
        item: col: full:
        let
          q = qualifierOf item;
          others = builtins.filter (o: qualifierOf o != q) items;
          unqualifiedOk = !(builtins.any (carries col) others);
          hits = builtins.filter (
            c:
            c.left.column == col && (if c.left.table or null == null then unqualifiedOk else c.left.table == q)
          ) (equalities ast);
        in
        if hits == [ ] then full else lib.unique (map (c: c.right) hits);
      occurrenceKey = item: "reaches:${qualifierOf item}";
      rename =
        item:
        if item.kind == "reaches" then
          item
          // {
            kind = occurrenceKey item;
            alias = qualifierOf item;
          }
        else
          item;
      grounded = lib.listToAttrs (
        map (item: {
          name = occurrenceKey item;
          value = ground ir {
            viaSet = constrained item "via" (vias ir);
            srcSet = constrained item "src" (domain ir);
          };
        }) (builtins.filter (item: item.kind == "reaches") items)
      );
      edgeWhy.edge = builtins.mapAttrs (k: row: row // { why = ir.origins.${k}; }) ir.tables.edge;
    in
    {
      tables = ir.tables // edgeWhy // grounded;
      ast = ast // {
        from = rename ast.from;
        joins = map rename (ast.joins or [ ]);
      };
    };

  # THE ENTRY. It returns the executor's two arguments: the table map, now also holding `edge`'s
  # `why` and one grounded `reaches` relation per occurrence, and the AST, with each `reaches`
  # occurrence pointed at its own relation.
  compile =
    ir: ast:
    let
      hit = builtins.filter isReserved (names ast);
    in
    if hit != [ ] then refuse (lib.head hit) else route ir ast;

  # `i.why <atom>`: an IR key answers its `origin`; a `reaches` atom that holds answers the query
  # program's derivations for its `(via, src)`; anything else is refused by name.
  why =
    ir: a:
    let
      p = lib.splitString ":" a;
      via = lib.elemAt p 1;
      s = lib.elemAt p 2;
      k = "${via}:${s}:${lib.elemAt p 3}";
      rel = ground ir {
        viaSet = [ via ];
        srcSet = [ s ];
      };
    in
    if ir.origins ? ${a} then
      ir.origins.${a}
    else if lib.length p != 4 || lib.head p != "reaches" then
      throw "gen-inspect: '${a}' is neither an IR edge key nor a reaches atom"
    else if !(builtins.elem via (vias ir)) then
      throw "gen-inspect: unknown via '${via}'; known: ${builtins.concatStringsSep ", " (vias ir)}"
    else if !(builtins.elem s (domain ir)) then
      throw "gen-inspect: unknown src '${s}'; known: ${builtins.concatStringsSep ", " (domain ir)}"
    else if rel ? ${k} then
      rel.${k}.why
    else
      throw "gen-inspect: '${a}' does not hold, so it has no derivation";
in
{
  inherit
    compile
    isReserved
    reserved
    columnsOf
    domain
    vias
    why
    ;
  reservedNames = builtins.attrNames reserved;
}
