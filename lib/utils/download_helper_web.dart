import 'dart:html' as html;

Future<void> downloadFileImpl(List<int> bytes, String fileName) async {
  final blob = html.Blob([bytes], 'application/sql');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
