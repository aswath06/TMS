import 'dart:convert';

void main() {
  String message = "Exception: {\"success\":false,\"message\":\"Chromium not found inside backend container\"}";
  
  String parsedMessage = message;
  bool parsedIsError = true;

  try {
    // Check if message contains JSON
    final startIndex = message.indexOf('{');
    final endIndex = message.lastIndexOf('}');
    
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      final jsonStr = message.substring(startIndex, endIndex + 1);
      final json = jsonDecode(jsonStr);
      
      if (json is Map) {
        if (json.containsKey('message')) {
          parsedMessage = json['message'].toString();
        }
        if (json.containsKey('success')) {
          parsedIsError = json['success'] == false;
        }
      }
    }
  } catch (e) {
    // Not valid JSON or failed to parse, keep original
  }

  print("Parsed Message: \$parsedMessage");
  print("Parsed isError: \$parsedIsError");
}
