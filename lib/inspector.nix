# mkInspector — THE CONSUMER'S FLAKE OUTPUT, BOUND TO ONE SUBJECT.
#
# The library publishes PURE FUNCTIONS ONLY — no app, no CLI. The human entries are the nix ones:
#
#   nix eval --json .#inspect --apply 'i: i.query "SELECT src, dst FROM edge WHERE label = '\''rings'\''"'
#   nix eval --raw  .#inspect --apply 'i: i.render.mermaid i.facts'
#   nix repl .#
#
# ★ ONE DOOR, BOTH ENTRIES THROUGH IT. `query` is the only text stage and every refusal it raises is
# an evaluation error, so `nix eval` and `nix repl` surface the same refusal with the same message by
# construction rather than by two code paths agreeing.
#
# ★ A FIXED MENU OF DEMO QUERIES WOULD FAIL THIS COMPONENT'S ACCEPTANCE BY CONSTRUCTION. The exit is
# a person running a query OF THEIR OWN CHOOSING, so `query` takes arbitrary text and the doors are
# what make an unanticipated query either answer or refuse by name.
{
  lib,
  genSelect,
  materialize,
  selecting,
  sql,
  door,
  compile,
  executor,
  render,
}:
let
  # The pipeline of §2.4, left to right, with nothing between the stages:
  #   scope → materialize → IR → select | (parse → door → compile → executor) → IR′ → render
  mkInspector =
    subject:
    let
      facts = materialize.materialize subject;
    in
    {
      inherit facts;

      # THE TEXT ENTRY. `door` before `compile` is the design's order and it is load-bearing: the
      # door refuses an unknown name off the IR's own known sets, and defers a name this gate
      # reserves so `compile` can refuse it as a CONSTRUCT rather than as a typo.
      query =
        text:
        let
          ast = sql.parseSql text;
        in
        executor.evalQuery facts.tables (compile.compile (door.check facts ast));

      # THE PROGRAMMATIC ENTRY — the same path with no text stage, and therefore no door: a selector
      # is a VALUE built from gen-select's constructors, so there is no name to mistype and nothing
      # for a known-set comparison to do. Its result is an IR′, which is why it composes with
      # `render` and with itself.
      select = selecting.select genSelect facts;

      # The AST, for a caller that wants the parse without the run.
      parse = sql.parseSql;

      render = {
        inherit (render) mermaid dot json;
      };
    };

  # The refusal is `materialize`'s and it is reached here by FORCING the subject's field check — a
  # non-scope must fail at `mkInspector`, not at whichever attribute a consumer happens to read
  # first. `facts.labels` is the cheapest field that cannot be produced without the whole subject.
  checked =
    subject:
    let
      i = mkInspector subject;
    in
    builtins.seq i.facts.labels i;
in
{
  mkInspector = checked;
  # The degenerate case, through the explicit wrapper rather than a shape probe: a probe would
  # silently accept a graph as a scope and answer about an empty program, so the missing-field
  # refusal that `materialize` raises stays NAMED for everything that is neither.
  fromGraph = args: checked (materialize.graphSubject args);
}
