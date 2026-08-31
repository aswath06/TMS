import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final loginResponse = await http.post(
    Uri.parse('http://localhost:4004/api/auth/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': 'faculty@tripzo.com',
      'password': 'password123'
    }),
  );
  print('Login: ${loginResponse.statusCode}');
  
  if (loginResponse.statusCode == 200) {
    final data = jsonDecode(loginResponse.body);
    final token = data['token'];
    
    final bResponse = await http.get(
      Uri.parse('http://localhost:4004/api/battery-vehicle-booking/my-bookings'),
      headers: {'Authorization': 'TMS $token'},
    );
    print('My Bookings: ${bResponse.statusCode}');
    print(bResponse.body);
    
    final allResponse = await http.get(
      Uri.parse('http://localhost:4004/api/battery-vehicle-booking/bookings'),
      headers: {'Authorization': 'TMS $token'},
    );
    print('All Bookings (as faculty): ${allResponse.statusCode}');
  }
}
