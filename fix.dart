import 'dart:io';

void main() {
  final file = File('lib/features/groups/views/group_home_view.dart');
  final bytes = file.readAsBytesSync();
  final newBytes = bytes.where((b) => b != 0).toList();
  file.writeAsBytesSync(newBytes);
}
