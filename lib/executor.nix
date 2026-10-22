# ══ ORIGIN ══════════════════════════════════════════════════════════════════════════════════════
# COPIED, not imported, from `gen-scope/examples/sql-schema/lib/engine.nix` at gen-scope
# `675d9f3542320546351605ba29f7c6361fcb0268`; md5 of the source file at that rev is
# `374c959d0c68b3d980c2f3487d5c7d37`. The same ADR-0037 ground as `./sql.nix` — an example is not
# published surface, and a second root input to reach one is what the ADR forbids.
#
# THIS IS THE EXECUTOR OF THE DESIGN'S COMPILE RULE (§2.1): the route that serves `JOIN`,
# projection, `ORDER BY` and `LIMIT`. gen-select has neither a join nor a comprehension — measured,
# its constructors yield exactly nine tags and `sel ? join` is false — so those constructs have no
# selector to compile to and this fold is where they go. `WHERE` still compiles to gen-select, in
# `astToSelector` below, which is the second route and is unchanged from the origin.
#
# FOUR CHANGES AGAINST THE ORIGIN, EACH NAMED.
#
# (1) ★ THE KIND-ALIAS TABLE IS STRIPPED TO THE IDENTITY. The origin carried 23 entries mapping
#     plural SQL table names to singular fleet kinds, and those entries sit AT KIND POSITION:
#     `user`, `service`, `server`, `network`, `port`, `interface`, `datacenter` among them. ADR-0035
#     admits no den or fleet vocabulary at kind, label, option or error position anywhere in this
#     library's text, so the table cannot be carried and is not merely renamed — `resolveKind` is
#     now the identity, and a caller wanting a plural table name spells the kind it declared. The
#     binding stays rather than being inlined away: it is the ONE site a later normalization would
#     re-enter, and deleting it would move that decision to 4 call sites.
#
# (2) `import ./sql.nix` resolves to this library's copied parser, a sibling in `lib/`.
#
# (3) ★ A TABLE WITH NO DECLARED ALIAS IS QUALIFIED BY ITS OWN NAME (`qualifierOf`). The origin
#     populated the alias map from an explicit alias only, so `FROM tocsin JOIN belfry ON
#     tocsin.belfry = belfry.name` resolved both qualifiers to the unqualified fallback and answered
#     `[ ]` at exit 0. SQL's range-variable rule: a FROM item's correlation name is its alias if one is
#     given, else the table name. An unknown or duplicated qualifier is refused in `./door.nix`.
#
# (4) ★ THE AMBIGUITY DOOR (`ambiguityRefusals`) AND THE PROJECTION/ORDER/ON SCOPING THAT GO WITH IT.
#     The origin merged a joined row as `leftRow // joinRow`, so a column both sides carry read the
#     right side's value, and keyed the projection and the sort by the bare column name, so two
#     columns of one name collapsed to one, a `*` inside a column list became a column named `*`, an
#     ORDER BY ignored its qualifier and sorted an unprojected column as "", and an unqualified ON
#     column read only the left row. Each answered WRONG at exit 0; each is now refused by name or
#     served as SQL's range-variable rule reads it: a lone `t.*` is t's columns, an ORDER BY column is
#     read from the row the query ranges over rather than from the projection, and an unqualified ON
#     column is read from the row the join builds, refused when no item in scope at that JOIN carries it.
#
# `lib` here is gen-prelude extended by `./extras.nix`, not nixpkgs `lib`; see that file's header.
# The three nixpkgs names the origin used that the prelude does not publish —
# `stringToCharacters`, `concatStrings`, `take` — arrive from the extension under the same
# spellings, so no call site in this file moved.
# ════════════════════════════════════════════════════════════════════════════════════════════════
#
# SQL query engine — evaluates parsed ASTs against materialized IR tables.
#
# JOINs are resolved via field lookup in the IR's table projection.
# WHERE predicates filter rows. ORDER BY sorts. LIMIT truncates.
{ lib, genSelect }:
let
  # ★ THE IDENTITY, by ADR-0035 — see change (1) in this file's origin header. A table name IS the
  # kind name: the IR's `tables` are keyed by the register's own kinds, and `ir.kinds` is what a
  # `WHERE kind = '…'` resolves against.
  resolveKind = name: name;

  # The correlation name of a FROM or JOIN item: its alias if declared, else its table name.
  qualifierOf = item: if item.alias != null then item.alias else item.kind;

  # Get rows from fleet: { name → row } with name injected
  getRows =
    fleet: kindName:
    let
      kind = resolveKind kindName;
    in
    lib.mapAttrs (name: row: (if builtins.isAttrs row then row else { }) // { inherit name; }) (
      fleet.${kind} or { }
    );

  # Resolve a field value from a row, handling ref instances (extract .name)
  getField =
    row: fieldName:
    let
      raw = row.${fieldName} or null;
    in
    if raw == null then
      null
    else if builtins.isAttrs raw && raw ? name then
      raw.name
    else if builtins.isList raw && builtins.length raw > 0 && builtins.isAttrs (builtins.head raw) then
      map (x: if builtins.isAttrs x && x ? name then x.name else x) raw
    else
      raw;

  sel = genSelect;

  # Convert SQL LIKE pattern to Nix regex: % → .*, _ → ., escape rest
  likeToRegex =
    p:
    let
      chars = lib.stringToCharacters p;
      converted = map (
        c:
        if c == "%" then
          ".*"
        else if c == "_" then
          "."
        else if
          builtins.elem c [
            "."
            "^"
            "$"
            "["
            "]"
            "("
            ")"
            "{"
            "}"
            "\\"
            "+"
            "?"
            "|"
          ]
        then
          "\\${c}"
        else
          c
      ) chars;
    in
    lib.concatStrings converted;

  # Build a gen-select context for a single row
  mkRowContext = row: {
    data = _id: row;
    parent = _: null;
    children = _: [ ];
    ancestors = _: [ ];
    siblings = _: [ ];
  };

  # Compile a WHERE AST node into a gen-select selector
  astToSelector =
    aliases: expr:
    if expr == null then
      sel.star
    else if expr.op == "AND" then
      sel.and [
        (astToSelector aliases expr.left)
        (astToSelector aliases expr.right)
      ]
    else if expr.op == "OR" then
      sel.anyOf [
        (astToSelector aliases expr.left)
        (astToSelector aliases expr.right)
      ]
    else if expr.op == "=" then
      sel.when (
        _id: ctx:
        let
          row = ctx.data _id;
        in
        resolveValue aliases row expr.left == resolveValue aliases row expr.right
      )
    else if expr.op == "!=" then
      sel.when (
        _id: ctx:
        let
          row = ctx.data _id;
        in
        resolveValue aliases row expr.left != resolveValue aliases row expr.right
      )
    else if expr.op == ">" then
      sel.when (
        _id: ctx:
        let
          row = ctx.data _id;
        in
        resolveValue aliases row expr.left > resolveValue aliases row expr.right
      )
    else if expr.op == ">=" then
      sel.when (
        _id: ctx:
        let
          row = ctx.data _id;
        in
        resolveValue aliases row expr.left >= resolveValue aliases row expr.right
      )
    else if expr.op == "<" then
      sel.when (
        _id: ctx:
        let
          row = ctx.data _id;
        in
        resolveValue aliases row expr.left < resolveValue aliases row expr.right
      )
    else if expr.op == "<=" then
      sel.when (
        _id: ctx:
        let
          row = ctx.data _id;
        in
        resolveValue aliases row expr.left <= resolveValue aliases row expr.right
      )
    else if expr.op == "LIKE" then
      sel.when (
        _id: ctx:
        let
          row = ctx.data _id;
          lv = resolveValue aliases row expr.left;
          regex = likeToRegex expr.right;
        in
        builtins.isString lv && builtins.match regex lv != null
      )
    else if expr.op == "IN" then
      sel.when (
        _id: ctx:
        let
          row = ctx.data _id;
          lv = resolveValue aliases row expr.left;
          rv = expr.right;
        in
        # Forward: column IN (values)
        if builtins.isList rv then
          if builtins.isList lv then builtins.any (item: builtins.elem item rv) lv else builtins.elem lv rv
        # Reverse: 'value' IN column (column is a list)
        else if builtins.isList lv then
          builtins.elem rv lv
        else
          lv == rv
      )
    else if expr.op == "IS NULL" then
      sel.when (_id: ctx: resolveValue aliases (ctx.data _id) expr.left == null)
    else if expr.op == "IS NOT NULL" then
      sel.when (_id: ctx: resolveValue aliases (ctx.data _id) expr.left != null)
    else
      throw "sql-engine: unsupported WHERE operator '${expr.op}'";

  # Resolve a value reference (column ref or literal)
  resolveValue =
    aliases: row: ref:
    if builtins.isString ref then
      ref
    else if builtins.isInt ref then
      ref
    else if builtins.isBool ref then
      ref
    else if builtins.isAttrs ref && ref ? column then
      let
        targetRow = if ref.table != null && aliases ? ${ref.table} then aliases.${ref.table} else row;
      in
      getField targetRow ref.column
    else
      ref;

  # Resolve a JOIN: for each row in leftRows, find matching rows in the joined kind
  resolveJoin =
    fleet: join: leftRows: leftAliases:
    let
      joinKind = resolveKind join.kind;
      joinRows = getRows fleet joinKind;
      joinAlias = qualifierOf join;

      # The ON condition tells us which field on the join table matches which field on the left
      # e.g., ON svc.server = s.name means: joinRow.server == leftRow.name
      matchRows =
        leftRow: leftAlias:
        let
          # Build alias map for value resolution
          rowAliases = leftAlias // {
            ${joinAlias} = leftRow; # placeholder, will be replaced per join row
          };

          matching = lib.filterAttrs (
            _: joinRow:
            let
              fullAliases = rowAliases // {
                ${joinAlias} = joinRow;
              };
              # An unqualified ON column is read from the merged row, so one carried only by the
              # joined item resolves; one both carry is refused in `ambiguityRefusals`.
              lv = resolveValue fullAliases (leftRow // joinRow) join.on.left;
              rv = resolveValue fullAliases (leftRow // joinRow) join.on.right;
            in
            lv == rv
          ) joinRows;
        in
        if matching == { } then
          if join.isLeft then
            # LEFT JOIN: include row with nulls for joined fields
            [
              {
                row = leftRow;
                aliases = rowAliases // {
                  ${joinAlias} = { };
                };
              }
            ]
          else
            [ ]
        else
          lib.mapAttrsToList (_: joinRow: {
            row = leftRow // joinRow;
            aliases = rowAliases // {
              ${joinAlias} = joinRow;
            };
          }) matching;
    in
    builtins.concatMap (item: matchRows item.row item.aliases) leftRows;

  # Project selected columns from a row
  projectRow =
    aliases: row: selectCols:
    if builtins.length selectCols == 1 && (builtins.head selectCols).column == "*" then
      let
        star = builtins.head selectCols;
      in
      if star.table != null && aliases ? ${star.table} then aliases.${star.table} else row
    else
      lib.listToAttrs (
        map (
          col:
          let
            targetRow = if col.table != null && aliases ? ${col.table} then aliases.${col.table} else row;
            val = getField targetRow col.column;
          in
          {
            name = col.column;
            value = val;
          }
        ) selectCols
      );

  # ── THE AMBIGUITY DOOR ──
  # A joined row is `leftRow // joinRow`, so a column both sides carry reads the right side's value,
  # and the projection keys its output by the bare column name, so two columns of one name collapse
  # to one. Each answers WRONG at exit 0, so each is refused by name instead.
  whereRefs =
    expr:
    if expr == null || !(builtins.isAttrs expr) || !(expr ? op) then
      [ ]
    else if expr.op == "AND" || expr.op == "OR" then
      whereRefs expr.left ++ whereRefs expr.right
    else
      builtins.filter (r: builtins.isAttrs r && r ? column) [
        (expr.left or null)
        (expr.right or null)
      ];

  ambiguityRefusals =
    fleet: ast:
    let
      items = [ ast.from ] ++ ast.joins;
      columnsOfItem =
        item:
        lib.unique (builtins.concatMap builtins.attrNames (builtins.attrValues (getRows fleet item.kind)));
      cols = map (item: {
        q = qualifierOf item;
        columns = columnsOfItem item;
      }) items;
      carriersIn = scope: col: map (c: c.q) (builtins.filter (c: builtins.elem col c.columns) scope);
      carriers = carriersIn cols;
      ambiguous = col: builtins.length (carriers col) > 1;
      unqualified = builtins.filter (r: r.table == null && r.column != "*") (
        ast.select
        ++ builtins.concatMap (j: [
          j.on.left
          j.on.right
        ]) ast.joins
        ++ whereRefs ast.where
        ++ lib.optional (ast.orderBy != null) ast.orderBy
      );
      named = map (c: c.column) (builtins.filter (c: c.column != "*") ast.select);
      shared = builtins.filter ambiguous (lib.unique (builtins.concatMap (c: c.columns) cols));
      # An unqualified ON column must be carried by an item in scope at its JOIN: the items to its
      # left and the joined one.
      onOutOfScope = builtins.concatMap (
        n:
        let
          j = builtins.elemAt ast.joins n;
          scope = lib.take (n + 2) cols;
        in
        map
          (r: {
            inherit (r) column;
            scope = map (c: c.q) scope;
          })
          (
            builtins.filter (r: r.table == null && carriersIn scope r.column == [ ]) [
              j.on.left
              j.on.right
            ]
          )
      ) (builtins.genList (n: n) (builtins.length ast.joins));
      stars = builtins.filter (c: c.column == "*") ast.select;
      starSpelling = c: if c.table == null then "*" else "${c.table}.*";
    in
    lib.optional (ast.joins != [ ]) (
      builtins.deepSeq (map (
        r:
        if ambiguous r.column then
          throw "gen-inspect: ambiguous column '${r.column}'; carried by ${builtins.concatStringsSep ", " (carriers r.column)}; qualify it"
        else
          null
      ) unqualified) null
    )
    ++ map (
      o:
      throw "gen-inspect: column '${o.column}' is not carried by an item in scope at its JOIN (${builtins.concatStringsSep ", " o.scope}); qualify it or join its table first"
    ) onOutOfScope
    ++ lib.optional (builtins.length ast.select > 1 && stars != [ ]) (
      throw "gen-inspect: '${starSpelling (lib.head stars)}' inside a column list is not a column; select it alone or name the columns"
    )
    ++
      lib.optional
        (
          ast.joins != [ ]
          && builtins.length ast.select == 1
          && stars != [ ]
          && (lib.head stars).table == null
          && shared != [ ]
        )
        (
          throw "gen-inspect: SELECT * over a join is ambiguous; ${builtins.concatStringsSep ", " shared} ${
            if builtins.length shared == 1 then "is" else "are"
          } carried by more than one of ${builtins.concatStringsSep ", " (map qualifierOf items)}; name the columns"
        )
    ++ map (
      n:
      throw "gen-inspect: duplicate output column '${n}'; a projection keys by column name, so the second would replace the first"
    ) (lib.unique (builtins.filter (n: builtins.length (builtins.filter (m: m == n) named) > 1) named));

  # Compare values for ORDER BY
  compareValues =
    a: b:
    if builtins.isString a && builtins.isString b then
      a < b
    else if builtins.isInt a && builtins.isInt b then
      a < b
    else
      builtins.toJSON a < builtins.toJSON b;

  # Main query function: fleet → SQL string → result set
  query =
    fleet: sqlString:
    let
      parseSql = (import ./sql.nix { inherit lib; }).parseSql;
      ast = parseSql sqlString;
    in
    evalQuery ast fleet;

  # Evaluate a parsed AST against fleet data. SUBJECT LAST (den-hoag-7gp66 P2, rule 4): the AST is
  # the configuration, the table map it runs over is the subject, so `evalQuery ast fleet`.
  evalQuery =
    ast: fleet:
    let
      # FROM clause
      fromKind = resolveKind ast.from.kind;
      fromRows = getRows fleet fromKind;
      fromAlias = qualifierOf ast.from;

      # Build initial row set with alias tracking
      initialRows = lib.mapAttrsToList (_: row: {
        inherit row;
        aliases = {
          ${fromAlias} = row;
        };
      }) fromRows;

      # Apply JOINs sequentially
      joinedRows = builtins.foldl' (
        rows: join: resolveJoin fleet join rows (builtins.head rows).aliases or { }
      ) initialRows ast.joins;

      # Apply WHERE filter via gen-select selector
      filteredRows = builtins.filter (
        item:
        let
          selector = astToSelector item.aliases ast.where;
          ctx = mkRowContext item.row;
        in
        genSelect.matches selector "row" ctx
      ) joinedRows;

      # ORDER BY sorts the rows the query ranges over, by the column it names (qualifier honoured,
      # projected or not); a null column sorts as "".
      orderedItems =
        if ast.orderBy == null then
          filteredRows
        else
          let
            key =
              item:
              let
                v = resolveValue item.aliases item.row ast.orderBy;
              in
              if v == null then "" else v;
          in
          builtins.sort (a: b: compareValues (key a) (key b)) filteredRows;

      # Project columns
      orderedRows = map (item: projectRow item.aliases item.row ast.select) orderedItems;

      # LIMIT
      limitedRows = if ast.limit == null then orderedRows else lib.take ast.limit orderedRows;
    in
    builtins.deepSeq (ambiguityRefusals fleet ast) limitedRows;

in
{
  inherit
    query
    evalQuery
    astToSelector
    mkRowContext
    resolveKind
    qualifierOf
    getRows
    getField
    ;
}
