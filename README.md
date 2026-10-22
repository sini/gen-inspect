# gen-inspect

The library that **interrogates a materialized gen graph**. Which nodes exist and of what kind,
which edges are declared, **which a rule program produced and why**, and what reaches what.

A picture of the same materialization, with the rule's edge visibly distinct, is one output of
that pipeline — not the ask.

```nix
genInspect = import gen-inspect/lib {
  prelude = gen.prelude;
  graph = gen.graph;
  select = gen.select;
  scope = gen.scope;
  program = gen.program;   # gen-program, APPLIED
};

i = genInspect.mkInspector {
  register  = { … };   # kind -> name -> attrs
  relations = { … };   # label -> src -> [ dst ]
  declarations = …;    # gen-program declarations; one carrying `label` denotes an edge
  model     = program.model { … };  # gen-program's result record for these declarations
  minted    = { nodes = { … }; edges = [ … ]; };  # the caller's mint output for its included
                                                  # promoted heads; { nodes = { }; edges = [ ]; } if none
};

i.facts                    # the IR
i.query "SELECT …"         # the text surface
i.select selector          # the programmatic surface; the result is an IR
i.why (builtins.toJSON [ "rings" "hemony" "bourdon" ])  # one atom's derivation: an edge's origin, or a reaches row's witnesses
i.render.mermaid { } i.facts   # the picture's source
```

## Why it exists

**A person sits down in front of an assembled graph and needs to interrogate it.** Interrogating a
materialized graph is a capability every gen consumer needs, so it ships as end-user surface at the
`framework` stratum rather than as a demo.

**A fixed menu of demo queries fails that by construction.** The surface takes an **unanticipated**
query, and every way that query can be wrong is refused **by name, with the known set** — because
against a raw row source each of those mistakes reads `[]` at exit 0, which is indistinguishable
from *"the rule produced nothing"*.

## The IR contract

Between `materialize` and everything downstream sits ONE named contract. **Renderers read the IR and
never the scope**, and **a query's result IS an IR**, so filters are the selector algebra rather
than an ad-hoc filter set.

```
nodes   : [ { id; kind; attrs; } ]
edges   : [ { src; dst; label; origin; } ]
origins : { "<label>:<src>:<dst>" -> origin }   every edge gen-program's `reached` yields is a key
origin  : { kind = "declaration"; site; }
        | { kind = "rule"; derivations = [ { rule = { head; pos; neg; };
                                              fired = [ { atom; verdict; sign; } ]; } ]; }
tables  : kind -> name -> { name; kind; <attrs splatted>; },  plus `edge`
kinds   : kind -> { name; }
labels  : [ label ]  (declared ++ derived)
graph   : a gen-scope evaluated scope over the SAME edge list (each label `l` the attribute `edges-l`,
          `marks = _: _: [ ]`); walk it with gen-scope's `resolve`
```

**`origin` is constructed at materialization, and the engine is not its source.** gen-scope's
`provenance` is a condensation-depth stamp, not per-atom provenance. There is no capture stage and
nothing is instrumented: the declarations and the model verdicts are both in hand, which is what
makes origin derivable at all.

**The rule edges are gen-program's `(ruleEdges model declarations).reached`, never an atom parsed
here.** A declaration's `label` names the edge its head denotes, `{ from = relata[0]; to = relata[1]; label; }`. `reached` refuses by name every answer an edge list cannot carry, so a labelled head
the well-founded model leaves **undefined** is refused rather than dropped.

**A promoted head is a node, read from the caller's mint.** A declaration carrying gen-program's
`promote` makes its included head a node, whose identity only the caller's mint supplies, so the
subject carries the mint's output as `minted` (gen-scope `mintStrata`'s `{ nodes; edges; }`,
projected to the included promoted heads) and this library mints nothing. Each minted node joins
`nodes` by its kind and its edges join `edges` with a `rule` origin. `minted` is required, empty when
nothing is promoted, and `materialize` refuses it by name, listing every fault, unless its nodes are
exactly the included promoted heads, none already registered, each with a non-empty string `identity`
and its promotion's `kind`, with edges exactly its promotion's relata and no edge from anything else
(`tests-error.nix`, Doors 12–17). **That is a shape door, not a check of where the identity came
from:** the mint's node record carries no provenance mark, so a well-formed identity this library
cannot re-derive is taken from the caller, as `model` is.

**The subject's `model` is gen-program's result record.** It is the value `program.model` returns,
solved from the subject's own `declarations`. It carries the rules the verdicts were solved from,
which is what lets `ruleEdges` refuse a model of other declarations or a relation still growing. A
gen-scope `solve` record carries the verdicts alone, so with a labelled declaration gen-program
refuses it by name and the refusal passes through. With no labelled declaration only `verdict` is
read, which is the degenerate subject `graphSubject` builds.

**A witness is body-checked, never head-matched.** Van Gelder, Ross & Schlipf 1991 Def 3.3: an atom
is derived iff some rule has it as head **and every body literal is true in the model**. A head match
alone reports a rule whose body is false, in a field named `fired` — Def 3.1 calls that a *witness of
unusability*.

**Provenance rider.** `origins` is why/derivation provenance **in the sense of** Cheney, Chiticariu &
Tan (2009) — a name taken from the literature rather than a citation checked against a held copy. The
**semiring is deliberately not realized and is not planned**: these are records about a run, and
nothing here computes with them algebraically.

## Three layers, one model

| layer             | form                                | what it is                                              | where recursion lives |
| ----------------- | ----------------------------------- | ------------------------------------------------------- | --------------------- |
| (c) **selectors** | `gen-select` combinators            | the primary programmatic API; the **guard** sublanguage | none — no fixpoint    |
| (b) **programs**  | `gen-program` on gen-scope's engine | recursion, derivation, why                              | the fixpoint          |
| (a) **SQL**       | text                                | the novice surface                                      | compiled onto b + c   |

**The compile rule is three routes by executor, not two by recursion.**

| construct                               | executor                   |
| --------------------------------------- | -------------------------- |
| `WHERE` predicate                       | **gen-select**             |
| `JOIN`, projection, `ORDER BY`, `LIMIT` | **gen-inspect's own fold** |
| `reaches`, `why`                        | **the program layer**      |
| `paths` / `path` (path enumeration)     | **refused, permanently**   |

The selector layer is the **guard sublanguage**, not "the non-recursive fragment". Measured:
gen-select's constructors yield exactly nine tags, and `sel ? join`, `sel ? comprehension` and
`sel ? fix` are all false. So a `JOIN` has no selector to compile to and routes to the fold — **a
`JOIN` is not refused**.

## Reachability and `why`

**`reaches` is a table** with columns `src`, `dst`, `via` and `why`. A row says `dst` is reachable from
`src` along edges labelled `via`, reflexively and transitively; `via = '*'` means any label.

```console
$ nix eval --json .#inspect --apply 'i: i.query "SELECT dst FROM reaches WHERE src = '\''hemony'\'' AND via = '\''*'\'' ORDER BY dst"'
[{"dst":"bourdon"},{"dst":"campanile"},{"dst":"chiming"},{"dst":"full-circle"},{"dst":"hemony"}]
```

**The engine computes it and the relational fold consumes it.** Each constrained `(via, src)` becomes
a gen-program declaration set over the IR's edges (one fact per edge, a base fact
`["reaches", via, s, s]`, and one rule per edge extending a reach by that edge), solved by gen-scope's
engine; this library computes no fixpoint of its own. The program has no negative literal, so it is
a Horn program, and its well-founded model is its least model (Van Gelder, Ross & Schlipf 1991,
Theorem 3.7): the reflexive-transitive closure, total. The relation is handed to the executor as a
table, so `WHERE`, `JOIN`, projection, `ORDER BY` and `LIMIT` serve it unchanged — relational
algebra plus fixed points, with the fixed point in the engine. A `reaches` row is a query relation
and never an IR edge.

**Equalities on `src` and `via` prune; they never change the answer.** Only top-level `AND`
equalities are read, each `reaches` occurrence is grounded by its own constraints (a self-join is
two relations), and an unqualified `src` or `via` is read as a `reaches` constraint only when no other
table in the query has that column. The whole `WHERE` still runs over the result.

**The relata are the node ids plus every edge endpoint.** An edge may end at a name no register
entry declares; the graph walk follows it, and so does `reaches`.

**`why` is one step.** On `edge` it is the IR's `origin`. On `reaches` it lists every rule of the
query program whose body is true in the model — the same body-checked construction an edge's origin
uses. An IR edge key is `builtins.toJSON [ label src dst ]` and a `reaches` atom is `builtins.toJSON [ "reaches" via src dst ]`, so an id containing `:` forges no other key and `why` refuses a colon-joined string by name. Every edge atom a witness names is an IR key, so a reader chains `why` from a reachability row
to the edge to the rule that derived it. **Some one-step witnesses are circular**: on a cycle
`treble ⇄ second`, `["reaches","changes","treble","treble"]` has two derivations, the base fact and one through
`second` that leads back to itself. Each is a rule whose body is true, but together they are not a
well-founded proof tree, and choosing one needs stage information the engine does not publish. So
`why` never unfolds, and a reader unfolding by hand stops at a repeated atom.

**Path enumeration is refused, and not by a gate.** On a cyclic graph the set of paths is infinite,
and a fixed point is only defined over a finite lattice.

## The example

`examples/fleet/` carries a campanology register whose rule derives **one edge no declaration
states**: `hemony` rings `bourdon`, through two intermediate derivations. `enrolled` is **both a
declared and a derived label**, which is why the dynamic label set is taken from the declarations'
own labels rather than hand-written — a hand-written list drops the derived edge with no diagnostic.

### The three human entries

The library publishes **pure functions only** — no app, no CLI. Run from `examples/fleet/`.

```console
$ nix eval --json .#inspect --apply 'i: i.query "SELECT src, dst FROM edge WHERE label = '\''rings'\''"'
[{"dst":"bourdon","src":"hemony"}]
```

```console
$ nix eval --raw .#inspect --apply 'i: i.render.mermaid { } i.facts'
flowchart LR
  n0["campanile<br/>belfry"]
  n1["lantern<br/>belfry"]
  n2["compline<br/>chime"]
  n3["evensong<br/>chime"]
  n4["matins<br/>chime"]
  n5["chiming<br/>peal"]
  n6["full-circle<br/>peal"]
  n7["hemony<br/>ringer"]
  n8["mears<br/>ringer"]
  n9["rudhall<br/>ringer"]
  n10["angelus<br/>tocsin"]
  n11["bourdon<br/>tocsin"]
  n12["sanctus<br/>tocsin"]
  n13["tenor<br/>tocsin"]
  n6 -->|"absorbs"| n5
  n11 -->|"admits"| n6
  n13 -->|"admits"| n5
  n7 -->|"enrolled"| n5
  n9 -->|"enrolled"| n5
  n10 -->|"housed"| n1
  n11 -->|"housed"| n0
  n12 -->|"housed"| n1
  n13 -->|"housed"| n0
  n2 -->|"hung"| n12
  n3 -->|"hung"| n11
  n4 -->|"hung"| n13
  n7 -.->|"enrolled"| n6
  n7 -.->|"rings"| n11
```

The **two dashed edges are the rule's**; the twelve solid ones are declared. `n7 -.->|"rings"| n11` (hemony to bourdon) is the edge no `relations` entry states. A node's handle is its position in the IR's node list, so it is unique whatever bytes the id holds; the id itself is the label, escaped.

`render.mermaid` and `render.dot` take one closed options set first, and `{ }` is the picture above:

- `direction` (`"LR"`): one of `BT LR RL TB TD`.
- `shapeOf` (`_: null`): kind → `null` (the renderer's own default) or one of `circle`, `cylinder`,
  `hexagon`, `rect`, `rhombus`, `round`.
- `labelOf` (`n: n.id`): the IR node record → the text drawn in place of the id. The id stays the
  node's identity.
- `nest` (`false`): when `true`, the IR's `parent` edges draw as nesting (mermaid subgraphs, dot
  clusters), and every edge is still drawn. Two `parent` targets on one vertex, or a `parent` cycle,
  is refused by name.

An unknown option is refused by name, and so is the positional `render.mermaid i.facts`, whose first
field it reads as an option. `render.json ir` takes no options.

```console
$ nix repl .#
Loading installable 'git+file:///…/gen-inspect?dir=examples/fleet#'...
Added 3 variables.

nix-repl> :p (builtins.head inspect.facts.origins.${builtins.toJSON [ "rings" "hemony" "bourdon" ]}.derivations).fired
[
  { atom = "enrolled:hemony:full-circle"; sign = "pos"; verdict = "true"; }
  { atom = "admits:bourdon:full-circle"; sign = "pos"; verdict = "true"; }
  { atom = "silenced:hemony:bourdon"; sign = "neg"; verdict = "false"; }
]
```

The picture itself is a build, and **not a CI cell**:

```
nix build .#fleet-graph-svg
```

Picture fidelity needs an **element-scoped** predicate: mermaid emits `edge-pattern-dotted` in its
stylesheet unconditionally, so a whole-file count reds against a correct build and greens at the red
state, and `stroke-dasharray` discriminates not at all. What CI asserts is the **source**.

## Every way a query can be wrong

```console
$ nix eval .#inspect --apply 'i: i.query "SELECT name FROM anvils"'
error: gen-inspect: unknown name 'anvils'; known: belfry, chime, edge, peal, reaches, ringer, tocsin

$ … "SELECT name FROM tocsin WHERE wieght = 'heavy'"
error: gen-inspect: unknown name 'wieght'; known: belfry, kind, name, weight

$ … "SELECT src FROM edge WHERE label = 'anvils'"
error: gen-inspect: unknown label 'anvils'; known: absorbs, admits, enrolled, housed, hung, rings

$ … "SELECT dst FROM reaches WHERE src = 'hemony' AND via = 'anvils'"
error: gen-inspect: unknown via 'anvils'; known: absorbs, admits, enrolled, housed, hung, rings, *

$ … "SELECT dst FROM paths WHERE src = 'hemony'"
error: gen-inspect: unsupported construct 'paths' (path enumeration); a cyclic graph has infinitely
many paths, so no finite answer exists and no gate adds one. Ask `reaches` for what a path reaches
and `why` for the edge that carries it.
```

The label and via doors are the sharp cases: each is a **well-formed query over a known column**.
Without its door, `WHERE label = 'anvils'` returns `[]` at exit 0 and reads as *"the rule produced
nothing"*, and `via = 'anvils'` answers `hemony` alone, reading as *"hemony reaches nothing"*.

## Dependencies, and what is not one

Five gen libraries, all **injected as values** — only plain data crosses a gen↔gen boundary.
`gen-prelude` and `gen-select` serve the selector and executor routes (and `gen-graph` is declared, but no
symbol of it is read); `gen-scope` serves the lifted graph and, with `gen-program`, the program route.

**`program` is gen-program applied, and its standalone default is built from this library's own
`prelude` and `scope`.** gen-program's root is itself unapplied. Resolving it the way the other four
resolve (`import <pin> { }`) would fetch gen-program's own locked gen-scope and put a second
substrate in one evaluation, so the default in `default.nix` names its sibling formals instead:
`program ? … (import (src [ "gen-program" ]) { inherit prelude scope; })`. A formal's default may
name a sibling formal. **This is the pattern for any library that depends on an unapplied library.**

**The standalone path holds two gen-program instances; the hub's flake path holds one.** Through
the hub, gen-inspect receives the hub's applied `program`. Through `import <gen-inspect> { }`, the
default above builds its own, so an evaluation that also reaches the hub's roster carries two.

**nixpkgs is not a dependency.** The SQL parser and executor are copied from
`gen-scope/examples/sql-schema`, which took nixpkgs `lib` — twelve distinct `lib.*` names, six of
them absent from gen-prelude. `lib/extras.nix` supplies those seven names over `builtins` instead,
because every gen library's `lib/` is free of the nixpkgs standard library, and a library at this layer
declaring nixpkgs as a dependency would hand its whole closure to every consumer of this one.
`ci/tests/purity.nix` is what keeps that from reverting.

**The copies carry an origin header** naming the source revision and the whole diff against it. The
kind-alias table is **stripped to the identity**: its 23 entries sit at kind position and name
machines, users and networks, and this library's vocabulary is invented end to end.

## Tests

```
nix develop ./ci --command ci                # the cells, per cell, guarded
nix develop ./ci --command ci --tests-error  # the refusals, asserted by message, guarded
nix flake check ./ci                    # the suites, through the batch asserter; unguarded
nix-unit --flake ./ci#tests             # the same cells, per cell; unguarded
nix-unit --flake ./ci#testsError        # the refusals, asserted by message; unguarded
cd ci && nix fmt -- --ci
```

`ci` refuses when anything under a declared read root is unknown to git — any extension or name,
`_`-prefixed included — and the remedy is `git add` or a move. The unguarded forms read a
git-filtered copy of the tree, so an untracked cell is silently absent and the run stays green.

Cells whose subject is an error **message** live on `testsError`: the asserter behind
`checks.default` forces every `flake.tests` cell's `expr` unconditionally, so a throwing `expr`
crashes that gate instead of failing it.
