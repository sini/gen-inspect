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

  # A DOT quoted string reads `\"` as a quote and nothing else, but a LABEL then reads every
  # backslash as an escString escape (`\N` is the node's name), so the backslash is doubled too;
  # and graphviz decodes HTML entities in a label, so `&` is written `&amp;`.
  dotText = builtins.replaceStrings [ "\\" "\"" "&" ] [ "\\\\" "\\\"" "&amp;" ];

  mermaid =
    ir:
    let
      v = vertices ir;
      h = v.handle;
      nodeLine = n: "  ${h.${n.id}}[\"${mermaidText n.id}<br/>${mermaidText n.kind}\"]";
      # An endpoint no node record lists has no kind; it is drawn by its id, never by its handle.
      endpointLine = id: "  ${h.${id}}[\"${mermaidText id}\"]";
      edgeLine =
        e:
        let
          arrow = if e.origin.kind == "rule" then "-.->" else "-->";
        in
        "  ${h.${e.src}} ${arrow}|\"${mermaidText e.label}\"| ${h.${e.dst}}";
    in
    builtins.concatStringsSep "\n" (
      [ "flowchart LR" ] ++ map nodeLine ir.nodes ++ map endpointLine v.unlisted ++ map edgeLine ir.edges
    )
    + "\n";

  dot =
    ir:
    let
      nodeLine = n: "  \"${dotText n.id}\" [label=\"${dotText n.id}\\n${dotText n.kind}\"];";
      endpointLine = id: "  \"${dotText id}\" [label=\"${dotText id}\"];";
      edgeLine =
        e:
        let
          style = if e.origin.kind == "rule" then ", style=dashed" else "";
        in
        "  \"${dotText e.src}\" -> \"${dotText e.dst}\" [label=\"${dotText e.label}\"${style}];";
    in
    builtins.concatStringsSep "\n" (
      [ "digraph inspect {" ]
      ++ [ "  rankdir=LR;" ]
      ++ map nodeLine ir.nodes
      ++ map endpointLine (vertices ir).unlisted
      ++ map edgeLine ir.edges
      ++ [ "}" ]
    )
    + "\n";

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
