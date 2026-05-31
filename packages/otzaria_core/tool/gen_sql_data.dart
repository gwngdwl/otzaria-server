import 'dart:io';
void main() {
  final dir = Directory(r'C:/Users/user/otzaria-server/packages/otzaria_core/lib/src/database/sql');
  final files = dir.listSync().whereType<File>()
      .where((f) => f.path.endsWith('.sq'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final buf = StringBuffer()
    ..writeln('// GENERATED — do not edit by hand.')
    ..writeln('// Embeds the .sq query files so the package needs no runtime asset/file IO')
    ..writeln('// (works under AOT `dart compile exe`). Regenerate with tool/gen_sql_data.dart.')
    ..writeln()
    ..writeln('const Map<String, String> kEmbeddedSqlFiles = {');
  for (final f in files) {
    final name = f.uri.pathSegments.last;
    var content = f.readAsStringSync().replaceAll('\r\n', '\n');
    if (content.contains("'''")) {
      throw StateError('triple-quote in $name — cannot raw-embed');
    }
    buf.writeln("  '$name': r'''");
    buf.write(content);
    if (!content.endsWith('\n')) buf.writeln();
    buf.writeln("''',");
  }
  buf.writeln('};');
  File(r'C:/Users/user/otzaria-server/packages/otzaria_core/lib/src/database/sql/sql_queries_data.dart')
      .writeAsStringSync(buf.toString());
  print('wrote sql_queries_data.dart with ${files.length} files');
}
