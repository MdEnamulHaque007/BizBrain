import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/presentation/providers/google_sheets_providers.dart';
import 'package:bizbrain/features/organizations/presentation/providers/organization_providers.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[
    const _ChatMessage(
      text: 'Ask me about your connected business data. For example: আজ Cutting কত হয়েছে?',
      isUser: false,
    ),
  ];
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(List<SheetCacheModel> sources) async {
    final question = _controller.text.trim();
    if (question.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_ChatMessage(text: question, isUser: true));
      _controller.clear();
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final businessContext = {
        'sources': sources.map((source) => {
          'name': source.sourceLabel,
          'sheetName': source.sheetName,
          'columns': source.columns,
          'rows': source.rows,
        }).toList(),
      };

      // Callable Functions attach the signed-in user's Firebase Auth token.
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-south1',
      ).httpsCallable('aiChat');

      final response = await callable.call(<String, dynamic>{
        'question': question,
        'businessContext': businessContext,
      });

      final data = Map<String, dynamic>.from(response.data as Map);
      final answer = data['answer']?.toString().trim();
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(
        text: answer?.isNotEmpty == true ? answer! : 'AI backend কোনো উত্তর দেয়নি।',
        isUser: false,
      )));
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'deadline-exceeded' => 'AI সেবা সময় শেষ হয়েছে। কিছুক্ষণ পরে আবার চেষ্টা করুন।',
        'unauthenticated' => 'AI Chat ব্যবহার করতে প্রথমে লগইন করুন।',
        'invalid-argument' => 'প্রশ্ন বা business data সঠিকভাবে পাঠানো যায়নি।',
        'not-found' => 'Firebase-এর aiChat function deploy করা নেই বা পাওয়া যায়নি।',
        'unavailable' => 'AI সেবা এখন পাওয়া যাচ্ছে না। কিছুক্ষণ পরে আবার চেষ্টা করুন।',
        _ => 'AI অনুরোধ ব্যর্থ হয়েছে (${error.code}): ${error.message ?? 'অজানা ত্রুটি'}',
      };
      setState(() => _messages.add(_ChatMessage(text: message, isUser: false)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(
        text: 'AI backend-এর সাথে সংযোগ করা যায়নি: $error',
        isUser: false,
      )));
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Only the active organization's cached sheets may feed the chat context.
    final organizationId = ref.watch(activeOrganizationProvider)?.id ?? '';
    final sources = ref.watch(sourcesListProvider(organizationId));
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.primary, colors.tertiary],
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(Icons.auto_awesome_rounded, color: colors.onPrimary),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Chat'),
                Text('Business data assistant',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
              ],
            ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.primary.withValues(alpha: 0.045),
              colors.surface,
              colors.tertiary.withValues(alpha: 0.035),
            ],
          ),
        ),
        child: sources.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Could not load business data: $e'),
            ),
          ),
          data: (items) => Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                  itemCount: _messages.length + (_isSending ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isSending && index == _messages.length) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: colors.outlineVariant),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 17,
                                height: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.tertiary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text('AI is thinking…'),
                            ],
                          ),
                        ),
                      );
                    }
                    final message = _messages[index];
                    return Align(
                      alignment: message.isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 720),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          gradient: message.isUser
                              ? LinearGradient(
                                  colors: [colors.primary, colors.tertiary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: message.isUser ? null : colors.surface,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(message.isUser ? 20 : 5),
                            bottomRight: Radius.circular(message.isUser ? 5 : 20),
                          ),
                          border: message.isUser
                              ? null
                              : Border.all(color: colors.outlineVariant),
                          boxShadow: [
                            BoxShadow(
                              color: colors.shadow.withValues(alpha: 0.045),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          message.text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                            color: message.isUser ? colors.onPrimary : colors.onSurface,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border(top: BorderSide(color: colors.outlineVariant)),
                    boxShadow: [
                      BoxShadow(
                        color: colors.shadow.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(items),
                          decoration: InputDecoration(
                            hintText: 'Ask about your business data…',
                            filled: true,
                            fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.55),
                            prefixIcon: Icon(Icons.chat_bubble_outline_rounded,
                                color: colors.primary),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: colors.outlineVariant),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: colors.primary, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 52,
                        width: 52,
                        child: IconButton.filled(
                          onPressed: _isSending ? null : () => _send(items),
                          style: IconButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                          icon: const Icon(Icons.send_rounded),
                          tooltip: 'Send message',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.isUser});
  final String text;
  final bool isUser;
}
