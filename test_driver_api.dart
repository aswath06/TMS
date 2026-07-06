import 'package:tripzo/store/user_store.dart';
import 'package:tripzo/utils/api_constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final token = await UserStore.getToken();
  final response = await http.get(Uri.parse(ApiConstants.getAllDriversWithoutPagination), headers: ApiConstants.getHeaders(token));
  print(response.body);
}
