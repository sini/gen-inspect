# gen-inspect — agent sheet

The library that interrogates a **materialized gen graph**: which nodes exist and of what kind, which
edges are declared, which a policy program produced and **why**, and what reaches what.

It implements **no semantics** and **never evaluates**. Every fixpoint goes through gen-scope, the
sole evaluator (ADR-0006); this library READS a model an evaluator already produced. That is what
makes the conformance true by construction rather than by inspection.

## The published surface

The library is a function of its injected substrate: `import ./lib { prelude, graph, select, scope }`. The root is published **UNAPPLIED** (`flake.nix`'s output is `lib = import ./.;`), which
is the framework-stratum convention — the hub applies it verbatim through `gen/lib/hubSubstrate.nix`,
so an APPLIED output here would abort every hub evaluation with `attempt to call something which is not a function but a set`.

```json
[
  "astToSelector",
  "compile",
  "door",
  "evalQuery",
  "fromGraph",
  "graphSubject",
  "materialize",
  "mkInspector",
  "parseSql",
  "render",
  "reservedNames",
  "select",
  "tokenize"
]
```

`ci/tests/surface.nix` asserts that block against the library's own `attrNames`.

## The modules

- **`materialize.nix`** — the IR contract, and its one construction. `origin` is built here from
  `program.rules` × `model.verdict`, because gen-scope's `provenance` is a **condensation-depth
  stamp** and not per-atom provenance. Carries three doors: the missing-field refusal, the
  model-true-atom-with-no-IR-edge refusal, and the no-firing-rule refusal.
- **`extras.nix`** — gen-prelude plus the seven names the copied parser needs. **Not nixpkgs `lib`.**
- **`sql.nix`** / **`executor.nix`** — COPIES from `gen-scope/examples/sql-schema` at gen-scope
  `675d9f3`, each with an origin header naming the source md5 and the whole diff. An example is not
  published surface and a second root input to reach one is what ADR-0037 forbids.
- **`compile.nix`** — the three-route rule, and the reserved-construct door this gate refuses at.
- **`door.nix`** — unknown table, unknown column, unknown label value, unknown kind value.
- **`select.nix`** — IR + selector → IR′, carrying origins forward.
- **`render.nix`** — mermaid, dot, JSON. Reads the IR, never the scope.
- **`inspector.nix`** — `mkInspector scope → { facts, select, query, parse, render }`.

## Invariants a change must not break

- ★★ **The dynamic label set is DERIVED from the program, never a literal.** A hand-kept list drops
  every derived edge whose label is not on it, with **no diagnostic**. In the example fleet
  `enrolled` is both a declared and a derived label, so a literal `[ "rings" ]` loses a true edge at
  exit 0. The door that catches it is `unrepresented` in `materialize.nix`.
- ★★ **A witness is body-checked, never head-matched** (Van Gelder, Ross & Schlipf 1991 Def 3.3). A
  head match alone reports a rule whose body is FALSE in a field named `fired`.
- ★ **`origins` stays a FIELD of the IR, not a derived accessor.** Gate 3 needs provenance to survive
  `select` and `compile`; a derived accessor closes that seam.
- ★ **`derivations` is a LIST and `fired` is per-derivation.** Recursion produces multiply-derived
  atoms by construction, so an origin holding one rule freezes an IR that cannot carry the program
  layer's own output.
- ★ **The `fired` tuple carries NEGATIVE literals.** Dropping them would make why-not unbuildable
  without an IR change.
- ★ **`deepSeq`, not `seq`, in the door.** `builtins.seq` over a checked-name list forces the list to
  WHNF and not one element — a refusal that refuses nothing looks exactly like a working one.
- ★ **Force the whole IR, do not count it.** `builtins.length` forces the list spine and not one
  origin, so a stray-atom build reads its full edge count at exit 0 under a count assertion.
- ★ **The library reaches no nixpkgs `lib`.** `ci/tests/purity.nix` enforces it over `lib/**` plus
  the root `flake.nix` and `default.nix`.
- ★ **No den or fleet vocabulary at kind, label, option or error position** (ADR-0035).
  `ci/tests/conformance.nix` enforces it, POSITION-SCOPED and comment-stripped — a bare word sweep
  over the same correct tree reads non-zero, which is ordinary English in prose, and a cell written
  on the bare predicate reds against a conforming build.

## What this gate does NOT build

The **program route**. Reachability, transitive closure and `WHY` are refused at `compile` **by name**
— a door, not a stub, so its replacement changes no caller. `gen-scope` is already a formal of
`lib/default.nix` for exactly that landing; `gen-program` is not, because the hub's substrate fold is a
function of its `members` binding and `program` is one of the three UNAPPLIED members that fold
produces. Gate 2 adds the formal, the flake input and the hub's fourth substrate key together.

Also deferred: planted violations across every cell, query/graph parity, a `TERMINOLOGY.md` census,
picture fidelity against the built svg, and a staleness enforcer for the copied parser.

## Tests

```
nix flake check ./ci                    # the suites, through the batch asserter
nix-unit --flake ./ci#tests             # the same cells, per cell
nix-unit --flake ./ci#testsError        # the refusals, asserted by message
cd ci && nix fmt -- --ci
```

★ **Read the asserter's own count, not the nix-unit summary.** nix-unit collects only `test`-prefixed
attrs while `checks.default` forces ALL of `flake.tests`; a repo whose cells are not test-prefixed
reports a green that asserts almost nothing. Both figures agree here, and a change that makes them
disagree has added a cell nix-unit is not running.

★ **Both nix-unit planes.** `./ci#tests` alone silently omits every by-name refusal cell, which reads
as a clean green.

★★ **`ci/flake.lock` PINS gen-harness AT THE REVISION THE WHOLE ROSTER PINS**, and the alignment is
load-bearing rather than incidental. The hub's `pin-coherence` check uses gen-harness as its LIVE
POSITIVE CONTROL — "pinned by every member and at one revision" — and gates on that control, not on
the coherence reading itself, which ships observe-only. A gen-harness here that the roster does not
share turns the hub's own control incoherent and reds the hub. The check list is whatever that
revision's `mkCi` ships; read it with `nix eval ./ci#checks.x86_64-linux --apply builtins.attrNames`
rather than from this file.

★ **`ci/` declares no hub input.** The hub pins this repository, so a `github:sini/gen` input here is
an oracle-graph cycle (ADR-0037). The entry-path agreement cell is the hub's own, `hub-entry-agreement`
in the hub's ci.

## What this library is NOT

<!-- gen-citations:begin -->

- **It never evaluates.** Every fixpoint goes through gen-scope, the sole evaluator (ADR-0006).
  This library READS a model an evaluator already produced and computes none of its own — which is
  also why the program route is a refusal door rather than a local fixpoint.
- **It defines no substrate vocabulary** (ADR-0035). Its kinds, labels and error text are invented
  end to end, and `ci/tests/conformance.nix` is the position-scoped scan that says so, with the
  unstripped origin alias table as its firing control.
- **It gives the policy edge no second structure.** ADR-0012: the dynamic edge joins the ONE edge
  list and is told apart by its `origin`, never by living somewhere else. `materialize.nix` builds
  `declaredEdges ++ policyEdges` and the graph is derived from that one list.
- **It re-exports nothing of its substrate.** gen-select, gen-graph and gen-prelude arrive as
  injected VALUES; no construct of theirs is republished under a name here.
- **It does not implement the provenance semiring.** `origins` is why/derivation provenance in the
  sense of Cheney, Chiticariu & Tan (2009), a name taken from the literature rather than a citation
  checked against a held copy. The semiring is deliberately not realized and is not planned: these
  are records about a run, and nothing here computes with them algebraically.
- **It imports the SQL parser from nowhere.** `gen-scope/examples/` is not published surface, and a
  second root input to reach one is what ADR-0037 forbids, so the parser and executor are COPIES
  under an origin header.

<!-- gen-citations:end -->

## A known limitation, inherited from the copy

A `JOIN` whose ON condition qualifies columns with **table names rather than explicit aliases**
answers `[ ]` at exit 0 rather than refusing: the copied executor populates its alias map only from
an explicit alias. Write `FROM tocsin t JOIN belfry b ON t.belfry = b.name`. This is origin behaviour
carried by the copy, recorded rather than repaired — a repair to a copied artefact's semantics is its
own change.
