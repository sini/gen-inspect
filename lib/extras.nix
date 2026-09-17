# THE PRELUDE EXTENSION — seven names, and the reason each one is here is measured.
#
# The SQL parser and executor under `./sql.nix` and `./executor.nix` are COPIES from
# `gen-scope/examples/sql-schema`, and that example took nixpkgs `lib`. This library does not: every
# gen roster member's `lib/` is nixpkgs-lib-free, stated in its own source at gen-graph, gen-scope,
# gen-select, gen-schema and gen-program, and ADR-0014 records the motive the ecosystem holds it for
# — "so consumers … never reach for nixpkgs `lib`". A framework-stratum member that declared nixpkgs
# as a LIBRARY input would hand its whole closure to every consumer of this one, for seven functions.
#
# MEASURED at gen-prelude (53 published names) against the copied sources: the two files reach
# TWELVE distinct `lib.*` names, and SIX of them are absent from the prelude —
# `stringToCharacters`, `concatStrings`, `toUpper`, `take`, `lists.findFirstIndex`,
# `strings.toInt`. The example fleet's own materialization reaches a seventh, `splitString`. The six
# present ones (`optionalAttrs`, `mapAttrsToList`, `mapAttrs`, `listToAttrs`, `hasPrefix`,
# `filterAttrs`) arrive from the prelude unchanged, which is why this file EXTENDS rather than
# replaces: `lib` inside the copied files stays one name with the same meanings, and the copy's diff
# against its origin stays at its header plus two accessor paths.
#
# Each definition below is the nixpkgs semantics it stands in for, over `builtins` and the prelude
# alone. They are utilities and not vocabulary: nothing here is published on this library's surface.
prelude:
prelude
// rec {
  # nixpkgs: `genList (p: substring p 1 s) (stringLength s)`.
  stringToCharacters = s: prelude.genList (i: prelude.substring i 1 s) (prelude.stringLength s);

  # nixpkgs: `concatStringsSep ""`.
  concatStrings = prelude.concatStringsSep "";

  # nixpkgs splits on a LITERAL separator, so the separator is escaped before it reaches the regex
  # engine — `prelude.escapeRegex` is the ecosystem's own spelling of that escape.
  splitString =
    sep: s: builtins.filter builtins.isString (builtins.split (prelude.escapeRegex sep) s);

  # nixpkgs: `sublist 0 count`, which is TOTAL — a count past the end yields the whole list and a
  # negative count yields none, rather than aborting on an out-of-range index.
  take =
    n: xs:
    let
      l = prelude.length xs;
      c =
        if n < 0 then
          0
        else if n > l then
          l
        else
          n;
    in
    prelude.genList (i: prelude.elemAt xs i) c;

  # nixpkgs `lists.findFirstIndex pred default list` — the index of the first match, or `default`.
  findFirstIndex =
    pred: default: xs:
    let
      l = prelude.length xs;
      go =
        i:
        if i >= l then
          default
        else if pred (prelude.elemAt xs i) then
          i
        else
          go (i + 1);
    in
    go 0;

  # nixpkgs: `replaceStrings lowerChars upperChars`. ASCII only, as the original is.
  toUpper = builtins.replaceStrings (stringToCharacters "abcdefghijklmnopqrstuvwxyz") (
    stringToCharacters "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  );

  # nixpkgs `strings.toInt`: leading zeros and surrounding space are stripped before conversion,
  # which is what makes `007` an integer here and a JSON syntax error without the strip. A
  # non-integer is refused BY NAME rather than returning null — the caller's token already matched
  # `[0-9]+`, so reaching the refusal means the classifier and this function disagree.
  toInt =
    str:
    let
      m = builtins.match "[[:space:]]*0*([[:digit:]]+)[[:space:]]*" str;
    in
    if m == null then
      throw "gen-inspect: toInt: not an integer: '${str}'"
    else
      builtins.fromJSON (
        let
          d = prelude.head m;
        in
        if d == "" then "0" else d
      );
}
