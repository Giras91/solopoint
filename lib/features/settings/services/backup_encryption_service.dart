import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

/// Encryption service for securing backup files
class BackupEncryptionService {
  /// Generate a deterministic encryption key from app name
  /// In production, consider using a user-specific secret or secure storage
  static String get _appSecret => 'solopoint_backup_secret_key_2026';

  /// Derive a 32-byte key from the app secret
  static encrypt.Key get _encryptionKey {
    // Create a 32-byte key by hashing the secret multiple times
    final derived = _appSecret
        .split('')
        .fold<List<int>>([], (acc, char) => [...acc, char.codeUnitAt(0)])
        .take(32)
        .toList();
    
    // Pad if necessary
    while (derived.length < 32) {
      derived.add(0);
    }
    
    return encrypt.Key(Uint8List.fromList(derived.sublist(0, 32)));
  }

  /// Encrypt database file
  /// Returns encrypted bytes with IV prepended
  static Future<List<int>> encryptFile(File file) async {
    final bytes = await file.readAsBytes();
    return encryptBytes(bytes);
  }

  /// Encrypt raw bytes
  static List<int> encryptBytes(List<int> data) {
    final key = _encryptionKey;
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    
    final encrypted = encrypter.encryptBytes(data, iv: iv);
    
    // Prepend IV to encrypted data (IV + ciphertext)
    return [...iv.bytes, ...encrypted.bytes];
  }

  /// Decrypt database file
  static Future<List<int>> decryptFile(File file) async {
    final bytes = await file.readAsBytes();
    return decryptBytes(bytes);
  }

  /// Decrypt raw bytes
  /// Expects IV prepended to ciphertext
  static List<int> decryptBytes(List<int> data) {
    if (data.length < 16) {
      throw Exception('Invalid encrypted data: too short');
    }

    final key = _encryptionKey;
    
    // Extract IV (first 16 bytes) and ciphertext (rest)
    final ivBytes = Uint8List.fromList(data.sublist(0, 16));
    final ciphertextBytes = Uint8List.fromList(data.sublist(16));
    
    final iv = encrypt.IV(ivBytes);
    final encrypted = encrypt.Encrypted(ciphertextBytes);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    
    try {
      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
      return decrypted;
    } catch (e) {
      throw Exception('Failed to decrypt backup: ${e.toString()}');
    }
  }

  /// Calculate MD5 checksum of file
  static Future<String> calculateChecksum(File file) async {
    final bytes = await file.readAsBytes();
    return md5.convert(bytes).toString();
  }

  /// Calculate MD5 checksum of bytes
  static String calculateBytesChecksum(List<int> bytes) {
    return md5.convert(bytes).toString();
  }

  /// Verify integrity by comparing checksums
  static bool verifyChecksum(List<int> data, String expectedChecksum) {
    final calculatedChecksum = md5.convert(data).toString();
    return calculatedChecksum == expectedChecksum;
  }
}
