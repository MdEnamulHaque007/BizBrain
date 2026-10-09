import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/presentation/providers/google_sheets_providers.dart';
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
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(sourcesListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('AI Chat')),
      body: sources.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load business data: $e')),
        data: (items) => Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final m = _messages[index];
                  return Align(
                    alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 720),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: m.isUser ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(m.text),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        onSubmitted: (_) => _send(items),
                        decoration: const InputDecoration(
                          hintText: 'Ask about your business data…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _isSending ? null : () => _send(items),
                      icon: _isSending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send),
                      tooltip: 'Send',
                    ),
                  ],
                ),
              ),
            ),
          ],
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
