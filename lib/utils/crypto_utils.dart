import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:typed_data';

class CryptoUtils {
  static const String _secretKey = "sureshaswath05!";

  static String decryptOTP(String encryptedOtp) {
    if (encryptedOtp.isEmpty) return "";
    try {
      final keyBytes = sha256.convert(utf8.encode(_secretKey)).bytes;
      final key = encrypt.Key(Uint8List.fromList(keyBytes));
      final iv = encrypt.IV(Uint8List(16)); // All zeros, matching Node.js Buffer.alloc(16, 0)

      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
      final decrypted = encrypter.decrypt(encrypt.Encrypted.fromBase16(encryptedOtp), iv: iv);
      return decrypted;
    } catch (e) {
      // If decryption fails, it might not be hex or correctly padded
      return encryptedOtp;
    }
  }
}
