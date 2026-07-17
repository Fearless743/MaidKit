// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ServersTable extends Servers with TableInfo<$ServersTable, Server> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ServersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _portMeta = const VerificationMeta('port');
  @override
  late final GeneratedColumn<int> port = GeneratedColumn<int>(
    'port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(22),
  );
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastConnectedAtMeta = const VerificationMeta(
    'lastConnectedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastConnectedAt =
      GeneratedColumn<DateTime>(
        'last_connected_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
    'sync_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _credentialTypeMeta = const VerificationMeta(
    'credentialType',
  );
  @override
  late final GeneratedColumn<String> credentialType = GeneratedColumn<String>(
    'credential_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _encryptedCredentialMeta =
      const VerificationMeta('encryptedCredential');
  @override
  late final GeneratedColumn<String> encryptedCredential =
      GeneratedColumn<String>(
        'encrypted_credential',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _credentialNonceMeta = const VerificationMeta(
    'credentialNonce',
  );
  @override
  late final GeneratedColumn<String> credentialNonce = GeneratedColumn<String>(
    'credential_nonce',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hostKeyAlgorithmMeta = const VerificationMeta(
    'hostKeyAlgorithm',
  );
  @override
  late final GeneratedColumn<String> hostKeyAlgorithm = GeneratedColumn<String>(
    'host_key_algorithm',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hostKeyFingerprintMeta =
      const VerificationMeta('hostKeyFingerprint');
  @override
  late final GeneratedColumn<String> hostKeyFingerprint =
      GeneratedColumn<String>(
        'host_key_fingerprint',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _collectStatsMeta = const VerificationMeta(
    'collectStats',
  );
  @override
  late final GeneratedColumn<bool> collectStats = GeneratedColumn<bool>(
    'collect_stats',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("collect_stats" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _collectSystemInfoMeta = const VerificationMeta(
    'collectSystemInfo',
  );
  @override
  late final GeneratedColumn<bool> collectSystemInfo = GeneratedColumn<bool>(
    'collect_system_info',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("collect_system_info" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    host,
    port,
    username,
    lastConnectedAt,
    syncId,
    createdAt,
    updatedAt,
    deletedAt,
    credentialType,
    encryptedCredential,
    credentialNonce,
    hostKeyAlgorithm,
    hostKeyFingerprint,
    collectStats,
    collectSystemInfo,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'servers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Server> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    } else if (isInserting) {
      context.missing(_hostMeta);
    }
    if (data.containsKey('port')) {
      context.handle(
        _portMeta,
        port.isAcceptableOrUnknown(data['port']!, _portMeta),
      );
    }
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('last_connected_at')) {
      context.handle(
        _lastConnectedAtMeta,
        lastConnectedAt.isAcceptableOrUnknown(
          data['last_connected_at']!,
          _lastConnectedAtMeta,
        ),
      );
    }
    if (data.containsKey('sync_id')) {
      context.handle(
        _syncIdMeta,
        syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('credential_type')) {
      context.handle(
        _credentialTypeMeta,
        credentialType.isAcceptableOrUnknown(
          data['credential_type']!,
          _credentialTypeMeta,
        ),
      );
    }
    if (data.containsKey('encrypted_credential')) {
      context.handle(
        _encryptedCredentialMeta,
        encryptedCredential.isAcceptableOrUnknown(
          data['encrypted_credential']!,
          _encryptedCredentialMeta,
        ),
      );
    }
    if (data.containsKey('credential_nonce')) {
      context.handle(
        _credentialNonceMeta,
        credentialNonce.isAcceptableOrUnknown(
          data['credential_nonce']!,
          _credentialNonceMeta,
        ),
      );
    }
    if (data.containsKey('host_key_algorithm')) {
      context.handle(
        _hostKeyAlgorithmMeta,
        hostKeyAlgorithm.isAcceptableOrUnknown(
          data['host_key_algorithm']!,
          _hostKeyAlgorithmMeta,
        ),
      );
    }
    if (data.containsKey('host_key_fingerprint')) {
      context.handle(
        _hostKeyFingerprintMeta,
        hostKeyFingerprint.isAcceptableOrUnknown(
          data['host_key_fingerprint']!,
          _hostKeyFingerprintMeta,
        ),
      );
    }
    if (data.containsKey('collect_stats')) {
      context.handle(
        _collectStatsMeta,
        collectStats.isAcceptableOrUnknown(
          data['collect_stats']!,
          _collectStatsMeta,
        ),
      );
    }
    if (data.containsKey('collect_system_info')) {
      context.handle(
        _collectSystemInfoMeta,
        collectSystemInfo.isAcceptableOrUnknown(
          data['collect_system_info']!,
          _collectSystemInfoMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Server map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Server(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      )!,
      port: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}port'],
      )!,
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      lastConnectedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_connected_at'],
      ),
      syncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      credentialType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credential_type'],
      ),
      encryptedCredential: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encrypted_credential'],
      ),
      credentialNonce: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}credential_nonce'],
      ),
      hostKeyAlgorithm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host_key_algorithm'],
      ),
      hostKeyFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host_key_fingerprint'],
      ),
      collectStats: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}collect_stats'],
      )!,
      collectSystemInfo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}collect_system_info'],
      )!,
    );
  }

  @override
  $ServersTable createAlias(String alias) {
    return $ServersTable(attachedDatabase, alias);
  }
}

class Server extends DataClass implements Insertable<Server> {
  final int id;
  final String name;
  final String host;
  final int port;
  final String username;
  final DateTime? lastConnectedAt;
  final String? syncId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final String? credentialType;
  final String? encryptedCredential;
  final String? credentialNonce;
  final String? hostKeyAlgorithm;
  final String? hostKeyFingerprint;
  final bool collectStats;
  final bool collectSystemInfo;
  const Server({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.username,
    this.lastConnectedAt,
    this.syncId,
    this.createdAt,
    this.updatedAt,
    this.deletedAt,
    this.credentialType,
    this.encryptedCredential,
    this.credentialNonce,
    this.hostKeyAlgorithm,
    this.hostKeyFingerprint,
    required this.collectStats,
    required this.collectSystemInfo,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['host'] = Variable<String>(host);
    map['port'] = Variable<int>(port);
    map['username'] = Variable<String>(username);
    if (!nullToAbsent || lastConnectedAt != null) {
      map['last_connected_at'] = Variable<DateTime>(lastConnectedAt);
    }
    if (!nullToAbsent || syncId != null) {
      map['sync_id'] = Variable<String>(syncId);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<DateTime>(updatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || credentialType != null) {
      map['credential_type'] = Variable<String>(credentialType);
    }
    if (!nullToAbsent || encryptedCredential != null) {
      map['encrypted_credential'] = Variable<String>(encryptedCredential);
    }
    if (!nullToAbsent || credentialNonce != null) {
      map['credential_nonce'] = Variable<String>(credentialNonce);
    }
    if (!nullToAbsent || hostKeyAlgorithm != null) {
      map['host_key_algorithm'] = Variable<String>(hostKeyAlgorithm);
    }
    if (!nullToAbsent || hostKeyFingerprint != null) {
      map['host_key_fingerprint'] = Variable<String>(hostKeyFingerprint);
    }
    map['collect_stats'] = Variable<bool>(collectStats);
    map['collect_system_info'] = Variable<bool>(collectSystemInfo);
    return map;
  }

  ServersCompanion toCompanion(bool nullToAbsent) {
    return ServersCompanion(
      id: Value(id),
      name: Value(name),
      host: Value(host),
      port: Value(port),
      username: Value(username),
      lastConnectedAt: lastConnectedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastConnectedAt),
      syncId: syncId == null && nullToAbsent
          ? const Value.absent()
          : Value(syncId),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      credentialType: credentialType == null && nullToAbsent
          ? const Value.absent()
          : Value(credentialType),
      encryptedCredential: encryptedCredential == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptedCredential),
      credentialNonce: credentialNonce == null && nullToAbsent
          ? const Value.absent()
          : Value(credentialNonce),
      hostKeyAlgorithm: hostKeyAlgorithm == null && nullToAbsent
          ? const Value.absent()
          : Value(hostKeyAlgorithm),
      hostKeyFingerprint: hostKeyFingerprint == null && nullToAbsent
          ? const Value.absent()
          : Value(hostKeyFingerprint),
      collectStats: Value(collectStats),
      collectSystemInfo: Value(collectSystemInfo),
    );
  }

  factory Server.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Server(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      host: serializer.fromJson<String>(json['host']),
      port: serializer.fromJson<int>(json['port']),
      username: serializer.fromJson<String>(json['username']),
      lastConnectedAt: serializer.fromJson<DateTime?>(json['lastConnectedAt']),
      syncId: serializer.fromJson<String?>(json['syncId']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime?>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      credentialType: serializer.fromJson<String?>(json['credentialType']),
      encryptedCredential: serializer.fromJson<String?>(
        json['encryptedCredential'],
      ),
      credentialNonce: serializer.fromJson<String?>(json['credentialNonce']),
      hostKeyAlgorithm: serializer.fromJson<String?>(json['hostKeyAlgorithm']),
      hostKeyFingerprint: serializer.fromJson<String?>(
        json['hostKeyFingerprint'],
      ),
      collectStats: serializer.fromJson<bool>(json['collectStats']),
      collectSystemInfo: serializer.fromJson<bool>(json['collectSystemInfo']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'host': serializer.toJson<String>(host),
      'port': serializer.toJson<int>(port),
      'username': serializer.toJson<String>(username),
      'lastConnectedAt': serializer.toJson<DateTime?>(lastConnectedAt),
      'syncId': serializer.toJson<String?>(syncId),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime?>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'credentialType': serializer.toJson<String?>(credentialType),
      'encryptedCredential': serializer.toJson<String?>(encryptedCredential),
      'credentialNonce': serializer.toJson<String?>(credentialNonce),
      'hostKeyAlgorithm': serializer.toJson<String?>(hostKeyAlgorithm),
      'hostKeyFingerprint': serializer.toJson<String?>(hostKeyFingerprint),
      'collectStats': serializer.toJson<bool>(collectStats),
      'collectSystemInfo': serializer.toJson<bool>(collectSystemInfo),
    };
  }

  Server copyWith({
    int? id,
    String? name,
    String? host,
    int? port,
    String? username,
    Value<DateTime?> lastConnectedAt = const Value.absent(),
    Value<String?> syncId = const Value.absent(),
    Value<DateTime?> createdAt = const Value.absent(),
    Value<DateTime?> updatedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<String?> credentialType = const Value.absent(),
    Value<String?> encryptedCredential = const Value.absent(),
    Value<String?> credentialNonce = const Value.absent(),
    Value<String?> hostKeyAlgorithm = const Value.absent(),
    Value<String?> hostKeyFingerprint = const Value.absent(),
    bool? collectStats,
    bool? collectSystemInfo,
  }) => Server(
    id: id ?? this.id,
    name: name ?? this.name,
    host: host ?? this.host,
    port: port ?? this.port,
    username: username ?? this.username,
    lastConnectedAt: lastConnectedAt.present
        ? lastConnectedAt.value
        : this.lastConnectedAt,
    syncId: syncId.present ? syncId.value : this.syncId,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    credentialType: credentialType.present
        ? credentialType.value
        : this.credentialType,
    encryptedCredential: encryptedCredential.present
        ? encryptedCredential.value
        : this.encryptedCredential,
    credentialNonce: credentialNonce.present
        ? credentialNonce.value
        : this.credentialNonce,
    hostKeyAlgorithm: hostKeyAlgorithm.present
        ? hostKeyAlgorithm.value
        : this.hostKeyAlgorithm,
    hostKeyFingerprint: hostKeyFingerprint.present
        ? hostKeyFingerprint.value
        : this.hostKeyFingerprint,
    collectStats: collectStats ?? this.collectStats,
    collectSystemInfo: collectSystemInfo ?? this.collectSystemInfo,
  );
  Server copyWithCompanion(ServersCompanion data) {
    return Server(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      host: data.host.present ? data.host.value : this.host,
      port: data.port.present ? data.port.value : this.port,
      username: data.username.present ? data.username.value : this.username,
      lastConnectedAt: data.lastConnectedAt.present
          ? data.lastConnectedAt.value
          : this.lastConnectedAt,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      credentialType: data.credentialType.present
          ? data.credentialType.value
          : this.credentialType,
      encryptedCredential: data.encryptedCredential.present
          ? data.encryptedCredential.value
          : this.encryptedCredential,
      credentialNonce: data.credentialNonce.present
          ? data.credentialNonce.value
          : this.credentialNonce,
      hostKeyAlgorithm: data.hostKeyAlgorithm.present
          ? data.hostKeyAlgorithm.value
          : this.hostKeyAlgorithm,
      hostKeyFingerprint: data.hostKeyFingerprint.present
          ? data.hostKeyFingerprint.value
          : this.hostKeyFingerprint,
      collectStats: data.collectStats.present
          ? data.collectStats.value
          : this.collectStats,
      collectSystemInfo: data.collectSystemInfo.present
          ? data.collectSystemInfo.value
          : this.collectSystemInfo,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Server(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('host: $host, ')
          ..write('port: $port, ')
          ..write('username: $username, ')
          ..write('lastConnectedAt: $lastConnectedAt, ')
          ..write('syncId: $syncId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('credentialType: $credentialType, ')
          ..write('encryptedCredential: $encryptedCredential, ')
          ..write('credentialNonce: $credentialNonce, ')
          ..write('hostKeyAlgorithm: $hostKeyAlgorithm, ')
          ..write('hostKeyFingerprint: $hostKeyFingerprint, ')
          ..write('collectStats: $collectStats, ')
          ..write('collectSystemInfo: $collectSystemInfo')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    host,
    port,
    username,
    lastConnectedAt,
    syncId,
    createdAt,
    updatedAt,
    deletedAt,
    credentialType,
    encryptedCredential,
    credentialNonce,
    hostKeyAlgorithm,
    hostKeyFingerprint,
    collectStats,
    collectSystemInfo,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Server &&
          other.id == this.id &&
          other.name == this.name &&
          other.host == this.host &&
          other.port == this.port &&
          other.username == this.username &&
          other.lastConnectedAt == this.lastConnectedAt &&
          other.syncId == this.syncId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.credentialType == this.credentialType &&
          other.encryptedCredential == this.encryptedCredential &&
          other.credentialNonce == this.credentialNonce &&
          other.hostKeyAlgorithm == this.hostKeyAlgorithm &&
          other.hostKeyFingerprint == this.hostKeyFingerprint &&
          other.collectStats == this.collectStats &&
          other.collectSystemInfo == this.collectSystemInfo);
}

class ServersCompanion extends UpdateCompanion<Server> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> host;
  final Value<int> port;
  final Value<String> username;
  final Value<DateTime?> lastConnectedAt;
  final Value<String?> syncId;
  final Value<DateTime?> createdAt;
  final Value<DateTime?> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> credentialType;
  final Value<String?> encryptedCredential;
  final Value<String?> credentialNonce;
  final Value<String?> hostKeyAlgorithm;
  final Value<String?> hostKeyFingerprint;
  final Value<bool> collectStats;
  final Value<bool> collectSystemInfo;
  const ServersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.host = const Value.absent(),
    this.port = const Value.absent(),
    this.username = const Value.absent(),
    this.lastConnectedAt = const Value.absent(),
    this.syncId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.credentialType = const Value.absent(),
    this.encryptedCredential = const Value.absent(),
    this.credentialNonce = const Value.absent(),
    this.hostKeyAlgorithm = const Value.absent(),
    this.hostKeyFingerprint = const Value.absent(),
    this.collectStats = const Value.absent(),
    this.collectSystemInfo = const Value.absent(),
  });
  ServersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String host,
    this.port = const Value.absent(),
    required String username,
    this.lastConnectedAt = const Value.absent(),
    this.syncId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.credentialType = const Value.absent(),
    this.encryptedCredential = const Value.absent(),
    this.credentialNonce = const Value.absent(),
    this.hostKeyAlgorithm = const Value.absent(),
    this.hostKeyFingerprint = const Value.absent(),
    this.collectStats = const Value.absent(),
    this.collectSystemInfo = const Value.absent(),
  }) : name = Value(name),
       host = Value(host),
       username = Value(username);
  static Insertable<Server> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? host,
    Expression<int>? port,
    Expression<String>? username,
    Expression<DateTime>? lastConnectedAt,
    Expression<String>? syncId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? credentialType,
    Expression<String>? encryptedCredential,
    Expression<String>? credentialNonce,
    Expression<String>? hostKeyAlgorithm,
    Expression<String>? hostKeyFingerprint,
    Expression<bool>? collectStats,
    Expression<bool>? collectSystemInfo,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (host != null) 'host': host,
      if (port != null) 'port': port,
      if (username != null) 'username': username,
      if (lastConnectedAt != null) 'last_connected_at': lastConnectedAt,
      if (syncId != null) 'sync_id': syncId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (credentialType != null) 'credential_type': credentialType,
      if (encryptedCredential != null)
        'encrypted_credential': encryptedCredential,
      if (credentialNonce != null) 'credential_nonce': credentialNonce,
      if (hostKeyAlgorithm != null) 'host_key_algorithm': hostKeyAlgorithm,
      if (hostKeyFingerprint != null)
        'host_key_fingerprint': hostKeyFingerprint,
      if (collectStats != null) 'collect_stats': collectStats,
      if (collectSystemInfo != null) 'collect_system_info': collectSystemInfo,
    });
  }

  ServersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? host,
    Value<int>? port,
    Value<String>? username,
    Value<DateTime?>? lastConnectedAt,
    Value<String?>? syncId,
    Value<DateTime?>? createdAt,
    Value<DateTime?>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String?>? credentialType,
    Value<String?>? encryptedCredential,
    Value<String?>? credentialNonce,
    Value<String?>? hostKeyAlgorithm,
    Value<String?>? hostKeyFingerprint,
    Value<bool>? collectStats,
    Value<bool>? collectSystemInfo,
  }) {
    return ServersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      syncId: syncId ?? this.syncId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      credentialType: credentialType ?? this.credentialType,
      encryptedCredential: encryptedCredential ?? this.encryptedCredential,
      credentialNonce: credentialNonce ?? this.credentialNonce,
      hostKeyAlgorithm: hostKeyAlgorithm ?? this.hostKeyAlgorithm,
      hostKeyFingerprint: hostKeyFingerprint ?? this.hostKeyFingerprint,
      collectStats: collectStats ?? this.collectStats,
      collectSystemInfo: collectSystemInfo ?? this.collectSystemInfo,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (port.present) {
      map['port'] = Variable<int>(port.value);
    }
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (lastConnectedAt.present) {
      map['last_connected_at'] = Variable<DateTime>(lastConnectedAt.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (credentialType.present) {
      map['credential_type'] = Variable<String>(credentialType.value);
    }
    if (encryptedCredential.present) {
      map['encrypted_credential'] = Variable<String>(encryptedCredential.value);
    }
    if (credentialNonce.present) {
      map['credential_nonce'] = Variable<String>(credentialNonce.value);
    }
    if (hostKeyAlgorithm.present) {
      map['host_key_algorithm'] = Variable<String>(hostKeyAlgorithm.value);
    }
    if (hostKeyFingerprint.present) {
      map['host_key_fingerprint'] = Variable<String>(hostKeyFingerprint.value);
    }
    if (collectStats.present) {
      map['collect_stats'] = Variable<bool>(collectStats.value);
    }
    if (collectSystemInfo.present) {
      map['collect_system_info'] = Variable<bool>(collectSystemInfo.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ServersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('host: $host, ')
          ..write('port: $port, ')
          ..write('username: $username, ')
          ..write('lastConnectedAt: $lastConnectedAt, ')
          ..write('syncId: $syncId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('credentialType: $credentialType, ')
          ..write('encryptedCredential: $encryptedCredential, ')
          ..write('credentialNonce: $credentialNonce, ')
          ..write('hostKeyAlgorithm: $hostKeyAlgorithm, ')
          ..write('hostKeyFingerprint: $hostKeyFingerprint, ')
          ..write('collectStats: $collectStats, ')
          ..write('collectSystemInfo: $collectSystemInfo')
          ..write(')'))
        .toString();
  }
}

class $VaultMetadataTable extends VaultMetadata
    with TableInfo<$VaultMetadataTable, VaultMetadataData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _formatVersionMeta = const VerificationMeta(
    'formatVersion',
  );
  @override
  late final GeneratedColumn<int> formatVersion = GeneratedColumn<int>(
    'format_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _saltMeta = const VerificationMeta('salt');
  @override
  late final GeneratedColumn<String> salt = GeneratedColumn<String>(
    'salt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wrappedDataKeyMeta = const VerificationMeta(
    'wrappedDataKey',
  );
  @override
  late final GeneratedColumn<String> wrappedDataKey = GeneratedColumn<String>(
    'wrapped_data_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wrappedDataKeyNonceMeta =
      const VerificationMeta('wrappedDataKeyNonce');
  @override
  late final GeneratedColumn<String> wrappedDataKeyNonce =
      GeneratedColumn<String>(
        'wrapped_data_key_nonce',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _verifierMeta = const VerificationMeta(
    'verifier',
  );
  @override
  late final GeneratedColumn<String> verifier = GeneratedColumn<String>(
    'verifier',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _verifierNonceMeta = const VerificationMeta(
    'verifierNonce',
  );
  @override
  late final GeneratedColumn<String> verifierNonce = GeneratedColumn<String>(
    'verifier_nonce',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    formatVersion,
    salt,
    wrappedDataKey,
    wrappedDataKeyNonce,
    verifier,
    verifierNonce,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_metadata';
  @override
  VerificationContext validateIntegrity(
    Insertable<VaultMetadataData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('format_version')) {
      context.handle(
        _formatVersionMeta,
        formatVersion.isAcceptableOrUnknown(
          data['format_version']!,
          _formatVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_formatVersionMeta);
    }
    if (data.containsKey('salt')) {
      context.handle(
        _saltMeta,
        salt.isAcceptableOrUnknown(data['salt']!, _saltMeta),
      );
    } else if (isInserting) {
      context.missing(_saltMeta);
    }
    if (data.containsKey('wrapped_data_key')) {
      context.handle(
        _wrappedDataKeyMeta,
        wrappedDataKey.isAcceptableOrUnknown(
          data['wrapped_data_key']!,
          _wrappedDataKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_wrappedDataKeyMeta);
    }
    if (data.containsKey('wrapped_data_key_nonce')) {
      context.handle(
        _wrappedDataKeyNonceMeta,
        wrappedDataKeyNonce.isAcceptableOrUnknown(
          data['wrapped_data_key_nonce']!,
          _wrappedDataKeyNonceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_wrappedDataKeyNonceMeta);
    }
    if (data.containsKey('verifier')) {
      context.handle(
        _verifierMeta,
        verifier.isAcceptableOrUnknown(data['verifier']!, _verifierMeta),
      );
    } else if (isInserting) {
      context.missing(_verifierMeta);
    }
    if (data.containsKey('verifier_nonce')) {
      context.handle(
        _verifierNonceMeta,
        verifierNonce.isAcceptableOrUnknown(
          data['verifier_nonce']!,
          _verifierNonceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_verifierNonceMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultMetadataData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultMetadataData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      formatVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}format_version'],
      )!,
      salt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}salt'],
      )!,
      wrappedDataKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wrapped_data_key'],
      )!,
      wrappedDataKeyNonce: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wrapped_data_key_nonce'],
      )!,
      verifier: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verifier'],
      )!,
      verifierNonce: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verifier_nonce'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $VaultMetadataTable createAlias(String alias) {
    return $VaultMetadataTable(attachedDatabase, alias);
  }
}

class VaultMetadataData extends DataClass
    implements Insertable<VaultMetadataData> {
  final int id;
  final int formatVersion;
  final String salt;
  final String wrappedDataKey;
  final String wrappedDataKeyNonce;
  final String verifier;
  final String verifierNonce;
  final DateTime createdAt;
  const VaultMetadataData({
    required this.id,
    required this.formatVersion,
    required this.salt,
    required this.wrappedDataKey,
    required this.wrappedDataKeyNonce,
    required this.verifier,
    required this.verifierNonce,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['format_version'] = Variable<int>(formatVersion);
    map['salt'] = Variable<String>(salt);
    map['wrapped_data_key'] = Variable<String>(wrappedDataKey);
    map['wrapped_data_key_nonce'] = Variable<String>(wrappedDataKeyNonce);
    map['verifier'] = Variable<String>(verifier);
    map['verifier_nonce'] = Variable<String>(verifierNonce);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  VaultMetadataCompanion toCompanion(bool nullToAbsent) {
    return VaultMetadataCompanion(
      id: Value(id),
      formatVersion: Value(formatVersion),
      salt: Value(salt),
      wrappedDataKey: Value(wrappedDataKey),
      wrappedDataKeyNonce: Value(wrappedDataKeyNonce),
      verifier: Value(verifier),
      verifierNonce: Value(verifierNonce),
      createdAt: Value(createdAt),
    );
  }

  factory VaultMetadataData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultMetadataData(
      id: serializer.fromJson<int>(json['id']),
      formatVersion: serializer.fromJson<int>(json['formatVersion']),
      salt: serializer.fromJson<String>(json['salt']),
      wrappedDataKey: serializer.fromJson<String>(json['wrappedDataKey']),
      wrappedDataKeyNonce: serializer.fromJson<String>(
        json['wrappedDataKeyNonce'],
      ),
      verifier: serializer.fromJson<String>(json['verifier']),
      verifierNonce: serializer.fromJson<String>(json['verifierNonce']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'formatVersion': serializer.toJson<int>(formatVersion),
      'salt': serializer.toJson<String>(salt),
      'wrappedDataKey': serializer.toJson<String>(wrappedDataKey),
      'wrappedDataKeyNonce': serializer.toJson<String>(wrappedDataKeyNonce),
      'verifier': serializer.toJson<String>(verifier),
      'verifierNonce': serializer.toJson<String>(verifierNonce),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  VaultMetadataData copyWith({
    int? id,
    int? formatVersion,
    String? salt,
    String? wrappedDataKey,
    String? wrappedDataKeyNonce,
    String? verifier,
    String? verifierNonce,
    DateTime? createdAt,
  }) => VaultMetadataData(
    id: id ?? this.id,
    formatVersion: formatVersion ?? this.formatVersion,
    salt: salt ?? this.salt,
    wrappedDataKey: wrappedDataKey ?? this.wrappedDataKey,
    wrappedDataKeyNonce: wrappedDataKeyNonce ?? this.wrappedDataKeyNonce,
    verifier: verifier ?? this.verifier,
    verifierNonce: verifierNonce ?? this.verifierNonce,
    createdAt: createdAt ?? this.createdAt,
  );
  VaultMetadataData copyWithCompanion(VaultMetadataCompanion data) {
    return VaultMetadataData(
      id: data.id.present ? data.id.value : this.id,
      formatVersion: data.formatVersion.present
          ? data.formatVersion.value
          : this.formatVersion,
      salt: data.salt.present ? data.salt.value : this.salt,
      wrappedDataKey: data.wrappedDataKey.present
          ? data.wrappedDataKey.value
          : this.wrappedDataKey,
      wrappedDataKeyNonce: data.wrappedDataKeyNonce.present
          ? data.wrappedDataKeyNonce.value
          : this.wrappedDataKeyNonce,
      verifier: data.verifier.present ? data.verifier.value : this.verifier,
      verifierNonce: data.verifierNonce.present
          ? data.verifierNonce.value
          : this.verifierNonce,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultMetadataData(')
          ..write('id: $id, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('salt: $salt, ')
          ..write('wrappedDataKey: $wrappedDataKey, ')
          ..write('wrappedDataKeyNonce: $wrappedDataKeyNonce, ')
          ..write('verifier: $verifier, ')
          ..write('verifierNonce: $verifierNonce, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    formatVersion,
    salt,
    wrappedDataKey,
    wrappedDataKeyNonce,
    verifier,
    verifierNonce,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultMetadataData &&
          other.id == this.id &&
          other.formatVersion == this.formatVersion &&
          other.salt == this.salt &&
          other.wrappedDataKey == this.wrappedDataKey &&
          other.wrappedDataKeyNonce == this.wrappedDataKeyNonce &&
          other.verifier == this.verifier &&
          other.verifierNonce == this.verifierNonce &&
          other.createdAt == this.createdAt);
}

class VaultMetadataCompanion extends UpdateCompanion<VaultMetadataData> {
  final Value<int> id;
  final Value<int> formatVersion;
  final Value<String> salt;
  final Value<String> wrappedDataKey;
  final Value<String> wrappedDataKeyNonce;
  final Value<String> verifier;
  final Value<String> verifierNonce;
  final Value<DateTime> createdAt;
  const VaultMetadataCompanion({
    this.id = const Value.absent(),
    this.formatVersion = const Value.absent(),
    this.salt = const Value.absent(),
    this.wrappedDataKey = const Value.absent(),
    this.wrappedDataKeyNonce = const Value.absent(),
    this.verifier = const Value.absent(),
    this.verifierNonce = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  VaultMetadataCompanion.insert({
    this.id = const Value.absent(),
    required int formatVersion,
    required String salt,
    required String wrappedDataKey,
    required String wrappedDataKeyNonce,
    required String verifier,
    required String verifierNonce,
    required DateTime createdAt,
  }) : formatVersion = Value(formatVersion),
       salt = Value(salt),
       wrappedDataKey = Value(wrappedDataKey),
       wrappedDataKeyNonce = Value(wrappedDataKeyNonce),
       verifier = Value(verifier),
       verifierNonce = Value(verifierNonce),
       createdAt = Value(createdAt);
  static Insertable<VaultMetadataData> custom({
    Expression<int>? id,
    Expression<int>? formatVersion,
    Expression<String>? salt,
    Expression<String>? wrappedDataKey,
    Expression<String>? wrappedDataKeyNonce,
    Expression<String>? verifier,
    Expression<String>? verifierNonce,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (formatVersion != null) 'format_version': formatVersion,
      if (salt != null) 'salt': salt,
      if (wrappedDataKey != null) 'wrapped_data_key': wrappedDataKey,
      if (wrappedDataKeyNonce != null)
        'wrapped_data_key_nonce': wrappedDataKeyNonce,
      if (verifier != null) 'verifier': verifier,
      if (verifierNonce != null) 'verifier_nonce': verifierNonce,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  VaultMetadataCompanion copyWith({
    Value<int>? id,
    Value<int>? formatVersion,
    Value<String>? salt,
    Value<String>? wrappedDataKey,
    Value<String>? wrappedDataKeyNonce,
    Value<String>? verifier,
    Value<String>? verifierNonce,
    Value<DateTime>? createdAt,
  }) {
    return VaultMetadataCompanion(
      id: id ?? this.id,
      formatVersion: formatVersion ?? this.formatVersion,
      salt: salt ?? this.salt,
      wrappedDataKey: wrappedDataKey ?? this.wrappedDataKey,
      wrappedDataKeyNonce: wrappedDataKeyNonce ?? this.wrappedDataKeyNonce,
      verifier: verifier ?? this.verifier,
      verifierNonce: verifierNonce ?? this.verifierNonce,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (formatVersion.present) {
      map['format_version'] = Variable<int>(formatVersion.value);
    }
    if (salt.present) {
      map['salt'] = Variable<String>(salt.value);
    }
    if (wrappedDataKey.present) {
      map['wrapped_data_key'] = Variable<String>(wrappedDataKey.value);
    }
    if (wrappedDataKeyNonce.present) {
      map['wrapped_data_key_nonce'] = Variable<String>(
        wrappedDataKeyNonce.value,
      );
    }
    if (verifier.present) {
      map['verifier'] = Variable<String>(verifier.value);
    }
    if (verifierNonce.present) {
      map['verifier_nonce'] = Variable<String>(verifierNonce.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultMetadataCompanion(')
          ..write('id: $id, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('salt: $salt, ')
          ..write('wrappedDataKey: $wrappedDataKey, ')
          ..write('wrappedDataKeyNonce: $wrappedDataKeyNonce, ')
          ..write('verifier: $verifier, ')
          ..write('verifierNonce: $verifierNonce, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ServersTable servers = $ServersTable(this);
  late final $VaultMetadataTable vaultMetadata = $VaultMetadataTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [servers, vaultMetadata];
}

typedef $$ServersTableCreateCompanionBuilder =
    ServersCompanion Function({
      Value<int> id,
      required String name,
      required String host,
      Value<int> port,
      required String username,
      Value<DateTime?> lastConnectedAt,
      Value<String?> syncId,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String?> credentialType,
      Value<String?> encryptedCredential,
      Value<String?> credentialNonce,
      Value<String?> hostKeyAlgorithm,
      Value<String?> hostKeyFingerprint,
      Value<bool> collectStats,
      Value<bool> collectSystemInfo,
    });
typedef $$ServersTableUpdateCompanionBuilder =
    ServersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> host,
      Value<int> port,
      Value<String> username,
      Value<DateTime?> lastConnectedAt,
      Value<String?> syncId,
      Value<DateTime?> createdAt,
      Value<DateTime?> updatedAt,
      Value<DateTime?> deletedAt,
      Value<String?> credentialType,
      Value<String?> encryptedCredential,
      Value<String?> credentialNonce,
      Value<String?> hostKeyAlgorithm,
      Value<String?> hostKeyFingerprint,
      Value<bool> collectStats,
      Value<bool> collectSystemInfo,
    });

class $$ServersTableFilterComposer
    extends Composer<_$AppDatabase, $ServersTable> {
  $$ServersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get credentialType => $composableBuilder(
    column: $table.credentialType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptedCredential => $composableBuilder(
    column: $table.encryptedCredential,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get credentialNonce => $composableBuilder(
    column: $table.credentialNonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hostKeyAlgorithm => $composableBuilder(
    column: $table.hostKeyAlgorithm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hostKeyFingerprint => $composableBuilder(
    column: $table.hostKeyFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get collectStats => $composableBuilder(
    column: $table.collectStats,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get collectSystemInfo => $composableBuilder(
    column: $table.collectSystemInfo,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ServersTableOrderingComposer
    extends Composer<_$AppDatabase, $ServersTable> {
  $$ServersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get credentialType => $composableBuilder(
    column: $table.credentialType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptedCredential => $composableBuilder(
    column: $table.encryptedCredential,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get credentialNonce => $composableBuilder(
    column: $table.credentialNonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hostKeyAlgorithm => $composableBuilder(
    column: $table.hostKeyAlgorithm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hostKeyFingerprint => $composableBuilder(
    column: $table.hostKeyFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get collectStats => $composableBuilder(
    column: $table.collectStats,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get collectSystemInfo => $composableBuilder(
    column: $table.collectSystemInfo,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ServersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ServersTable> {
  $$ServersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<int> get port =>
      $composableBuilder(column: $table.port, builder: (column) => column);

  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<DateTime> get lastConnectedAt => $composableBuilder(
    column: $table.lastConnectedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get credentialType => $composableBuilder(
    column: $table.credentialType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get encryptedCredential => $composableBuilder(
    column: $table.encryptedCredential,
    builder: (column) => column,
  );

  GeneratedColumn<String> get credentialNonce => $composableBuilder(
    column: $table.credentialNonce,
    builder: (column) => column,
  );

  GeneratedColumn<String> get hostKeyAlgorithm => $composableBuilder(
    column: $table.hostKeyAlgorithm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get hostKeyFingerprint => $composableBuilder(
    column: $table.hostKeyFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get collectStats => $composableBuilder(
    column: $table.collectStats,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get collectSystemInfo => $composableBuilder(
    column: $table.collectSystemInfo,
    builder: (column) => column,
  );
}

class $$ServersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ServersTable,
          Server,
          $$ServersTableFilterComposer,
          $$ServersTableOrderingComposer,
          $$ServersTableAnnotationComposer,
          $$ServersTableCreateCompanionBuilder,
          $$ServersTableUpdateCompanionBuilder,
          (Server, BaseReferences<_$AppDatabase, $ServersTable, Server>),
          Server,
          PrefetchHooks Function()
        > {
  $$ServersTableTableManager(_$AppDatabase db, $ServersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ServersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ServersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ServersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> host = const Value.absent(),
                Value<int> port = const Value.absent(),
                Value<String> username = const Value.absent(),
                Value<DateTime?> lastConnectedAt = const Value.absent(),
                Value<String?> syncId = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> credentialType = const Value.absent(),
                Value<String?> encryptedCredential = const Value.absent(),
                Value<String?> credentialNonce = const Value.absent(),
                Value<String?> hostKeyAlgorithm = const Value.absent(),
                Value<String?> hostKeyFingerprint = const Value.absent(),
                Value<bool> collectStats = const Value.absent(),
                Value<bool> collectSystemInfo = const Value.absent(),
              }) => ServersCompanion(
                id: id,
                name: name,
                host: host,
                port: port,
                username: username,
                lastConnectedAt: lastConnectedAt,
                syncId: syncId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                credentialType: credentialType,
                encryptedCredential: encryptedCredential,
                credentialNonce: credentialNonce,
                hostKeyAlgorithm: hostKeyAlgorithm,
                hostKeyFingerprint: hostKeyFingerprint,
                collectStats: collectStats,
                collectSystemInfo: collectSystemInfo,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String host,
                Value<int> port = const Value.absent(),
                required String username,
                Value<DateTime?> lastConnectedAt = const Value.absent(),
                Value<String?> syncId = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime?> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> credentialType = const Value.absent(),
                Value<String?> encryptedCredential = const Value.absent(),
                Value<String?> credentialNonce = const Value.absent(),
                Value<String?> hostKeyAlgorithm = const Value.absent(),
                Value<String?> hostKeyFingerprint = const Value.absent(),
                Value<bool> collectStats = const Value.absent(),
                Value<bool> collectSystemInfo = const Value.absent(),
              }) => ServersCompanion.insert(
                id: id,
                name: name,
                host: host,
                port: port,
                username: username,
                lastConnectedAt: lastConnectedAt,
                syncId: syncId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                credentialType: credentialType,
                encryptedCredential: encryptedCredential,
                credentialNonce: credentialNonce,
                hostKeyAlgorithm: hostKeyAlgorithm,
                hostKeyFingerprint: hostKeyFingerprint,
                collectStats: collectStats,
                collectSystemInfo: collectSystemInfo,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ServersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ServersTable,
      Server,
      $$ServersTableFilterComposer,
      $$ServersTableOrderingComposer,
      $$ServersTableAnnotationComposer,
      $$ServersTableCreateCompanionBuilder,
      $$ServersTableUpdateCompanionBuilder,
      (Server, BaseReferences<_$AppDatabase, $ServersTable, Server>),
      Server,
      PrefetchHooks Function()
    >;
typedef $$VaultMetadataTableCreateCompanionBuilder =
    VaultMetadataCompanion Function({
      Value<int> id,
      required int formatVersion,
      required String salt,
      required String wrappedDataKey,
      required String wrappedDataKeyNonce,
      required String verifier,
      required String verifierNonce,
      required DateTime createdAt,
    });
typedef $$VaultMetadataTableUpdateCompanionBuilder =
    VaultMetadataCompanion Function({
      Value<int> id,
      Value<int> formatVersion,
      Value<String> salt,
      Value<String> wrappedDataKey,
      Value<String> wrappedDataKeyNonce,
      Value<String> verifier,
      Value<String> verifierNonce,
      Value<DateTime> createdAt,
    });

class $$VaultMetadataTableFilterComposer
    extends Composer<_$AppDatabase, $VaultMetadataTable> {
  $$VaultMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get salt => $composableBuilder(
    column: $table.salt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wrappedDataKey => $composableBuilder(
    column: $table.wrappedDataKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wrappedDataKeyNonce => $composableBuilder(
    column: $table.wrappedDataKeyNonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verifier => $composableBuilder(
    column: $table.verifier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verifierNonce => $composableBuilder(
    column: $table.verifierNonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VaultMetadataTableOrderingComposer
    extends Composer<_$AppDatabase, $VaultMetadataTable> {
  $$VaultMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get salt => $composableBuilder(
    column: $table.salt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wrappedDataKey => $composableBuilder(
    column: $table.wrappedDataKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wrappedDataKeyNonce => $composableBuilder(
    column: $table.wrappedDataKeyNonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verifier => $composableBuilder(
    column: $table.verifier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verifierNonce => $composableBuilder(
    column: $table.verifierNonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VaultMetadataTableAnnotationComposer
    extends Composer<_$AppDatabase, $VaultMetadataTable> {
  $$VaultMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get salt =>
      $composableBuilder(column: $table.salt, builder: (column) => column);

  GeneratedColumn<String> get wrappedDataKey => $composableBuilder(
    column: $table.wrappedDataKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get wrappedDataKeyNonce => $composableBuilder(
    column: $table.wrappedDataKeyNonce,
    builder: (column) => column,
  );

  GeneratedColumn<String> get verifier =>
      $composableBuilder(column: $table.verifier, builder: (column) => column);

  GeneratedColumn<String> get verifierNonce => $composableBuilder(
    column: $table.verifierNonce,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$VaultMetadataTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VaultMetadataTable,
          VaultMetadataData,
          $$VaultMetadataTableFilterComposer,
          $$VaultMetadataTableOrderingComposer,
          $$VaultMetadataTableAnnotationComposer,
          $$VaultMetadataTableCreateCompanionBuilder,
          $$VaultMetadataTableUpdateCompanionBuilder,
          (
            VaultMetadataData,
            BaseReferences<
              _$AppDatabase,
              $VaultMetadataTable,
              VaultMetadataData
            >,
          ),
          VaultMetadataData,
          PrefetchHooks Function()
        > {
  $$VaultMetadataTableTableManager(_$AppDatabase db, $VaultMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VaultMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VaultMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VaultMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> formatVersion = const Value.absent(),
                Value<String> salt = const Value.absent(),
                Value<String> wrappedDataKey = const Value.absent(),
                Value<String> wrappedDataKeyNonce = const Value.absent(),
                Value<String> verifier = const Value.absent(),
                Value<String> verifierNonce = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => VaultMetadataCompanion(
                id: id,
                formatVersion: formatVersion,
                salt: salt,
                wrappedDataKey: wrappedDataKey,
                wrappedDataKeyNonce: wrappedDataKeyNonce,
                verifier: verifier,
                verifierNonce: verifierNonce,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int formatVersion,
                required String salt,
                required String wrappedDataKey,
                required String wrappedDataKeyNonce,
                required String verifier,
                required String verifierNonce,
                required DateTime createdAt,
              }) => VaultMetadataCompanion.insert(
                id: id,
                formatVersion: formatVersion,
                salt: salt,
                wrappedDataKey: wrappedDataKey,
                wrappedDataKeyNonce: wrappedDataKeyNonce,
                verifier: verifier,
                verifierNonce: verifierNonce,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VaultMetadataTable,
      VaultMetadataData,
      $$VaultMetadataTableFilterComposer,
      $$VaultMetadataTableOrderingComposer,
      $$VaultMetadataTableAnnotationComposer,
      $$VaultMetadataTableCreateCompanionBuilder,
      $$VaultMetadataTableUpdateCompanionBuilder,
      (
        VaultMetadataData,
        BaseReferences<_$AppDatabase, $VaultMetadataTable, VaultMetadataData>,
      ),
      VaultMetadataData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ServersTableTableManager get servers =>
      $$ServersTableTableManager(_db, _db.servers);
  $$VaultMetadataTableTableManager get vaultMetadata =>
      $$VaultMetadataTableTableManager(_db, _db.vaultMetadata);
}
