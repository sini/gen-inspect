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
# TWO CHANGES AGAINST THE ORIGIN, BOTH NAMED.
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
      sel.any [
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

      # The ON condition tells us which field on the join table matches which field on the left
      # e.g., ON svc.server = s.name means: joinRow.server == leftRow.name
      matchRows =
        leftRow: leftAlias:
        let
          # Build alias map for value resolution
          rowAliases =
            leftAlias
            // lib.optionalAttrs (join.alias != null) {
              ${join.alias} = leftRow; # placeholder, will be replaced per join row
            };

          matching = lib.filterAttrs (
            _: joinRow:
            let
              fullAliases =
                rowAliases
                // lib.optionalAttrs (join.alias != null) {
                  ${join.alias} = joinRow;
                };
              lv = resolveValue fullAliases leftRow join.on.left;
              rv = resolveValue fullAliases leftRow join.on.right;
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
                aliases =
                  rowAliases
                  // lib.optionalAttrs (join.alias != null) {
                    ${join.alias} = { };
                  };
              }
            ]
          else
            [ ]
        else
          lib.mapAttrsToList (_: joinRow: {
            row = leftRow // joinRow;
            aliases =
              rowAliases
              // lib.optionalAttrs (join.alias != null) {
                ${join.alias} = joinRow;
              };
          }) matching;
    in
    builtins.concatMap (item: matchRows item.row item.aliases) leftRows;

  # Project selected columns from a row
  projectRow =
    aliases: row: selectCols:
    if builtins.length selectCols == 1 && (builtins.head selectCols).column == "*" then
      row
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
    evalQuery fleet ast;

  # Evaluate a parsed AST against fleet data
  evalQuery =
    fleet: ast:
    let
      # FROM clause
      fromKind = resolveKind ast.from.kind;
      fromRows = getRows fleet fromKind;
      fromAlias = ast.from.alias;

      # Build initial row set with alias tracking
      initialRows = lib.mapAttrsToList (_: row: {
        inherit row;
        aliases = lib.optionalAttrs (fromAlias != null) { ${fromAlias} = row; };
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

      # Project columns
      projectedRows = map (item: projectRow item.aliases item.row ast.select) filteredRows;

      # ORDER BY
      orderedRows =
        if ast.orderBy == null then
          projectedRows
        else
          let
            colName = ast.orderBy.column;
          in
          builtins.sort (a: b: compareValues (a.${colName} or "") (b.${colName} or "")) projectedRows;

      # LIMIT
      limitedRows = if ast.limit == null then orderedRows else lib.take ast.limit orderedRows;
    in
    limitedRows;

in
{
  inherit
    query
    evalQuery
    astToSelector
    mkRowContext
    resolveKind
    getRows
    getField
    ;
}
