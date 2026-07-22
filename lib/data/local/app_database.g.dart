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

class $ComposeProjectLinksTable extends ComposeProjectLinks
    with TableInfo<$ComposeProjectLinksTable, ComposeProjectLink> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ComposeProjectLinksTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  static const VerificationMeta _directoryMeta = const VerificationMeta(
    'directory',
  );
  @override
  late final GeneratedColumn<String> directory = GeneratedColumn<String>(
    'directory',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runtimeMeta = const VerificationMeta(
    'runtime',
  );
  @override
  late final GeneratedColumn<String> runtime = GeneratedColumn<String>(
    'runtime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _linkedAtMeta = const VerificationMeta(
    'linkedAt',
  );
  @override
  late final GeneratedColumn<DateTime> linkedAt = GeneratedColumn<DateTime>(
    'linked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    name,
    directory,
    runtime,
    scope,
    linkedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'compose_project_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<ComposeProjectLink> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('directory')) {
      context.handle(
        _directoryMeta,
        directory.isAcceptableOrUnknown(data['directory']!, _directoryMeta),
      );
    } else if (isInserting) {
      context.missing(_directoryMeta);
    }
    if (data.containsKey('runtime')) {
      context.handle(
        _runtimeMeta,
        runtime.isAcceptableOrUnknown(data['runtime']!, _runtimeMeta),
      );
    } else if (isInserting) {
      context.missing(_runtimeMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('linked_at')) {
      context.handle(
        _linkedAtMeta,
        linkedAt.isAcceptableOrUnknown(data['linked_at']!, _linkedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_linkedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ComposeProjectLink map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ComposeProjectLink(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      directory: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}directory'],
      )!,
      runtime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}runtime'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      linkedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}linked_at'],
      )!,
    );
  }

  @override
  $ComposeProjectLinksTable createAlias(String alias) {
    return $ComposeProjectLinksTable(attachedDatabase, alias);
  }
}

class ComposeProjectLink extends DataClass
    implements Insertable<ComposeProjectLink> {
  final int id;
  final int serverId;
  final String name;
  final String directory;
  final String runtime;
  final String scope;
  final DateTime linkedAt;
  const ComposeProjectLink({
    required this.id,
    required this.serverId,
    required this.name,
    required this.directory,
    required this.runtime,
    required this.scope,
    required this.linkedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['server_id'] = Variable<int>(serverId);
    map['name'] = Variable<String>(name);
    map['directory'] = Variable<String>(directory);
    map['runtime'] = Variable<String>(runtime);
    map['scope'] = Variable<String>(scope);
    map['linked_at'] = Variable<DateTime>(linkedAt);
    return map;
  }

  ComposeProjectLinksCompanion toCompanion(bool nullToAbsent) {
    return ComposeProjectLinksCompanion(
      id: Value(id),
      serverId: Value(serverId),
      name: Value(name),
      directory: Value(directory),
      runtime: Value(runtime),
      scope: Value(scope),
      linkedAt: Value(linkedAt),
    );
  }

  factory ComposeProjectLink.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ComposeProjectLink(
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<int>(json['serverId']),
      name: serializer.fromJson<String>(json['name']),
      directory: serializer.fromJson<String>(json['directory']),
      runtime: serializer.fromJson<String>(json['runtime']),
      scope: serializer.fromJson<String>(json['scope']),
      linkedAt: serializer.fromJson<DateTime>(json['linkedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<int>(serverId),
      'name': serializer.toJson<String>(name),
      'directory': serializer.toJson<String>(directory),
      'runtime': serializer.toJson<String>(runtime),
      'scope': serializer.toJson<String>(scope),
      'linkedAt': serializer.toJson<DateTime>(linkedAt),
    };
  }

  ComposeProjectLink copyWith({
    int? id,
    int? serverId,
    String? name,
    String? directory,
    String? runtime,
    String? scope,
    DateTime? linkedAt,
  }) => ComposeProjectLink(
    id: id ?? this.id,
    serverId: serverId ?? this.serverId,
    name: name ?? this.name,
    directory: directory ?? this.directory,
    runtime: runtime ?? this.runtime,
    scope: scope ?? this.scope,
    linkedAt: linkedAt ?? this.linkedAt,
  );
  ComposeProjectLink copyWithCompanion(ComposeProjectLinksCompanion data) {
    return ComposeProjectLink(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      name: data.name.present ? data.name.value : this.name,
      directory: data.directory.present ? data.directory.value : this.directory,
      runtime: data.runtime.present ? data.runtime.value : this.runtime,
      scope: data.scope.present ? data.scope.value : this.scope,
      linkedAt: data.linkedAt.present ? data.linkedAt.value : this.linkedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ComposeProjectLink(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('name: $name, ')
          ..write('directory: $directory, ')
          ..write('runtime: $runtime, ')
          ..write('scope: $scope, ')
          ..write('linkedAt: $linkedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, serverId, name, directory, runtime, scope, linkedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ComposeProjectLink &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.name == this.name &&
          other.directory == this.directory &&
          other.runtime == this.runtime &&
          other.scope == this.scope &&
          other.linkedAt == this.linkedAt);
}

class ComposeProjectLinksCompanion extends UpdateCompanion<ComposeProjectLink> {
  final Value<int> id;
  final Value<int> serverId;
  final Value<String> name;
  final Value<String> directory;
  final Value<String> runtime;
  final Value<String> scope;
  final Value<DateTime> linkedAt;
  const ComposeProjectLinksCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.name = const Value.absent(),
    this.directory = const Value.absent(),
    this.runtime = const Value.absent(),
    this.scope = const Value.absent(),
    this.linkedAt = const Value.absent(),
  });
  ComposeProjectLinksCompanion.insert({
    this.id = const Value.absent(),
    required int serverId,
    required String name,
    required String directory,
    required String runtime,
    required String scope,
    required DateTime linkedAt,
  }) : serverId = Value(serverId),
       name = Value(name),
       directory = Value(directory),
       runtime = Value(runtime),
       scope = Value(scope),
       linkedAt = Value(linkedAt);
  static Insertable<ComposeProjectLink> custom({
    Expression<int>? id,
    Expression<int>? serverId,
    Expression<String>? name,
    Expression<String>? directory,
    Expression<String>? runtime,
    Expression<String>? scope,
    Expression<DateTime>? linkedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (name != null) 'name': name,
      if (directory != null) 'directory': directory,
      if (runtime != null) 'runtime': runtime,
      if (scope != null) 'scope': scope,
      if (linkedAt != null) 'linked_at': linkedAt,
    });
  }

  ComposeProjectLinksCompanion copyWith({
    Value<int>? id,
    Value<int>? serverId,
    Value<String>? name,
    Value<String>? directory,
    Value<String>? runtime,
    Value<String>? scope,
    Value<DateTime>? linkedAt,
  }) {
    return ComposeProjectLinksCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      name: name ?? this.name,
      directory: directory ?? this.directory,
      runtime: runtime ?? this.runtime,
      scope: scope ?? this.scope,
      linkedAt: linkedAt ?? this.linkedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (directory.present) {
      map['directory'] = Variable<String>(directory.value);
    }
    if (runtime.present) {
      map['runtime'] = Variable<String>(runtime.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (linkedAt.present) {
      map['linked_at'] = Variable<DateTime>(linkedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ComposeProjectLinksCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('name: $name, ')
          ..write('directory: $directory, ')
          ..write('runtime: $runtime, ')
          ..write('scope: $scope, ')
          ..write('linkedAt: $linkedAt')
          ..write(')'))
        .toString();
  }
}

class $ContainerCacheEntriesTable extends ContainerCacheEntries
    with TableInfo<$ContainerCacheEntriesTable, ContainerCacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContainerCacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _runtimeMeta = const VerificationMeta(
    'runtime',
  );
  @override
  late final GeneratedColumn<String> runtime = GeneratedColumn<String>(
    'runtime',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _containerIdMeta = const VerificationMeta(
    'containerId',
  );
  @override
  late final GeneratedColumn<String> containerId = GeneratedColumn<String>(
    'container_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _imageMeta = const VerificationMeta('image');
  @override
  late final GeneratedColumn<String> image = GeneratedColumn<String>(
    'image',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _composeProjectMeta = const VerificationMeta(
    'composeProject',
  );
  @override
  late final GeneratedColumn<String> composeProject = GeneratedColumn<String>(
    'compose_project',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    serverId,
    runtime,
    scope,
    containerId,
    name,
    image,
    state,
    status,
    composeProject,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'container_cache_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ContainerCacheEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('runtime')) {
      context.handle(
        _runtimeMeta,
        runtime.isAcceptableOrUnknown(data['runtime']!, _runtimeMeta),
      );
    } else if (isInserting) {
      context.missing(_runtimeMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('container_id')) {
      context.handle(
        _containerIdMeta,
        containerId.isAcceptableOrUnknown(
          data['container_id']!,
          _containerIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_containerIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('image')) {
      context.handle(
        _imageMeta,
        image.isAcceptableOrUnknown(data['image']!, _imageMeta),
      );
    } else if (isInserting) {
      context.missing(_imageMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('compose_project')) {
      context.handle(
        _composeProjectMeta,
        composeProject.isAcceptableOrUnknown(
          data['compose_project']!,
          _composeProjectMeta,
        ),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    serverId,
    runtime,
    scope,
    containerId,
  };
  @override
  ContainerCacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContainerCacheEntry(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      )!,
      runtime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}runtime'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      containerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}container_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      image: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      composeProject: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}compose_project'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $ContainerCacheEntriesTable createAlias(String alias) {
    return $ContainerCacheEntriesTable(attachedDatabase, alias);
  }
}

class ContainerCacheEntry extends DataClass
    implements Insertable<ContainerCacheEntry> {
  final int serverId;
  final String runtime;
  final String scope;
  final String containerId;
  final String name;
  final String image;
  final String state;
  final String status;
  final String? composeProject;
  final DateTime cachedAt;
  const ContainerCacheEntry({
    required this.serverId,
    required this.runtime,
    required this.scope,
    required this.containerId,
    required this.name,
    required this.image,
    required this.state,
    required this.status,
    this.composeProject,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<int>(serverId);
    map['runtime'] = Variable<String>(runtime);
    map['scope'] = Variable<String>(scope);
    map['container_id'] = Variable<String>(containerId);
    map['name'] = Variable<String>(name);
    map['image'] = Variable<String>(image);
    map['state'] = Variable<String>(state);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || composeProject != null) {
      map['compose_project'] = Variable<String>(composeProject);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  ContainerCacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return ContainerCacheEntriesCompanion(
      serverId: Value(serverId),
      runtime: Value(runtime),
      scope: Value(scope),
      containerId: Value(containerId),
      name: Value(name),
      image: Value(image),
      state: Value(state),
      status: Value(status),
      composeProject: composeProject == null && nullToAbsent
          ? const Value.absent()
          : Value(composeProject),
      cachedAt: Value(cachedAt),
    );
  }

  factory ContainerCacheEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContainerCacheEntry(
      serverId: serializer.fromJson<int>(json['serverId']),
      runtime: serializer.fromJson<String>(json['runtime']),
      scope: serializer.fromJson<String>(json['scope']),
      containerId: serializer.fromJson<String>(json['containerId']),
      name: serializer.fromJson<String>(json['name']),
      image: serializer.fromJson<String>(json['image']),
      state: serializer.fromJson<String>(json['state']),
      status: serializer.fromJson<String>(json['status']),
      composeProject: serializer.fromJson<String?>(json['composeProject']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<int>(serverId),
      'runtime': serializer.toJson<String>(runtime),
      'scope': serializer.toJson<String>(scope),
      'containerId': serializer.toJson<String>(containerId),
      'name': serializer.toJson<String>(name),
      'image': serializer.toJson<String>(image),
      'state': serializer.toJson<String>(state),
      'status': serializer.toJson<String>(status),
      'composeProject': serializer.toJson<String?>(composeProject),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  ContainerCacheEntry copyWith({
    int? serverId,
    String? runtime,
    String? scope,
    String? containerId,
    String? name,
    String? image,
    String? state,
    String? status,
    Value<String?> composeProject = const Value.absent(),
    DateTime? cachedAt,
  }) => ContainerCacheEntry(
    serverId: serverId ?? this.serverId,
    runtime: runtime ?? this.runtime,
    scope: scope ?? this.scope,
    containerId: containerId ?? this.containerId,
    name: name ?? this.name,
    image: image ?? this.image,
    state: state ?? this.state,
    status: status ?? this.status,
    composeProject: composeProject.present
        ? composeProject.value
        : this.composeProject,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  ContainerCacheEntry copyWithCompanion(ContainerCacheEntriesCompanion data) {
    return ContainerCacheEntry(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      runtime: data.runtime.present ? data.runtime.value : this.runtime,
      scope: data.scope.present ? data.scope.value : this.scope,
      containerId: data.containerId.present
          ? data.containerId.value
          : this.containerId,
      name: data.name.present ? data.name.value : this.name,
      image: data.image.present ? data.image.value : this.image,
      state: data.state.present ? data.state.value : this.state,
      status: data.status.present ? data.status.value : this.status,
      composeProject: data.composeProject.present
          ? data.composeProject.value
          : this.composeProject,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContainerCacheEntry(')
          ..write('serverId: $serverId, ')
          ..write('runtime: $runtime, ')
          ..write('scope: $scope, ')
          ..write('containerId: $containerId, ')
          ..write('name: $name, ')
          ..write('image: $image, ')
          ..write('state: $state, ')
          ..write('status: $status, ')
          ..write('composeProject: $composeProject, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    serverId,
    runtime,
    scope,
    containerId,
    name,
    image,
    state,
    status,
    composeProject,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContainerCacheEntry &&
          other.serverId == this.serverId &&
          other.runtime == this.runtime &&
          other.scope == this.scope &&
          other.containerId == this.containerId &&
          other.name == this.name &&
          other.image == this.image &&
          other.state == this.state &&
          other.status == this.status &&
          other.composeProject == this.composeProject &&
          other.cachedAt == this.cachedAt);
}

class ContainerCacheEntriesCompanion
    extends UpdateCompanion<ContainerCacheEntry> {
  final Value<int> serverId;
  final Value<String> runtime;
  final Value<String> scope;
  final Value<String> containerId;
  final Value<String> name;
  final Value<String> image;
  final Value<String> state;
  final Value<String> status;
  final Value<String?> composeProject;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const ContainerCacheEntriesCompanion({
    this.serverId = const Value.absent(),
    this.runtime = const Value.absent(),
    this.scope = const Value.absent(),
    this.containerId = const Value.absent(),
    this.name = const Value.absent(),
    this.image = const Value.absent(),
    this.state = const Value.absent(),
    this.status = const Value.absent(),
    this.composeProject = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContainerCacheEntriesCompanion.insert({
    required int serverId,
    required String runtime,
    required String scope,
    required String containerId,
    required String name,
    required String image,
    required String state,
    required String status,
    this.composeProject = const Value.absent(),
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       runtime = Value(runtime),
       scope = Value(scope),
       containerId = Value(containerId),
       name = Value(name),
       image = Value(image),
       state = Value(state),
       status = Value(status),
       cachedAt = Value(cachedAt);
  static Insertable<ContainerCacheEntry> custom({
    Expression<int>? serverId,
    Expression<String>? runtime,
    Expression<String>? scope,
    Expression<String>? containerId,
    Expression<String>? name,
    Expression<String>? image,
    Expression<String>? state,
    Expression<String>? status,
    Expression<String>? composeProject,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (runtime != null) 'runtime': runtime,
      if (scope != null) 'scope': scope,
      if (containerId != null) 'container_id': containerId,
      if (name != null) 'name': name,
      if (image != null) 'image': image,
      if (state != null) 'state': state,
      if (status != null) 'status': status,
      if (composeProject != null) 'compose_project': composeProject,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContainerCacheEntriesCompanion copyWith({
    Value<int>? serverId,
    Value<String>? runtime,
    Value<String>? scope,
    Value<String>? containerId,
    Value<String>? name,
    Value<String>? image,
    Value<String>? state,
    Value<String>? status,
    Value<String?>? composeProject,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return ContainerCacheEntriesCompanion(
      serverId: serverId ?? this.serverId,
      runtime: runtime ?? this.runtime,
      scope: scope ?? this.scope,
      containerId: containerId ?? this.containerId,
      name: name ?? this.name,
      image: image ?? this.image,
      state: state ?? this.state,
      status: status ?? this.status,
      composeProject: composeProject ?? this.composeProject,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (runtime.present) {
      map['runtime'] = Variable<String>(runtime.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (containerId.present) {
      map['container_id'] = Variable<String>(containerId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (image.present) {
      map['image'] = Variable<String>(image.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (composeProject.present) {
      map['compose_project'] = Variable<String>(composeProject.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContainerCacheEntriesCompanion(')
          ..write('serverId: $serverId, ')
          ..write('runtime: $runtime, ')
          ..write('scope: $scope, ')
          ..write('containerId: $containerId, ')
          ..write('name: $name, ')
          ..write('image: $image, ')
          ..write('state: $state, ')
          ..write('status: $status, ')
          ..write('composeProject: $composeProject, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeploymentProjectsTable extends DeploymentProjects
    with TableInfo<$DeploymentProjectsTable, DeploymentProject> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeploymentProjectsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
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
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deployment_projects';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeploymentProject> instance, {
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
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeploymentProject map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeploymentProject(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DeploymentProjectsTable createAlias(String alias) {
    return $DeploymentProjectsTable(attachedDatabase, alias);
  }
}

class DeploymentProject extends DataClass
    implements Insertable<DeploymentProject> {
  final int id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DeploymentProject({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DeploymentProjectsCompanion toCompanion(bool nullToAbsent) {
    return DeploymentProjectsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DeploymentProject.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeploymentProject(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DeploymentProject copyWith({
    int? id,
    String? name,
    Value<String?> description = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DeploymentProject(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DeploymentProject copyWithCompanion(DeploymentProjectsCompanion data) {
    return DeploymentProject(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeploymentProject(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, description, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeploymentProject &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DeploymentProjectsCompanion extends UpdateCompanion<DeploymentProject> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const DeploymentProjectsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DeploymentProjectsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DeploymentProject> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DeploymentProjectsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? description,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return DeploymentProjectsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeploymentProjectsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $DeploymentResourcesTable extends DeploymentResources
    with TableInfo<$DeploymentResourcesTable, DeploymentResource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeploymentResourcesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<int> projectId = GeneratedColumn<int>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _configurationMeta = const VerificationMeta(
    'configuration',
  );
  @override
  late final GeneratedColumn<String> configuration = GeneratedColumn<String>(
    'configuration',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    projectId,
    kind,
    name,
    serverId,
    configuration,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deployment_resources';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeploymentResource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('configuration')) {
      context.handle(
        _configurationMeta,
        configuration.isAcceptableOrUnknown(
          data['configuration']!,
          _configurationMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeploymentResource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeploymentResource(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      configuration: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}configuration'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DeploymentResourcesTable createAlias(String alias) {
    return $DeploymentResourcesTable(attachedDatabase, alias);
  }
}

class DeploymentResource extends DataClass
    implements Insertable<DeploymentResource> {
  final int id;
  final int projectId;
  final String kind;
  final String name;
  final int? serverId;
  final String configuration;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DeploymentResource({
    required this.id,
    required this.projectId,
    required this.kind,
    required this.name,
    this.serverId,
    required this.configuration,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['project_id'] = Variable<int>(projectId);
    map['kind'] = Variable<String>(kind);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['configuration'] = Variable<String>(configuration);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DeploymentResourcesCompanion toCompanion(bool nullToAbsent) {
    return DeploymentResourcesCompanion(
      id: Value(id),
      projectId: Value(projectId),
      kind: Value(kind),
      name: Value(name),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      configuration: Value(configuration),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DeploymentResource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeploymentResource(
      id: serializer.fromJson<int>(json['id']),
      projectId: serializer.fromJson<int>(json['projectId']),
      kind: serializer.fromJson<String>(json['kind']),
      name: serializer.fromJson<String>(json['name']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      configuration: serializer.fromJson<String>(json['configuration']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'projectId': serializer.toJson<int>(projectId),
      'kind': serializer.toJson<String>(kind),
      'name': serializer.toJson<String>(name),
      'serverId': serializer.toJson<int?>(serverId),
      'configuration': serializer.toJson<String>(configuration),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DeploymentResource copyWith({
    int? id,
    int? projectId,
    String? kind,
    String? name,
    Value<int?> serverId = const Value.absent(),
    String? configuration,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DeploymentResource(
    id: id ?? this.id,
    projectId: projectId ?? this.projectId,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    serverId: serverId.present ? serverId.value : this.serverId,
    configuration: configuration ?? this.configuration,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DeploymentResource copyWithCompanion(DeploymentResourcesCompanion data) {
    return DeploymentResource(
      id: data.id.present ? data.id.value : this.id,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      kind: data.kind.present ? data.kind.value : this.kind,
      name: data.name.present ? data.name.value : this.name,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      configuration: data.configuration.present
          ? data.configuration.value
          : this.configuration,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeploymentResource(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('serverId: $serverId, ')
          ..write('configuration: $configuration, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    projectId,
    kind,
    name,
    serverId,
    configuration,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeploymentResource &&
          other.id == this.id &&
          other.projectId == this.projectId &&
          other.kind == this.kind &&
          other.name == this.name &&
          other.serverId == this.serverId &&
          other.configuration == this.configuration &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DeploymentResourcesCompanion extends UpdateCompanion<DeploymentResource> {
  final Value<int> id;
  final Value<int> projectId;
  final Value<String> kind;
  final Value<String> name;
  final Value<int?> serverId;
  final Value<String> configuration;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const DeploymentResourcesCompanion({
    this.id = const Value.absent(),
    this.projectId = const Value.absent(),
    this.kind = const Value.absent(),
    this.name = const Value.absent(),
    this.serverId = const Value.absent(),
    this.configuration = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DeploymentResourcesCompanion.insert({
    this.id = const Value.absent(),
    required int projectId,
    required String kind,
    required String name,
    this.serverId = const Value.absent(),
    this.configuration = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : projectId = Value(projectId),
       kind = Value(kind),
       name = Value(name),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<DeploymentResource> custom({
    Expression<int>? id,
    Expression<int>? projectId,
    Expression<String>? kind,
    Expression<String>? name,
    Expression<int>? serverId,
    Expression<String>? configuration,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (projectId != null) 'project_id': projectId,
      if (kind != null) 'kind': kind,
      if (name != null) 'name': name,
      if (serverId != null) 'server_id': serverId,
      if (configuration != null) 'configuration': configuration,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DeploymentResourcesCompanion copyWith({
    Value<int>? id,
    Value<int>? projectId,
    Value<String>? kind,
    Value<String>? name,
    Value<int?>? serverId,
    Value<String>? configuration,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return DeploymentResourcesCompanion(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      kind: kind ?? this.kind,
      name: name ?? this.name,
      serverId: serverId ?? this.serverId,
      configuration: configuration ?? this.configuration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<int>(projectId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (configuration.present) {
      map['configuration'] = Variable<String>(configuration.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeploymentResourcesCompanion(')
          ..write('id: $id, ')
          ..write('projectId: $projectId, ')
          ..write('kind: $kind, ')
          ..write('name: $name, ')
          ..write('serverId: $serverId, ')
          ..write('configuration: $configuration, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ScriptSnippetsTable extends ScriptSnippets
    with TableInfo<$ScriptSnippetsTable, ScriptSnippet> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScriptSnippetsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _scriptMeta = const VerificationMeta('script');
  @override
  late final GeneratedColumn<String> script = GeneratedColumn<String>(
    'script',
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    script,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'script_snippets';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScriptSnippet> instance, {
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
    if (data.containsKey('script')) {
      context.handle(
        _scriptMeta,
        script.isAcceptableOrUnknown(data['script']!, _scriptMeta),
      );
    } else if (isInserting) {
      context.missing(_scriptMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScriptSnippet map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScriptSnippet(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      script: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}script'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ScriptSnippetsTable createAlias(String alias) {
    return $ScriptSnippetsTable(attachedDatabase, alias);
  }
}

class ScriptSnippet extends DataClass implements Insertable<ScriptSnippet> {
  final int id;
  final String name;
  final String script;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ScriptSnippet({
    required this.id,
    required this.name,
    required this.script,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['script'] = Variable<String>(script);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ScriptSnippetsCompanion toCompanion(bool nullToAbsent) {
    return ScriptSnippetsCompanion(
      id: Value(id),
      name: Value(name),
      script: Value(script),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ScriptSnippet.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScriptSnippet(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      script: serializer.fromJson<String>(json['script']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'script': serializer.toJson<String>(script),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ScriptSnippet copyWith({
    int? id,
    String? name,
    String? script,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ScriptSnippet(
    id: id ?? this.id,
    name: name ?? this.name,
    script: script ?? this.script,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ScriptSnippet copyWithCompanion(ScriptSnippetsCompanion data) {
    return ScriptSnippet(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      script: data.script.present ? data.script.value : this.script,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScriptSnippet(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('script: $script, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, script, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScriptSnippet &&
          other.id == this.id &&
          other.name == this.name &&
          other.script == this.script &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ScriptSnippetsCompanion extends UpdateCompanion<ScriptSnippet> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> script;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ScriptSnippetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.script = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ScriptSnippetsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String script,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : name = Value(name),
       script = Value(script),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ScriptSnippet> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? script,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (script != null) 'script': script,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ScriptSnippetsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? script,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return ScriptSnippetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      script: script ?? this.script,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (script.present) {
      map['script'] = Variable<String>(script.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScriptSnippetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('script: $script, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ServersTable servers = $ServersTable(this);
  late final $VaultMetadataTable vaultMetadata = $VaultMetadataTable(this);
  late final $ComposeProjectLinksTable composeProjectLinks =
      $ComposeProjectLinksTable(this);
  late final $ContainerCacheEntriesTable containerCacheEntries =
      $ContainerCacheEntriesTable(this);
  late final $DeploymentProjectsTable deploymentProjects =
      $DeploymentProjectsTable(this);
  late final $DeploymentResourcesTable deploymentResources =
      $DeploymentResourcesTable(this);
  late final $ScriptSnippetsTable scriptSnippets = $ScriptSnippetsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    servers,
    vaultMetadata,
    composeProjectLinks,
    containerCacheEntries,
    deploymentProjects,
    deploymentResources,
    scriptSnippets,
  ];
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
typedef $$ComposeProjectLinksTableCreateCompanionBuilder =
    ComposeProjectLinksCompanion Function({
      Value<int> id,
      required int serverId,
      required String name,
      required String directory,
      required String runtime,
      required String scope,
      required DateTime linkedAt,
    });
typedef $$ComposeProjectLinksTableUpdateCompanionBuilder =
    ComposeProjectLinksCompanion Function({
      Value<int> id,
      Value<int> serverId,
      Value<String> name,
      Value<String> directory,
      Value<String> runtime,
      Value<String> scope,
      Value<DateTime> linkedAt,
    });

class $$ComposeProjectLinksTableFilterComposer
    extends Composer<_$AppDatabase, $ComposeProjectLinksTable> {
  $$ComposeProjectLinksTableFilterComposer({
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

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get directory => $composableBuilder(
    column: $table.directory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runtime => $composableBuilder(
    column: $table.runtime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get linkedAt => $composableBuilder(
    column: $table.linkedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ComposeProjectLinksTableOrderingComposer
    extends Composer<_$AppDatabase, $ComposeProjectLinksTable> {
  $$ComposeProjectLinksTableOrderingComposer({
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

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get directory => $composableBuilder(
    column: $table.directory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runtime => $composableBuilder(
    column: $table.runtime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get linkedAt => $composableBuilder(
    column: $table.linkedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ComposeProjectLinksTableAnnotationComposer
    extends Composer<_$AppDatabase, $ComposeProjectLinksTable> {
  $$ComposeProjectLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get directory =>
      $composableBuilder(column: $table.directory, builder: (column) => column);

  GeneratedColumn<String> get runtime =>
      $composableBuilder(column: $table.runtime, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<DateTime> get linkedAt =>
      $composableBuilder(column: $table.linkedAt, builder: (column) => column);
}

class $$ComposeProjectLinksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ComposeProjectLinksTable,
          ComposeProjectLink,
          $$ComposeProjectLinksTableFilterComposer,
          $$ComposeProjectLinksTableOrderingComposer,
          $$ComposeProjectLinksTableAnnotationComposer,
          $$ComposeProjectLinksTableCreateCompanionBuilder,
          $$ComposeProjectLinksTableUpdateCompanionBuilder,
          (
            ComposeProjectLink,
            BaseReferences<
              _$AppDatabase,
              $ComposeProjectLinksTable,
              ComposeProjectLink
            >,
          ),
          ComposeProjectLink,
          PrefetchHooks Function()
        > {
  $$ComposeProjectLinksTableTableManager(
    _$AppDatabase db,
    $ComposeProjectLinksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ComposeProjectLinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ComposeProjectLinksTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ComposeProjectLinksTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> serverId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> directory = const Value.absent(),
                Value<String> runtime = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<DateTime> linkedAt = const Value.absent(),
              }) => ComposeProjectLinksCompanion(
                id: id,
                serverId: serverId,
                name: name,
                directory: directory,
                runtime: runtime,
                scope: scope,
                linkedAt: linkedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int serverId,
                required String name,
                required String directory,
                required String runtime,
                required String scope,
                required DateTime linkedAt,
              }) => ComposeProjectLinksCompanion.insert(
                id: id,
                serverId: serverId,
                name: name,
                directory: directory,
                runtime: runtime,
                scope: scope,
                linkedAt: linkedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ComposeProjectLinksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ComposeProjectLinksTable,
      ComposeProjectLink,
      $$ComposeProjectLinksTableFilterComposer,
      $$ComposeProjectLinksTableOrderingComposer,
      $$ComposeProjectLinksTableAnnotationComposer,
      $$ComposeProjectLinksTableCreateCompanionBuilder,
      $$ComposeProjectLinksTableUpdateCompanionBuilder,
      (
        ComposeProjectLink,
        BaseReferences<
          _$AppDatabase,
          $ComposeProjectLinksTable,
          ComposeProjectLink
        >,
      ),
      ComposeProjectLink,
      PrefetchHooks Function()
    >;
typedef $$ContainerCacheEntriesTableCreateCompanionBuilder =
    ContainerCacheEntriesCompanion Function({
      required int serverId,
      required String runtime,
      required String scope,
      required String containerId,
      required String name,
      required String image,
      required String state,
      required String status,
      Value<String?> composeProject,
      required DateTime cachedAt,
      Value<int> rowid,
    });
typedef $$ContainerCacheEntriesTableUpdateCompanionBuilder =
    ContainerCacheEntriesCompanion Function({
      Value<int> serverId,
      Value<String> runtime,
      Value<String> scope,
      Value<String> containerId,
      Value<String> name,
      Value<String> image,
      Value<String> state,
      Value<String> status,
      Value<String?> composeProject,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

class $$ContainerCacheEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ContainerCacheEntriesTable> {
  $$ContainerCacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runtime => $composableBuilder(
    column: $table.runtime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get containerId => $composableBuilder(
    column: $table.containerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get image => $composableBuilder(
    column: $table.image,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get composeProject => $composableBuilder(
    column: $table.composeProject,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ContainerCacheEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ContainerCacheEntriesTable> {
  $$ContainerCacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runtime => $composableBuilder(
    column: $table.runtime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get containerId => $composableBuilder(
    column: $table.containerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get image => $composableBuilder(
    column: $table.image,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get composeProject => $composableBuilder(
    column: $table.composeProject,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ContainerCacheEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContainerCacheEntriesTable> {
  $$ContainerCacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get runtime =>
      $composableBuilder(column: $table.runtime, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get containerId => $composableBuilder(
    column: $table.containerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get image =>
      $composableBuilder(column: $table.image, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get composeProject => $composableBuilder(
    column: $table.composeProject,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$ContainerCacheEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ContainerCacheEntriesTable,
          ContainerCacheEntry,
          $$ContainerCacheEntriesTableFilterComposer,
          $$ContainerCacheEntriesTableOrderingComposer,
          $$ContainerCacheEntriesTableAnnotationComposer,
          $$ContainerCacheEntriesTableCreateCompanionBuilder,
          $$ContainerCacheEntriesTableUpdateCompanionBuilder,
          (
            ContainerCacheEntry,
            BaseReferences<
              _$AppDatabase,
              $ContainerCacheEntriesTable,
              ContainerCacheEntry
            >,
          ),
          ContainerCacheEntry,
          PrefetchHooks Function()
        > {
  $$ContainerCacheEntriesTableTableManager(
    _$AppDatabase db,
    $ContainerCacheEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContainerCacheEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ContainerCacheEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ContainerCacheEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> serverId = const Value.absent(),
                Value<String> runtime = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> containerId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> image = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> composeProject = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ContainerCacheEntriesCompanion(
                serverId: serverId,
                runtime: runtime,
                scope: scope,
                containerId: containerId,
                name: name,
                image: image,
                state: state,
                status: status,
                composeProject: composeProject,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int serverId,
                required String runtime,
                required String scope,
                required String containerId,
                required String name,
                required String image,
                required String state,
                required String status,
                Value<String?> composeProject = const Value.absent(),
                required DateTime cachedAt,
                Value<int> rowid = const Value.absent(),
              }) => ContainerCacheEntriesCompanion.insert(
                serverId: serverId,
                runtime: runtime,
                scope: scope,
                containerId: containerId,
                name: name,
                image: image,
                state: state,
                status: status,
                composeProject: composeProject,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ContainerCacheEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ContainerCacheEntriesTable,
      ContainerCacheEntry,
      $$ContainerCacheEntriesTableFilterComposer,
      $$ContainerCacheEntriesTableOrderingComposer,
      $$ContainerCacheEntriesTableAnnotationComposer,
      $$ContainerCacheEntriesTableCreateCompanionBuilder,
      $$ContainerCacheEntriesTableUpdateCompanionBuilder,
      (
        ContainerCacheEntry,
        BaseReferences<
          _$AppDatabase,
          $ContainerCacheEntriesTable,
          ContainerCacheEntry
        >,
      ),
      ContainerCacheEntry,
      PrefetchHooks Function()
    >;
typedef $$DeploymentProjectsTableCreateCompanionBuilder =
    DeploymentProjectsCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> description,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$DeploymentProjectsTableUpdateCompanionBuilder =
    DeploymentProjectsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> description,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$DeploymentProjectsTableFilterComposer
    extends Composer<_$AppDatabase, $DeploymentProjectsTable> {
  $$DeploymentProjectsTableFilterComposer({
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

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
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
}

class $$DeploymentProjectsTableOrderingComposer
    extends Composer<_$AppDatabase, $DeploymentProjectsTable> {
  $$DeploymentProjectsTableOrderingComposer({
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

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
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
}

class $$DeploymentProjectsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeploymentProjectsTable> {
  $$DeploymentProjectsTableAnnotationComposer({
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

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DeploymentProjectsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeploymentProjectsTable,
          DeploymentProject,
          $$DeploymentProjectsTableFilterComposer,
          $$DeploymentProjectsTableOrderingComposer,
          $$DeploymentProjectsTableAnnotationComposer,
          $$DeploymentProjectsTableCreateCompanionBuilder,
          $$DeploymentProjectsTableUpdateCompanionBuilder,
          (
            DeploymentProject,
            BaseReferences<
              _$AppDatabase,
              $DeploymentProjectsTable,
              DeploymentProject
            >,
          ),
          DeploymentProject,
          PrefetchHooks Function()
        > {
  $$DeploymentProjectsTableTableManager(
    _$AppDatabase db,
    $DeploymentProjectsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeploymentProjectsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeploymentProjectsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeploymentProjectsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => DeploymentProjectsCompanion(
                id: id,
                name: name,
                description: description,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> description = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => DeploymentProjectsCompanion.insert(
                id: id,
                name: name,
                description: description,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeploymentProjectsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeploymentProjectsTable,
      DeploymentProject,
      $$DeploymentProjectsTableFilterComposer,
      $$DeploymentProjectsTableOrderingComposer,
      $$DeploymentProjectsTableAnnotationComposer,
      $$DeploymentProjectsTableCreateCompanionBuilder,
      $$DeploymentProjectsTableUpdateCompanionBuilder,
      (
        DeploymentProject,
        BaseReferences<
          _$AppDatabase,
          $DeploymentProjectsTable,
          DeploymentProject
        >,
      ),
      DeploymentProject,
      PrefetchHooks Function()
    >;
typedef $$DeploymentResourcesTableCreateCompanionBuilder =
    DeploymentResourcesCompanion Function({
      Value<int> id,
      required int projectId,
      required String kind,
      required String name,
      Value<int?> serverId,
      Value<String> configuration,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$DeploymentResourcesTableUpdateCompanionBuilder =
    DeploymentResourcesCompanion Function({
      Value<int> id,
      Value<int> projectId,
      Value<String> kind,
      Value<String> name,
      Value<int?> serverId,
      Value<String> configuration,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$DeploymentResourcesTableFilterComposer
    extends Composer<_$AppDatabase, $DeploymentResourcesTable> {
  $$DeploymentResourcesTableFilterComposer({
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

  ColumnFilters<int> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configuration => $composableBuilder(
    column: $table.configuration,
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
}

class $$DeploymentResourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $DeploymentResourcesTable> {
  $$DeploymentResourcesTableOrderingComposer({
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

  ColumnOrderings<int> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configuration => $composableBuilder(
    column: $table.configuration,
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
}

class $$DeploymentResourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeploymentResourcesTable> {
  $$DeploymentResourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get configuration => $composableBuilder(
    column: $table.configuration,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DeploymentResourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeploymentResourcesTable,
          DeploymentResource,
          $$DeploymentResourcesTableFilterComposer,
          $$DeploymentResourcesTableOrderingComposer,
          $$DeploymentResourcesTableAnnotationComposer,
          $$DeploymentResourcesTableCreateCompanionBuilder,
          $$DeploymentResourcesTableUpdateCompanionBuilder,
          (
            DeploymentResource,
            BaseReferences<
              _$AppDatabase,
              $DeploymentResourcesTable,
              DeploymentResource
            >,
          ),
          DeploymentResource,
          PrefetchHooks Function()
        > {
  $$DeploymentResourcesTableTableManager(
    _$AppDatabase db,
    $DeploymentResourcesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeploymentResourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeploymentResourcesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DeploymentResourcesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> projectId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> configuration = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => DeploymentResourcesCompanion(
                id: id,
                projectId: projectId,
                kind: kind,
                name: name,
                serverId: serverId,
                configuration: configuration,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int projectId,
                required String kind,
                required String name,
                Value<int?> serverId = const Value.absent(),
                Value<String> configuration = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => DeploymentResourcesCompanion.insert(
                id: id,
                projectId: projectId,
                kind: kind,
                name: name,
                serverId: serverId,
                configuration: configuration,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeploymentResourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeploymentResourcesTable,
      DeploymentResource,
      $$DeploymentResourcesTableFilterComposer,
      $$DeploymentResourcesTableOrderingComposer,
      $$DeploymentResourcesTableAnnotationComposer,
      $$DeploymentResourcesTableCreateCompanionBuilder,
      $$DeploymentResourcesTableUpdateCompanionBuilder,
      (
        DeploymentResource,
        BaseReferences<
          _$AppDatabase,
          $DeploymentResourcesTable,
          DeploymentResource
        >,
      ),
      DeploymentResource,
      PrefetchHooks Function()
    >;
typedef $$ScriptSnippetsTableCreateCompanionBuilder =
    ScriptSnippetsCompanion Function({
      Value<int> id,
      required String name,
      required String script,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$ScriptSnippetsTableUpdateCompanionBuilder =
    ScriptSnippetsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> script,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$ScriptSnippetsTableFilterComposer
    extends Composer<_$AppDatabase, $ScriptSnippetsTable> {
  $$ScriptSnippetsTableFilterComposer({
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

  ColumnFilters<String> get script => $composableBuilder(
    column: $table.script,
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
}

class $$ScriptSnippetsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScriptSnippetsTable> {
  $$ScriptSnippetsTableOrderingComposer({
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

  ColumnOrderings<String> get script => $composableBuilder(
    column: $table.script,
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
}

class $$ScriptSnippetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScriptSnippetsTable> {
  $$ScriptSnippetsTableAnnotationComposer({
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

  GeneratedColumn<String> get script =>
      $composableBuilder(column: $table.script, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ScriptSnippetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ScriptSnippetsTable,
          ScriptSnippet,
          $$ScriptSnippetsTableFilterComposer,
          $$ScriptSnippetsTableOrderingComposer,
          $$ScriptSnippetsTableAnnotationComposer,
          $$ScriptSnippetsTableCreateCompanionBuilder,
          $$ScriptSnippetsTableUpdateCompanionBuilder,
          (
            ScriptSnippet,
            BaseReferences<_$AppDatabase, $ScriptSnippetsTable, ScriptSnippet>,
          ),
          ScriptSnippet,
          PrefetchHooks Function()
        > {
  $$ScriptSnippetsTableTableManager(
    _$AppDatabase db,
    $ScriptSnippetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScriptSnippetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScriptSnippetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScriptSnippetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> script = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ScriptSnippetsCompanion(
                id: id,
                name: name,
                script: script,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String script,
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => ScriptSnippetsCompanion.insert(
                id: id,
                name: name,
                script: script,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScriptSnippetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ScriptSnippetsTable,
      ScriptSnippet,
      $$ScriptSnippetsTableFilterComposer,
      $$ScriptSnippetsTableOrderingComposer,
      $$ScriptSnippetsTableAnnotationComposer,
      $$ScriptSnippetsTableCreateCompanionBuilder,
      $$ScriptSnippetsTableUpdateCompanionBuilder,
      (
        ScriptSnippet,
        BaseReferences<_$AppDatabase, $ScriptSnippetsTable, ScriptSnippet>,
      ),
      ScriptSnippet,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ServersTableTableManager get servers =>
      $$ServersTableTableManager(_db, _db.servers);
  $$VaultMetadataTableTableManager get vaultMetadata =>
      $$VaultMetadataTableTableManager(_db, _db.vaultMetadata);
  $$ComposeProjectLinksTableTableManager get composeProjectLinks =>
      $$ComposeProjectLinksTableTableManager(_db, _db.composeProjectLinks);
  $$ContainerCacheEntriesTableTableManager get containerCacheEntries =>
      $$ContainerCacheEntriesTableTableManager(_db, _db.containerCacheEntries);
  $$DeploymentProjectsTableTableManager get deploymentProjects =>
      $$DeploymentProjectsTableTableManager(_db, _db.deploymentProjects);
  $$DeploymentResourcesTableTableManager get deploymentResources =>
      $$DeploymentResourcesTableTableManager(_db, _db.deploymentResources);
  $$ScriptSnippetsTableTableManager get scriptSnippets =>
      $$ScriptSnippetsTableTableManager(_db, _db.scriptSnippets);
}
