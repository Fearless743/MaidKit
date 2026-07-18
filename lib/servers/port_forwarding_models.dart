enum PortForwardDirection { local, remote }

class ActivePortForward {
  const ActivePortForward({
    required this.id,
    required this.serverId,
    required this.serverName,
    required this.direction,
    required this.bindHost,
    required this.bindPort,
    required this.targetHost,
    required this.targetPort,
  });

  final String id;
  final int serverId;
  final String serverName;
  final PortForwardDirection direction;
  final String bindHost;
  final int bindPort;
  final String targetHost;
  final int targetPort;

  String get directionLabel => switch (direction) {
    PortForwardDirection.local => 'Local',
    PortForwardDirection.remote => 'Remote',
  };

  String get summary => '$bindHost:$bindPort → $targetHost:$targetPort';
}
