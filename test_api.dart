import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:tripzo/services/api_constants.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'auth_token': 'test_token'});
  // Wait, I can't access the real SharedPreferences from a test environment like this easily without running the app.
}
