import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:goblink_park/screens/api_connection/api_config.dart';
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:goblink_park/screens/reports/my_reports_screen.dart';
import 'package:goblink_park/screens/reports/report_submitted_success_screen.dart';
import 'package:goblink_park/services/local_database_service.dart';
import 'package:goblink_park/services/sync_service.dart';

class ReviewReportScreen extends StatefulWidget {
  final String category;
  final String title;
  final String description;
  final DateTime dateTime;
  final String priority;
  final List<File> photos;
  final Map<String, dynamic> specificData;
  final LatLng location;
  final String sector;
  final String municipio;

  const ReviewReportScreen({
    super.key,
    required this.category,
    required this.title,
    required this.description,
    required this.dateTime,
    required this.priority,
    required this.photos,
    required this.specificData,
    required this.location,
    required this.sector,
    required this.municipio,
  });

  @override
  State<ReviewReportScreen> createState() => _ReviewReportScreenState();
}

class _ReviewReportScreenState extends State<ReviewReportScreen> {
  static const _baseUrl = ApiConfig.baseUrl;

  bool _confirmCorrect = false;
  bool _confirmAuth = false;
  bool _isSubmitting = false;
  late List<File> _currentPhotos;

  @override
  void initState() {
    super.initState();
    _currentPhotos = List.from(widget.photos);
  }

  String _categoryAsset(String cat) {
    switch (cat.toLowerCase()) {
      case 'fauna':
        return 'assets/images/Fauna.jpg';
      case 'suelo':
        return 'assets/images/Suelo.jpg';
      case 'agua':
        return 'assets/images/Agua.jpg';
      case 'aire':
        return 'assets/images/Aire.jpg';
      default:
        return 'assets/images/Flora.jpg';
    }
  }

  Color _getPriorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'alta':
        return const Color(0xFFEF4444);
      case 'media':
        return const Color(0xFFF59E0B);
      case 'baja':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} · $hour:$minute';
  }

  Future<void> _addPhoto() async {
    if (_currentPhotos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo 5 evidencias')),
      );
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1080,
      maxHeight: 1080,
    );
    if (picked != null) {
      final compressed =
          await LocalDatabaseService.compressAndSavePhoto(File(picked.path));
      if (!mounted) return;
      setState(() {
        _currentPhotos.add(compressed);
      });
    }
  }

  Future<int?> _resolveCategoriaId(String token) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/categorias'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        for (final item in list) {
          final nom = (item['nombre'] ?? '').toString().toLowerCase();
          if (nom.contains(widget.category.toLowerCase())) {
            return item['id'] as int;
          }
        }
        if (list.isNotEmpty) return list.first['id'] as int;
      }
    } catch (_) {}
    final c = widget.category.toLowerCase();
    if (c.contains('fauna')) return 2;
    if (c.contains('agua')) return 3;
    if (c.contains('suelo')) return 4;
    if (c.contains('aire')) return 5;
    return 1;
  }

  Future<int?> _resolvePrioridadId(String token) async {
    try {
      final res = await http
          .get(
            Uri.parse('$_baseUrl/api/prioridades'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        for (final item in list) {
          final nom = (item['nombre'] ?? '').toString().toLowerCase();
          if (nom.contains(widget.priority.toLowerCase())) {
            return item['id'] as int;
          }
        }
        if (list.isNotEmpty) return list.first['id'] as int;
      }
    } catch (_) {}
    final p = widget.priority.toLowerCase();
    if (p.contains('alta')) return 1;
    if (p.contains('baja')) return 3;
    return 2;
  }

  Future<void> _saveToOfflineQueueAndRedirect({
    required String clientUuid,
    required List<File> persistedPhotos,
  }) async {
    final String primaryPhotoPath =
        persistedPhotos.isNotEmpty ? persistedPhotos.first.path : '';
    final List<String> extraPhotoPaths = persistedPhotos.length > 1
        ? persistedPhotos.skip(1).map((f) => f.path).toList()
        : [];

    await LocalDatabaseService.instance.insertOfflineReport(
      clientUuid: clientUuid,
      titulo: widget.title,
      categoria: widget.category,
      prioridad: widget.priority,
      descripcion: widget.description,
      latitud: widget.location.latitude,
      longitud: widget.location.longitude,
      fotoRutaLocal: primaryPhotoPath,
      fotosAdicionales: extraPhotoPaths,
      fechaCreacion: widget.dateTime.toIso8601String(),
      estadoSincronizacion: 'PENDIENTE',
      reintentos: 0,
      sector: widget.sector,
      municipio: widget.municipio,
      datosEspecificos: widget.specificData,
    );

    await SyncService.instance.refreshPendingCount();

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sin conexión: El reporte se guardó de forma segura en tu teléfono y se subirá automáticamente cuando tengas señal.',
        ),
        backgroundColor: Color(0xFF1E5E3A),
        duration: Duration(seconds: 5),
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MyReportsScreen()),
      (route) => route.isFirst,
    );
  }

  Future<void> _submitReport() async {
    if (!_confirmCorrect || !_confirmAuth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar ambos consentimientos para continuar'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final String clientUuid = LocalDatabaseService.generateClientUuid();
    List<File> persistedPhotos = [];

    try {
      // 1. Comprimir las fotos a máx. 1080px y calidad ~75% y guardarlas en getApplicationDocumentsDirectory()
      persistedPhotos =
          await LocalDatabaseService.compressAndSavePhotos(_currentPhotos);

      // 2. Comprobar la conexión a internet
      final bool hasInternet = await SyncService.hasInternetConnection();
      if (!hasInternet) {
        await _saveToOfflineQueueAndRedirect(
          clientUuid: clientUuid,
          persistedPhotos: persistedPhotos,
        );
        return;
      }

      // 3. Si hay internet: intentar envío al backend incluyendo clientUuid
      final token = await AuthService.getToken();
      final catId = await _resolveCategoriaId(token ?? '');
      final prioId = await _resolvePrioridadId(token ?? '');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/reportes'),
      );

      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['clientUuid'] = clientUuid;
      request.fields['titulo'] = widget.title;
      request.fields['descripcion'] = widget.description;
      request.fields['categoriaId'] = (catId ?? 1).toString();
      request.fields['prioridadId'] = (prioId ?? 2).toString();
      request.fields['latitud'] = widget.location.latitude.toString();
      request.fields['longitud'] = widget.location.longitude.toString();
      request.fields['direccionReferencia'] =
          '${widget.sector}, ${widget.municipio}';
      request.fields['sector'] = widget.sector;
      request.fields['municipio'] = widget.municipio;
      request.fields['fuente'] = 'mobile';
      if (widget.specificData.isNotEmpty) {
        request.fields['datosEspecificos'] = jsonEncode(widget.specificData);
      }

      for (int i = 0; i < persistedPhotos.length; i++) {
        final file = persistedPhotos[i];
        final ext = file.path.split('.').last.toLowerCase();
        String mime = 'image/jpeg';
        if (ext == 'png') {
          mime = 'image/png';
        } else if (ext == 'webp') {
          mime = 'image/webp';
        }

        request.files.add(
          await http.MultipartFile.fromPath(
            'evidencias',
            file.path,
            filename: file.path.split(Platform.isWindows ? '\\' : '/').last,
            contentType: MediaType.parse(mime),
          ),
        );
      }

      final streamedRes =
          await request.send().timeout(const Duration(seconds: 35));
      final response = await http.Response.fromStream(streamedRes);

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        Map<String, dynamic> responseData;
        try {
          responseData = jsonDecode(response.body);
        } catch (_) {
          responseData = {
            'id': DateTime.now().millisecondsSinceEpoch % 10000,
            'titulo': widget.title,
            'categoriaNombre': widget.category,
            'fechaReporte': widget.dateTime.toIso8601String(),
          };
        }

        if (responseData['datosEspecificos'] == null &&
            widget.specificData.isNotEmpty) {
          responseData['datosEspecificos'] = widget.specificData;
        }
        if (responseData['sector'] == null) {
          responseData['sector'] = widget.sector;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ReportSubmittedSuccessScreen(reporteData: responseData),
          ),
        );
      } else if (response.statusCode >= 500 || response.statusCode == 408) {
        // Respaldo automático en cola offline ante indisponibilidad temporal del servidor
        await _saveToOfflineQueueAndRedirect(
          clientUuid: clientUuid,
          persistedPhotos: persistedPhotos.isNotEmpty
              ? persistedPhotos
              : _currentPhotos,
        );
      } else {
        String errorMsg = 'Error del servidor (${response.statusCode})';
        try {
          final errBody = jsonDecode(response.body);
          if (errBody is Map && errBody['message'] != null) {
            errorMsg = errBody['message'].toString();
          } else if (errBody is Map && errBody['error'] != null) {
            errorMsg = errBody['error'].toString();
          }
        } catch (_) {
          if (response.body.isNotEmpty) {
            errorMsg = response.body;
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Si la petición falla por timeout o caída de red, guardar automáticamente en la cola offline
      await _saveToOfflineQueueAndRedirect(
        clientUuid: clientUuid,
        persistedPhotos:
            persistedPhotos.isNotEmpty ? persistedPhotos : _currentPhotos,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBg = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F3A22);

    final bool canSubmit = _confirmCorrect && _confirmAuth && !_isSubmitting;

    return Scaffold(
      backgroundColor: primaryBg,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: isDark ? Colors.white : const Color(0xFF0F3A22),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Confirmar reporte",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F3A22),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepIndicator(4, "Confirmar la información", isDark: isDark),
                    const SizedBox(height: 12),
                    Text(
                      "Revisa tu observación",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Verifica que todos los datos y evidencias sean correctos antes de enviar",
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Banner Superior de Resumen
                    _buildHeaderBanner(cardBg, isDark),
                    const SizedBox(height: 14),

                    // Tarjeta de Ubicación
                    _buildLocationCard(cardBg, isDark),
                    const SizedBox(height: 14),

                    // Detalles Específicos
                    _buildSpecificDetailsCard(cardBg, isDark),
                    const SizedBox(height: 14),

                    // Descripción
                    _buildDescriptionCard(cardBg, isDark),
                    const SizedBox(height: 14),

                    // Galería de Evidencias
                    _buildEvidenceGallery(cardBg, isDark),
                    const SizedBox(height: 16),

                    // Consentimientos
                    _buildConsentSection(isDark),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _buildBottomBar(canSubmit),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int currentStep, String stepTitle, {bool isDark = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (index) {
            final stepNum = index + 1;
            final isDone = stepNum < currentStep;
            final isCurrent = stepNum == currentStep;
            final color = isDone || isCurrent
                ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF1E5E3A))
                : (isDark ? const Color(0xFF374151) : const Color(0xFFD1D5DB));

            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index < 3 ? 6 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          "Paso $currentStep de 4 • $stepTitle",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF1E5E3A),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderBanner(Color cardBg, bool isDark) {
    final prioColor = _getPriorityColor(widget.priority);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen representativa de la categoría
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: SizedBox(
              width: double.infinity,
              height: 140,
              child: Image.asset(_categoryAsset(widget.category), fit: BoxFit.cover),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.category,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E5E3A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: prioColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: prioColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "Prioridad: ${widget.priority}",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: prioColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatDateTime(widget.dateTime),
                      style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(Color cardBg, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.place_outlined, color: Color(0xFF1E5E3A), size: 18),
              SizedBox(width: 6),
              Text(
                "Ubicación y Sector",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F3A22)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "${widget.sector} · ${widget.municipio}",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "GPS: ${widget.location.latitude.toStringAsFixed(4)}° N, ${widget.location.longitude.toStringAsFixed(4)}° W",
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecificDetailsCard(Color cardBg, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, color: Color(0xFF1E5E3A), size: 18),
              SizedBox(width: 6),
              Text(
                "Detalles de la observación",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F3A22)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...widget.specificData.entries.map((entry) {
            final val = entry.value is List ? (entry.value as List).join(', ') : entry.value.toString();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${_capitalize(entry.key)}: ",
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                  ),
                  Expanded(
                    child: Text(
                      val.isNotEmpty ? val : 'No especificado',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  Widget _buildDescriptionCard(Color cardBg, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notes_rounded, color: Color(0xFF1E5E3A), size: 18),
              SizedBox(width: 6),
              Text(
                "Descripción registrada",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F3A22)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.description,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : const Color(0xFF374151),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEvidenceGallery(Color cardBg, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.photo_library_outlined, color: Color(0xFF1E5E3A), size: 18),
                  SizedBox(width: 6),
                  Text(
                    "Evidencias adjuntas",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F3A22)),
                  ),
                ],
              ),
              if (_currentPhotos.length < 5)
                InkWell(
                  onTap: _addPhoto,
                  child: const Text(
                    "+ Agregar más",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E5E3A)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_currentPhotos.isEmpty)
            const Text(
              "No se adjuntaron fotos directas.",
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            )
          else
            SizedBox(
              height: 75,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _currentPhotos.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 75,
                        height: 75,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(_currentPhotos[index], fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 10,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _currentPhotos.removeAt(index));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConsentSection(bool isDark) {
    return Column(
      children: [
        CheckboxListTile(
          value: _confirmCorrect,
          activeColor: const Color(0xFF1E5E3A),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            "Confirmo que la información es correcta y corresponde a mi observación.",
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white70 : const Color(0xFF374151),
            ),
          ),
          onChanged: (val) => setState(() => _confirmCorrect = val ?? false),
        ),
        CheckboxListTile(
          value: _confirmAuth,
          activeColor: const Color(0xFF1E5E3A),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            "Autorizo el uso de esta información para fines de conservación, monitoreo e investigación.",
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white70 : const Color(0xFF374151),
            ),
          ),
          onChanged: (val) => setState(() => _confirmAuth = val ?? false),
        ),
      ],
    );
  }

  Widget _buildBottomBar(bool canSubmit) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: const Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: canSubmit ? _submitReport : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E5E3A),
            disabledBackgroundColor: const Color(0xFF9CA3AF),
            elevation: canSubmit ? 2 : 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _isSubmitting
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    SizedBox(width: 10),
                    Text(
                      "Enviando reporte...",
                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Enviar reporte",
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
