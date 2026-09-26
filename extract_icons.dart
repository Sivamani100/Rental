import 'dart:io';

void main() {
  final dir = Directory('lib');
  final regex = RegExp(r'(Iconsax|Icons)\.([a-zA-Z0-9_]+)');
  final icons = <String>{};

  for (final file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      final content = file.readAsStringSync();
      final matches = regex.allMatches(content);
      for (final match in matches) {
        icons.add(match.group(0)!);
      }
    }
  }

  final sorted = icons.toList()..sort();
  print(sorted.join('\n'));
}
