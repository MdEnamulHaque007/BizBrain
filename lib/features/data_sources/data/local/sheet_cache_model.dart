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
    this.sourceLabel,
    this.sourceInput,
    this.dataRange,
    this.headerRow = 1,
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
  @HiveField(9)
  final String? sourceLabel;
  @HiveField(10)
  final String? sourceInput;
  @HiveField(11)
  final String? dataRange;
  @HiveField(12)
  final int headerRow;

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
    'sourceLabel': sourceLabel,
    'sourceInput': sourceInput,
    'dataRange': dataRange,
    'headerRow': headerRow,
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
    sourceLabel: json['sourceLabel'] as String?,
    sourceInput: json['sourceInput'] as String?,
    dataRange: json['dataRange'] as String?,
    headerRow: json['headerRow'] as int? ?? 1,
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
    String? sourceLabel,
    bool clearSourceLabel = false,
    String? sourceInput,
    String? dataRange,
    int? headerRow,
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
      sourceLabel: clearSourceLabel ? null : (sourceLabel ?? this.sourceLabel),
      sourceInput: sourceInput ?? this.sourceInput,
      dataRange: dataRange ?? this.dataRange,
      headerRow: headerRow ?? this.headerRow,
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
            other.version == version &&
            other.sourceLabel == sourceLabel &&
            other.sourceInput == sourceInput &&
            other.dataRange == dataRange &&
            other.headerRow == headerRow);
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
    sourceLabel,
    sourceInput,
    dataRange,
    headerRow,
  );
}
