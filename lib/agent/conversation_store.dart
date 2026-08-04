import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

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

/// A saved agent conversation. History lives as a JSON Lines file in a folder
/// of the app's internal storage (one file per conversation), so chats are
/// device-local and never travel with a user's vault.
class AgentConversation {
  const AgentConversation({
    required this.id,
    required this.title,
    this.messages = const [],
    this.providerId,
    this.modelId,
    required this.createdAt,
    required this.updatedAt,
  });
  final int id;
  final String title;
  final List<AgentConversationMessage> messages;
  final int? providerId;
  final int? modelId;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// File-backed store for agent conversation history.
///
/// Each conversation is a `.jsonl` file named `<id>.jsonl`: the first line is
/// the conversation metadata, every following line is one message as
/// `{role, text}`. Embedded newlines stay inside a single line because
/// `jsonEncode` escapes them. Writes are atomic (temp file + rename) and the
/// folder is capped at [maxConversations] entries, oldest evicted first.
class AgentConversationStore {
  AgentConversationStore({Directory? directory})
    : _directoryOverride = directory;

  /// Overrides the default internal-storage location, used by tests.
  final Directory? _directoryOverride;

  /// Maximum number of saved conversations kept in history. Oldest entries are
  /// evicted first when this is exceeded.
  static const int maxConversations = 20;

  final _changes = StreamController<List<AgentConversation>>.broadcast();

  Future<Directory> _directory() async {
    final override = _directoryOverride;
    if (override != null) return override;
    final support = await getApplicationSupportDirectory();
    return Directory(
      '${support.path}${Platform.pathSeparator}agent_conversations',
    ).create(recursive: true);
  }

  String _path(Directory dir, int id) =>
      '${dir.path}${Platform.pathSeparator}$id.jsonl';

  /// Current conversation list, newest first.
  Future<List<AgentConversation>> list() async {
    final conversations = <AgentConversation>[];
    await for (final entity in (await _directory()).list()) {
      if (entity is! File || !entity.path.endsWith('.jsonl')) continue;
      final header = await _parseHeader(entity);
      if (header != null) conversations.add(header);
    }
    conversations.sort((a, b) {
      final byUpdated = b.updatedAt.compareTo(a.updatedAt);
      return byUpdated != 0 ? byUpdated : b.id.compareTo(a.id);
    });
    return conversations;
  }

  Future<AgentConversation?> conversation(int id) async {
    final file = File(_path(await _directory(), id));
    final header = await _parseHeader(file);
    if (header == null) return null;
    final messages = <AgentConversationMessage>[];
    await for (final line in _readLines(file).skip(1)) {
      final decoded = _tryDecode(line);
      if (decoded == null) continue;
      messages.add(AgentConversationMessage.fromJson(decoded));
    }
    return AgentConversation(
      id: header.id,
      title: header.title,
      providerId: header.providerId,
      modelId: header.modelId,
      createdAt: header.createdAt,
      updatedAt: header.updatedAt,
      messages: messages,
    );
  }

  /// Creates a new conversation (when [id] is null) or rewrites an existing
  /// one in place. Returns the conversation id.
  Future<int> saveConversation(AgentConversationDraft draft, {int? id}) async {
    final dir = await _directory();
    final now = DateTime.now().toUtc();
    final conversationId = id ?? await _nextId(dir);
    final createdAt = id == null ? now : (await _createdAt(dir, id) ?? now);
    final lines = <String>[
      jsonEncode({
        'id': conversationId,
        'title': draft.title,
        'providerId': draft.providerId,
        'modelId': draft.modelId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      }),
      for (final message in draft.messages) jsonEncode(message.toJson()),
    ];
    final file = File(_path(dir, conversationId));
    final temp = File('${file.path}.tmp');
    await temp.writeAsString('${lines.join('\n')}\n');
    await temp.rename(file.path);
    await _evictIfNeeded(dir);
    await _notify();
    return conversationId;
  }

  Future<void> deleteConversation(int id) async {
    final file = File(_path(await _directory(), id));
    if (await file.exists()) await file.delete();
    await _notify();
  }

  /// Emits the current list, then a fresh list after every mutation.
  Stream<List<AgentConversation>> watchConversations() async* {
    yield await list();
    yield* _changes.stream;
  }

  Future<void> _notify() async {
    if (!_changes.hasListener) return;
    _changes.add(await list());
  }

  Future<int> _nextId(Directory dir) async {
    var maxId = 0;
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final id = int.tryParse(
        entity.uri.pathSegments.last.replaceFirst(RegExp(r'\.jsonl$'), ''),
      );
      if (id != null && id > maxId) maxId = id;
    }
    return maxId + 1;
  }

  Future<DateTime?> _createdAt(Directory dir, int id) async {
    final header = await _parseHeader(File(_path(dir, id)));
    return header?.createdAt;
  }

  Future<void> _evictIfNeeded(Directory dir) async {
    final conversations = await list();
    if (conversations.length <= maxConversations) return;
    for (final conversation in conversations.sublist(maxConversations)) {
      final file = File(_path(dir, conversation.id));
      if (await file.exists()) await file.delete();
    }
  }

  Future<AgentConversation?> _parseHeader(File file) async {
    try {
      final first = await _readLines(file).first;
      final decoded = _tryDecode(first);
      if (decoded == null) return null;
      return AgentConversation(
        id: decoded['id'] as int? ?? -1,
        title: decoded['title'] as String? ?? '',
        providerId: decoded['providerId'] as int?,
        modelId: decoded['modelId'] as int?,
        createdAt:
            DateTime.tryParse(decoded['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt:
            DateTime.tryParse(decoded['updatedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
    } on StateError {
      // Empty file.
      return null;
    } on FileSystemException {
      return null;
    }
  }

  static Stream<String> _readLines(File file) =>
      file.openRead().transform(utf8.decoder).transform(const LineSplitter());

  static Map<String, dynamic>? _tryDecode(String line) {
    try {
      final decoded = jsonDecode(line);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}
