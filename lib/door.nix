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
{
  lib,
  compile,
  qualifierOf,
}:
let
  # `reaches` is a table the program route computes, so it is known without being in `ir.tables`.
  tableSet = ir: ir.tables // { reaches = { }; };
  known = set: builtins.concatStringsSep ", " (builtins.attrNames set);

  # A table's columns are the union over its rows, because a row is an attrs splat and two rows of
  # one kind need not carry the same optional attributes. `name` and `kind` are injected by the IR's
  # own projection and are therefore columns of every table. `reaches`'s are DECLARED (`./compile.nix`)
  # and `edge` also carries `why`.
  inherit (compile) columnsOf;

  checkTable =
    ir: name:
    # A reserved construct is a KNOWN name no route serves, not an unknown one. It is left for
    # `compile` to refuse, naming the construct and the reason; refusing it here as "unknown" would
    # tell a reader to check their spelling of a word that is spelled correctly.
    if compile.isReserved name then
      name
    else if tableSet ir ? ${name} then
      name
    else
      throw "gen-inspect: unknown name '${name}'; known: ${known (tableSet ir)}";

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
  #
  # ★ `via` AND, ON A QUERY OVER `reaches`, `src`. Without the `via` door `via = 'anvils'` grounds no
  #   edge and answers the reflexive row alone at exit 0 — "hemony reaches nothing". `src` ranges over
  #   the relata domain (node ids plus every edge endpoint); an edge's `src` is always in it, so the
  #   door is sound for a joined `edge` too, and it is scoped to `reaches` queries because another
  #   table may carry a `src` attribute of its own.
  valueSets =
    ir: tables:
    {
      label = ir.labels;
      kind = builtins.attrNames ir.kinds;
      via = compile.vias ir;
    }
    // lib.optionalAttrs (builtins.elem "reaches" tables) { src = compile.domain ir; };

  checkValue =
    ir: tables: col: value:
    let
      sets = valueSets ir tables;
    in
    if !(sets ? ${col}) || !(builtins.isString value) || builtins.elem value sets.${col} then
      value
    else
      throw "gen-inspect: unknown ${col} '${value}'; known: ${
        builtins.concatStringsSep ", " sets.${col}
      }";

  # Walk the WHERE tree for equality-shaped comparisons against a value-doored column.
  checkWhere =
    ir: tables: expr:
    if expr == null || !(builtins.isAttrs expr) || !(expr ? op) then
      [ ]
    else if expr.op == "AND" || expr.op == "OR" then
      checkWhere ir tables expr.left ++ checkWhere ir tables expr.right
    else if
      (expr.op == "=" || expr.op == "!=")
      && expr ? left
      && builtins.isAttrs expr.left
      && expr.left ? column
      && expr ? right
    then
      [ (checkValue ir tables expr.left.column expr.right) ]
    else if expr.op == "IN" && expr ? left && builtins.isAttrs expr.left && expr.left ? column then
      map (v: checkValue ir tables expr.left.column v) (
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

  # ── THE QUALIFIER DOOR ──
  # ★ A QUALIFIER THE EXECUTOR CANNOT RESOLVE FALLS BACK TO THE UNQUALIFIED ROW, which is a silent
  #   wrong answer rather than a refusal — measured on the origin: `FROM tocsin JOIN belfry ON
  #   tocsin.belfry = belfry.name` answered `[ ]` at exit 0. The known set is each FROM/JOIN item's
  #   correlation name (`qualifierOf`: its alias, else its table name). Two items with one name make
  #   every reference to it ambiguous, so a duplicate is refused before any reference is resolved.
  refOf = r: lib.optional (builtins.isAttrs r && r ? table && r.table != null) r.table;

  whereQualifiers =
    expr:
    if expr == null || !(builtins.isAttrs expr) || !(expr ? op) then
      [ ]
    else if expr.op == "AND" || expr.op == "OR" then
      whereQualifiers expr.left ++ whereQualifiers expr.right
    else
      refOf (expr.left or null) ++ refOf (expr.right or null);

  checkQualifiers =
    ast:
    let
      declared = map qualifierOf ([ ast.from ] ++ (ast.joins or [ ]));
      dups = lib.unique (
        builtins.filter (n: builtins.length (builtins.filter (m: m == n) declared) > 1) declared
      );
      used =
        builtins.concatMap refOf (ast.select or [ ])
        ++ builtins.concatMap (j: refOf j.on.left ++ refOf j.on.right) (ast.joins or [ ])
        ++ whereQualifiers (ast.where or null)
        ++ refOf (ast.orderBy or null);
      unknown = builtins.filter (q: !(builtins.elem q declared)) used;
    in
    if dups != [ ] then
      throw "gen-inspect: duplicate qualifier '${builtins.head dups}'; give each FROM/JOIN item a distinct alias"
    else if unknown != [ ] then
      throw "gen-inspect: unknown qualifier '${builtins.head unknown}'; known: ${builtins.concatStringsSep ", " declared}"
    else
      declared;

  # THE ONE ENTRY. It returns the AST so the pipeline reads `parse → door → compile → executor`.
  #
  # ★ THE THREE CHECKS ARE FORCED IN ORDER, NOT AS ONE ATTRSET. Nix does not order an attrset's
  #   members, so a query that is bad in two ways refused under whichever member happened to be
  #   forced first — measured: `WHERE kind = 'anvil'` on the edge table, whose `kind` column does not
  #   exist either, reported the VALUE refusal on one run. Chaining `seq` makes the message a
  #   function of the query rather than of the evaluator: the widest name fails first.
  #
  # ★ A RESERVED CONSTRUCT SHORT-CIRCUITS THE WHOLE DOOR. `FROM paths` names a table no route serves,
  #   so its column domain is EMPTY and every projected column reads as unknown against an empty known
  #   set — measured on the gate-1 form of this guard: `SELECT src FROM reaches` refused with
  #   "unknown name 'src'; known: ", which tells a reader to check the spelling of a correct column
  #   and never mentions the construct. The construct refusal is `compile`'s and it is the only one
  #   this query should see.
  check =
    ir: ast:
    let
      tableNames = [ ast.from.kind ] ++ map (j: j.kind) (ast.joins or [ ]);
      tables = map (checkTable ir) tableNames;
      present = builtins.filter (t: tableSet ir ? ${t}) tables;
      columns =
        map (c: checkColumn ir present c.column) (ast.select or [ ])
        ++ map (c: checkColumn ir present c) (whereColumns (ast.where or null))
        ++ lib.optional (ast.orderBy or null != null) (checkColumn ir present ast.orderBy.column);
      values = checkWhere ir tables (ast.where or null);
      qualifiers = checkQualifiers ast;
    in
    if builtins.any compile.isReserved tableNames then
      ast
    else
      builtins.deepSeq tables (
        builtins.deepSeq columns (builtins.deepSeq values (builtins.deepSeq qualifiers ast))
      );
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
