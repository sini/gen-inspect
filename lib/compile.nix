# THE COMPILE RULE — THREE ROUTES BY EXECUTOR, NOT TWO BY RECURSION.
#
# | construct                              | executor              | why                            |
# |----------------------------------------|-----------------------|--------------------------------|
# | `WHERE` predicate                      | gen-select            | `astToSelector`                |
# | `JOIN`, projection, `ORDER BY`, `LIMIT`| this library's fold   | gen-select has neither         |
# | reachability, transitive closure, `WHY`| the program layer     | the fixpoint, and only here    |
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
# ── THE THIRD ROUTE IS A DOOR, NOT A STUB ──
# At this gate reachability, transitive closure and `WHY` are refused BY NAME, naming the construct.
# A stub answering silently would make gate 2's replacement invisible; a door refuses, so gate 2
# replaces this body with the program route and changes no caller.
{ lib }:
let
  # ★ THE RESERVED SET IS DECLARED HERE AND READ BY THE DOOR. `./door.nix` refuses an unknown table
  #   or column BY NAME off `ir.tables`, and a reserved construct is not an unknown name — it is a
  #   KNOWN name this gate does not serve. Two refusals for one input is one refusal too many, so
  #   the door defers every name on this list and the message a reader gets says which gate owes it.
  reserved = {
    reaches = "reachability";
    reachable = "reachability";
    closure = "transitive closure";
    why = "why — the derivation of a derived edge";
    path = "path enumeration";
    paths = "path enumeration";
  };

  isReserved = name: builtins.isString name && reserved ? ${name};

  refuse =
    name:
    throw "gen-inspect: unsupported construct '${name}' (${reserved.${name}}); it compiles onto the program layer, which this gate does not build. Supported at this gate: SELECT, FROM, JOIN, LEFT JOIN, WHERE, ORDER BY, LIMIT over the materialized IR.";

  # Every name position a reserved construct can arrive at. The WHERE tree is walked whole rather
  # than at its root: `WHERE why IS NOT NULL` names the construct just as `FROM why` does.
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

  # The AST passes through unchanged when no route is refused: at this gate the executor serves
  # every construct the parser produces, so `compile` is the REFUSAL and not a translation. It is a
  # named stage rather than an inlined guard because gate 2's second route replaces exactly this
  # body.
  compile =
    ast:
    let
      hit = builtins.filter isReserved (names ast);
    in
    if hit == [ ] then ast else refuse (lib.head hit);
in
{
  inherit compile isReserved reserved;
  reservedNames = builtins.attrNames reserved;
}
