# THE IR CONTRACT, AND ITS ONE CONSTRUCTION.
#
# Between `materialize` and everything downstream sits ONE named contract. Renderers read the IR and
# never the scope; a query's result IS an IR, so filters are the selector algebra rather than an
# ad-hoc filter set. The shape is the design's §2.2, transcribed:
#
#   nodes   : [ { id; kind; attrs; } ]
#   edges   : [ { src; dst; label; origin; } ]
#   origins : { "<label>:<src>:<dst>" -> origin }   — EVERY model-true atom at an edge label is a key
#   origin  : { kind = "declaration"; site; }
#           | { kind = "policy"; derivations = [ { rule  = { head; pos; neg; };
#                                                  fired = [ { atom; verdict; sign; } ]; } ]; }
#   tables  : kind -> name -> { name; kind; <attrs splatted>; },  plus `edge` — the queryable rows
#   kinds   : kind -> { name; }                     — what a `WHERE kind = '…'` resolves against
#   labels  : [ label ]  (declared ++ derived)      — the door's known set for a label value
#   graph   : the gen-graph labeled value over the SAME edge list (ADR-0012: one edge list)
#
# ── ORIGIN IS CONSTRUCTED HERE, AND THE ENGINE IS NOT ITS SOURCE ──
# gen-scope's `provenance` is a CONDENSATION-DEPTH STAMP, not per-atom provenance: measured at the
# hub, `scope.provenanceFor 1` ⇒ `[]` and `scope.provenanceFor 999999` ⇒ one entry reading "the
# input exceeds the engine's benchmark-verified condensation depth". So there is no capture stage
# and nothing is instrumented; the program value and the model verdicts are BOTH in hand at
# materialization, which is what makes origin derivable at all.
#
# ★ THE PROVENANCE RIDER TRAVELS WITH THE CITATION. `origins` is why/derivation provenance IN THE
# SENSE OF Cheney, Chiticariu & Tan (2009) — a name taken from the literature rather than a citation
# checked against a held copy; the project holds neither that survey nor Green, Karvounarakis &
# Tannen. The SEMIRING IS DELIBERATELY NOT REALIZED AND IS NOT PLANNED: these are records about a
# run, and nothing here computes with them algebraically.
{ lib, graph }:
let
  # ── ATOM ⇄ EDGE ──
  # TOTAL BY CONSTRUCTION, and the totality is load-bearing rather than defensive. `unrepresented`
  # below quantifies over EVERY model-true atom, and a caller's model may hold atoms that are not
  # edge atoms at all — a two-segment guard atom is the ordinary case. Reading one positionally with
  # `elemAt … 2` aborts UNNAMED on an index; answering `null` says "this atom names no edge", which
  # is the same judgement the label scope makes and is why a non-edge atom is SKIPPED rather than
  # refused.
  atomEdge =
    atom:
    let
      p = lib.splitString ":" atom;
    in
    if lib.length p != 3 then
      null
    else
      {
        label = lib.elemAt p 0;
        src = lib.elemAt p 1;
        dst = lib.elemAt p 2;
      };

  labelOf =
    atom:
    let
      e = atomEdge atom;
    in
    if e == null then null else e.label;

  keyOf = e: "${e.label}:${e.src}:${e.dst}";

  materialize =
    subject:
    let
      missing = builtins.filter (f: !(subject ? ${f})) [
        "register"
        "relations"
        "program"
        "model"
      ];
      inherit (subject) register relations;
      prog = subject.program;
      mdl = subject.model;

      # ── WITNESSES ARE BODY-CHECKED, NEVER HEAD-MATCHED ──
      # Van Gelder, Ross & Schlipf 1991 Def 3.3: p is derived iff some rule has head p AND EVERY body
      # literal is true in the model. A head match ALONE reports a rule whose body is false, which
      # Def 3.1 calls a witness of UNUSABILITY — an origin naming a rule that did not fire is
      # nothing to look at, and "why is this edge here" is the whole component.
      bodied = r: (r.pos or [ ]) != [ ] || (r.neg or [ ]) != [ ];
      firesUnder =
        r:
        builtins.all (a: mdl.verdict a == "true") (r.pos or [ ])
        && builtins.all (a: mdl.verdict a == "false") (r.neg or [ ]);
      witnessesOf = atom: builtins.filter (r: r.head == atom && bodied r && firesUnder r) prog.rules;

      firedTuple =
        r:
        map (a: {
          atom = a;
          verdict = mdl.verdict a;
          sign = "pos";
        }) (r.pos or [ ])
        ++ map (a: {
          atom = a;
          verdict = mdl.verdict a;
          sign = "neg";
        }) (r.neg or [ ]);

      # ★ `derivations` IS A LIST, with one entry at this gate. Recursion produces multiply-derived
      #   atoms BY CONSTRUCTION — that is what a fixpoint does — so an origin holding ONE rule would
      #   freeze an IR that cannot carry the program layer's own output. `fired` is per-derivation
      #   rather than per-origin because a second derivation has a different body.
      #
      # ★ A CALLER-FUNCTION TOTALITY DOOR, not a hypothetical: the model's `interpretation` is
      #   caller-supplied, and an asserted atom at a dynamic label has no rule at all. Without this
      #   the construction aborts UNNAMED — measured on that input: "expected a set but found null".
      derivationsOf =
        atom:
        let
          ws = witnessesOf atom;
        in
        if ws == [ ] then
          throw "gen-inspect: no firing rule derives '${atom}'"
        else
          map (r: {
            rule = {
              inherit (r) head;
              pos = r.pos or [ ];
              neg = r.neg or [ ];
            };
            fired = firedTuple r;
          }) ws;

      # ★★ DYNAMIC LABELS ARE DERIVED FROM THE PROGRAM, NEVER A LITERAL. A hand-kept list drops
      #    every derived edge whose label is not on it, WITH NO DIAGNOSTIC. In this fleet `enrolled`
      #    is both a declared and a derived label, and a literal `[ "rings" ]` loses the derived
      #    `enrolled:hemony:full-circle` at exit 0 — a true edge gone and nothing said.
      dynamicLabels = lib.unique (
        builtins.filter (l: l != null) (map (r: labelOf r.head) (builtins.filter bodied prog.rules))
      );

      policyEdges = map (
        a:
        atomEdge a
        // {
          origin = {
            kind = "policy";
            derivations = derivationsOf a;
          };
        }
      ) (builtins.filter (a: atomEdge a != null && witnessesOf a != [ ]) mdl.trueAtoms);

      declaredEdges = lib.concatMap (
        label:
        lib.concatMap (
          from:
          map (to: {
            inherit label;
            src = from;
            dst = to;
            origin = {
              kind = "declaration";
              site = "relations.${label}.${from}";
            };
          }) relations.${label}.${from}
        ) (builtins.attrNames relations.${label})
      ) (builtins.attrNames relations);

      edges = declaredEdges ++ policyEdges; # ONE edge list, one construction (ADR-0012)

      nodes = lib.concatMap (
        kind:
        map (id: {
          inherit id kind;
          attrs = register.${kind}.${id};
        }) (builtins.attrNames register.${kind})
      ) (builtins.attrNames register);

      origins = lib.listToAttrs (
        map (e: {
          name = keyOf e;
          value = e.origin;
        }) edges
      );

      labels = lib.unique (builtins.attrNames relations ++ dynamicLabels);

      # ★★ THE DOOR: every model-true atom AT AN EDGE LABEL is an IR key, or it is refused BY NAME.
      #    SCOPED BY LABEL because an atom at a label the subject does not publish is a control atom
      #    and names no edge — the withdrawn arm asserts exactly one. Containment and not equality,
      #    because the IR also holds declared edges the program never mentions.
      #
      # ★ FORCE THE WHOLE IR, DO NOT COUNT IT. `builtins.length` forces the list SPINE and not one
      #   origin, so a stray-atom build reads its full edge count at exit 0 under a count assertion;
      #   `deepSeq` is what makes it exit 1. That is a property of the CONSUMER's force, stated here
      #   because this door is what the force is supposed to reach.
      unrepresented = builtins.filter (
        a:
        let
          l = labelOf a;
        in
        l != null && builtins.elem l labels && !(origins ? ${a})
      ) mdl.trueAtoms;

      checked =
        if unrepresented == [ ] then
          origins
        else
          throw "gen-inspect: model-true atom(s) with no IR edge: ${builtins.concatStringsSep ", " unrepresented}";

      # ── THE QUERYABLE PROJECTION: `id` becomes `name`, `attrs` splat, `kind` retained. ──
      tables =
        lib.mapAttrs (
          kind: rows:
          lib.mapAttrs (
            id: a:
            a
            // {
              name = id;
              inherit kind;
            }
          ) rows
        ) register
        // {
          edge = lib.listToAttrs (
            map (e: {
              name = keyOf e;
              value = {
                inherit (e) src dst label;
                origin = e.origin.kind;
              };
            }) edges
          );
        };

      kinds = lib.mapAttrs (k: _: { name = k; }) register;

      # ★ `perLabel` is an attrset of ACCESSORS, label -> (id -> [targets]), NOT an edge list. The
      #   wrong shape fails LAZILY — a flat edge list here leaves `nodes` reading its full count at
      #   exit 0 and reds only at the first APPLICATION of `labeledEdges`.
      perLabel = lib.genAttrs labels (
        label: id: map (e: e.dst) (builtins.filter (e: e.label == label && e.src == id) edges)
      );
    in
    if missing != [ ] then
      throw "gen-inspect: not an evaluated scope; missing field(s): ${builtins.concatStringsSep ", " missing}"
    else
      {
        inherit
          nodes
          edges
          tables
          kinds
          labels
          ;
        origins = checked;
        graph = graph.labeledFrom {
          inherit perLabel;
          nodes = map (n: n.id) nodes;
        };
      };

  # ── THE DEGENERATE CASE, THROUGH AN EXPLICIT WRAPPER ──
  # Any gen-graph labeled value is a subject with no policy half. It arrives through a wrapper
  # rather than a shape probe so that `materialize`'s missing-field refusal stays NAMED: a probe
  # would silently accept a graph as a scope and answer about an empty program.
  graphSubject =
    {
      nodes,
      perLabel,
      kind ? "vertex",
    }:
    {
      register.${kind} = lib.genAttrs nodes (_: { });
      # `perLabel` is an ACCESSOR per label; `relations` is the same relation as DATA. The node set
      # is what makes the conversion possible at all — an accessor's domain is not enumerable, which
      # is the reason gen-graph makes `nodes` a required formal of its own constructor.
      relations = lib.mapAttrs (
        _label: acc: lib.listToAttrs (map (n: lib.nameValuePair n (acc n)) nodes)
      ) perLabel;
      program.rules = [ ];
      model = {
        trueAtoms = [ ];
        verdict = _: "false";
      };
    };
in
{
  inherit
    materialize
    graphSubject
    atomEdge
    keyOf
    ;
  fromGraph = args: materialize (graphSubject args);
}
