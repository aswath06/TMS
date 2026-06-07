import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

Future<void> downloadFileImpl(List<int> bytes, String fileName) async {
  final tempDir = await getTemporaryDirectory();
  final file = File("${tempDir.path}/$fileName");
  await file.writeAsBytes(bytes);
  await OpenFilex.open(file.path);
}
