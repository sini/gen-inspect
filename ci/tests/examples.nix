# The fleet example's flake, applied to the working tree (ci/flake.nix `fleetFlake`). The declared
# value is its non-derivation outputs: `packages` is derivations, which forcing would only reach
# through nixpkgs and never build, so it is outside the force domain.
{ fleetFlake, ... }:
{
  gen.ci.examples.fleet = {
    inherit (fleetFlake) inspect inspect-withdrawn;
  };
}
