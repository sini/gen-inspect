# RENDER — IR′ → source string. IT READS THE IR AND NEVER THE SCOPE.
#
# That separation is the owner's amendment stated as a contract: "decouple the data from the
# renderer; like den-diagram is architected but better". A renderer that reached past the IR would
# make every query's result unrenderable, since a query's result is an IR and not a scope.
#
# ★ THE POLICY EDGE IS VISIBLY DISTINCT, AND THAT IS THE COMPONENT'S SECOND EXIT. `origin.kind` is a
# field of every edge, so "which of these did a policy produce" is a lookup rather than a heuristic:
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
  # mermaid ids must not collide with its own syntax. The IR's node ids are register keys and may
  # carry hyphens (`full-circle`), which mermaid reads as part of an arrow, so every id is quoted
  # through a bracket label and referenced by a sanitized handle.
  handle = id: builtins.replaceStrings [ "-" "." ":" " " ] [ "_" "_" "_" "_" ] id;

  mermaid =
    ir:
    let
      nodeLine = n: "  ${handle n.id}[\"${n.id}<br/>${n.kind}\"]";
      edgeLine =
        e:
        let
          arrow = if e.origin.kind == "policy" then "-.->" else "-->";
        in
        "  ${handle e.src} ${arrow}|${e.label}| ${handle e.dst}";
    in
    builtins.concatStringsSep "\n" (
      [ "flowchart LR" ] ++ map nodeLine ir.nodes ++ map edgeLine ir.edges
    )
    + "\n";

  dot =
    ir:
    let
      nodeLine = n: "  \"${n.id}\" [label=\"${n.id}\\n${n.kind}\"];";
      edgeLine =
        e:
        let
          style = if e.origin.kind == "policy" then ", style=dashed" else "";
        in
        "  \"${e.src}\" -> \"${e.dst}\" [label=\"${e.label}\"${style}];";
    in
    builtins.concatStringsSep "\n" (
      [ "digraph inspect {" ]
      ++ [ "  rankdir=LR;" ]
      ++ map nodeLine ir.nodes
      ++ map edgeLine ir.edges
      ++ [ "}" ]
    )
    + "\n";

  # ★ THE IR CARRIES A gen-graph VALUE, AND A GRAPH HOLDS ACCESSORS — `builtins.toJSON` of the whole
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
    handle
    ;
}
