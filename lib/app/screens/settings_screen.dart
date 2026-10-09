import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _models = const ['gpt-5.6', 'gpt-5.6-mini', 'gpt-5.6-nano'];
  String _provider = 'openai';
  String _model = 'gpt-5.6';
  bool _loading = true;
  bool _saving = false;
  String? _message;

  FirebaseFunctions get _functions => FirebaseFunctions.instanceFor(region: 'asia-south1');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await _functions.httpsCallable('getAiModelSettings').call();
      final data = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;
      setState(() {
        _provider = data['provider']?.toString() ?? 'openai';
        final saved = data['model']?.toString() ?? 'gpt-5.6';
        _model = _models.contains(saved) ? saved : 'gpt-5.6';
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() { _saving = true; _message = null; });
    try {
      await _functions.httpsCallable('saveAiModelSettings').call({
        'provider': _provider,
        'model': _model,
      });
      if (!mounted) return;
      setState(() { _saving = false; _message = 'AI model settings saved.'; });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _message = e.message ?? e.code; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _message = 'Could not save settings: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text('AI Model Settings', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('Choose the model used by AI Chat. API keys remain on the secure backend and are never displayed here.'),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  initialValue: _provider,
                  decoration: const InputDecoration(labelText: 'Provider', border: OutlineInputBorder()),
                  items: const [DropdownMenuItem(value: 'openai', child: Text('OpenAI'))],
                  onChanged: (v) => setState(() => _provider = v ?? 'openai'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _model,
                  decoration: const InputDecoration(labelText: 'Model', border: OutlineInputBorder()),
                  items: _models.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                  onChanged: (v) => setState(() => _model = v ?? _model),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save AI Settings'),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(_message!),
                ],
              ],
            ),
    );
  }
}
