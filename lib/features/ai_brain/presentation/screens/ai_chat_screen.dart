import 'package:bizbrain/features/data_sources/data/local/sheet_cache_model.dart';
import 'package:bizbrain/features/data_sources/presentation/providers/google_sheets_providers.dart';
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send(List<SheetCacheModel> sources) {
    final question = _controller.text.trim();
    if (question.isEmpty) return;
    final answer = _answer(question, sources);
    setState(() {
      _messages.add(_ChatMessage(text: question, isUser: true));
      _messages.add(_ChatMessage(text: answer, isUser: false));
      _controller.clear();
    });
  }

  String _answer(String question, List<SheetCacheModel> sources) {
    final q = question.toLowerCase();
    final stage = q.contains('cutting') || q.contains('কাটিং')
        ? 'cutting'
        : q.contains('sewing') || q.contains('সুইং') || q.contains('সোয়িং')
            ? 'sewing'
            : null;
    if (stage == null) {
      return 'Cutting বা Sewing উল্লেখ করে PO, color, article, quantity বা date সম্পর্কে প্রশ্ন করুন।';
    }
    final source = sources.cast<SheetCacheModel?>().firstWhere((s) {
      final name = '${s?.sourceLabel ?? ''} ${s?.sheetName ?? ''}'.toLowerCase();
      return name.contains(stage);
    }, orElse: () => null);
    if (source == null) return '${stage == 'cutting' ? 'Cutting' : 'Sewing'} data source পাওয়া যায়নি।';

    final date = _extractDate(question);
    final po = _extractFilter(question, source, const ['po no', 'po number', 'pono', 'po']);
    final article = _extractFilter(question, source, const ['article', 'article no', 'article number', 'article code']);
    final rows = source.rows.where((row) {
      if (date != null && !_rowMatchesDate(row, date)) return false;
      if (po != null && !_matches(row, const ['po no', 'po number', 'pono', 'po'], po)) return false;
      if (article != null && !_matches(row, const ['article', 'article no', 'article number', 'article code'], article)) return false;
      return true;
    }).toList();

    final wantsColor = q.contains('color') || q.contains('colour') || q.contains('কালার') || q.contains('রং');
    if (wantsColor) {
      final colors = _distinct(rows, const ['color', 'colour', 'color code', 'colour code']);
      if (colors.isEmpty) return 'এই filter অনুযায়ী কোনো color পাওয়া যায়নি।';
      return 'মোট ${colors.length}টি color আছে: ${colors.join(', ')}।';
    }

    final wantsArticle = q.contains('article') || q.contains('আর্টিকেল');
    if (wantsArticle && (q.contains('কত') || q.contains('how many') || q.contains('list') || q.contains('কি কি'))) {
      final articles = _distinct(rows, const ['article', 'article no', 'article number', 'article code']);
      if (articles.isEmpty) return 'এই filter অনুযায়ী কোনো article পাওয়া যায়নি।';
      return 'মোট ${articles.length}টি article আছে: ${articles.join(', ')}।';
    }

    var total = 0.0;
    var matched = 0;
    for (final row in rows) {
      final qty = _quantity(row);
      if (qty == null) continue;
      total += qty;
      matched++;
    }
    if (matched == 0) return 'এই প্রশ্নের filter অনুযায়ী কোনো matching quantity পাওয়া যায়নি।';
    final label = stage == 'cutting' ? 'Cutting' : 'Sewing';
    return 'Matching $label quantity মোট ${_qty(total)} pairs ($matched rows)।';
  }

  String? _extractFilter(String question, SheetCacheModel source, List<String> aliases) {
    final q = question.toLowerCase();
    final values = _distinct(source.rows, aliases)..sort((a, b) => b.length.compareTo(a.length));
    for (final value in values) {
      if (value.isNotEmpty && q.contains(value.toLowerCase())) return value;
    }
    return null;
  }

  bool _matches(Map<String, String> row, List<String> aliases, String value) {
    final wanted = value.trim().toLowerCase();
    for (final entry in row.entries) {
      if (!aliases.contains(entry.key.trim().toLowerCase())) continue;
      if (entry.value.trim().toLowerCase() == wanted) return true;
    }
    return false;
  }

  List<String> _distinct(List<Map<String, String>> rows, List<String> aliases) {
    final values = <String>{};
    for (final row in rows) {
      for (final entry in row.entries) {
        if (!aliases.contains(entry.key.trim().toLowerCase())) continue;
        final value = entry.value.trim();
        if (value.isNotEmpty) values.add(value);
      }
    }
    final result = values.toList()..sort();
    return result;
  }

  DateTime? _extractDate(String text) {
    final iso = RegExp(r'(\\d{4})[-/](\\d{1,2})[-/](\\d{1,2})').firstMatch(text);
    if (iso != null) return DateTime(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!));
    final dmy = RegExp(r'(\\d{1,2})[-/](\\d{1,2})[-/](\\d{4})').firstMatch(text);
    if (dmy != null) return DateTime(int.parse(dmy.group(3)!), int.parse(dmy.group(2)!), int.parse(dmy.group(1)!));
    return null;
  }

  bool _rowMatchesDate(Map<String, String> row, DateTime target) {
    for (final entry in row.entries) {
      if (!entry.key.toLowerCase().contains('date')) continue;
      final value = entry.value.trim();
      final parts = RegExp(r'(\\d{1,4})[-/](\\d{1,2})[-/](\\d{1,4})').firstMatch(value);
      if (parts == null) continue;
      final a = int.parse(parts.group(1)!);
      final b = int.parse(parts.group(2)!);
      final c = int.parse(parts.group(3)!);
      final parsed = a > 31 ? DateTime(a, b, c) : DateTime(c, b, a);
      if (parsed.year == target.year && parsed.month == target.month && parsed.day == target.day) return true;
    }
    return false;
  }

  double? _quantity(Map<String, String> row) {
    const aliases = ['quantity', 'qty', 'pairs', 'order qty', 'order quantity'];
    for (final entry in row.entries) {
      final key = entry.key.trim().toLowerCase();
      if (!aliases.contains(key)) continue;
      return double.tryParse(entry.value.replaceAll(',', '').trim());
    }
    return null;
  }

  String _dateLabel(DateTime d) => '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  String _qty(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

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
