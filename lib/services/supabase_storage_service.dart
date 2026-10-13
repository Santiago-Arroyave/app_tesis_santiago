import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SupabaseStorageService {
  static const String supabaseUrl = 'https://znkoxmkxkimteknuacya.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpua294bWt4a2ltdGVrbnVhY3lhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzOTEyMzcsImV4cCI6MjA5MTk2NzIzN30.lttj4lUWRSF661QQo-BrDvXDTatoCNiMrIRD-GNIybI';
  static const String bucketName = 'goblin-media';

  /// Sube un archivo de imagen al bucket goblin-media/reportes en Supabase Storage
  /// y retorna la URL pública directa del archivo subido.
  static Future<String?> uploadReportImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return await uploadBytes(
        bytes: bytes,
        originalPath: file.path,
        folder: 'reportes',
      );
    } catch (e) {
      debugPrint('Error al leer bytes para Supabase: $e');
      return null;
    }
  }

  /// Sube bytes de archivo a Supabase Storage
  static Future<String?> uploadBytes({
    required Uint8List bytes,
    required String originalPath,
    String folder = 'reportes',
  }) async {
    try {
      final ext = originalPath.split('.').last.toLowerCase();
      String mimeType = 'image/jpeg';
      String fileExt = '.jpg';

      if (ext == 'png') {
        mimeType = 'image/png';
        fileExt = '.png';
      } else if (ext == 'webp') {
        mimeType = 'image/webp';
        fileExt = '.webp';
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = Random().nextInt(999999);
      final fileName = 'evidencia_${timestamp}_$random$fileExt';
      final cleanFolder = folder.replaceAll(RegExp(r'^/+|/+$'), '');
      final objectPath = '$cleanFolder/$fileName';

      final uploadUrl = '$supabaseUrl/storage/v1/object/$bucketName/$objectPath';
      debugPrint('>>> Subiendo imagen a Supabase Storage: $uploadUrl (${bytes.length} bytes)');

      final response = await http.post(
        Uri.parse(uploadUrl),
        headers: {
          'apikey': anonKey,
          'Authorization': 'Bearer $anonKey',
          'Content-Type': mimeType,
          'x-upsert': 'true',
        },
        body: bytes,
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final publicUrl = '$supabaseUrl/storage/v1/object/public/$bucketName/$objectPath';
        debugPrint('>>> Imagen subida exitosamente a Supabase: $publicUrl');
        return publicUrl;
      } else {
        debugPrint('>>> Error en respuesta Supabase: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('>>> Excepción al subir a Supabase: $e');
      return null;
    }
  }
}
