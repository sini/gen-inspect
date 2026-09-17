# THE DOOR — every bad state refused BY NAME, WITH THE KNOWN SET, before it can form.
#
# ★ WHY THIS EXISTS AT ALL: against the raw row source, every one of these shapes reads `[]` or a row
# of `null`s AT EXIT 0. An unknown table yields no rows; a typo'd column projects `null`; a label
# value nothing publishes yields the empty answer. All three are indistinguishable from "the policy
# produced nothing", which is the one reading this library exists to make impossible.
#
# The known sets are all in hand at the IR — `ir.tables`, each table's column projection,
# `ir.labels`, `ir.kinds` — so refusing costs nothing but the comparison.
#
# ★ `deepSeq`, NOT `seq`. `builtins.seq` over the checked-name list forces the list to WHNF and not
# one element, so a door built on it reads exit 0 on EVERY bad shape — a refusal that refuses
# nothing looks exactly like a working one.
{ lib, compile }:
let
  known = set: builtins.concatStringsSep ", " (builtins.attrNames set);

  # A table's columns are the union over its rows, because a row is an attrs splat and two rows of
  # one kind need not carry the same optional attributes. `name` and `kind` are injected by the IR's
  # own projection and are therefore columns of every table.
  columnsOf =
    ir: table:
    lib.unique (
      builtins.concatMap (row: builtins.attrNames row) (builtins.attrValues ir.tables.${table})
    );

  checkTable =
    ir: name:
    # A reserved construct is a KNOWN name this gate does not serve, not an unknown one. It is left
    # for `compile` to refuse, naming the construct and the layer that owes it; refusing it here as
    # "unknown" would tell a reader to check their spelling of a word that is spelled correctly.
    if compile.isReserved name then
      name
    else if ir.tables ? ${name} then
      name
    else
      throw "gen-inspect: unknown name '${name}'; known: ${known ir.tables}";

  # The column domain is the union over the FROM table and every joined table, because a join widens
  # the row: a column that exists only on the joined side is legitimate and must not be refused.
  columnsOver = ir: tables: lib.unique (builtins.concatMap (columnsOf ir) tables);

  checkColumn =
    ir: tables: col:
    if col == "*" then
      col
    else if compile.isReserved col then
      col
    else if builtins.elem col (columnsOver ir tables) then
      col
    else
      throw "gen-inspect: unknown name '${col}'; known: ${builtins.concatStringsSep ", " (columnsOver ir tables)}";

  # ── THE VALUE DOOR ──
  # ★ A well-formed `WHERE label = 'anvils'` over a KNOWN column returns `[]` at exit 0 without this
  #   — indistinguishable from "the policy produced nothing". `kind` is here on the IR contract's
  #   own words: `kinds` is "what a `WHERE kind = '…'` resolves against".
  #
  # ★ A MEASURED DOOR THIS RESPECTS RATHER THAN DUPLICATES: gen-select's own `sel.kind` refuses a
  #   string — "sel.kind expects a kind value (e.g. schema.user), got the string …; pass the kind
  #   value; strings are internal keys only". A SQL `WHERE kind = '…'` therefore never reaches
  #   `sel.kind`: the executor compiles `=` to `sel.when`, and this door resolves the string against
  #   `ir.kinds` first.
  valueSets = ir: {
    label = ir.labels;
    kind = builtins.attrNames ir.kinds;
  };

  checkValue =
    ir: col: value:
    let
      sets = valueSets ir;
    in
    if !(sets ? ${col}) || !(builtins.isString value) || builtins.elem value sets.${col} then
      value
    else
      throw "gen-inspect: unknown ${col} '${value}'; known: ${
        builtins.concatStringsSep ", " sets.${col}
      }";

  # Walk the WHERE tree for equality-shaped comparisons against a value-doored column.
  checkWhere =
    ir: expr:
    if expr == null || !(builtins.isAttrs expr) || !(expr ? op) then
      [ ]
    else if expr.op == "AND" || expr.op == "OR" then
      checkWhere ir expr.left ++ checkWhere ir expr.right
    else if
      (expr.op == "=" || expr.op == "!=")
      && expr ? left
      && builtins.isAttrs expr.left
      && expr.left ? column
      && expr ? right
    then
      [ (checkValue ir expr.left.column expr.right) ]
    else if expr.op == "IN" && expr ? left && builtins.isAttrs expr.left && expr.left ? column then
      map (v: checkValue ir expr.left.column v) (
        if builtins.isList expr.right then expr.right else [ expr.right ]
      )
    else
      [ ];

  whereColumns =
    expr:
    if expr == null || !(builtins.isAttrs expr) then
      [ ]
    else if expr ? op && (expr.op == "AND" || expr.op == "OR") then
      whereColumns expr.left ++ whereColumns expr.right
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

  # THE ONE ENTRY. It returns the AST so the pipeline reads `parse → door → compile → executor`.
  #
  # ★ THE THREE CHECKS ARE FORCED IN ORDER, NOT AS ONE ATTRSET. Nix does not order an attrset's
  #   members, so a query that is bad in two ways refused under whichever member happened to be
  #   forced first — measured: `WHERE kind = 'anvil'` on the edge table, whose `kind` column does not
  #   exist either, reported the VALUE refusal on one run. Chaining `seq` makes the message a
  #   function of the query rather than of the evaluator: the widest name fails first.
  #
  # ★ A RESERVED CONSTRUCT SHORT-CIRCUITS THE WHOLE DOOR. `FROM reaches` names a table this gate does
  #   not serve, so its column domain is EMPTY and every projected column reads as unknown against an
  #   empty known set — measured before this guard: `SELECT src FROM reaches` refused with
  #   "unknown name 'src'; known: ", which tells a reader to check the spelling of a correct column
  #   and never mentions the construct. The construct refusal is `compile`'s and it is the only one
  #   this query should see.
  check =
    ir: ast:
    let
      tableNames = [ ast.from.kind ] ++ map (j: j.kind) (ast.joins or [ ]);
      tables = map (checkTable ir) tableNames;
      present = builtins.filter (t: ir.tables ? ${t}) tables;
      columns =
        map (c: checkColumn ir present c.column) (ast.select or [ ])
        ++ map (c: checkColumn ir present c) (whereColumns (ast.where or null))
        ++ lib.optional (ast.orderBy or null != null) (checkColumn ir present ast.orderBy.column);
      values = checkWhere ir (ast.where or null);
    in
    if builtins.any compile.isReserved tableNames then
      ast
    else
      builtins.deepSeq tables (builtins.deepSeq columns (builtins.deepSeq values ast));
in
{
  inherit
    check
    checkTable
    checkColumn
    checkValue
    columnsOf
    ;
}
