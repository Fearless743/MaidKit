/// Detected host firewall implementation.
enum FirewallBackend {
  ufw,
  firewalld,
  nftables,
  iptables,
  none;

  String get label => switch (this) {
    FirewallBackend.ufw => 'UFW',
    FirewallBackend.firewalld => 'firewalld',
    FirewallBackend.nftables => 'nftables',
    FirewallBackend.iptables => 'iptables',
    FirewallBackend.none => 'None',
  };

  bool get supportsRuleEditing =>
      this == FirewallBackend.ufw || this == FirewallBackend.firewalld;
}

enum FirewallAction { allow, deny, reject, drop }

extension FirewallActionX on FirewallAction {
  String get label => name.toUpperCase();
}

/// A simplified firewall rule shown in the management UI.
class FirewallRule {
  const FirewallRule({
    required this.id,
    required this.display,
    this.action,
    this.direction,
    this.port,
    this.protocol,
    this.source,
    this.destination,
    this.enabled = true,
    this.zone,
  });

  /// Backend-specific identifier (UFW rule number, firewalld port string, …).
  final String id;
  final String display;
  final FirewallAction? action;
  final String? direction;
  final String? port;
  final String? protocol;
  final String? source;
  final String? destination;
  final bool enabled;
  final String? zone;
}

class FirewallStatus {
  const FirewallStatus({
    required this.backend,
    required this.active,
    this.rules = const [],
    this.defaultIncoming,
    this.defaultOutgoing,
    this.zones = const [],
    this.error,
    this.rawStatus,
  });

  final FirewallBackend backend;
  final bool active;
  final List<FirewallRule> rules;
  final String? defaultIncoming;
  final String? defaultOutgoing;
  final List<String> zones;
  final String? error;
  final String? rawStatus;

  bool get isAvailable => backend != FirewallBackend.none;

  FirewallStatus copyWith({
    bool? active,
    List<FirewallRule>? rules,
    String? error,
  }) => FirewallStatus(
    backend: backend,
    active: active ?? this.active,
    rules: rules ?? this.rules,
    defaultIncoming: defaultIncoming,
    defaultOutgoing: defaultOutgoing,
    zones: zones,
    error: error,
    rawStatus: rawStatus,
  );
}

/// Draft used when adding a new allow/deny rule.
class FirewallRuleDraft {
  const FirewallRuleDraft({
    required this.action,
    required this.port,
    this.protocol = 'tcp',
    this.source,
    this.comment,
  });

  final FirewallAction action;
  final String port;
  final String protocol;
  final String? source;
  final String? comment;
}
