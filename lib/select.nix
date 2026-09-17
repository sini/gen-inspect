# SELECT — IR + a gen-select selector → IR′. THE PROGRAMMATIC API.
#
# A query's result IS an IR. That is the whole reason the contract is named: a filter is the selector
# algebra rather than an ad-hoc filter set, and a renderer downstream cannot tell a filtered
# materialization from a whole one.
#
# ★ THE ORIGINS SEAM. `origins` stays a FIELD of the IR rather than a derived accessor precisely so
# that a filter can carry it forward without recomputing from the model. Gate 3 needs provenance to
# survive `select` and `compile`; an IR′ that dropped origins — or that rebuilt them — would make
# that a re-derivation against a model the filtered value no longer carries.
#
# THE VOCABULARY IS NOT FILTERED. `labels` and `kinds` are the subject's published vocabulary and the
# door's known sets; narrowing them with the node set would make a query's own result the authority
# on which label names exist, so `WHERE label = 'rings'` over an IR′ that kept no `rings` edge would
# refuse the name it had just been asked about.
{ lib, graph }:
let
  # gen-select matches a POSITION against a context. A node here is its own position: the IR is flat
  # — nodes carry a kind and an attrs splat, and no containment relation among them — so `parent`,
  # `children`, `ancestors` and `siblings` are empty rather than absent. An absent accessor would
  # abort inside a `within`/`parentMatches` selector instead of answering that nothing contains it.
  mkNodeContext = ir: {
    data =
      id:
      let
        hits = builtins.filter (n: n.id == id) ir.nodes;
      in
      if hits == [ ] then
        { }
      else
        (lib.head hits).attrs
        // {
          name = id;
          inherit ((lib.head hits)) kind;
        };
    parent = _: null;
    children = _: [ ];
    ancestors = _: [ ];
    siblings = _: [ ];
  };

  select =
    genSelect: ir: selector:
    let
      ctx = mkNodeContext ir;
      keptNodes = builtins.filter (n: genSelect.matches selector n.id ctx) ir.nodes;
      ids = map (n: n.id) keptNodes;
      # AN EDGE SURVIVES IFF BOTH ENDPOINTS DO. A dangling edge would make the IR′ describe a graph
      # whose source or target is not in it, and gen-graph's own labeled contract is node-set-total.
      keptEdges = builtins.filter (e: builtins.elem e.src ids && builtins.elem e.dst ids) ir.edges;
      keyOf = e: "${e.label}:${e.src}:${e.dst}";
      keptKeys = map keyOf keptEdges;
      keptIds = builtins.listToAttrs (
        map (id: {
          name = id;
          value = true;
        }) ids
      );
    in
    ir
    // {
      nodes = keptNodes;
      edges = keptEdges;
      # Carried forward, not recomputed — the gate-3 seam above.
      origins = lib.filterAttrs (k: _: builtins.elem k keptKeys) ir.origins;
      tables =
        lib.mapAttrs (
          kind: rows: if kind == "edge" then rows else lib.filterAttrs (id: _: keptIds ? ${id}) rows
        ) ir.tables
        // {
          edge = lib.filterAttrs (k: _: builtins.elem k keptKeys) ir.tables.edge;
        };
      graph = graph.labeledFrom {
        nodes = ids;
        perLabel = lib.genAttrs ir.labels (
          label: id: map (e: e.dst) (builtins.filter (e: e.label == label && e.src == id) keptEdges)
        );
      };
    };
in
{
  inherit select mkNodeContext;
}
