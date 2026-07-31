import 'dart:convert';

import 'package:auto_route/auto_route.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:island_ui_foundation/island_ui_foundation.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:markdown_widget/markdown_widget.dart';

import 'package:maid_kit/data/local/app_database.dart';
import 'package:maid_kit/shared/presentation/app_scaffold.dart';
import 'package:maid_kit/theme.dart';
import 'package:maid_kit/shared/presentation/maidkit_alert.dart';
import 'package:maid_kit/servers/server_connection_actions.dart';
import 'package:maid_kit/servers/server_providers.dart';
import 'package:maid_kit/snippets/snippet_repository.dart';
import 'agent_input_focus.dart';
import 'agent_repository.dart';
import 'agent_run_policy.dart';
import 'ssh_agent_service.dart';

class _AgentProviderPreset {
  const _AgentProviderPreset(this.name, this.baseUrl, this.models);
  final String name;
  final String baseUrl;
  final List<String> models;
}

const _providerPresets = [
  _AgentProviderPreset('OpenAI', 'https://api.openai.com', [
    'gpt-4o-mini',
    'gpt-4.1-mini',
  ]),
  _AgentProviderPreset('DeepSeek', 'https://api.deepseek.com', [
    'deepseek-chat',
    'deepseek-reasoner',
  ]),
  _AgentProviderPreset('OpenRouter', 'https://openrouter.ai/api', [
    'anthropic/claude-sonnet-4',
    'deepseek/deepseek-chat',
    'openai/gpt-4o-mini',
  ]),
  _AgentProviderPreset('Ollama', 'http://localhost:11434', [
    'llama3.2',
    'qwen2.5-coder',
    'deepseek-r1',
  ]),
];

List<String> _presetModelsFor(AgentProvider provider) {
  for (final preset in _providerPresets) {
    if (preset.name == provider.name || preset.baseUrl == provider.baseUrl) {
      return preset.models;
    }
  }
  return const [];
}

@RoutePage()
class AgentPage extends ConsumerStatefulWidget {
  const AgentPage({super.key});
  @override
  ConsumerState<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends ConsumerState<AgentPage> {
  final _prompt = TextEditingController();
  final _promptFocus = FocusNode();
  final _showSidebar = ValueNotifier<bool>(false);
  final _messages = <_AgentMessage>[];
  // OpenAI tool calls need their complete protocol history (assistant call and
  // matching tool result) to be meaningful on the next request. The rendered
  // chat messages alone cannot provide that because tool-call IDs are omitted.
  final _agentContext = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _pendingContext = const [];
  final _messagesScroll = ScrollController();
  AgentProposal? _proposal;
  bool _reconnectRequired = false;
  bool _showScrollToBottom = false;
  String? _pendingPrompt;
  int? _activeProviderId;
  int? _activeModelId;
  int? _conversationId;
  bool _ghost = false;
  bool _working = false;
  AgentCancelToken? _activeToken;

  @override
  void initState() {
    super.initState();
    _messagesScroll.addListener(_updateScrollToBottomVisibility);
    _promptFocus.addListener(
      () => ref
          .read(agentInputFocusedProvider.notifier)
          .setFocused(_promptFocus.hasFocus),
    );
    _promptFocus.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;
      if (event.logicalKey != LogicalKeyboardKey.enter) {
        return KeyEventResult.ignored;
      }
      if (HardwareKeyboard.instance.isShiftPressed) {
        _insertNewLine();
      } else {
        _send();
      }
      return KeyEventResult.handled;
    };
  }

  void _insertNewLine() {
    final text = _prompt.text;
    final selection = _prompt.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;
    final newText = text.replaceRange(start, end, '\n');
    _prompt.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + 1),
    );
  }

  @override
  void dispose() {
    _showSidebar.dispose();
    _messagesScroll.removeListener(_updateScrollToBottomVisibility);
    _messagesScroll.dispose();
    _promptFocus.dispose();
    _prompt.dispose();
    super.dispose();
  }

  void _interrupt() => _activeToken?.cancel();

  void _updateScrollToBottomVisibility() {
    if (!_messagesScroll.hasClients) return;
    _setScrollToBottomVisibility(_messagesScroll.position);
  }

  void _setScrollToBottomVisibility(ScrollMetrics position) {
    if (!position.hasContentDimensions) return;
    final visible = position.pixels < position.maxScrollExtent - 64;
    if (visible == _showScrollToBottom || !mounted) return;
    setState(() => _showScrollToBottom = visible);
  }

  void _scrollToLatest() {
    if (!_messagesScroll.hasClients) return;
    _messagesScroll.animateTo(
      _messagesScroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  /// Scrolls the chat list to the bottom when the user is already near it,
  /// so new tokens and tool results stay in view while streaming.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messagesScroll.hasClients) return;
      final position = _messagesScroll.position;
      if (!position.hasContentDimensions) return;
      final maxScroll = position.maxScrollExtent;
      if (maxScroll <= 0) return;
      if (position.pixels >= maxScroll - 64) {
        position.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
      _updateScrollToBottomVisibility();
    });
  }

  Future<void> _send() async {
    final text = _prompt.text.trim();
    final servers = ref.read(serversProvider).asData?.value ?? const <Server>[];
    if (text.isEmpty || servers.isEmpty || _working || _proposal != null) {
      return;
    }
    final targets = _serverTargets(servers);
    final snippets = await ref.read(snippetRepositoryProvider).all();
    if (!mounted) return;
    final conversationContext = List<Map<String, dynamic>>.from(_agentContext);
    setState(() {
      _working = true;
      _pendingPrompt = text;
      _pendingContext = [
        ...conversationContext,
        _rawContextMessage('user', text),
      ];
      _messages.add(_AgentMessage.user(text));
      _prompt.clear();
    });
    _scrollToBottom();
    try {
      final config = await ref
          .read(agentRepositoryProvider)
          .configuration(_activeProviderId, _activeModelId);
      if (config == null) {
        if (mounted) await _showProviderEditor();
        return;
      }
      final personality = await ref.read(agentPersonalityProvider.future);
      if (!mounted) return;
      var streamedMessageIndex = -1;
      final cancelToken = AgentCancelToken();
      _activeToken = cancelToken;
      final turn =
          await SshAgentService(
            config,
            personality: personality,
            uiLanguage: context.locale.toLanguageTag(),
          ).request(
            servers: targets,
            snippets: _snippetTargets(snippets),
            prompt: text,
            history: conversationContext,
            onText: (streamedText) {
              if (!mounted) return;
              setState(() {
                final message = _AgentMessage.assistant(streamedText);
                if (streamedMessageIndex < 0) {
                  _messages.add(message);
                  streamedMessageIndex = _messages.length - 1;
                } else {
                  _messages[streamedMessageIndex] = message;
                }
              });
              _scrollToBottom();
            },
            cancelToken: cancelToken,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        if (streamedMessageIndex < 0 &&
            turn.text != null &&
            turn.text!.isNotEmpty) {
          _messages.add(_AgentMessage.assistant(turn.text!));
        }
      });
      _scrollToBottom();
      await _handleTurn(turn);
    } on AgentCancelledException {
      if (mounted) {
        setState(
          () => _messages.add(const _AgentMessage.assistant('Interrupted.')),
        );
        _scrollToBottom();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _messages.add(_AgentMessage.assistant('Error: $error')));
        _scrollToBottom();
      }
    } finally {
      _activeToken = null;
      if (mounted) {
        setState(() => _working = false);
        await _persistConversation();
      }
    }
  }

  Future<void> _approve([
    AgentProposal? proposal,
    bool autoApproved = false,
  ]) async {
    final approvedProposal = proposal ?? _proposal;
    if (approvedProposal == null || _pendingPrompt == null) {
      return;
    }
    setState(() => _working = true);
    try {
      final config = await ref
          .read(agentRepositoryProvider)
          .configuration(_activeProviderId, _activeModelId);
      final servers =
          ref.read(serversProvider).asData?.value ?? const <Server>[];
      if (config == null) {
        throw StateError('The AI provider is no longer available.');
      }
      if (!mounted) {
        return;
      }
      SSHClient? client;
      final serverId = approvedProposal.serverId;
      if (serverId != null) {
        final server = servers
            .where((server) => server.id == serverId)
            .firstOrNull;
        if (server == null) {
          throw StateError('The target server is no longer available.');
        }
        if (ref.read(connectionManagerProvider).clientFor(server.id) == null &&
            !await connectForStatistics(context, ref, server)) {
          if (mounted) setState(() => _reconnectRequired = true);
          return;
        }
        client = ref.read(connectionManagerProvider).clientFor(server.id);
        if (client == null) {
          if (mounted) setState(() => _reconnectRequired = true);
          return;
        }
      }
      _reconnectRequired = false;
      final personality = await ref.read(agentPersonalityProvider.future);
      if (!mounted) return;
      final agent = SshAgentService(
        config,
        personality: personality,
        uiLanguage: context.locale.toLanguageTag(),
      );
      final cancelToken = AgentCancelToken();
      _activeToken = cancelToken;
      final result = await _executeProposal(
        agent,
        client,
        approvedProposal,
        cancelToken,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(
          _AgentMessage.tool(
            '${approvedProposal.title}:\n$result',
            autoApproved: autoApproved,
          ),
        );
        _proposal = null;
        _reconnectRequired = false;
      });
      _scrollToBottom();
      var streamedMessageIndex = -1;
      final turn = await agent.continueAfterExecution(
        servers: _serverTargets(servers),
        snippets: _snippetTargets(
          await ref.read(snippetRepositoryProvider).all(),
        ),
        history: _pendingContext,
        proposal: approvedProposal,
        result: result,
        onText: (streamedText) {
          if (!mounted) return;
          setState(() {
            final message = _AgentMessage.assistant(streamedText);
            if (streamedMessageIndex < 0) {
              _messages.add(message);
              streamedMessageIndex = _messages.length - 1;
            } else {
              _messages[streamedMessageIndex] = message;
            }
          });
          _scrollToBottom();
        },
        cancelToken: cancelToken,
      );
      if (!mounted) {
        return;
      }
      _agentContext
        ..clear()
        ..addAll(_pendingContext)
        ..add(_proposalContextMessage(approvedProposal))
        ..add({
          'role': 'tool',
          'tool_call_id': approvedProposal.toolCall.id ?? 'approved-action',
          'content': result,
        });
      _pendingContext = List<Map<String, dynamic>>.from(_agentContext);
      setState(() {
        if (streamedMessageIndex < 0 &&
            turn.text != null &&
            turn.text!.isNotEmpty) {
          _messages.add(_AgentMessage.assistant(turn.text!));
        }
      });
      await _handleTurn(turn);
    } on AgentCancelledException {
      if (mounted) {
        setState(() {
          _messages.add(const _AgentMessage.assistant('Action interrupted.'));
          _proposal = null;
          _reconnectRequired = false;
        });
        _scrollToBottom();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _messages.add(_AgentMessage.assistant('Action failed: $error'));
          _proposal = null;
          _reconnectRequired = false;
        });
      }
    } finally {
      _activeToken = null;
      if (mounted) {
        setState(() => _working = false);
        await _persistConversation();
      }
    }
  }

  List<AgentServerTarget> _serverTargets(List<Server> servers) => [
    for (final server in servers)
      AgentServerTarget(
        id: server.id,
        name: server.name,
        host: server.host,
        username: server.username,
      ),
  ];

  List<AgentSnippetTarget> _snippetTargets(List<ScriptSnippet> snippets) => [
    for (final snippet in snippets)
      AgentSnippetTarget(id: snippet.id, name: snippet.name),
  ];

  Future<String> _executeProposal(
    SshAgentService agent,
    SSHClient? client,
    AgentProposal proposal,
    AgentCancelToken cancelToken,
  ) async {
    final snippets = ref.read(snippetRepositoryProvider);
    switch (proposal.kind) {
      case AgentActionKind.createSnippet:
        final name = proposal.arguments['name'] as String? ?? '';
        final script = proposal.arguments['script'] as String? ?? '';
        if (name.trim().isEmpty || script.trim().isEmpty) {
          throw ArgumentError('A snippet name and script are required.');
        }
        final id = await snippets.save(name: name, script: script);
        return 'Created saved snippet #$id: ${name.trim()}';
      case AgentActionKind.runSnippet:
        final snippetId = proposal.arguments['snippet_id'] as int?;
        if (snippetId == null) throw ArgumentError('A snippet ID is required.');
        final snippet = await snippets.snippet(snippetId);
        if (snippet == null) {
          throw StateError('Saved snippet #$snippetId no longer exists.');
        }
        return agent.execute(
          _requireClient(client),
          proposal,
          snippetScript: snippet.script,
          cancelToken: cancelToken,
        );
      case AgentActionKind.command:
      case AgentActionKind.readFile:
      case AgentActionKind.writeFile:
      case AgentActionKind.deleteFile:
        return agent.execute(
          _requireClient(client),
          proposal,
          cancelToken: cancelToken,
        );
    }
  }

  SSHClient _requireClient(SSHClient? client) =>
      client ??
      (throw StateError(
        'This action requires an active SSH connection to its target server.',
      ));

  Future<void> _handleTurn(AgentTurn turn) async {
    final proposal = turn.proposal;
    if (proposal == null) {
      _agentContext
        ..clear()
        ..addAll(_pendingContext)
        ..add(
          _assistantContextMessage(
            turn.assistantMessage,
            turn.text,
            turn.reasoningContent,
          ),
        );
      _pendingContext = List<Map<String, dynamic>>.from(_agentContext);
      setState(() => _proposal = null);
      return;
    }
    final policy =
        ref.read(agentRunPolicyProvider).value ?? AgentRunPolicy.alwaysAsk;
    final shouldAutoRun = switch (policy) {
      AgentRunPolicy.alwaysApprove => true,
      AgentRunPolicy.autoReview => proposal.safeToRun,
      AgentRunPolicy.alwaysAsk => false,
    };
    if (shouldAutoRun) {
      await _approve(proposal, true);
    } else {
      setState(() {
        _proposal = proposal;
        _reconnectRequired = false;
      });
    }
  }

  Future<void> _declineProposal() async {
    if (_working) return;
    setState(() {
      _messages.add(const _AgentMessage.assistant('Action declined.'));
      _proposal = null;
      _reconnectRequired = false;
    });
    _scrollToBottom();
    _agentContext
      ..clear()
      ..addAll(_pendingContext)
      ..add(_rawContextMessage('assistant', 'Action declined.'));
    _pendingContext = List<Map<String, dynamic>>.from(_agentContext);
    await _persistConversation();
  }

  Future<void> _persistConversation() async {
    if (_ghost || _messages.isEmpty) return;
    final snapshot = List<_AgentMessage>.of(_messages);
    final id = _conversationId;
    final providerId = _activeProviderId;
    final modelId = _activeModelId;
    final savedId = await ref
        .read(agentRepositoryProvider)
        .saveConversation(
          AgentConversationDraft(
            title: _conversationTitle(snapshot),
            providerId: providerId,
            modelId: modelId,
            messages: [
              for (final message in snapshot)
                AgentConversationMessage(
                  role: _roleName(message.kind),
                  text: message.text,
                ),
            ],
          ),
          id: id,
        );
    if (!mounted || _ghost) return;
    setState(() => _conversationId = savedId);
  }

  Future<void> _startNewConversation() async {
    if (_working) return;
    await _persistConversation();
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _agentContext.clear();
      _pendingContext = const [];
      _conversationId = null;
      _proposal = null;
      _reconnectRequired = false;
      _pendingPrompt = null;
    });
    _showSidebar.value = false;
    _promptFocus.requestFocus();
  }

  Future<void> _setGhost(bool value) async {
    if (_working) return;
    if (value) {
      setState(() {
        _ghost = true;
        _conversationId = null;
      });
      return;
    }
    setState(() => _ghost = false);
    await _persistConversation();
  }

  Future<void> _loadConversation(int id) async {
    if (_working || _conversationId == id) return;
    await _persistConversation();
    final conversation = await ref
        .read(agentRepositoryProvider)
        .conversation(id);
    if (!mounted || conversation == null) return;
    setState(() {
      _messages
        ..clear()
        ..addAll(_decodeMessages(conversation.messages));
      _agentContext
        ..clear()
        ..addAll(_contextFromMessages(_messages));
      _pendingContext = List<Map<String, dynamic>>.from(_agentContext);
      _conversationId = conversation.id;
      _ghost = false;
      _activeProviderId = conversation.providerId;
      _activeModelId = conversation.modelId;
      _proposal = null;
      _reconnectRequired = false;
      _pendingPrompt = null;
    });
    _showSidebar.value = false;
  }

  Future<void> _deleteConversation(AgentConversation conversation) async {
    if (_working) return;
    final confirmed = await showMaidKitConfirmAlert(
      'Delete "${conversation.title}"? This cannot be undone.',
      'Delete conversation',
      icon: Symbols.delete_outline,
      isDanger: true,
    );
    if (!confirmed) return;
    await ref.read(agentRepositoryProvider).deleteConversation(conversation.id);
    if (mounted && _conversationId == conversation.id) {
      setState(() {
        _messages.clear();
        _agentContext.clear();
        _pendingContext = const [];
        _conversationId = null;
        _proposal = null;
        _reconnectRequired = false;
        _pendingPrompt = null;
      });
    }
  }

  Future<void> _showProviderEditor([AgentProvider? existing]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (sheetContext) => _AgentProviderEditorSheet(
        existing: existing,
        onSave: (draft) async {
          try {
            await ref
                .read(agentRepositoryProvider)
                .save(draft, id: existing?.id);
            if (sheetContext.mounted) Navigator.pop(sheetContext);
          } catch (error) {
            showMaidKitErrorAlert(error, title: 'Could not save provider');
          }
        },
      ),
    );
  }

  Future<void> _deleteProvider(AgentProvider provider) async {
    final confirmed = await showMaidKitConfirmAlert(
      'Delete ${provider.name}? Its encrypted API key will be removed from this vault.',
      'Delete AI provider',
      icon: Symbols.delete_outline,
      isDanger: true,
    );
    if (!confirmed) return;
    await ref.read(agentRepositoryProvider).delete(provider.id);
    if (mounted && _activeProviderId == provider.id) {
      setState(() => _activeProviderId = null);
    }
  }

  Future<void> _showAddModelSheet(AgentProvider provider) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        useRootNavigator: true,
        builder: (sheetContext) => _AgentModelEditorSheet(
          onSave: (model) async {
            try {
              await ref
                  .read(agentRepositoryProvider)
                  .addModel(provider.id, model);
              if (sheetContext.mounted) Navigator.pop(sheetContext);
            } catch (error) {
              showMaidKitErrorAlert(error, title: 'Could not add model');
            }
          },
          presets: _presetModelsFor(provider),
        ),
      );

  Future<void> _deleteModel(AgentProviderModel model) async {
    final confirmed = await showMaidKitConfirmAlert(
      'Remove ${model.model} from this provider?',
      'Remove model',
      icon: Symbols.delete_outline,
      isDanger: true,
    );
    if (!confirmed) return;
    await ref.read(agentRepositoryProvider).deleteModel(model.id);
    if (mounted && _activeModelId == model.id) {
      setState(() => _activeModelId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final servers =
        ref.watch(serversProvider).asData?.value ?? const <Server>[];
    final providers =
        ref.watch(agentProvidersProvider).asData?.value ??
        const <AgentProvider>[];
    final conversations =
        ref.watch(agentConversationsProvider).asData?.value ??
        const <AgentConversation>[];
    final selectedProviderId =
        _activeProviderId ?? (providers.isEmpty ? null : providers.first.id);
    final models = selectedProviderId == null
        ? const <AgentProviderModel>[]
        : ref
                  .watch(agentProviderModelsProvider(selectedProviderId))
                  .asData
                  ?.value ??
              const <AgentProviderModel>[];
    final selectedModelId =
        _activeModelId ?? (models.isEmpty ? null : models.first.id);
    if (_activeProviderId != null &&
        !providers.any((provider) => provider.id == _activeProviderId)) {
      _activeProviderId = null;
      _activeModelId = null;
    }
    final scheme = Theme.of(context).colorScheme;
    return MaidKitAppScaffold(
      appBar: AppBar(
        actions: _buildAppBarActions(
          providers: providers,
          models: models,
          selectedProviderId: selectedProviderId,
          selectedModelId: selectedModelId,
          scheme: scheme,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: ResponsiveSidebar(
            isLeft: false,
            showSidebar: _showSidebar,
            sidebarWidth: 360,
            minWideSidebarWidth: 300,
            maxWideSidebarWidth: 400,
            minMainContentWidth: 480,
            sidebarBackgroundColor: scheme.surface,
            sidebarElevation: 0,
            sidebarContent: _buildConversationSidebar(
              conversations: conversations,
              scheme: scheme,
            ),
            mainContent: _buildChatColumn(servers: servers, scheme: scheme),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions({
    required List<AgentProvider> providers,
    required List<AgentProviderModel> models,
    required int? selectedProviderId,
    required int? selectedModelId,
    required ColorScheme scheme,
  }) {
    final selectedProvider = selectedProviderId == null
        ? null
        : providers
              .where((provider) => provider.id == selectedProviderId)
              .firstOrNull;
    final selectedModel = selectedModelId == null
        ? null
        : models.where((model) => model.id == selectedModelId).firstOrNull;
    return [
      const SizedBox(width: 4),
      _AppBarDropdown(
        label: 'AI provider',
        value: selectedProviderId,
        entries: [
          for (final provider in providers) (provider.id, provider.name),
        ],
        enabled: !_working,
        onChanged: (id) => setState(() {
          _activeProviderId = id;
          _activeModelId = null;
        }),
        actions: [
          _DropdownAction(
            label: 'Add provider',
            icon: Symbols.add,
            onSelected: () => _showProviderEditor(),
          ),
          _DropdownAction(
            label: 'Edit provider',
            icon: Symbols.edit,
            onSelected: () => _showProviderEditor(selectedProvider!),
            enabled: selectedProvider != null,
          ),
          _DropdownAction(
            label: 'Delete provider',
            icon: Symbols.delete_outline,
            onSelected: () => _deleteProvider(selectedProvider!),
            enabled: selectedProvider != null,
          ),
        ],
      ),
      const SizedBox(width: 8),
      _AppBarDropdown(
        label: 'Model',
        value: selectedModelId,
        entries: [for (final model in models) (model.id, model.model)],
        enabled: !_working && selectedProviderId != null,
        onChanged: (id) => setState(() => _activeModelId = id),
        actions: [
          _DropdownAction(
            label: 'Add model',
            icon: Symbols.add,
            onSelected: () => _showAddModelSheet(selectedProvider!),
            enabled: selectedProvider != null,
          ),
          _DropdownAction(
            label: 'Remove model',
            icon: Symbols.delete_outline,
            onSelected: () => _deleteModel(selectedModel!),
            enabled: selectedModel != null,
          ),
        ],
      ),
      const SizedBox(width: 8),
      IconButton(
        tooltip: 'Conversations',
        onPressed: () => _showSidebar.value = !_showSidebar.value,
        visualDensity: VisualDensity.compact,
        icon: const Icon(Symbols.history),
      ),
      const SizedBox(width: 8),
    ];
  }

  Widget _buildConversationSidebar({
    required List<AgentConversation> conversations,
    required ColorScheme scheme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Chats',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'New conversation',
                onPressed: _working ? null : _startNewConversation,
                icon: const Icon(Symbols.add),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => _showSidebar.value = false,
                icon: const Icon(Symbols.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "Don't save this conversation",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Switch(value: _ghost, onChanged: _working ? null : _setGhost),
            ],
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: 4),
        Expanded(
          child: conversations.isEmpty
              ? Center(
                  child: Text(
                    'No saved conversations yet',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: conversations.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (_, index) {
                    final conversation = conversations[index];
                    return _ConversationTile(
                      conversation: conversation,
                      selected: conversation.id == _conversationId,
                      onTap: () => _loadConversation(conversation.id),
                      onDelete: () => _deleteConversation(conversation),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildChatColumn({
    required List<Server> servers,
    required ColorScheme scheme,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _buildMessageList(servers: servers, scheme: scheme),
                ),
                if (_showScrollToBottom)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FloatingActionButton.small(
                      heroTag: 'agent-scroll-to-bottom',
                      tooltip: 'Scroll to latest',
                      onPressed: _scrollToLatest,
                      child: const Icon(Symbols.arrow_downward),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Material(
            elevation: 2,
            color: scheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
              side: BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _prompt,
                      focusNode: _promptFocus,
                      enabled: !_working && _proposal == null,
                      keyboardType: TextInputType.multiline,
                      maxLines: 5,
                      minLines: 1,
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Check why nginx is failing to start',
                        hintMaxLines: 1,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _working ? 'Stop' : 'Send message',
                    color: scheme.primary,
                    onPressed: _working
                        ? _interrupt
                        : _proposal != null
                        ? null
                        : _send,
                    icon: _working
                        ? const Icon(Symbols.stop)
                        : const Icon(Symbols.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList({
    required List<Server> servers,
    required ColorScheme scheme,
  }) {
    final pendingProposal = _proposal;
    final showThinking = _working && pendingProposal == null;
    final serverName = pendingProposal == null
        ? ''
        : pendingProposal.serverId == null
        ? 'MaidKit'
        : servers
                  .where((server) => server.id == pendingProposal.serverId)
                  .map((server) => server.name)
                  .firstOrNull ??
              'Unavailable server';
    if (_messages.isEmpty && pendingProposal == null) {
      return Center(
        child: Text(
          _ghost
              ? 'Ghost chat — messages are not saved to history.'
              : 'Describe the task. The agent can inspect any saved server.',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        _setScrollToBottomVisibility(notification.metrics);
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 16),
        controller: _messagesScroll,
        itemCount:
            _messages.length +
            (pendingProposal != null ? 1 : 0) +
            (showThinking ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          if (pendingProposal != null && index == _messages.length) {
            return _ProposalCard(
              proposal: pendingProposal,
              serverName: serverName,
              working: _working,
              reconnectRequired: _reconnectRequired,
              onApprove: _approve,
              onDecline: _declineProposal,
            );
          }
          if (showThinking &&
              index == _messages.length + (pendingProposal != null ? 1 : 0)) {
            return const _AgentThinkingIndicator();
          }
          return _MessageCard(message: _messages[index]);
        },
      ),
    );
  }

  static String _roleName(_MessageKind kind) => switch (kind) {
    _MessageKind.user => 'user',
    _MessageKind.tool => 'tool',
    _MessageKind.assistant => 'assistant',
  };

  static _MessageKind _roleKind(String? role) => switch (role) {
    'user' => _MessageKind.user,
    'tool' => _MessageKind.tool,
    _ => _MessageKind.assistant,
  };

  static Map<String, dynamic> _rawContextMessage(String role, String text) => {
    'role': role,
    'content': text,
  };

  static Map<String, dynamic> _assistantContextMessage(
    OpenAIChatCompletionChoiceMessageModel? message, [
    String? fallbackText,
    String? reasoningContent,
  ]) {
    final result =
        message?.toMap() ?? _rawContextMessage('assistant', fallbackText ?? '');
    if (result['tool_calls'] case final List calls when calls.isEmpty) {
      result.remove('tool_calls');
    }
    if (reasoningContent != null && reasoningContent.isNotEmpty) {
      result['reasoning_content'] = reasoningContent;
    }
    return result;
  }

  static Map<String, dynamic> _proposalContextMessage(AgentProposal proposal) {
    final result = _assistantContextMessage(
      proposal.assistantMessage,
      proposal.explanation,
      proposal.reasoningContent,
    );
    // Subsequent requests must include a result for every listed tool call.
    // Only this call was approved and executed.
    result['tool_calls'] = [proposal.toolCall.toMap()];
    return result;
  }

  static List<Map<String, dynamic>> _contextFromMessages(
    List<_AgentMessage> messages,
  ) => [
    for (final message in messages)
      _rawContextMessage(
        message.kind == _MessageKind.user ? 'user' : 'assistant',
        message.kind == _MessageKind.tool
            ? 'Tool result from an earlier action:\n${message.text}'
            : message.text,
      ),
  ];

  static String _conversationTitle(List<_AgentMessage> messages) {
    final firstUser = messages
        .where((message) => message.kind == _MessageKind.user)
        .firstOrNull;
    final text = (firstUser?.text ?? 'Conversation')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text.length <= 48 ? text : '${text.substring(0, 48)}…';
  }

  static List<_AgentMessage> _decodeMessages(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const [];
    }
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map<String, dynamic>)
          _AgentMessage(
            item['text'] as String? ?? '',
            _roleKind(item['role'] as String?),
          ),
    ];
  }
}

class _AgentMessage {
  const _AgentMessage(this.text, this.kind, {this.autoApproved = false});
  const _AgentMessage.user(String text) : this(text, _MessageKind.user);
  const _AgentMessage.assistant(String text)
    : this(text, _MessageKind.assistant);
  const _AgentMessage.tool(String text, {bool autoApproved = false})
    : this(text, _MessageKind.tool, autoApproved: autoApproved);
  final String text;
  final _MessageKind kind;
  final bool autoApproved;
}

class _DropdownAction {
  const _DropdownAction({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onSelected;
  final bool enabled;
}

class _AppBarDropdown extends StatelessWidget {
  const _AppBarDropdown({
    required this.label,
    required this.value,
    required this.entries,
    required this.onChanged,
    this.enabled = true,
    this.actions = const [],
  });

  final String label;
  final int? value;
  final List<(int, String)> entries;
  final ValueChanged<int> onChanged;
  final bool enabled;
  final List<_DropdownAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = entries.any((entry) => entry.$1 == value) ? value : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<int>(
        value: selected,
        isDense: true,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(8),
        style: theme.textTheme.bodyMedium,
        icon: const Icon(Symbols.expand_more, size: 18),
        hint: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        items: [
          for (final (id, name) in entries)
            DropdownMenuItem(
              value: id,
              enabled: enabled,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(name, overflow: TextOverflow.ellipsis),
              ),
            ),
          if (actions.isNotEmpty) ...[
            for (var index = 0; index < actions.length; index++)
              DropdownMenuItem(
                value: -index - 1,
                enabled: actions[index].enabled,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(actions[index].icon, size: 18),
                    const SizedBox(width: 10),
                    Text(actions[index].label),
                  ],
                ),
              ),
          ],
        ],
        onChanged: (id) {
          if (id == null) return;
          if (id < 0) {
            actions[-id - 1].onSelected();
            return;
          }
          onChanged(id);
        },
        selectedItemBuilder: (context) => [
          for (final (_, name) in entries)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Text(name, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          if (actions.isNotEmpty)
            for (var index = 0; index < actions.length; index++)
              const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
    required this.onDelete,
  });
  final AgentConversation conversation;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.surfaceContainerHighest : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _relativeTime(conversation.updatedAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                IconButton(
                  tooltip: 'Delete conversation',
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Symbols.delete_outline, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AgentProviderEditorSheet extends StatefulWidget {
  const _AgentProviderEditorSheet({
    required this.existing,
    required this.onSave,
  });
  final AgentProvider? existing;
  final Future<void> Function(AgentProviderDraft draft) onSave;

  @override
  State<_AgentProviderEditorSheet> createState() =>
      _AgentProviderEditorSheetState();
}

class _AgentModelEditorSheet extends StatefulWidget {
  const _AgentModelEditorSheet({required this.onSave, required this.presets});
  final Future<void> Function(String model) onSave;
  final List<String> presets;

  @override
  State<_AgentModelEditorSheet> createState() => _AgentModelEditorSheetState();
}

class _AgentModelEditorSheetState extends State<_AgentModelEditorSheet> {
  final _model = TextEditingController();
  var _saving = false;

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(_model.text);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
    titleText: 'Add model',
    heightFactor: 0.36,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const Text('Enter the model identifier accepted by this provider.'),
        const SizedBox(height: 20),
        if (widget.presets.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Preset model'),
            items: [
              for (final model in widget.presets)
                DropdownMenuItem(value: model, child: Text(model)),
            ],
            onChanged: (model) {
              if (model != null) _model.text = model;
            },
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _model,
          autofocus: true,
          onSubmitted: (_) => _save(),
          decoration: const InputDecoration(
            labelText: 'Model identifier',
            hintText: 'e.g. deepseek-chat',
          ),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Add model'),
          ),
        ),
      ],
    ),
  );
}

class _AgentProviderEditorSheetState extends State<_AgentProviderEditorSheet> {
  late final _name = TextEditingController(
    text: widget.existing?.name ?? 'OpenAI',
  );
  final _key = TextEditingController();
  late final _endpoint = TextEditingController(
    text: widget.existing?.baseUrl ?? 'https://api.openai.com',
  );
  late final _model = TextEditingController(
    text: widget.existing?.model ?? 'gpt-4o-mini',
  );
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _key.dispose();
    _endpoint.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        AgentProviderDraft(
          name: _name.text,
          apiKey: _key.text,
          baseUrl: _endpoint.text,
          model: _model.text,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
    titleText: widget.existing == null ? 'Add AI provider' : 'Edit AI provider',
    heightFactor: 0.72,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        const Text(
          'Profiles use OpenAI-compatible chat endpoints. Keys are encrypted with the vault key and sync with the vault.',
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<_AgentProviderPreset>(
          decoration: const InputDecoration(labelText: 'Provider preset'),
          items: [
            for (final preset in _providerPresets)
              DropdownMenuItem(value: preset, child: Text(preset.name)),
          ],
          onChanged: (preset) {
            if (preset == null) return;
            setState(() {
              _name.text = preset.name;
              _endpoint.text = preset.baseUrl;
              _model.text = preset.models.first;
            });
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Provider name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _key,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: widget.existing == null
                ? 'API key'
                : 'API key (leave empty to keep current key)',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _endpoint,
          keyboardType: TextInputType.url,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText:
                'Base URL (without /v1, for example https://api.deepseek.com)',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _model,
          onSubmitted: (_) => _save(),
          decoration: const InputDecoration(labelText: 'Model'),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Symbols.save),
            label: const Text('Save provider'),
          ),
        ),
      ],
    ),
  );
}

enum _MessageKind { user, assistant, tool }

String _relativeTime(DateTime time) {
  final local = time.toLocal();
  final difference = DateTime.now().difference(local);
  if (difference.inMinutes < 1) return 'just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '${local.year}-$month-$day';
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});
  final _AgentMessage message;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (message.kind == _MessageKind.tool) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _ToolCallCard(
            text: message.text,
            autoApproved: message.autoApproved,
          ),
        ),
      );
    }
    final color = switch (message.kind) {
      _MessageKind.user => scheme.secondaryContainer,
      _MessageKind.tool => scheme.surfaceContainerHighest,
      _MessageKind.assistant => scheme.surfaceContainerLow,
    };
    return Align(
      alignment: message.kind == _MessageKind.user
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: message.kind == _MessageKind.assistant
            // This follows Island's MarkdownTextContent implementation while
            // keeping MaidKit independent of Island's app-level package.
            ? _buildMarkdown(context)
            : SelectableText(message.text),
      ),
    );
  }

  Widget _buildMarkdown(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final base = isDark
        ? MarkdownConfig.darkConfig
        : MarkdownConfig.defaultConfig;
    return MarkdownBlock(
      data: message.text,
      selectable: true,
      config: base.copy(
        configs: [
          PConfig(textStyle: theme.textTheme.bodyMedium!),
          PreConfig(
            textStyle: const TextStyle(fontSize: 13),
            styleNotMatched: const TextStyle(fontSize: 13),
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          CodeConfig(
            style: TextStyle(backgroundColor: scheme.surfaceContainerHighest),
          ),
          TableConfig(
            wrapper: (child) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: child,
            ),
          ),
          LinkConfig(
            style: TextStyle(
              color: scheme.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
      generator: MarkdownGenerator(
        linesMargin: const EdgeInsets.symmetric(vertical: 4),
      ),
    );
  }
}

class _ToolCallCard extends StatelessWidget {
  const _ToolCallCard({required this.text, this.autoApproved = false});
  final String text;
  final bool autoApproved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final separator = text.indexOf('\n');
    final title = separator < 0
        ? text
        : text.substring(0, separator).replaceFirst(RegExp(r':\s*$'), '');
    final content = separator < 0 ? '' : text.substring(separator + 1);
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      backgroundColor: scheme.surfaceContainerHighest,
      collapsedBackgroundColor: scheme.surfaceContainerHighest,
      visualDensity: VisualDensity.compact,
      title: Row(
        children: [
          Icon(Symbols.terminal, size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
          ),
          if (autoApproved) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Auto-approved',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
      children: [
        SelectableText(
          content,
          style: TextStyle(
            fontFamily: MaidKitFonts.mono,
            fontSize: 12,
            height: 1.4,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _ProposalCard extends StatelessWidget {
  const _ProposalCard({
    required this.proposal,
    required this.serverName,
    required this.working,
    required this.reconnectRequired,
    required this.onApprove,
    required this.onDecline,
  });

  final AgentProposal proposal;
  final String serverName;
  final bool working;
  final bool reconnectRequired;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Icon(Symbols.terminal, size: 16, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    proposal.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  proposal.detail,
                  style: TextStyle(
                    fontFamily: MaidKitFonts.mono,
                    fontSize: 12,
                    height: 1.4,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Target: $serverName',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: working ? null : onApprove,
                      icon: Icon(
                        reconnectRequired
                            ? Symbols.refresh
                            : Symbols.play_arrow,
                      ),
                      label: Text(
                        reconnectRequired
                            ? 'Reconnect & resume'
                            : 'Approve & run',
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: working ? null : onDecline,
                      child: const Text('Decline'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentThinkingIndicator extends StatelessWidget {
  const _AgentThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Agent is working…',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
