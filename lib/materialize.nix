# THE IR CONTRACT, AND ITS ONE CONSTRUCTION.
#
# Between `materialize` and everything downstream sits ONE named contract. Renderers read the IR and
# never the scope; a query's result IS an IR, so filters are the selector algebra rather than an
# ad-hoc filter set. The shape is the design's §2.2, transcribed:
#
#   nodes   : [ { id; kind; attrs; } ]
#   edges   : [ { src; dst; label; origin; } ]
#   origins : { "<label>:<src>:<dst>" -> origin }   — EVERY edge gen-program's `reached` yields is a key
#   origin  : { kind = "declaration"; site; }
#           | { kind = "rule"; derivations = [ { rule  = { head; pos; neg; };
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
{
  lib,
  graph,
  program,
}:
let
  keyOf = e: "${e.label}:${e.src}:${e.dst}";

  # ── WITNESSES ARE BODY-CHECKED, NEVER HEAD-MATCHED ──
  # Van Gelder, Ross & Schlipf 1991 Def 3.3: p is derived iff some rule has head p AND EVERY body
  # literal is true in the model. A head match ALONE reports a rule whose body is false, which Def 3.1
  # calls a witness of UNUSABILITY — an origin naming a rule that did not fire is nothing to look at,
  # and "why is this edge here" is the whole component.
  #
  # ONE CONSTRUCTION FOR BOTH PROGRAMS: the subject's rule program (an edge's origin) and the query
  # program `./compile.nix` builds for `reaches`. `keep` is the caller's rule filter; a fact's empty
  # body fires vacuously, and whether a fact counts as a witness is the caller's judgement.
  witnesses =
    { rules, verdict }:
    keep: atom:
    let
      firesUnder =
        r:
        builtins.all (a: verdict a == "true") (r.pos or [ ])
        && builtins.all (a: verdict a == "false") (r.neg or [ ]);
      firedTuple =
        r:
        map (a: {
          atom = a;
          verdict = verdict a;
          sign = "pos";
        }) (r.pos or [ ])
        ++ map (a: {
          atom = a;
          verdict = verdict a;
          sign = "neg";
        }) (r.neg or [ ]);
    in
    map (r: {
      rule = {
        inherit (r) head;
        pos = r.pos or [ ];
        neg = r.neg or [ ];
      };
      fired = firedTuple r;
    }) (builtins.filter (r: r.head == atom && keep r && firesUnder r) rules);

  materialize =
    subject:
    let
      missing = builtins.filter (f: !(subject ? ${f})) [
        "register"
        "relations"
        "declarations"
        "model"
      ];
      inherit (subject) register relations declarations;
      mdl = subject.model;

      # A rule program's FACT is a declaration and carries a declaration origin, so only a rule with
      # a body is a rule witness. The filter sits HERE, at this call site, and not in `witnesses`.
      bodied = r: (r.pos or [ ]) != [ ] || (r.neg or [ ]) != [ ];
      witnessesOf = witnesses {
        rules = map program.rule declarations;
        inherit (mdl) verdict;
      } bodied;

      # ★★ THE RULE EDGES ARE gen-program's `reached`, NEVER AN ATOM PARSED HERE. A declaration's
      #    `label` names the edge its head denotes, `{ from = relata[0]; to = relata[1]; label; }`,
      #    so an atom stays caller text this library does not split. `reached` refuses BY NAME every
      #    answer an edge list cannot carry: a head the well-founded model leaves UNDEFINED
      #    (ADR-0020), a relation still growing, a declaration the model was not solved from. Reading
      #    `trueAtoms` instead dropped an undefined head at exit 0, because it is in no list of true
      #    atoms, so no edge and no door ever saw it.
      reached =
        (program.ruleEdges {
          inherit declarations;
          model = mdl;
        }).reached;

      # The origin's join back to the heads. An edge is a property of the membership, and gen-program
      # collapses agreeing heads into one edge, so one key may carry several heads, and its
      # derivations are all of theirs. `reached ⊆ candidates`, so every reached key has a head here.
      labelled = builtins.filter (d: d.label != null) (map program.declaration declarations);
      edgeOf = d: {
        inherit (d) label;
        src = builtins.elemAt d.relata 0;
        dst = builtins.elemAt d.relata 1;
      };
      headsByKey = builtins.groupBy (d: keyOf (edgeOf d)) labelled;
      reachedKeys = lib.unique (
        map (
          e:
          keyOf {
            inherit (e) label;
            src = e.from;
            dst = e.to;
          }
        ) reached
      );

      # ★ `derivations` IS A LIST. Recursion produces multiply-derived atoms BY CONSTRUCTION — that
      #   is what a fixpoint does — so an origin holding ONE rule would freeze an IR that cannot carry
      #   the program layer's own output. `fired` is per-derivation rather than per-origin because a
      #   second derivation has a different body. A reached edge with no bodied witness is a FACT,
      #   which is a declaration and is owed a `relations` entry; the door below refuses it if absent.
      ruleEdges = builtins.filter (e: e.origin.derivations != [ ]) (
        map (
          key:
          let
            ds = headsByKey.${key};
          in
          edgeOf (builtins.head ds)
          // {
            origin = {
              kind = "rule";
              derivations = builtins.concatMap witnessesOf (lib.unique (map (d: d.head) ds));
            };
          }
        ) reachedKeys
      );

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

      edges = declaredEdges ++ ruleEdges; # ONE edge list, one construction (ADR-0012)

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

      # ★★ DYNAMIC LABELS ARE THE DECLARATIONS' OWN, NEVER A LITERAL. A hand-kept list drops every
      #    derived edge whose label is not on it, WITH NO DIAGNOSTIC. In this fleet `enrolled` is both
      #    a declared and a derived label, and a literal `[ "rings" ]` loses the derived
      #    `enrolled:hemony:full-circle` at exit 0 — a true edge gone and nothing said.
      labels = lib.unique (builtins.attrNames relations ++ map (d: d.label) labelled);

      # ★★ THE DOOR: every reached edge is an IR key, or it is refused BY NAME. Containment and not
      #    equality, because the IR also holds declared edges the program never mentions.
      #
      # ★ FORCE THE WHOLE IR, DO NOT COUNT IT. `builtins.length` forces the list SPINE and not one
      #   origin, so a stray-edge build reads its full edge count at exit 0 under a count assertion;
      #   `deepSeq` is what makes it exit 1. That is a property of the CONSUMER's force, stated here
      #   because this door is what the force is supposed to reach.
      unrepresented = builtins.filter (k: !(origins ? ${k})) reachedKeys;

      checked =
        if unrepresented == [ ] then
          origins
        else
          throw "gen-inspect: reached edge(s) with neither a firing rule nor a declared relation: ${builtins.concatStringsSep ", " unrepresented}";

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
        graph = graph.labeledFrom perLabel (map (n: n.id) nodes);
      };

  # ── THE DEGENERATE CASE, THROUGH AN EXPLICIT WRAPPER ──
  # Any gen-graph labeled value is a subject with no rule half. It arrives through a wrapper
  # rather than a shape probe so that `materialize`'s missing-field refusal stays NAMED: a probe
  # would silently accept a graph as a scope and answer about an empty program.
  #
  # MIXED class (den-hoag-7gp66 P1, §v1.2/§v1.7 row 7-15): closed over the whole set — transitional,
  # per §v1.2, until P2 moves the options off the record. A native closed formal here aborted an
  # unknown or missing field past `tryEval` (ADR-0025 item 1); `lib.checkOptions`/`checkRequired`
  # (gen-prelude, threaded through via `./extras.nix`'s `prelude // { … }`) make both refusals named
  # and catchable instead.
  graphSubject =
    args:
    let
      checked =
        lib.checkOptions "gen-inspect.graphSubject"
          [
            "nodes"
            "perLabel"
            "kind"
          ]
          (
            lib.checkRequired "gen-inspect.graphSubject" [
              "nodes"
              "perLabel"
            ] args
          );
      nodes = checked.nodes;
      perLabel = checked.perLabel;
      kind = checked.kind or "vertex";
    in
    # `declarations` and `model` below are static — neither reads `checked` — so without this `seq`
    # the refusal would fire only for a caller who happens to force `register`/`relations`, never for
    # one who reads `declarations`/`model` alone or merely applies the door to WHNF (measured: `tryEval
    # (builtins.seq (graphSubject bad) null)` answered `success` with no `seq` here). Forcing `checked`
    # at application makes the refusal unconditional on what the caller later reads.
    builtins.seq checked {
      register.${kind} = lib.genAttrs nodes (_: { });
      # `perLabel` is an ACCESSOR per label; `relations` is the same relation as DATA. The node set
      # is what makes the conversion possible at all — an accessor's domain is not enumerable, which
      # is the reason gen-graph makes `nodes` a required formal of its own constructor.
      relations = lib.mapAttrs (
        _label: acc: lib.listToAttrs (map (n: lib.nameValuePair n (acc n)) nodes)
      ) perLabel;
      # No declaration is labelled, so gen-program's `reached` is `[ ]` without reading the model.
      declarations = [ ];
      model.verdict = _: "false";
    };
in
{
  inherit
    materialize
    graphSubject
    keyOf
    witnesses
    ;
  fromGraph = args: materialize (graphSubject args);
}
