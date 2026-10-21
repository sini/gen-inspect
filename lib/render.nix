# RENDER — IR′ → source string. IT READS THE IR AND NEVER THE SCOPE.
#
# That separation is the owner's amendment stated as a contract: "decouple the data from the
# renderer; like den-diagram is architected but better". A renderer that reached past the IR would
# make every query's result unrenderable, since a query's result is an IR and not a scope.
#
# ★ THE RULE EDGE IS VISIBLY DISTINCT, AND THAT IS THE COMPONENT'S SECOND EXIT. `origin.kind` is a
# field of every edge, so "which of these did a rule produce" is a lookup rather than a heuristic:
# mermaid gets `-.->` against `-->`, dot gets `style=dashed` against a solid edge.
#
# ★★ THE ASSERTION IS SOURCE-SIDE, AND A WHOLE-FILE SVG COUNT IS NOT A PREDICATE. mermaid emits
# `edge-pattern-dotted` in its STYLESHEET unconditionally, so a rendered-image cell asserting that
# the token occurs once reds against a correct build and greens at the red state; and
# `stroke-dasharray` discriminates not at all — measured 16 in both fixtures. Picture fidelity needs
# an ELEMENT-scoped predicate and a build, and the design sequences it to the guarantee row.
#
# `export` IS NOT HERE. Nothing in this file touches `pkgs` or produces a derivation; turning a
# source string into an image lives in the example and in consumers. den-diagram draws the same line:
# "`export` being the only stage that touches `pkgs`".
{ lib }:
let
  # THE IR ADMITS AN EDGE WHOSE ENDPOINT IS NO REGISTERED NODE (`materialize.nix`, `lift`), so the
  # vertices a picture draws are the node ids PLUS every edge endpoint. `unlisted` are the endpoints
  # no node record lists, sorted and each once (`attrNames`), and drawn by id alone.
  #
  # ★ THE HANDLE IS AN INDEX, SO IT IS INJECTIVE BY CONSTRUCTION OVER ANY BYTES: `n<i>`, where `i` is
  # the id's position in `ir.nodes`, and the unlisted endpoints are numbered after the nodes. The id
  # appears only as an attribute name, and no mermaid keyword is `n` followed by a digit. A handle is
  # therefore not stable across two IRs (a `select`ed sub-IR renumbers); the label carries the id.
  vertices =
    ir:
    let
      n = builtins.length ir.nodes;
      listed = builtins.listToAttrs (
        builtins.genList (i: {
          name = (builtins.elemAt ir.nodes i).id;
          value = "n${toString i}";
        }) n
      );
      unlisted = builtins.attrNames (
        builtins.listToAttrs (
          map
            (id: {
              name = id;
              value = null;
            })
            (
              builtins.filter (id: !(listed ? ${id})) (
                builtins.concatMap (e: [
                  e.src
                  e.dst
                ]) ir.edges
              )
            )
        )
      );
    in
    {
      inherit unlisted;
      handle =
        listed
        // builtins.listToAttrs (
          builtins.genList (i: {
            name = builtins.elemAt unlisted i;
            value = "n${toString (n + i)}";
          }) (builtins.length unlisted)
        );
    };

  # The text inside a mermaid `"…"` string. `"` ends it; an entity (`#quot;`) is decoded; `<`, `>`
  # and `&` are HTML; a backtick opens a markdown string; and every label reads the two characters
  # `\n` as a line break, through any entity spelling of either (entities decode first), so an empty
  # element is set between them. `%` opens a `%%{…}%%` directive and is written as an entity; `$`
  # opens KaTeX and `:` an `fa:` icon, and both passes run after entities decode, so an empty element
  # is set before each instead. `replaceStrings` makes one pass and never rescans its output, so the
  # entities and the element it writes stay what they were written as.
  #
  # The entity sigil is built from its code point, never written: the conformance and purity scans
  # cut each line at its first `#`, and one inside a string literal blinds them to the rest.
  sigil = builtins.fromJSON "\"\\u0023\"";
  mermaidText =
    builtins.replaceStrings
      [
        sigil
        "\""
        "<"
        ">"
        "&"
        "`"
        "\\n"
        "%"
        "$"
        ":"
      ]
      [
        "${sigil}35;"
        "${sigil}quot;"
        "${sigil}lt;"
        "${sigil}gt;"
        "${sigil}amp;"
        "${sigil}96;"
        "\\<b></b>n"
        "${sigil}37;"
        "<b></b>$"
        "<b></b>:"
      ];

  # A whole quoted string: mermaid refuses the empty `""` (an unlisted endpoint, an edge label, a
  # subgraph title), so an empty text is written as an empty element, which displays as nothing.
  mermaidString =
    t:
    let
      x = mermaidText t;
    in
    if x == "" then "<b></b>" else x;

  # A DOT quoted string reads `\"` as a quote and nothing else, but a LABEL then reads every
  # backslash as an escString escape (`\N` is the node's name), so the backslash is doubled too;
  # and graphviz decodes HTML entities in a label, so `&` is written `&amp;`.
  dotText = builtins.replaceStrings [ "\\" "\"" "&" ] [ "\\\\" "\\\"" "&amp;" ];

  # ── THE VIEW OPTIONS: one closed set, first (the uniform API grammar's R5, R7), the same for both renderers ──
  # A view choice says nothing about the data, so none of these is an IR field: an IR node is a data
  # record and carries no optional field (R5). `{ }` is today's picture, byte for byte.
  #   direction  "LR" — the flow; dot reads TD as TB
  #   shapeOf    kind -> null | a shape below; null is the renderer's own default
  #   labelOf    node -> string, the text in place of the id; the id stays the node's identity
  #   nest       false — when true, the IR's containment (the `parent` edges) draws as nesting
  options = [
    "direction"
    "shapeOf"
    "labelOf"
    "nest"
  ];
  directions = [
    "BT"
    "LR"
    "RL"
    "TB"
    "TD"
  ];
  # A shape is drawn by both renderers, so the set is the one both grammars have natively.
  shapes = {
    circle = {
      mermaid = [
        "(("
        "))"
      ];
      dot = ", shape=circle";
    };
    cylinder = {
      mermaid = [
        "[("
        ")]"
      ];
      dot = ", shape=cylinder";
    };
    hexagon = {
      mermaid = [
        "{{"
        "}}"
      ];
      dot = ", shape=hexagon";
    };
    rect = {
      mermaid = [
        "["
        "]"
      ];
      dot = ", shape=box";
    };
    rhombus = {
      mermaid = [
        "{"
        "}"
      ];
      dot = ", shape=diamond";
    };
    round = {
      mermaid = [
        "("
        ")"
      ];
      dot = ", shape=box, style=rounded";
    };
  };
  shown =
    x:
    let
      t = builtins.typeOf x;
    in
    if builtins.isString x then
      "'${x}'"
    else
      "${if builtins.match "[aeiou].*" t != null then "an" else "a"} ${t}";
  view =
    door: o:
    let
      fail = msg: throw "${door}: ${msg}";
      direction = o.direction or "LR";
      shapeOf = o.shapeOf or (_: null);
      labelOf = o.labelOf or (n: n.id);
      nest = o.nest or false;
    in
    if !(builtins.elem direction directions) then
      fail "direction ${shown direction} is not a direction (accepted: ${builtins.concatStringsSep ", " directions})"
    else if !(builtins.isFunction shapeOf) then
      fail "shapeOf must be a function from a kind to a shape or null, not ${shown shapeOf}"
    else if !(builtins.isFunction labelOf) then
      fail "labelOf must be a function from a node to a string, not ${shown labelOf}"
    else if !(builtins.isBool nest) then
      fail "nest must be a bool, not ${shown nest}"
    else
      {
        inherit direction nest;
        # An absent option adds no check per node; its default is the bare projection.
        shape =
          if !(o ? shapeOf) then
            _: null
          else
            kind:
            let
              s = shapeOf kind;
            in
            if s == null then
              null
            else if builtins.isString s && shapes ? ${s} then
              shapes.${s}
            else
              fail "shapeOf returned ${shown s} for kind '${kind}', which is no shape (accepted: null, ${builtins.concatStringsSep ", " (builtins.attrNames shapes)})";
        label =
          if !(o ? labelOf) then
            n: n.id
          else
            n:
            let
              l = labelOf n;
            in
            if builtins.isString l then
              l
            else
              fail "labelOf returned ${shown l} for node '${n.id}', not a string";
      };

  # ── NESTING READS THE IR'S OWN CONTAINMENT ──
  # The label `parent` is containment in this library already (`materialize.nix`, `lift`), and the
  # IR carries containment as `parent` edges; a node field would be a second source of it (R5 refuses
  # the optional field). Nesting is therefore a drawing of the
  # `parent` edges, which stay edges in the picture as well: the clusters are added, nothing is
  # removed. Containment is a function and a forest, so a vertex with two `parent` targets and a
  # `parent` cycle are refused by name. A target no node lists is a vertex like any endpoint, so every
  # parent is drawn by construction.
  nesting =
    door: ir: v:
    let
      h = v.handle;
      firstIds = builtins.filter (x: x != null) (
        builtins.genList (
          i:
          let
            id = (builtins.elemAt ir.nodes i).id;
          in
          if h.${id} == "n${toString i}" then id else null
        ) (builtins.length ir.nodes)
      );
      ids = firstIds ++ v.unlisted;
      up = builtins.groupBy (e: e.src) (builtins.filter (e: e.label == "parent") ir.edges);
      parentOf =
        id:
        let
          ts = lib.unique (map (e: e.dst) (up.${id} or [ ]));
        in
        if ts == [ ] then
          null
        else if builtins.length ts > 1 then
          throw "${door}: '${id}' has ${toString (builtins.length ts)} 'parent' targets (${builtins.toJSON ts}); nesting draws containment, which is a function, so a vertex has at most one parent"
        else
          builtins.head ts;
      parents = builtins.listToAttrs (
        map (id: {
          name = id;
          value = parentOf id;
        }) ids
      );
      under = builtins.groupBy (id: parents.${id}) (builtins.filter (id: parents.${id} != null) ids);
      roots = builtins.filter (id: parents.${id} == null) ids;
      key = id: { key = id; };
      reached = builtins.genericClosure {
        startSet = map key roots;
        operator = x: map key (under.${x.key} or [ ]);
      };
      seen = builtins.listToAttrs (
        map (x: {
          name = x.key;
          value = null;
        }) reached
      );
      above =
        id:
        map (x: x.key) (
          builtins.genericClosure {
            startSet = [ (key parents.${id}) ];
            operator = x: if parents.${x.key} == null then [ ] else [ (key parents.${x.key}) ];
          }
        );
      stray = builtins.head (builtins.filter (id: !(seen ? ${id})) ids);
      cycle = builtins.filter (id: builtins.elem id (above id)) (above stray);
    in
    if builtins.length reached == builtins.length ids then
      { inherit roots under; }
    else
      throw "${door}: the 'parent' edges form a cycle (${builtins.toJSON (lib.sort builtins.lessThan cycle)}); nesting draws containment, which is a forest";

  # The vertices in order, each nested under its parent: `open` and `close` bracket a vertex with
  # children, `inner` heads its block, and `linesOf` are its own lines. Without nesting every vertex is
  # a root with no children, so the walk is the flat list.
  nested =
    tree:
    {
      open,
      inner,
      close,
      linesOf,
    }:
    let
      walk =
        pad: id:
        let
          kids = tree.under.${id} or [ ];
        in
        if kids == [ ] then
          map (l: pad + l) (linesOf id)
        else
          [ (pad + open id) ]
          ++ map (l: pad + "  " + l) (inner id ++ linesOf id)
          ++ builtins.concatMap (walk (pad + "  ")) kids
          ++ [ (pad + close) ];
    in
    builtins.concatMap (walk "  ") tree.roots;

  mermaidDoor = lib.door {
    name = "gen-inspect.render.mermaid";
    optional = options;
  };
  mermaid = mermaidDoor (
    o: ir:
    let
      w = view "gen-inspect.render.mermaid" o;
      v = vertices ir;
      h = v.handle;
      bracket =
        n:
        let
          s = w.shape n.kind;
        in
        if s == null then shapes.rect.mermaid else s.mermaid;
      nodeText =
        n:
        let
          b = bracket n;
        in
        "${h.${n.id}}${builtins.elemAt b 0}\"${mermaidText (w.label n)}<br/>${mermaidText n.kind}\"${builtins.elemAt b 1}";
      # An endpoint no node record lists has no kind; it is drawn by its id, never by its handle.
      endpointText = id: "${h.${id}}[\"${mermaidString id}\"]";
      edgeLine =
        e:
        let
          arrow = if e.origin.kind == "rule" then "-.->" else "-->";
        in
        "  ${h.${e.src}} ${arrow}|\"${mermaidString e.label}\"| ${h.${e.dst}}";
      byId = builtins.groupBy (n: n.id) ir.nodes;
      # A cluster's id is its vertex's index under `g`, so it is injective and never a node handle.
      vertexLines =
        if w.nest then
          nested (nesting "gen-inspect.render.mermaid" ir v) {
            open =
              id:
              "subgraph g${builtins.substring 1 (builtins.stringLength h.${id}) h.${id}}[\"${
                mermaidString (if byId ? ${id} then w.label (builtins.head byId.${id}) else id)
              }\"]";
            inner = _: [ ];
            close = "end";
            linesOf = id: if byId ? ${id} then map nodeText byId.${id} else [ (endpointText id) ];
          }
        else
          map (n: "  ${nodeText n}") ir.nodes ++ map (id: "  ${endpointText id}") v.unlisted;
    in
    builtins.concatStringsSep "\n" (
      [ "flowchart ${w.direction}" ] ++ vertexLines ++ map edgeLine ir.edges
    )
    + "\n"
  );

  dotDoor = lib.door {
    name = "gen-inspect.render.dot";
    optional = options;
  };
  dot = dotDoor (
    o: ir:
    let
      w = view "gen-inspect.render.dot" o;
      v = vertices ir;
      shapeAttrs =
        n:
        let
          s = w.shape n.kind;
        in
        if s == null then "" else s.dot;
      nodeText =
        n: "\"${dotText n.id}\" [label=\"${dotText (w.label n)}\\n${dotText n.kind}\"${shapeAttrs n}];";
      endpointText = id: "\"${dotText id}\" [label=\"${dotText id}\"];";
      edgeLine =
        e:
        let
          style = if e.origin.kind == "rule" then ", style=dashed" else "";
        in
        "  \"${dotText e.src}\" -> \"${dotText e.dst}\" [label=\"${dotText e.label}\"${style}];";
      byId = builtins.groupBy (n: n.id) ir.nodes;
      vertexLines =
        if w.nest then
          nested (nesting "gen-inspect.render.dot" ir v) {
            open = id: "subgraph \"cluster:${dotText id}\" {";
            inner = id: [
              "label=\"${dotText (if byId ? ${id} then w.label (builtins.head byId.${id}) else id)}\";"
            ];
            close = "}";
            linesOf = id: if byId ? ${id} then map nodeText byId.${id} else [ (endpointText id) ];
          }
        else
          map (n: "  ${nodeText n}") ir.nodes ++ map (id: "  ${endpointText id}") v.unlisted;
    in
    builtins.concatStringsSep "\n" (
      [ "digraph inspect {" ]
      ++ [ "  rankdir=${if w.direction == "TD" then "TB" else w.direction};" ]
      ++ vertexLines
      ++ map edgeLine ir.edges
      ++ [ "}" ]
    )
    + "\n"
  );

  # ★ THE IR CARRIES AN EVALUATED SCOPE, AND A SCOPE HOLDS ACCESSORS — `builtins.toJSON` of the whole
  #   IR aborts with "cannot convert a function to JSON". The serializable projection is named here
  #   rather than left to the caller, so the JSON renderer is total over every IR this library
  #   produces instead of over the ones whose graph nobody reached.
  json =
    ir:
    builtins.toJSON {
      inherit (ir)
        nodes
        edges
        tables
        kinds
        labels
        origins
        ;
    };
in
{
  inherit
    mermaid
    dot
    json
    ;
}
