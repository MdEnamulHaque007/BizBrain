import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

/// Reads release history from GitHub and keeps a Hive copy for offline use.
///
/// GitHub is the shared source of truth, so the history is available across
/// devices. Hive is only a local cache and survives app restarts.
class ReleaseHistoryService {
  ReleaseHistoryService({http.Client? client}) : _client = client ?? http.Client();

  static const String _repository = 'MdEnamulHaque007/BizBrain';
  static const String _boxName = 'release_history_v1';
  final http.Client _client;

  Future<ReleaseHistoryResult> load() async {
    final cached = await _readCache();
    try {
      final responses = await Future.wait<http.Response>([
        _client.get(
          Uri.https('api.github.com', '/repos/$_repository/commits', {
            'per_page': '30',
          }),
          headers: const {'Accept': 'application/vnd.github+json'},
        ),
        _client.get(
          Uri.https('api.github.com', '/repos/$_repository/actions/runs', {
            'per_page': '100',
          }),
          headers: const {'Accept': 'application/vnd.github+json'},
        ),
      ]);

      if (responses[0].statusCode != 200 || responses[1].statusCode != 200) {
        throw StateError(
          'GitHub returned HTTP ${responses[0].statusCode}/${responses[1].statusCode}.',
        );
      }

      final commits = jsonDecode(responses[0].body) as List<dynamic>;
      final runPayload = jsonDecode(responses[1].body) as Map<String, dynamic>;
      final runs = (runPayload['workflow_runs'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final runsBySha = <String, Map<String, dynamic>>{};
      for (final run in runs) {
        final sha = run['head_sha']?.toString();
        if (sha != null && sha.isNotEmpty && !runsBySha.containsKey(sha)) {
          runsBySha[sha] = run;
        }
      }

      final entries = commits.whereType<Map<String, dynamic>>().map((item) {
        final commit = item['commit'] as Map<String, dynamic>? ?? const {};
        final author = commit['author'] as Map<String, dynamic>? ?? const {};
        final sha = item['sha']?.toString() ?? '';
        final message = (commit['message']?.toString() ?? 'Update').split('\n').first;
        final run = runsBySha[sha];
        return ReleaseHistoryEntry(
          sha: sha,
          message: message,
          date: DateTime.tryParse(author['date']?.toString() ?? '')?.toLocal(),
          url: item['html_url']?.toString() ?? 'https://github.com/$_repository/commits/main',
          releaseType: _releaseType(message),
          status: _status(run),
          workflowUrl: run?['html_url']?.toString(),
        );
      }).toList();

      await _writeCache(entries);
      return ReleaseHistoryResult(entries: entries, fromCache: false);
    } catch (error) {
      if (cached.isNotEmpty) {
        return ReleaseHistoryResult(
          entries: cached,
          fromCache: true,
          message: 'GitHub could not be reached. Showing the saved history.',
        );
      }
      return ReleaseHistoryResult(
        entries: const [],
        fromCache: false,
        message: 'Release history is unavailable right now: $error',
      );
    }
  }

  Future<List<ReleaseHistoryEntry>> _readCache() async {
    try {
      final box = await _openBox();
      final value = box.get('entries');
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((item) => ReleaseHistoryEntry.fromJson(
                Map<String, dynamic>.from(item),
              ))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeCache(List<ReleaseHistoryEntry> entries) async {
    try {
      final box = await _openBox();
      await box.put('entries', entries.map((entry) => entry.toJson()).toList());
    } catch (_) {
      // A cache failure must not hide successfully fetched GitHub history.
    }
  }

  Future<Box<dynamic>> _openBox() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box<dynamic>(_boxName);
    return Hive.openBox<dynamic>(_boxName);
  }

  static String _status(Map<String, dynamic>? run) {
    if (run == null) return 'No workflow run';
    if (run['status'] != 'completed') return 'In progress';
    switch (run['conclusion']?.toString()) {
      case 'success':
        return 'Success';
      case 'failure':
      case 'timed_out':
      case 'cancelled':
        return 'Failed';
      case 'skipped':
        return 'Skipped';
      default:
        return 'Completed';
    }
  }

  static String _releaseType(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('fix') || lower.contains('bug')) return 'Bug Fix';
    if (lower.contains('feat') || lower.contains('add')) return 'Feature';
    if (lower.contains('refactor') || lower.contains('improv')) {
      return 'Improvement';
    }
    if (lower.contains('doc')) return 'Documentation';
    return 'Update';
  }
}

class ReleaseHistoryResult {
  const ReleaseHistoryResult({
    required this.entries,
    required this.fromCache,
    this.message,
  });

  final List<ReleaseHistoryEntry> entries;
  final bool fromCache;
  final String? message;
}

class ReleaseHistoryEntry {
  const ReleaseHistoryEntry({
    required this.sha,
    required this.message,
    required this.date,
    required this.url,
    required this.releaseType,
    required this.status,
    required this.workflowUrl,
  });

  final String sha;
  final String message;
  final DateTime? date;
  final String url;
  final String releaseType;
  final String status;
  final String? workflowUrl;

  Map<String, dynamic> toJson() => {
        'sha': sha,
        'message': message,
        'date': date?.toIso8601String(),
        'url': url,
        'releaseType': releaseType,
        'status': status,
        'workflowUrl': workflowUrl,
      };

  factory ReleaseHistoryEntry.fromJson(Map<String, dynamic> json) =>
      ReleaseHistoryEntry(
        sha: json['sha']?.toString() ?? '',
        message: json['message']?.toString() ?? 'Update',
        date: DateTime.tryParse(json['date']?.toString() ?? ''),
        url: json['url']?.toString() ?? '',
        releaseType: json['releaseType']?.toString() ?? 'Update',
        status: json['status']?.toString() ?? 'Unknown',
        workflowUrl: json['workflowUrl']?.toString(),
      );
}
