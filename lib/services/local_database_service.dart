import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class LocalDatabaseService {
  static final LocalDatabaseService instance = LocalDatabaseService._init();
  static Database? _database;
  static const Uuid _uuid = Uuid();

  LocalDatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('goblinpark_offline.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE reportes_offline (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_uuid TEXT UNIQUE,
        titulo TEXT,
        categoria TEXT,
        prioridad TEXT,
        descripcion TEXT,
        latitud REAL,
        longitud REAL,
        foto_ruta_local TEXT,
        fecha_creacion TEXT,
        estado_sincronizacion TEXT,
        reintentos INTEGER DEFAULT 0,
        sector TEXT,
        municipio TEXT,
        datos_especificos TEXT,
        fotos_adicionales TEXT
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      for (final col in [
        'sector TEXT',
        'municipio TEXT',
        'datos_especificos TEXT',
        'fotos_adicionales TEXT',
      ]) {
        try {
          await db.execute('ALTER TABLE reportes_offline ADD COLUMN $col');
        } catch (_) {}
      }
    }
  }

  /// Genera un identificador único local (clientUuid)
  static String generateClientUuid() => _uuid.v4();

  /// Comprime una fotografía a máx. 1080px y calidad ~75% (< 500 KB objetivo)
  /// y la guarda de forma persistente en getApplicationDocumentsDirectory().
  static Future<File> compressAndSavePhoto(File sourceFile) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final offlineDir = Directory(p.join(docsDir.path, 'offline_reports'));
    if (!await offlineDir.exists()) {
      await offlineDir.create(recursive: true);
    }

    final fileName =
        'rep_${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4().substring(0, 8)}.jpg';
    final targetPath = p.join(offlineDir.path, fileName);

    try {
      final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
        sourceFile.absolute.path,
        targetPath,
        minWidth: 1080,
        minHeight: 1080,
        quality: 75,
        format: CompressFormat.jpeg,
      );

      if (compressed != null) {
        final compressedFile = File(compressed.path);
        if (await compressedFile.exists()) {
          final sizeKb = (await compressedFile.length()) / 1024;
          debugPrint(
            '>>> Foto comprimida exitosamente: ${compressedFile.path} (${sizeKb.toStringAsFixed(1)} KB)',
          );
          return compressedFile;
        }
      }
    } catch (e) {
      debugPrint('>>> Fallback copia directa de foto offline: $e');
    }

    // Fallback seguro si el compresor nativo falla
    return await sourceFile.copy(targetPath);
  }

  /// Comprime y persiste una lista de fotografías para almacenamiento offline
  static Future<List<File>> compressAndSavePhotos(List<File> files) async {
    final List<File> saved = [];
    for (final f in files) {
      if (await f.exists()) {
        saved.add(await compressAndSavePhoto(f));
      }
    }
    return saved;
  }

  /// Inserta un reporte en la cola local `reportes_offline` con estado 'PENDIENTE'
  Future<int> insertOfflineReport({
    String? clientUuid,
    required String titulo,
    required String categoria,
    required String prioridad,
    required String descripcion,
    required double latitud,
    required double longitud,
    required String fotoRutaLocal,
    List<String>? fotosAdicionales,
    String? fechaCreacion,
    String estadoSincronizacion = 'PENDIENTE',
    int reintentos = 0,
    String? sector,
    String? municipio,
    Map<String, dynamic>? datosEspecificos,
  }) async {
    final db = await database;
    final uuidStr = (clientUuid != null && clientUuid.isNotEmpty)
        ? clientUuid
        : generateClientUuid();

    final row = <String, dynamic>{
      'client_uuid': uuidStr,
      'titulo': titulo,
      'categoria': categoria,
      'prioridad': prioridad,
      'descripcion': descripcion,
      'latitud': latitud,
      'longitud': longitud,
      'foto_ruta_local': fotoRutaLocal,
      'fecha_creacion': fechaCreacion ?? DateTime.now().toIso8601String(),
      'estado_sincronizacion': estadoSincronizacion,
      'reintentos': reintentos,
      'sector': sector ?? '',
      'municipio': municipio ?? '',
      'datos_especificos':
          datosEspecificos != null ? jsonEncode(datosEspecificos) : '',
      'fotos_adicionales':
          fotosAdicionales != null ? jsonEncode(fotosAdicionales) : '',
    };

    return await db.insert(
      'reportes_offline',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Obtiene todos los reportes pendientes de sincronización ('PENDIENTE' o 'ERROR')
  Future<List<Map<String, dynamic>>> getPendingReports({
    bool includeError = true,
  }) async {
    final db = await database;
    final whereClause = includeError
        ? "estado_sincronizacion IN ('PENDIENTE', 'ERROR')"
        : "estado_sincronizacion = 'PENDIENTE'";

    return await db.query(
      'reportes_offline',
      where: whereClause,
      orderBy: 'id ASC',
    );
  }

  /// Obtiene todos los reportes almacenados en la cola local
  Future<List<Map<String, dynamic>>> getAllOfflineReports() async {
    final db = await database;
    return await db.query('reportes_offline', orderBy: 'id DESC');
  }

  /// Retorna la cantidad de reportes pendientes por subir
  Future<int> getPendingCount() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as total FROM reportes_offline WHERE estado_sincronizacion IN ('PENDIENTE', 'ERROR', 'SUBIENDO')",
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Actualiza el estado de sincronización y el contador de reintentos
  Future<int> updateSyncStatus({
    required int id,
    required String estadoSincronizacion,
    int? reintentos,
  }) async {
    final db = await database;
    final values = <String, dynamic>{
      'estado_sincronizacion': estadoSincronizacion,
    };
    if (reintentos != null) {
      values['reintentos'] = reintentos;
    }
    return await db.update(
      'reportes_offline',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Elimina un reporte de la cola local tras sincronización exitosa
  Future<int> deleteOfflineReport(int id) async {
    final db = await database;
    return await db.delete(
      'reportes_offline',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
