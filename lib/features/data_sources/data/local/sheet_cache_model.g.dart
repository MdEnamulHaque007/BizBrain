// Hand-written Hive adapter. hive_generator is incompatible with the
// analyzer version required by this project's existing lint tooling.
part of 'sheet_cache_model.dart';

class SheetCacheModelAdapter extends TypeAdapter<SheetCacheModel> {
  @override
  final int typeId = 100;

  @override
  SheetCacheModel read(BinaryReader reader) {
    final fieldCount = reader.readByte();
    final fields = <int, dynamic>{
      for (var i = 0; i < fieldCount; i++) reader.readByte(): reader.read(),
    };
    return SheetCacheModel(
      sourceId: fields[0] as String,
      organizationId: fields[1] as String,
      sheetUrl: fields[2] as String,
      sheetName: fields[3] as String?,
      rows: (fields[4] as List)
          .map((row) => Map<String, String>.from(row as Map))
          .toList(growable: false),
      columns: List<String>.from(fields[5] as List),
      fetchedAt: fields[6] as DateTime,
      rowCount: fields[7] as int,
      version: fields[8] as int,
      sourceLabel: fields[9] as String?,
      sourceInput: fields[10] as String?,
      dataRange: fields[11] as String?,
      headerRow: fields[12] as int? ?? 1,
    );
  }

  @override
  void write(BinaryWriter writer, SheetCacheModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.sourceId)
      ..writeByte(1)
      ..write(obj.organizationId)
      ..writeByte(2)
      ..write(obj.sheetUrl)
      ..writeByte(3)
      ..write(obj.sheetName)
      ..writeByte(4)
      ..write(obj.rows)
      ..writeByte(5)
      ..write(obj.columns)
      ..writeByte(6)
      ..write(obj.fetchedAt)
      ..writeByte(7)
      ..write(obj.rowCount)
      ..writeByte(8)
      ..write(obj.version)
      ..writeByte(9)
      ..write(obj.sourceLabel)
      ..writeByte(10)
      ..write(obj.sourceInput)
      ..writeByte(11)
      ..write(obj.dataRange)
      ..writeByte(12)
      ..write(obj.headerRow);
  }
}
