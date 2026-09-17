# ══ A FIXTURE, NOT LIBRARY SOURCE. It is here to be SCANNED AND TO MATCH. ══
#
# This is the kind-alias table exactly as it stands in the copied executor's ORIGIN,
# `gen-scope/examples/sql-schema/lib/engine.nix` at gen-scope
# `675d9f3542320546351605ba29f7c6361fcb0268`. `lib/executor.nix` strips it to the identity because
# its 23 entries sit AT KIND POSITION and carry ADR-0035 vocabulary; this copy exists so the
# conformance scan has a POSITIVE CONTROL — a body the predicate must FIRE on, in the same run in
# which it reports zero over the library tree. A scan that has only ever returned zero has not been
# shown to discriminate.
#
# ★ `ci/tests/_fixtures/` IS THE ONE DIRECTORY THE CONFORMANCE SCAN EXCLUDES, and this file is why.
# The exclusion is asserted by name in `ci/tests/conformance.nix` rather than assumed, and that cell
# also asserts that the excluded set is exactly this directory.
{
  kindAliases = {
    servers = "server";
    interfaces = "interface";
    services = "service";
    ports = "port";
    networks = "network";
    subnets = "subnet";
    vlans = "vlan";
    datacenters = "datacenter";
    environments = "environment";
    domains = "domain";
    dns_records = "dns-record";
    loadbalancers = "loadbalancer";
    backends = "backend";
    firewall_rules = "firewall-rule";
    certificates = "certificate";
    schedules = "schedule";
    ldap_groups = "ldap-group";
    ldap_roles = "ldap-role";
    users = "user";
    access_policies = "access-policy";
    service_dependencies = "service-dependency";
    effective_access = "effective-access";
    network_reachability = "network-reachability";
  };
}
