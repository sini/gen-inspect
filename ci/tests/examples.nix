# fleet/flake.nix takes the hub (integration); its default.nix entry value is what is declarable.
{ genInspect, mkFleet, ... }:
{
  gen.ci.examples.fleet = mkFleet genInspect false;
}
