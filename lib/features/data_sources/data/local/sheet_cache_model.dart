import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

part 'sheet_cache_model.g.dart';

@immutable
@HiveType(typeId: 100)
class SheetCacheModel {
  const SheetCacheModel({
    required this.sourceId,
    required this.organizationId,
    required this.sheetUrl,
    required this.sheetName,
    required this.rows,
    required this.columns,
    required this.fetchedAt,
    required this.rowCount,
    required this.version,
  });

  @HiveField(0)
  final String sourceId;
  @HiveField(1)
  final String organizationId;
  @HiveField(2)
  final String sheetUrl;
  @HiveField(3)
  final String? sheetName;

  /// Records keyed by header name (or positional column_{n}). Values are strings.
  @HiveField(4)
  final List<Map<String, String>> rows;
  @HiveField(5)
  final List<String> columns;
  @HiveField(6)
  final DateTime fetchedAt;
  @HiveField(7)
  final int rowCount;
  @HiveField(8)
  final int version;

  Map<String, dynamic> toJson() => {
    'sourceId': sourceId,
    'organizationId': organizationId,
    'sheetUrl': sheetUrl,
    'sheetName': sheetName,
    'rows': rows,
    'columns': columns,
    'fetchedAt': fetchedAt.toIso8601String(),
    'rowCount': rowCount,
    'version': version,
  };

  static SheetCacheModel fromJson(Map<String, dynamic> json) => SheetCacheModel(
    sourceId: json['sourceId'] as String,
    organizationId: json['organizationId'] as String,
    sheetUrl: json['sheetUrl'] as String,
    sheetName: json['sheetName'] as String?,
    rows: (json['rows'] as List<dynamic>)
        .map((e) => Map<String, String>.from(e as Map))
        .toList(),
    columns: List<String>.from(json['columns'] as List<dynamic>),
    fetchedAt: DateTime.parse(json['fetchedAt'] as String),
    rowCount: json['rowCount'] as int,
    version: json['version'] as int,
  );

  SheetCacheModel copyWith({
    String? sourceId,
    String? organizationId,
    String? sheetUrl,
    String? sheetName,
    List<Map<String, String>>? rows,
    List<String>? columns,
    DateTime? fetchedAt,
    int? rowCount,
    int? version,
  }) {
    return SheetCacheModel(
      sourceId: sourceId ?? this.sourceId,
      organizationId: organizationId ?? this.organizationId,
      sheetUrl: sheetUrl ?? this.sheetUrl,
      sheetName: sheetName ?? this.sheetName,
      rows: rows ?? this.rows,
      columns: columns ?? this.columns,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowCount: rowCount ?? this.rowCount,
      version: version ?? this.version,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is SheetCacheModel &&
            other.sourceId == sourceId &&
            other.organizationId == organizationId &&
            other.sheetUrl == sheetUrl &&
            other.sheetName == sheetName &&
            const DeepCollectionEquality().equals(other.rows, rows) &&
            const DeepCollectionEquality().equals(other.columns, columns) &&
            other.fetchedAt == fetchedAt &&
            other.rowCount == rowCount &&
            other.version == version);
  }

  @override
  int get hashCode => Object.hash(
    sourceId,
    organizationId,
    sheetUrl,
    sheetName,
    const DeepCollectionEquality().hash(rows),
    const DeepCollectionEquality().hash(columns),
    fetchedAt.toIso8601String(),
    rowCount,
    version,
  );
}
