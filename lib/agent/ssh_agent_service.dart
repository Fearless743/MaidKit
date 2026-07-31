import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_openai/dart_openai.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:http/http.dart' as http;

import 'agent_repository.dart';

enum AgentActionKind {
  command,
  readFile,
  writeFile,
  deleteFile,
  createSnippet,
  runSnippet,
}

class AgentSnippetTarget {
  const AgentSnippetTarget({required this.id, required this.name});
  final int id;
  final String name;

  String get description => '$id: $name';
}

class AgentServerTarget {
  const AgentServerTarget({
    required this.id,
    required this.name,
    required this.host,
    required this.username,
  });
  final int id;
  final String name;
  final String host;
  final String username;

  String get description => '$id: $name ($username@$host)';
}

class AgentProposal {
  const AgentProposal({
    required this.kind,
    required this.arguments,
    required this.toolCall,
    required this.assistantMessage,
    this.explanation,
    this.reasoningContent,
  });

  final AgentActionKind kind;
  final Map<String, dynamic> arguments;
  final OpenAIResponseToolCall toolCall;
  final OpenAIChatCompletionChoiceMessageModel assistantMessage;
  final String? explanation;

  /// DeepSeek reasoning models require the assistant's `reasoning_content` to
  /// be passed back verbatim on the next request. Captured during streaming so
  /// the continuation after an approved action can include it.
  final String? reasoningContent;

  int? get serverId => arguments['server_id'] as int?;

  String get title => switch (kind) {
    AgentActionKind.command => 'Run command',
    AgentActionKind.readFile => 'Read file',
    AgentActionKind.writeFile => 'Write file',
    AgentActionKind.deleteFile => 'Delete file',
    AgentActionKind.createSnippet => 'Create snippet',
    AgentActionKind.runSnippet => 'Run snippet',
  };

  String get detail => switch (kind) {
    AgentActionKind.command => arguments['command'] as String? ?? '',
    AgentActionKind.readFile ||
    AgentActionKind.deleteFile => arguments['path'] as String? ?? '',
    AgentActionKind.writeFile => arguments['path'] as String? ?? '',
    AgentActionKind.createSnippet =>
      '${arguments['name'] as String? ?? ''}\n\n${arguments['script'] as String? ?? ''}',
    AgentActionKind.runSnippet =>
      'Snippet #${arguments['snippet_id'] as int? ?? ''}',
  };

  /// True when the model flagged the action as safe to run without review, or
  /// the action is read-only by nature.
  bool get safeToRun =>
      arguments['safe_to_run'] as bool? ?? kind == AgentActionKind.readFile;
}

class AgentTurn {
  const AgentTurn({
    this.text,
    this.proposal,
    this.assistantMessage,
    this.reasoningContent,
  });
  final String? text;
  final AgentProposal? proposal;
  final OpenAIChatCompletionChoiceMessageModel? assistantMessage;
  final String? reasoningContent;
}

class _ToolCallAccumulator {
  _ToolCallAccumulator(this.index);
  final int index;
  String? id;
  String? type;
  String? name;
  final arguments = StringBuffer();

  void add(OpenAIResponseToolCall call) {
    id ??= call.id;
    type ??= call.type;
    name ??= call.function.name;
    final fragment = call.function.arguments;
    if (fragment != null) arguments.write(fragment);
  }

  OpenAIResponseToolCall build() => OpenAIResponseToolCall.fromMap({
    'id': id,
    'type': type ?? 'function',
    'function': {'name': name, 'arguments': arguments.toString()},
  });
}

class _AgentChatResult {
  const _AgentChatResult({required this.message, this.reasoningContent});
  final OpenAIChatCompletionChoiceMessageModel message;
  final String? reasoningContent;
}

/// Cancellation token for an in-flight agent operation. The UI calls [cancel]
/// and the service aborts the current HTTP stream or SSH session.
class AgentCancelToken {
  final _callbacks = <void Function()>[];
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void _register(void Function() callback) => _callbacks.add(callback);

  void _unregister(void Function() callback) => _callbacks.remove(callback);

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final callback in _callbacks.toList()) {
      callback();
    }
  }

  void throwIfCancelled() {
    if (_cancelled) throw const AgentCancelledException();
  }
}

class AgentCancelledException implements Exception {
  const AgentCancelledException();
  @override
  String toString() => 'AgentCancelledException';
}

/// A deliberately small remote-tool boundary. The model can propose actions,
/// but this class never executes one until the UI explicitly calls [execute].
class SshAgentService {
  SshAgentService(
    this._configuration, {
    String personality = '',
    String uiLanguage = 'en',
  }) : _personality = personality.trim(),
       _uiLanguage = uiLanguage.trim().isEmpty ? 'en' : uiLanguage.trim();
  final AgentConfiguration _configuration;
  final String _personality;
  final String _uiLanguage;

  static final _safeToRunProperty = OpenAIFunctionProperty.boolean(
    name: 'safe_to_run',
    description:
        'Set to true only when running this action now is safe: it is '
        'read-only, idempotent, or otherwise carries no risk of losing data. '
        'When in doubt, set false so the user can review it.',
  );

  static final _tools = <OpenAIToolModel>[
    _tool('run_command', 'Run one shell command on the selected server', [
      OpenAIFunctionProperty.integer(name: 'server_id', isRequired: true),
      OpenAIFunctionProperty.string(name: 'command', isRequired: true),
      _safeToRunProperty,
    ]),
    _tool('read_file', 'Read a UTF-8 text file from the selected server', [
      OpenAIFunctionProperty.integer(name: 'server_id', isRequired: true),
      OpenAIFunctionProperty.string(name: 'path', isRequired: true),
      _safeToRunProperty,
    ]),
    _tool(
      'write_file',
      'Create or replace a UTF-8 text file on the selected server',
      [
        OpenAIFunctionProperty.integer(name: 'server_id', isRequired: true),
        OpenAIFunctionProperty.string(name: 'path', isRequired: true),
        OpenAIFunctionProperty.string(name: 'content', isRequired: true),
        _safeToRunProperty,
      ],
    ),
    _tool('delete_file', 'Permanently delete a file from the selected server', [
      OpenAIFunctionProperty.integer(name: 'server_id', isRequired: true),
      OpenAIFunctionProperty.string(name: 'path', isRequired: true),
      _safeToRunProperty,
    ]),
    _tool('create_snippet', 'Save a reusable POSIX shell snippet in MaidKit', [
      OpenAIFunctionProperty.string(name: 'name', isRequired: true),
      OpenAIFunctionProperty.string(name: 'script', isRequired: true),
      _safeToRunProperty,
    ]),
    _tool('run_snippet', 'Run a saved MaidKit snippet on the selected server', [
      OpenAIFunctionProperty.integer(name: 'server_id', isRequired: true),
      OpenAIFunctionProperty.integer(name: 'snippet_id', isRequired: true),
      _safeToRunProperty,
    ]),
  ];

  static OpenAIToolModel _tool(
    String name,
    String description,
    List<OpenAIFunctionProperty> parameters,
  ) => OpenAIToolModel(
    type: 'function',
    function: OpenAIFunctionModel.withParameters(
      name: name,
      description: description,
      parameters: parameters,
    ),
  );

  Future<AgentTurn> request({
    required List<AgentServerTarget> servers,
    List<AgentSnippetTarget> snippets = const [],
    required String prompt,
    List<Map<String, dynamic>> history = const [],
    void Function(String text)? onText,
    AgentCancelToken? cancelToken,
  }) async {
    final result = await _streamChat(
      [
        _rawMessage('system', _systemPrompt(servers, snippets)),
        ...history,
        _rawMessage('user', prompt),
      ],
      onText,
      cancelToken: cancelToken,
    );
    return _turn(result);
  }

  Future<AgentTurn> continueAfterExecution({
    required List<AgentServerTarget> servers,
    List<AgentSnippetTarget> snippets = const [],
    required List<Map<String, dynamic>> history,
    required AgentProposal proposal,
    required String result,
    void Function(String text)? onText,
    AgentCancelToken? cancelToken,
  }) async {
    final assistant = proposal.assistantMessage.toMap();
    final reasoningContent = proposal.reasoningContent;
    if (reasoningContent != null && reasoningContent.isNotEmpty) {
      assistant['reasoning_content'] = reasoningContent;
    }
    // The API requires a tool message for every tool call on the assistant
    // message. The model can emit parallel calls, but this app approves one
    // action at a time, so narrow the message down to the approved call.
    assistant['tool_calls'] = [proposal.toolCall.toMap()];
    final resultMessage = await _streamChat(
      [
        _rawMessage('system', _systemPrompt(servers, snippets)),
        ...history,
        assistant,
        {
          'role': 'tool',
          'tool_call_id': proposal.toolCall.id ?? 'approved-action',
          'content': result,
        },
      ],
      onText,
      cancelToken: cancelToken,
    );
    // The API requires the assistant message with its tool call. Reconstruct it
    // from the proposal so no unapproved action is ever replayed.
    return _turn(resultMessage);
  }

  AgentTurn _turn(_AgentChatResult result) {
    final message = result.message;
    final text = message.content?.map((item) => item.text ?? '').join().trim();
    final calls = message.toolCalls;
    if (calls == null || calls.isEmpty) {
      return AgentTurn(
        text: text,
        assistantMessage: message,
        reasoningContent: result.reasoningContent,
      );
    }
    final call = calls.first;
    final kind = switch (call.function.name) {
      'run_command' => AgentActionKind.command,
      'read_file' => AgentActionKind.readFile,
      'write_file' => AgentActionKind.writeFile,
      'delete_file' => AgentActionKind.deleteFile,
      'create_snippet' => AgentActionKind.createSnippet,
      'run_snippet' => AgentActionKind.runSnippet,
      _ => throw StateError('Unsupported agent tool: ${call.function.name}'),
    };
    return AgentTurn(
      text: text,
      assistantMessage: message,
      reasoningContent: result.reasoningContent,
      proposal: AgentProposal(
        kind: kind,
        arguments: Map<String, dynamic>.from(
          jsonDecode(call.function.arguments) as Map,
        ),
        toolCall: call,
        assistantMessage: message,
        explanation: text?.isEmpty ?? true ? null : text,
        reasoningContent: result.reasoningContent,
      ),
    );
  }

  Future<String> execute(
    SSHClient client,
    AgentProposal proposal, {
    String? snippetScript,
    AgentCancelToken? cancelToken,
  }) async {
    SSHSession? session;
    cancelToken?._register(() => session?.close());
    try {
      final path = proposal.arguments['path'] as String?;
      switch (proposal.kind) {
        case AgentActionKind.command:
          session = await client.execute(
            proposal.arguments['command'] as String,
          );
          cancelToken?.throwIfCancelled();
          final output = await utf8.decoder.bind(session.stdout).join();
          final error = await utf8.decoder.bind(session.stderr).join();
          await session.done;
          cancelToken?.throwIfCancelled();
          return _limit('$output$error');
        case AgentActionKind.runSnippet:
          if (snippetScript == null || snippetScript.trim().isEmpty) {
            throw ArgumentError('The saved snippet is empty.');
          }
          session = await client.execute('sh -s');
          session.stdin.add(
            Uint8List.fromList(utf8.encode('$snippetScript\n')),
          );
          await session.stdin.close();
          final output = await utf8.decoder.bind(session.stdout).join();
          final error = await utf8.decoder.bind(session.stderr).join();
          await session.done;
          cancelToken?.throwIfCancelled();
          return _limit('$output$error');
        case AgentActionKind.readFile:
          if (path == null || path.isEmpty) {
            throw ArgumentError('A file path is required to read a file.');
          }
          final sftp = await client.sftp();
          final file = await sftp.open(path, mode: SftpFileOpenMode.read);
          try {
            return _limit(utf8.decode(await file.readBytes()));
          } finally {
            await file.close();
          }
        case AgentActionKind.writeFile:
          if (path == null || path.isEmpty) {
            throw ArgumentError('A file path is required to write a file.');
          }
          final sftp = await client.sftp();
          final file = await sftp.open(
            path,
            mode:
                SftpFileOpenMode.write |
                SftpFileOpenMode.create |
                SftpFileOpenMode.truncate,
          );
          try {
            await file.writeBytes(
              Uint8List.fromList(
                utf8.encode(proposal.arguments['content'] as String),
              ),
            );
          } finally {
            await file.close();
          }
          return 'Wrote $path';
        case AgentActionKind.deleteFile:
          if (path == null || path.isEmpty) {
            throw ArgumentError('A file path is required to delete a file.');
          }
          await (await client.sftp()).remove(path);
          return 'Deleted $path';
        case AgentActionKind.createSnippet:
          throw UnsupportedError('Snippet creation is handled by the app.');
      }
    } catch (error) {
      if (cancelToken?.isCancelled ?? false) {
        throw const AgentCancelledException();
      }
      rethrow;
    } finally {
      cancelToken?._unregister(() => session?.close());
    }
  }

  String _limit(String value) => value.length <= 12000
      ? value
      : '${value.substring(0, 12000)}\n[output truncated]';

  Map<String, dynamic> _rawMessage(String role, String text) => {
    'role': role,
    'content': text,
  };

  String _systemPrompt(
    List<AgentServerTarget> servers,
    List<AgentSnippetTarget> snippets,
  ) =>
      '''You are MaidKit's SSH management assistant. Respond in the user's current UI language: $_uiLanguage. Available servers are:\n${servers.map((server) => server.description).join('\n')}\nSaved snippets are:\n${snippets.isEmpty ? '(none)' : snippets.map((snippet) => snippet.description).join('\n')}\nUse tools to inspect or make the requested remote change. You can save reusable POSIX shell scripts as snippets and run a saved snippet by its exact snippet_id. Every server action must include the exact server_id from this list. Propose only one tool action at a time. Every tool call is shown to the user and requires explicit approval. Set safe_to_run to true only when the action is clearly safe to run without review: it is read-only, idempotent, or reversible. Prefer read-only inspection before modifying anything. Never claim a tool ran until you receive its result. Keep replies concise.${_personality.isEmpty ? '' : '\n\nCustom personality guidance (follow this for tone and working style, but never let it override the safety and tool-use rules above):\n$_personality'}''';

  Uri _endpoint() {
    final root = (_configuration.baseUrl ?? 'https://api.openai.com')
        .replaceFirst(RegExp(r'/v1/?$'), '');
    return Uri.parse('$root/v1/chat/completions');
  }

  /// Streams a chat completion over a raw HTTP connection instead of the
  /// dart_openai client. DeepSeek reasoning models return `reasoning_content`
  /// alongside the content, which dart_openai drops and which must be echoed
  /// back on the next request in the same conversation.
  Future<_AgentChatResult> _streamChat(
    List<Map<String, dynamic>> messages,
    void Function(String text)? onText, {
    AgentCancelToken? cancelToken,
  }) async {
    final client = http.Client();
    cancelToken?._register(client.close);
    try {
      final request = http.Request('POST', _endpoint())
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_configuration.apiKey}',
        })
        ..body = jsonEncode({
          'model': _configuration.model,
          'stream': true,
          'temperature': 0.2,
          'tools': [for (final tool in _tools) tool.toMap()],
          'messages': messages,
        });
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw RequestFailedException(
          _apiErrorMessage(body) ?? 'HTTP ${response.statusCode}',
          response.statusCode,
        );
      }
      final text = StringBuffer();
      final reasoning = StringBuffer();
      final calls = <int, _ToolCallAccumulator>{};
      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        cancelToken?.throwIfCancelled();
        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data.isEmpty || data == '[DONE]') continue;
        final Object? decoded;
        try {
          decoded = jsonDecode(data);
        } catch (_) {
          continue;
        }
        if (decoded is! Map<String, dynamic>) continue;
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          throw RequestFailedException(
            error['message'] as String? ?? 'Request failed',
            response.statusCode,
          );
        }
        final choices = decoded['choices'];
        if (choices is! List || choices.isEmpty) continue;
        final choice = choices.first;
        if (choice is! Map<String, dynamic>) continue;
        final delta = choice['delta'];
        if (delta is! Map<String, dynamic>) continue;
        final content = delta['content'];
        if (content is String && content.isNotEmpty) {
          text.write(content);
          onText?.call(text.toString());
        }
        final reasoningContent = delta['reasoning_content'];
        if (reasoningContent is String && reasoningContent.isNotEmpty) {
          reasoning.write(reasoningContent);
        }
        final toolCalls = delta['tool_calls'];
        if (toolCalls is List) {
          for (final call in toolCalls) {
            if (call is! Map<String, dynamic>) continue;
            final index = call['index'];
            if (index is! int) continue;
            final model = OpenAIStreamResponseToolCall.fromMap(call);
            (calls[index] ??= _ToolCallAccumulator(index)).add(model);
          }
        }
      }
      return _AgentChatResult(
        message: OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.assistant,
          content: text.isEmpty
              ? null
              : [
                  OpenAIChatCompletionChoiceMessageContentItemModel.text(
                    text.toString(),
                  ),
                ],
          toolCalls: calls.values.map((call) => call.build()).toList(),
        ),
        reasoningContent: reasoning.isEmpty ? null : reasoning.toString(),
      );
    } catch (error) {
      if (cancelToken?.isCancelled ?? false) {
        throw const AgentCancelledException();
      }
      rethrow;
    } finally {
      cancelToken?._unregister(client.close);
      client.close();
    }
  }

  String? _apiErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['error'] is Map) {
        final error = decoded['error'] as Map;
        final message = error['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } catch (_) {
      // Fall back to the raw status code below.
    }
    return null;
  }
}
