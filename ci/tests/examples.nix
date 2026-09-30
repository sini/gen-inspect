# The fleet example, both entries. `entry` is `default.nix`, which exports the subject, register,
# relations, program and model; `flake` is `flake.nix` applied to the working tree (ci/flake.nix
# `fleetFlake`), which exposes only the inspectors. Its `packages` are derivations, which forcing
# would only reach through nixpkgs and never build, so they are outside the force domain.
{
  genInspect,
  mkFleet,
  fleetFlake,
  ...
}:
{
  gen.ci.examples.fleet = {
    entry = mkFleet genInspect false;
    flake = removeAttrs fleetFlake [ "packages" ];
  };
}
