import 'dart:convert';

import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/presentation/providers/google_sheets_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(List<SheetCacheModel> sources) async {
    final question = _controller.text.trim();
    if (question.isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage(text: question, isUser: true));
      _controller.clear();
    });

    try {
      final context = {
        'sources': sources.map((source) => {
          'name': source.sourceLabel,
          'sheetName': source.sheetName,
          'columns': source.columns,
          'rows': source.rows,
        }).toList(),
      };

      final response = await http.post(
        Uri.parse('/api/ai-chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'question': question,
          'businessContext': context,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(data['error']?.toString() ?? 'AI backend request failed.');
      }

      final answer = data['answer']?.toString().trim();
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(
        text: answer?.isNotEmpty == true ? answer! : 'AI backend কোনো উত্তর দেয়নি।',
        isUser: false,
      )));
    } catch (error) {
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(
        text: 'AI backend-এর সাথে সংযোগ করা যায়নি: $error',
        isUser: false,
      )));
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
                      onPressed: () => _send(items),
                      icon: const Icon(Icons.send),
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
