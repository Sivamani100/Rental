import 'dart:io';

void main() {
  final dir = Directory('lib');
  
  for (final file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      String content = file.readAsStringSync();
      bool modified = false;

      if (content.contains('CupertinoCupertinoIcons')) {
        content = content.replaceAll('CupertinoCupertinoIcons', 'CupertinoIcons');
        modified = true;
      }
      if (content.contains('FontAwesomeCupertinoIcons')) {
        content = content.replaceAll('FontAwesomeCupertinoIcons', 'FontAwesomeIcons');
        modified = true;
      }
      if (content.contains('CupertinoIcons.device_tablet')) {
        content = content.replaceAll('CupertinoIcons.device_tablet', 'CupertinoIcons.device_laptop');
        modified = true;
      }
      if (content.contains('CupertinoIcons.doc_arrow_down')) {
        content = content.replaceAll('CupertinoIcons.doc_arrow_down', 'CupertinoIcons.arrow_down_doc');
        modified = true;
      }

      if (modified) {
        file.writeAsStringSync(content);
        print('Fixed');
      }
    }
  }
}
