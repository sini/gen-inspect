# CELL 8 — ADR-0035 CONFORMANCE, POSITION-SCOPED, OVER THE WHOLE TREE.
#
# No den or fleet word may sit at a KIND, LABEL, OPTION or ERROR position anywhere in this library's
# text. This library's vocabulary is invented end to end, and this cell is what says so.
#
# ★★ POSITION-SCOPING IS LOAD-BEARING, NOT A WEAKENING. A bare word sweep over the same tree reads
# NON-ZERO — ordinary English in comments: a sentence about a "system", a "user" of the library, a
# "service" this library does not provide. A bare-sweep cell therefore reds against a correct build
# and the next builder invents an exclusion nothing authorized. The two positions asserted are the
# two that ARE vocabulary:
#
#   (1) a double-quoted string that IS the word        — `"user"`   (kind, label, error text)
#   (2) the word at binding position at line start     — `user = `  (option, attribute, kind key)
#
# The cell carries the bare-sweep arm too, so the difference between the two predicates is a figure
# in this suite and not a claim in a comment.
#
# ★ THE WORD LIST IS ONE PIPE-JOINED STRING, SPLIT AT RUNTIME, AND THAT IS DELIBERATE. Written as a
# list of quoted words it would satisfy predicate (1) against ITSELF, and this file is inside the
# domain it scans — the scanner would red on its own word list and the fix would be an exclusion
# that hides the scanner from the scan.
#
# ★ ONE DIRECTORY IS EXCLUDED: `ci/tests/_fixtures/`, which holds the POSITIVE CONTROL — the
# unstripped alias table from the copied executor's origin, kept so this predicate can be seen to
# FIRE. The exclusion is asserted below by name, and so is the claim that it is the only one.
{ lib, ... }:
let
  root = ../..;

  forbidden = lib.splitString "|" "host|user|system|machine|service|cluster|server|network|port|interface|datacenter";

  # The excluded set, named. Everything else in the tree is scanned, including `ci/`.
  excludedDirs = [ "_fixtures" ];
  skipDir =
    name:
    builtins.elem name excludedDirs
    || builtins.elem name [
      ".git"
      ".direnv"
      "result"
      ".worktrees"
      ".gcroots"
    ];

  # The tree walk. `readDir` is the only enumerator that does not need a shell, and a shell is not
  # available to a pure evaluation. Symlinks are NOT followed: a tree of symlinks reads empty to a
  # recursive text scan, which is a clean zero over files a reader can open by name.
  filesUnder =
    dir: prefix:
    let
      entries = builtins.readDir dir;
    in
    builtins.concatLists (
      lib.mapAttrsToList (
        name: type:
        if type == "directory" then
          (if skipDir name then [ ] else filesUnder (dir + "/${name}") "${prefix}${name}/")
        else if type == "regular" then
          [
            {
              name = "${prefix}${name}";
              text = builtins.readFile (dir + "/${name}");
            }
          ]
        else
          [ ]
      ) entries
    );

  sources = filesUnder root "";

  # ★ COMMENTS ARE STRIPPED BEFORE THE PREDICATE RUNS, AND THAT IS THE POSITION SCOPE DOING ITS JOB
  # RATHER THAN AN EXEMPTION. ADR-0035 reaches KIND, LABEL, OPTION and ERROR position; a `#` comment
  # is none of those, and documentation must be able to NAME the vocabulary it excludes — this very
  # file does, in the paragraph above. MEASURED: without the strip this cell reported three hits,
  # all of them in this file's own header, all of them prose quoting the words the predicate
  # forbids. A scanner that reds on its own documentation gets an exclusion written for it, and the
  # exclusion is what would hide a real hit later. The ecosystem's own precedent is gen-program's
  # `ci/tests/purity.nix`, which strips for the same reason.
  #
  # The strip does NOT weaken the finding: error TEXT is a string literal and survives the cut, and
  # so does every kind key, label and option name, because all of them are code.
  stripComments =
    text:
    lib.concatStringsSep "\n" (
      map (line: lib.head (lib.splitString "#" line)) (lib.splitString "\n" text)
    );

  # The strip's premise, asserted rather than assumed: the `#` it cuts at stands OUTSIDE a string
  # literal. Where it does not, live code is truncated and this cell goes blind with no signal.
  countQuotes = s: (lib.length (lib.splitString "\"" s)) - 1;
  cutIsInString =
    line:
    let
      kept = stripComments line;
    in
    kept != line && lib.mod (countQuotes kept) 2 == 1;
  premiseBreaches = builtins.concatMap (
    src:
    lib.concatLists (
      lib.imap1 (i: line: lib.optional (cutIsInString line) "${src.name}:${toString i}") (
        lib.splitString "\n" src.text
      )
    )
  ) sources;

  lines =
    src:
    map (l: {
      inherit (src) name;
      line = l;
    }) (lib.splitString "\n" (stripComments src.text));
  allLines = builtins.concatMap lines sources;
  # The UNSTRIPPED lines, kept so the difference between the two domains is a figure below.
  rawLines = builtins.concatMap (
    src:
    map (l: {
      inherit (src) name;
      line = l;
    }) (lib.splitString "\n" src.text)
  ) sources;

  # ── THE TWO POSITION PREDICATES ──
  quotedIs = w: l: builtins.match ".*\"${w}\".*" l != null;
  boundAt = w: l: builtins.match "[[:space:]]*${w}[[:space:]]*=.*" l != null;
  atPosition = l: builtins.any (w: quotedIs w l || boundAt w l) forbidden;

  # ── THE BARE SWEEP, for the comparison the ★★ above claims ──
  # ★ NIX'S REGEX IS POSIX ERE AND HAS NO `\b`. Measured: `".*\\bhost\\b.*"` aborts with
  #   "invalid regular expression", which reads as a broken cell rather than as an unsupported
  #   construct. A bare sweep is CONTAINMENT anyway — that is what makes it the wrong predicate —
  #   so containment is what it uses.
  bare = l: builtins.any (w: builtins.match ".*${w}.*" l != null) forbidden;

  hitsIn = pred: ls: map (x: "${x.name}: ${x.line}") (builtins.filter (x: pred x.line) ls);

  positionHits = hitsIn atPosition allLines;
  # The bare sweep runs over the UNSTRIPPED text, because that is what a bare `grep -R` over the tree
  # would see and the comparison is against that instrument, not against a kinder version of it.
  bareHits = hitsIn bare rawLines;

  # ── THE POSITIVE CONTROL: the same predicate over the unstripped origin table ──
  fixtureFile = builtins.readFile ./_fixtures/unstripped-alias-table.nix;
  fixtureLines = map (l: {
    name = "_fixtures";
    line = l;
  }) (lib.splitString "\n" fixtureFile);
  # The fixture's HEADER is prose and would answer the bare sweep, so the control is scoped to the
  # table body: lines that bind an alias. Counting the whole file would make the control's non-zero
  # a fact about a comment.
  fixtureHits = hitsIn atPosition (
    builtins.filter (x: builtins.match "[[:space:]]+[a-z_]+ = \".*\";" x.line != null) fixtureLines
  );

  # ── A SECOND LIVE CONTROL: this library's OWN vocabulary, same predicate, same run ──
  ownVocabulary = [
    "tocsin"
    "peal"
  ];
  ownHits = builtins.filter (
    x:
    builtins.any (
      w:
      builtins.match ".*\"${w}\".*" x.line != null
      || builtins.match "[[:space:]]*${w}[[:space:]]*=.*" x.line != null
    ) ownVocabulary
  ) allLines;
in
{
  flake.tests.conformance = {
    # THE FINDING.
    test-no-fleet-vocabulary-at-kind-label-option-or-error-position = {
      expr = positionHits;
      expected = [ ];
    };

    # ★ THE CONTROL THAT MAKES THE ZERO ABOVE A MEASUREMENT. Same predicate, same run, a body it must
    # match. If this reads 0 the scanner is broken and the zero above means nothing.
    #
    # ★ SEVEN, NOT TWENTY-THREE, AND THE DIFFERENCE IS THE PREDICATE'S REACH RATHER THAN THE
    # FIXTURE'S SIZE. The origin table has 23 entries; 7 of their VALUES are words on the forbidden
    # list — `server`, `interface`, `service`, `port`, `network`, `datacenter`, `user`. The other 16
    # (`subnet`, `vlan`, `certificate`, `ldap-role`, …) are fleet vocabulary that this word list does
    # not name, so the predicate correctly does not fire on them. Asserting 23 here would be
    # asserting that the predicate matches things it was never given.
    test-positive-control-the-unstripped-origin-table-fires = {
      expr = builtins.length fixtureHits;
      expected = 7;
    };

    # ★ A SECOND CONTROL ON THE SCANNED TREE ITSELF, so the zero is not merely "the walk found no
    # files". This library's own invented vocabulary is at exactly the positions the predicate reads.
    test-live-control-the-invented-vocabulary-is-found-at-those-positions = {
      expr = builtins.length ownHits > 0;
      expected = true;
    };

    # ★★ THE BARE SWEEP READS NON-ZERO ON THE SAME CORRECT TREE. This is the figure behind the
    # claim that position-scoping is load-bearing rather than a weakening: a cell written on the bare
    # predicate would be red right now, against a tree that conforms.
    test-the-bare-sweep-is-not-the-predicate = {
      expr = builtins.length bareHits > builtins.length positionHits;
      expected = true;
    };

    # THE DOMAIN, ASSERTED. A walk that silently found nothing would satisfy every zero above.
    test-the-scan-reached-the-whole-tree = {
      expr = {
        libFiles = builtins.length (builtins.filter (s: lib.hasPrefix "lib/" s.name) sources);
        ciFilesScanned = builtins.length (builtins.filter (s: lib.hasPrefix "ci/" s.name) sources) > 0;
        exampleFilesScanned =
          builtins.length (builtins.filter (s: lib.hasPrefix "examples/" s.name) sources) > 0;
        rootFlakeScanned = builtins.any (s: s.name == "flake.nix") sources;
      };
      expected = {
        libFiles = 10;
        ciFilesScanned = true;
        exampleFilesScanned = true;
        rootFlakeScanned = true;
      };
    };

    # THE STRIP'S OWN PREMISE. Without it every zero above could be a zero over truncated code.
    #
    # ★ IT IS PINNED TO A NAMED LIST RATHER THAN TO EMPTY, AND THE REASON IS SELF-REFERENCE. This
    # scan's domain is the WHOLE TREE, so it scans the two files that DEFINE the cut — and their
    # definition spells the comment marker as a string literal, `lib.splitString "#" line`, which is
    # by construction a `#` inside a string. Those two lines are the only ones in the tree where the
    # cut lands inside a literal, and pinning them BY NAME is strictly stronger than excluding the
    # scanner from its own domain: a new breach anywhere, including a new line in these two files,
    # reds this cell.
    test-the-comment-strip-cuts-inside-a-string-only-where-it-defines-itself = {
      expr = premiseBreaches;
      expected = [
        "ci/tests/conformance.nix:86"
        "ci/tests/purity.nix:24"
      ];
    };

    # The two pinned lines ARE the strip's definition, asserted rather than trusted — a line number
    # drifts the moment either file is edited, and this is what says the drift was noticed.
    test-the-pinned-breaches-are-the-strips-own-definition = {
      expr =
        let
          at = file: n: lib.elemAt (lib.splitString "\n" (builtins.readFile file)) (n - 1);
        in
        lib.unique [
          (at ./conformance.nix 86)
          (at ./purity.nix 24)
        ];
      expected = [
        "      map (line: lib.head (lib.splitString \"#\" line)) (lib.splitString \"\\n\" text)"
      ];
    };

    # THE EXCLUSION, NAMED. It is one directory and this cell says which.
    test-the-only-excluded-directory-is-the-fixtures-one = {
      expr = excludedDirs;
      expected = [ "_fixtures" ];
    };

    test-nothing-from-the-excluded-directory-entered-the-domain = {
      expr = builtins.filter (s: lib.hasInfix "_fixtures" s.name) sources;
      expected = [ ];
    };
  };
}
