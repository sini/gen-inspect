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
#   graph   : a gen-scope evaluated scope over the SAME edge list (ADR-0012: one edge list), see `lift`
#
# ── ORIGIN IS CONSTRUCTED HERE, AND THE ENGINE IS NOT ITS SOURCE ──
# gen-scope's `provenance` is a CONDENSATION-DEPTH STAMP, not per-atom provenance: measured at the
# hub, `scope.provenanceFor 1` ⇒ `[]` and `scope.provenanceFor 999999` ⇒ one entry reading "the
# input exceeds the engine's benchmark-verified condensation depth". So there is no capture stage
# and nothing is instrumented; the declarations and the model verdicts are BOTH in hand at
# materialization, which is what makes origin derivable at all.
#
# ★ THE PROVENANCE RIDER TRAVELS WITH THE CITATION. `origins` is why/derivation provenance IN THE
# SENSE OF Cheney, Chiticariu & Tan (2009) — a name taken from the literature rather than a citation
# checked against a held copy; the project holds neither that survey nor Green, Karvounarakis &
# Tannen. The SEMIRING IS DELIBERATELY NOT REALIZED AND IS NOT PLANNED: these are records about a
# run, and nothing here computes with them algebraically.
{
  lib,
  scope,
  program,
}:
let
  keyOf = e: "${e.label}:${e.src}:${e.dst}";

  # ── LIFT — a materialized graph into an EVALUATED SCOPE (den-hoag-gayc U2c) ──
  # The one structure gen-scope's resolution calculus walks. `lift perLabel ids` takes `perLabel`, an
  # attrset of ACCESSORS (label -> id -> [targets]), and `ids`, the node set. The scope is
  # gen-authored, so its nodes declare `marks = _: _: [ ]`: nothing is withheld. A letter `l` becomes
  # the attribute `edges-l` the calculus reads at each reached node; the two letters the calculus owns
  # are read where it reads them — `parent` is containment, the node record's `.parent`, and
  # `imports` is its import relation — so a label spelled either way is walked as the calculus walks
  # that letter and not as a silently empty `edges-parent`. Containment is a FUNCTION, so a node with
  # two `parent` targets is refused by name rather than resolved over a graph the calculus cannot
  # represent.
  #
  # THE IR ADMITS AN EDGE WHOSE ENDPOINT IS NO REGISTERED NODE, and a walk follows it, so the scope's
  # vertices are the node ids PLUS every edge endpoint; the calculus refuses a node it was not
  # given. The scope carries nothing beside itself: the IR's own `nodes` and `edges` are the
  # enumerations, and the scope is what `resolve` walks.
  lift =
    perLabel: ids:
    let
      letters = builtins.attrNames perLabel;
      accessorOf = l: perLabel.${l};
      endpoints = builtins.attrNames (
        builtins.listToAttrs (
          map (n: {
            name = n;
            value = null;
          }) (builtins.concatMap (l: builtins.concatMap (accessorOf l) ids) letters)
        )
      );
      known = builtins.listToAttrs (
        map (n: {
          name = n;
          value = null;
        }) ids
      );
      vertices = ids ++ builtins.filter (n: !(known ? ${n})) endpoints;
      parentEdges = builtins.concatMap (
        s:
        let
          ps = accessorOf "parent" s;
        in
        if builtins.length ps > 1 then
          throw "gen-inspect: node '${s}' has ${toString (builtins.length ps)} 'parent' targets (${builtins.toJSON ps}); the label 'parent' is the calculus's containment, which is a function — a node has at most one parent"
        else
          map (t: {
            from = s;
            to = t;
          }) ps
      ) vertices;
      lifted =
        scope.eval { parseParent = _: null; }
          (
            {
              children = _: _: { };
              marks = _: _: [ ];
            }
            // lib.optionalAttrs (perLabel ? imports) { imports = _self: accessorOf "imports"; }
            // builtins.listToAttrs (
              map (l: {
                name = "edges-${l}";
                value = _self: accessorOf l;
              }) (builtins.filter (l: l != "parent" && l != "imports") letters)
            )
          )
          (
            scope.buildRoots {
              parentGraph =
                if perLabel ? parent then
                  scope.overlay (scope.vertices vertices) (scope.edges parentEdges)
                else
                  scope.vertices vertices;
            }
          );
    in
    lifted;

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
        "minted"
      ];
      inherit (subject)
        register
        relations
        declarations
        minted
        ;
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
      ruled = program.ruleEdges mdl declarations;
      inherit (ruled) reached;

      # The origin's join back to the heads. An edge is a property of the membership, and gen-program
      # collapses agreeing heads into one edge, so one key may carry several heads, and its
      # derivations are all of theirs. `reached ⊆ candidates`, so every reached key has a head here.
      # Each declaration record through gen-program's door: its defaulted fields as the options
      # step, then `relata` and `head` (den-hoag-7gp66 P2).
      normalized = map (
        d:
        program.declaration (removeAttrs d [
          "head"
          "relata"
        ]) d.relata d.head
      ) declarations;
      labelled = builtins.filter (d: d.label != null) normalized;

      # ★ A PROMOTED HEAD IS A NODE, READ FROM THE CALLER'S MINT. gen-program's `promoted` says which
      #   promoted heads the model includes; only the caller's mint gives such a head an identity
      #   (ADR-0016 rulings 5, 7), so the subject carries the mint's output as `minted` and this
      #   library mints nothing. `minted` is REQUIRED, `{ nodes = { }; edges = [ ]; }` when nothing
      #   is promoted, so the door below always runs: a mint that a subject without a promoted
      #   declaration carries is refused, never ignored. Its node set must be exactly the included
      #   promoted heads, none already registered, each with a string identity and its record's
      #   kind, with the mint's edges to its record's relata and no edge from anything else.
      #
      #   ★ THIS IS A SHAPE DOOR, NOT ADR-0016 r5's REFUSAL. The mint's node record carries no
      #   provenance mark and this library holds neither the relata identities nor the authority,
      #   so a well-formed identity it cannot re-derive is taken from the caller, as `model` is.
      promotedRecs = if builtins.any (d: d.promote != null) normalized then ruled.promoted else [ ];
      promotedIds = map (p: p.identifier) promotedRecs;
      mintedIds = builtins.attrNames minted.nodes;
      mintedEdgesOf = h: builtins.filter (e: e.from == h) minted.edges;
      sorted = lib.sort (a: b: a < b);
      mintedRecs = builtins.filter (p: builtins.elem p.identifier mintedIds) promotedRecs;
      faultsOf =
        msg: pred: xs:
        map msg (builtins.filter pred xs);
      mintFaults =
        faultsOf (h: "'${h}' is an included promoted head with no minted node") (
          h: !(builtins.elem h mintedIds)
        ) promotedIds
        ++ faultsOf (h: "minted node '${h}' is not a promoted head this model includes") (
          h: !(builtins.elem h promotedIds)
        ) mintedIds
        ++ faultsOf (
          h:
          "minted node '${h}' is already a registered node, of kind(s) ${
            builtins.concatStringsSep ", " (
              builtins.filter (k: register.${k} ? ${h}) (builtins.attrNames register)
            )
          }"
        ) (h: builtins.any (k: register.${k} ? ${h}) (builtins.attrNames register)) mintedIds
        ++ faultsOf (p: "minted node '${p.identifier}' carries no identity") (
          p:
          let
            i = minted.nodes.${p.identifier}.identity or null;
          in
          !(builtins.isString i && i != "")
        ) mintedRecs
        ++ faultsOf (
          p:
          "minted node '${p.identifier}' is of kind '${
            toString (minted.nodes.${p.identifier}.kind or null)
          }', not its promotion's kind '${p.kind}'"
        ) (p: (minted.nodes.${p.identifier}.kind or null) != p.kind) mintedRecs
        ++ faultsOf (p: "minted node '${p.identifier}' has edges that are not its promotion's relata") (
          p:
          sorted (lib.mapAttrsToList (l: t: "${l}:${t}") p.relata)
          != sorted (map (e: "${e.label}:${e.to}") (mintedEdgesOf p.identifier))
        ) mintedRecs
        ++ faultsOf (
          e: "minted edge '${e.label}:${e.from}:${e.to}' is from '${e.from}', which is no minted node"
        ) (e: !(builtins.elem e.from mintedIds)) minted.edges;
      # The promoted nodes join the register by their kind: ONE node list (ADR-0012). The door has
      # refused a head already registered, so `//` here only ever adds.
      nodeRegister = builtins.foldl' (
        acc: p:
        acc
        // {
          ${p.kind} = (acc.${p.kind} or { }) // {
            ${p.identifier} = { inherit (minted.nodes.${p.identifier}) identity content; };
          };
        }
      ) register promotedRecs;
      promotedEdges = builtins.concatMap (
        p:
        map (e: {
          inherit (e) label;
          src = e.from;
          dst = e.to;
          origin = {
            kind = "rule";
            derivations = witnessesOf p.identifier;
          };
        }) (mintedEdgesOf p.identifier)
      ) promotedRecs;
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

      edges = declaredEdges ++ ruleEdges ++ promotedEdges; # ONE edge list, one construction (ADR-0012)

      nodes = lib.concatMap (
        kind:
        map (id: {
          inherit id kind;
          attrs = nodeRegister.${kind}.${id};
        }) (builtins.attrNames nodeRegister.${kind})
      ) (builtins.attrNames nodeRegister);

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
      labels = lib.unique (
        builtins.attrNames relations ++ map (d: d.label) labelled ++ map (e: e.label) promotedEdges
      );

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
        ) nodeRegister
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

      kinds = lib.mapAttrs (k: _: { name = k; }) nodeRegister;

      # ★ `perLabel` is an attrset of ACCESSORS, label -> (id -> [targets]), NOT an edge list. The
      #   wrong shape fails LAZILY — a flat edge list here leaves `nodes` reading its full count at
      #   exit 0 and reds only at the first APPLICATION of `labeledEdges`.
      perLabel = lib.genAttrs labels (
        label: id: map (e: e.dst) (builtins.filter (e: e.label == label && e.src == id) edges)
      );
    in
    if missing != [ ] then
      throw "gen-inspect: not an evaluated scope; missing field(s): ${builtins.concatStringsSep ", " missing}"
    else if mintFaults != [ ] then
      throw "gen-inspect: the subject's `minted` does not match the model's promoted heads: ${builtins.concatStringsSep "; " mintFaults}"
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
        graph = lift perLabel (map (n: n.id) nodes);
      };

  # ── THE DEGENERATE CASE, THROUGH AN EXPLICIT WRAPPER ──
  # Any gen-graph labeled value is a subject with no rule half. It arrives through a wrapper
  # rather than a shape probe so that `materialize`'s missing-field refusal stays NAMED: a probe
  # would silently accept a graph as a scope and answer about an empty program.
  #
  # OPTIONS FIRST, THEN THE GRAPH (den-hoag-7gp66 P2, rules 2 and 3): `graphSubject { kind?; }
  # { nodes; perLabel; }`. The one optional field leaves for a closed options set, refused by name and
  # catchably at `graphSubject opts`'s own WHNF. `nodes` and `perLabel` together ARE the graph — an
  # accessor record (rule 3, owner-ruled "extend") — so they stay one open operand, its own door: a
  # missing field is refused by name at the record's application, an extra one is admitted (R5), and
  # `kind` given on the record instead of the options is refused by name rather than silently dropped
  # (`optionsStep`). Both specs are bound once, here.
  graphSubjectOptions = lib.door {
    name = "gen-inspect.graphSubject";
    next = graphRecordSpec;
    optional = [ "kind" ];
  };
  graphRecordSpec = {
    name = "gen-inspect.graphSubject";
    required = [
      "nodes"
      "perLabel"
    ];
    open = true;
    optionsStep = graphSubject;
  };
  graphRecord = lib.door graphRecordSpec;
  # `fromGraphWith k` is the same two steps with `k` applied to the subject: `fromGraph` is
  # `materialize` through it (and the inspector's `checked` through it), so its options and its
  # record are refused exactly as `graphSubject`'s are.
  fromGraphWith = k: graphSubjectOptions (o: graphRecord (r: k (graphSubjectCore o r)));
  graphSubject = fromGraphWith (subject: subject);
  graphSubjectCore =
    o:
    { nodes, perLabel, ... }:
    let
      kind = o.kind or "vertex";
    in
    {
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
      # Nothing is promoted, so the mint is empty.
      minted = {
        nodes = { };
        edges = [ ];
      };
    };
in
{
  inherit
    materialize
    graphSubject
    keyOf
    witnesses
    lift
    ;
  inherit fromGraphWith;
  fromGraph = fromGraphWith materialize;
}
