import 'dart:io';

void main() {
  for (var f in Directory('lib').listSync(recursive: true)) {
    if (f is File && f.path.endsWith('.dart')) {
      var s = f.readAsStringSync().replaceAll('\r\n', '\n');
      f.writeAsStringSync(s);
    }
  }
  print('Successfully normalized all dart files to LF');
}
