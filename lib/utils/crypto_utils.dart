import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class CryptoUtils {
  static const String _secretKey = "sureshaswath05!";

  static String decryptOTP(String encryptedOtp) {
    if (encryptedOtp.isEmpty) return "";
    try {
      final cleanInput = encryptedOtp.trim().toLowerCase();
      final keyBytes = sha256.convert(utf8.encode(_secretKey)).bytes;
      final key = encrypt.Key(Uint8List.fromList(keyBytes));
      final iv = encrypt.IV(Uint8List(16)); // All zeros

      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'));
      
      final encrypted = encrypt.Encrypted.fromBase16(cleanInput);
      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      return decrypted;
    } catch (e) {
      debugPrint("Decryption error: $e");
      return encryptedOtp;
    }
  }

  static String encryptOTP(String otp) {
    if (otp.isEmpty) return "";
    try {
      final cleanOtp = otp.toString().trim();
      final keyBytes = sha256.convert(utf8.encode(_secretKey)).bytes;
      final key = encrypt.Key(Uint8List.fromList(keyBytes));
      final iv = encrypt.IV(Uint8List(16)); // All zeros

      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'));
      final encrypted = encrypter.encrypt(cleanOtp, iv: iv);
      return encrypted.base16.toLowerCase();
    } catch (e) {
      debugPrint("Encryption error: $e");
      return otp;
    }
  }
}
