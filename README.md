# gen-inspect

The library that **interrogates a materialized gen graph**. Which nodes exist and of what kind,
which edges are declared, **which a policy program produced and why**, and what reaches what.

A picture of the same materialization, with the policy's edge visibly distinct, is one output of
that pipeline — not the ask.

```nix
genInspect = import gen-inspect/lib {
  prelude = gen.prelude;
  graph = gen.graph;
  select = gen.select;
  scope = gen.scope;
};

i = genInspect.mkInspector {
  register  = { … };   # kind -> name -> attrs
  relations = { … };   # label -> src -> [ dst ]
  program   = …;       # a gen-program program
  model     = …;       # its model, already solved by gen-scope
};

i.facts                    # the IR
i.query "SELECT …"         # the text surface
i.select selector          # the programmatic surface; the result is an IR
i.render.mermaid i.facts   # the picture's source
```

## Why it exists

**A person sits down in front of an assembled graph and needs to interrogate it.** Interrogating a
materialized graph is a capability every gen consumer needs, so it ships as end-user surface at the
`framework` stratum rather than as a demo.

**A fixed menu of demo queries fails that by construction.** The surface takes an **unanticipated**
query, and every way that query can be wrong is refused **by name, with the known set** — because
against a raw row source each of those mistakes reads `[]` at exit 0, which is indistinguishable
from *"the policy produced nothing"*.

## The IR contract

Between `materialize` and everything downstream sits ONE named contract. **Renderers read the IR and
never the scope**, and **a query's result IS an IR**, so filters are the selector algebra rather
than an ad-hoc filter set.

```
nodes   : [ { id; kind; attrs; } ]
edges   : [ { src; dst; label; origin; } ]
origins : { "<label>:<src>:<dst>" -> origin }
origin  : { kind = "declaration"; site; }
        | { kind = "policy"; derivations = [ { rule = { head; pos; neg; };
                                              fired = [ { atom; verdict; sign; } ]; } ]; }
tables  : kind -> name -> { name; kind; <attrs splatted>; },  plus `edge`
kinds   : kind -> { name; }
labels  : [ label ]  (declared ++ derived)
graph   : the gen-graph labeled value over the SAME edge list
```

**`origin` is constructed at materialization, and the engine is not its source.** gen-scope's
`provenance` is a condensation-depth stamp, not per-atom provenance. There is no capture stage and
nothing is instrumented: the program value and the model verdicts are both in hand, which is what
makes origin derivable at all.

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
| reachability, transitive closure, `WHY` | **the program layer**      |

The selector layer is the **guard sublanguage**, not "the non-recursive fragment". Measured:
gen-select's constructors yield exactly nine tags, and `sel ? join`, `sel ? comprehension` and
`sel ? fix` are all false. So a `JOIN` has no selector to compile to and routes to the fold — **a
`JOIN` is not refused**. The third route is a **refusal door by name**, not a stub.

## The example

`examples/fleet/` carries a campanology register whose policy derives **one edge no declaration
states**: `hemony` rings `bourdon`, through two intermediate derivations. `enrolled` is **both a
declared and a derived label**, which is why the dynamic label set is derived from the program rather
than hand-written — a hand-written list drops the derived edge with no diagnostic.

### The three human entries

The library publishes **pure functions only** — no app, no CLI. Run from `examples/fleet/`.

```console
$ nix eval --json .#inspect --apply 'i: i.query "SELECT src, dst FROM edge WHERE label = '\''rings'\''"'
[{"dst":"bourdon","src":"hemony"}]
```

```console
$ nix eval --raw .#inspect --apply 'i: i.render.mermaid i.facts'
flowchart LR
  campanile["campanile<br/>belfry"]
  lantern["lantern<br/>belfry"]
  compline["compline<br/>chime"]
  evensong["evensong<br/>chime"]
  matins["matins<br/>chime"]
  chiming["chiming<br/>peal"]
  full_circle["full-circle<br/>peal"]
  hemony["hemony<br/>ringer"]
  mears["mears<br/>ringer"]
  rudhall["rudhall<br/>ringer"]
  angelus["angelus<br/>tocsin"]
  bourdon["bourdon<br/>tocsin"]
  sanctus["sanctus<br/>tocsin"]
  tenor["tenor<br/>tocsin"]
  full_circle -->|absorbs| chiming
  bourdon -->|admits| full_circle
  tenor -->|admits| chiming
  hemony -->|enrolled| chiming
  rudhall -->|enrolled| chiming
  angelus -->|housed| lantern
  bourdon -->|housed| campanile
  sanctus -->|housed| lantern
  tenor -->|housed| campanile
  compline -->|hung| sanctus
  evensong -->|hung| bourdon
  matins -->|hung| tenor
  hemony -.->|enrolled| full_circle
  hemony -.->|rings| bourdon
```

The **two dashed edges are the policy's**; the twelve solid ones are declared. `hemony -.->|rings| bourdon` is the edge no `relations` entry states.

```console
$ nix repl .#
Loading installable 'git+file:///…/gen-inspect?dir=examples/fleet#'...
Added 3 variables.

nix-repl> :p (builtins.head inspect.facts.origins."rings:hemony:bourdon".derivations).fired
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
error: gen-inspect: unknown name 'anvils'; known: belfry, chime, edge, peal, ringer, tocsin

$ … "SELECT name FROM tocsin WHERE wieght = 'heavy'"
error: gen-inspect: unknown name 'wieght'; known: belfry, kind, name, weight

$ … "SELECT src FROM edge WHERE label = 'anvils'"
error: gen-inspect: unknown label 'anvils'; known: absorbs, admits, enrolled, housed, hung, rings

$ … "SELECT src FROM reaches"
error: gen-inspect: unsupported construct 'reaches' (reachability); it compiles onto the program
layer, which this gate does not build.
```

The third one is the sharp case: `WHERE label = 'anvils'` is a **well-formed query over a known
column**, so without its door it returns `[]` at exit 0 and reads as *"the policy produced nothing"*.

## Dependencies, and what is not one

Four gen libraries, all **injected as values** — only plain data crosses a gen↔gen boundary.
`gen-prelude`, `gen-graph` and `gen-select` are what this gate evaluates through; `gen-scope` is the
program route's evaluator, declared now so that route's landing changes no caller.

The design names a fifth, `gen-program`, and it is **absent by measurement**. The hub injects a
framework member's substrate through a function of its `members` binding — exactly the eighteen roster
entries whose `.lib` is published applied — and `program` is one of the three unapplied members that
the substrate fold itself produces, so it is not in scope where a fourth substrate entry is written.
Declaring it here would pin a dependency the hub has no way to inject. Gate 2 adds it in the commit
that replaces `compile`'s body.

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
nix flake check ./ci                    # the suites, through the batch asserter
nix-unit --flake ./ci#tests             # the same cells, per cell
nix-unit --flake ./ci#testsError        # the refusals, asserted by message
cd ci && nix fmt -- --ci
```

Cells whose subject is an error **message** live on `testsError`: the asserter behind
`checks.default` forces every `flake.tests` cell's `expr` unconditionally, so a throwing `expr`
crashes that gate instead of failing it.
