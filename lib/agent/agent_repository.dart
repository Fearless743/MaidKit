import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/servers/vault_service.dart';

import 'personality_service.dart';

class AgentConfiguration {
  const AgentConfiguration({
    required this.providerId,
    required this.providerName,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
  });
  final int providerId;
  final String providerName;
  final String apiKey;
  final String? baseUrl;
  final String model;
}

class AgentProviderDraft {
  const AgentProviderDraft({
    required this.name,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
  });
  final String name;

  /// Leave empty when editing to retain the stored key.
  final String apiKey;
  final String? baseUrl;
  final String model;
}

/// One message stored in a saved conversation. Only the rendered text is kept;
/// pending tool proposals are intentionally not restored.
class AgentConversationMessage {
  const AgentConversationMessage({required this.role, required this.text});
  final String role;
  final String text;

  Map<String, dynamic> toJson() => {'role': role, 'text': text};

  factory AgentConversationMessage.fromJson(Map<String, dynamic> json) =>
      AgentConversationMessage(
        role: json['role'] as String? ?? 'assistant',
        text: json['text'] as String? ?? '',
      );
}

class AgentConversationDraft {
  const AgentConversationDraft({
    required this.title,
    required this.messages,
    this.providerId,
    this.modelId,
  });
  final String title;
  final List<AgentConversationMessage> messages;
  final int? providerId;
  final int? modelId;
}

class AgentRepository {
  AgentRepository(this._database, this._vault);
  final AppDatabase _database;
  final VaultService _vault;

  /// Maximum number of saved conversations kept in history. Oldest entries are
  /// evicted first when this is exceeded.
  static const int maxConversations = 20;

  Stream<List<AgentProvider>> watchProviders() =>
      _database.watchAgentProviders();

  Stream<List<AgentProviderModel>> watchModels(int providerId) =>
      _database.watchAgentProviderModels(providerId);

  Stream<List<AgentConversation>> watchConversations() =>
      _database.watchAgentConversations();

  Future<AgentConversation?> conversation(int id) => (_database.select(
    _database.agentConversations,
  )..where((table) => table.id.equals(id))).getSingleOrNull();

  Future<int> saveConversation(AgentConversationDraft draft, {int? id}) async {
    final now = DateTime.now().toUtc();
    final messages = jsonEncode([
      for (final message in draft.messages) message.toJson(),
    ]);
    await _database.transaction(() async {
      if (id == null) {
        id = await _database
            .into(_database.agentConversations)
            .insert(
              AgentConversationsCompanion.insert(
                title: draft.title,
                providerId: Value(draft.providerId),
                modelId: Value(draft.modelId),
                messages: messages,
                createdAt: now,
                updatedAt: now,
              ),
            );
        await _evictOldestConversations();
      } else {
        await (_database.update(
          _database.agentConversations,
        )..where((table) => table.id.equals(id!))).write(
          AgentConversationsCompanion(
            title: Value(draft.title),
            providerId: Value(draft.providerId),
            modelId: Value(draft.modelId),
            messages: Value(messages),
            updatedAt: Value(now),
          ),
        );
      }
    });
    return id!;
  }

  Future<void> _evictOldestConversations() async {
    final count = await _database.agentConversations.count().getSingle();
    if (count <= maxConversations) return;
    final oldest =
        await (_database.select(_database.agentConversations)
              ..orderBy([(table) => OrderingTerm.asc(table.updatedAt)])
              ..limit(count - maxConversations))
            .get();
    for (final conversation in oldest) {
      await (_database.delete(
        _database.agentConversations,
      )..where((table) => table.id.equals(conversation.id))).go();
    }
  }

  Future<void> deleteConversation(int id) => (_database.delete(
    _database.agentConversations,
  )..where((table) => table.id.equals(id))).go();

  Future<void> save(AgentProviderDraft draft, {int? id}) async {
    final name = draft.name.trim();
    final model = draft.model.trim();
    final baseUrl = _normalizeBaseUrl(draft.baseUrl);
    if (baseUrl == PersonalityService.productionBaseUrl) {
      throw ArgumentError(
        'Solar Network Personality is managed automatically by Solarpass.',
      );
    }
    if (name.isEmpty || model.isEmpty) {
      throw ArgumentError('Provider name and model are required.');
    }
    final existing = id == null
        ? null
        : await (_database.select(
            _database.agentProviders,
          )..where((table) => table.id.equals(id))).getSingle();
    final rawKey = draft.apiKey.trim();
    if (existing == null && rawKey.isEmpty) {
      throw ArgumentError('An API key is required for a new provider.');
    }
    final encrypted = rawKey.isEmpty
        ? null
        : await _vault.encrypt(rawKey, context: 'agent-provider-api-key');
    final values = AgentProvidersCompanion(
      name: Value(name),
      encryptedApiKey: encrypted == null
          ? const Value.absent()
          : Value(encrypted.bytes),
      apiKeyNonce: encrypted == null
          ? const Value.absent()
          : Value(encrypted.nonce),
      baseUrl: Value(baseUrl),
      model: Value(model),
      updatedAt: Value(DateTime.now().toUtc()),
    );
    if (existing == null) {
      final providerId = await _database
          .into(_database.agentProviders)
          .insert(
            AgentProvidersCompanion.insert(
              name: name,
              encryptedApiKey: encrypted!.bytes,
              apiKeyNonce: encrypted.nonce,
              baseUrl: Value(baseUrl),
              model: model,
              updatedAt: DateTime.now().toUtc(),
            ),
          );
      await _database
          .into(_database.agentProviderModels)
          .insert(
            AgentProviderModelsCompanion.insert(
              providerId: providerId,
              model: model,
              createdAt: DateTime.now().toUtc(),
            ),
          );
    } else {
      await (_database.update(
        _database.agentProviders,
      )..where((table) => table.id.equals(existing.id))).write(values);
      await addModel(existing.id, model);
    }
  }

  Future<void> addModel(int providerId, String value) async {
    final model = value.trim();
    if (model.isEmpty) throw ArgumentError.value(value, 'model', 'is empty');
    final existing =
        await (_database.select(_database.agentProviderModels)..where(
              (table) =>
                  table.providerId.equals(providerId) &
                  table.model.equals(model),
            ))
            .get();
    if (existing.isNotEmpty) return;
    await _database
        .into(_database.agentProviderModels)
        .insert(
          AgentProviderModelsCompanion.insert(
            providerId: providerId,
            model: model,
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<void> deleteModel(int id) => (_database.delete(
    _database.agentProviderModels,
  )..where((table) => table.id.equals(id))).go();

  Future<void> delete(int id) => (_database.delete(
    _database.agentProviders,
  )..where((table) => table.id.equals(id))).go();

  /// Keeps the first-party provider available for the active Solarpass user.
  /// Its access token is encrypted with the vault key like other provider
  /// credentials, while the active request still uses a refreshed token.
  Future<void> ensurePersonalityProvider(
    String accessToken, {
    Iterable<String> models = const ['agent'],
  }) async {
    final encrypted = await _vault.encrypt(
      accessToken,
      context: 'agent-provider-api-key',
    );
    final existing =
        await (_database.select(_database.agentProviders)
              ..where(
                (table) =>
                    table.baseUrl.equals(PersonalityService.productionBaseUrl),
              )
              ..limit(1))
            .getSingleOrNull();
    final now = DateTime.now().toUtc();
    if (existing == null) {
      final providerId = await _database
          .into(_database.agentProviders)
          .insert(
            AgentProvidersCompanion.insert(
              name: 'Solar Network Personality',
              encryptedApiKey: encrypted.bytes,
              apiKeyNonce: encrypted.nonce,
              baseUrl: const Value(PersonalityService.productionBaseUrl),
              model: 'agent',
              updatedAt: now,
            ),
          );
      for (final model in models) {
        await addModel(providerId, model);
      }
      return;
    }
    await (_database.update(
      _database.agentProviders,
    )..where((table) => table.id.equals(existing.id))).write(
      AgentProvidersCompanion(
        encryptedApiKey: Value(encrypted.bytes),
        apiKeyNonce: Value(encrypted.nonce),
        updatedAt: Value(now),
      ),
    );
    for (final model in models) {
      await addModel(existing.id, model);
    }
  }

  Future<AgentConfiguration?> configuration([
    int? providerId,
    int? modelId,
  ]) async {
    final query = _database.select(_database.agentProviders)
      ..orderBy([(table) => OrderingTerm.asc(table.name)]);
    if (providerId != null) query.where((table) => table.id.equals(providerId));
    final rows = await query.get();
    if (rows.isEmpty) return null;
    final provider = rows.first;
    final modelsQuery = _database.select(_database.agentProviderModels)
      ..where((table) => table.providerId.equals(provider.id))
      ..orderBy([(table) => OrderingTerm.asc(table.model)]);
    if (modelId != null) modelsQuery.where((table) => table.id.equals(modelId));
    final models = await modelsQuery.get();
    final model = models.isEmpty ? provider.model : models.first.model;
    return AgentConfiguration(
      providerId: provider.id,
      providerName: provider.name,
      apiKey: await _vault.decrypt(
        EncryptedValue(
          bytes: provider.encryptedApiKey,
          nonce: provider.apiKeyNonce,
        ),
        context: 'agent-provider-api-key',
      ),
      baseUrl: provider.baseUrl,
      model: model,
    );
  }

  String? _normalizeBaseUrl(String? value) {
    final url = value?.trim();
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ArgumentError.value(value, 'baseUrl', 'must be an absolute URL');
    }
    return url.replaceFirst(RegExp(r'/+$'), '');
  }
}
