import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:goblink_park/screens/api_connection/api_config.dart';
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:goblink_park/screens/reports/complete_report_form_screen.dart';
import 'package:goblink_park/widgets/notification_bell_button.dart';

class NewReportCategoryScreen extends StatefulWidget {
  const NewReportCategoryScreen({super.key});

  @override
  State<NewReportCategoryScreen> createState() => _NewReportCategoryScreenState();
}

class _NewReportCategoryScreenState extends State<NewReportCategoryScreen> {
  List<dynamic> _categorias = [];
  bool _isLoading = true;

  // Catálogo local de respaldo por si el dispositivo está offline en campo
  static final List<Map<String, dynamic>> _defaultCategorias = [
    {
      'id': 1,
      'nombre': 'Flora',
      'descripcion': 'Plantas nativas, frailejones y otras especies de páramo.',
      'image': 'assets/images/Flora.jpg',
      'color': '#1E5E3A',
      'estado': true,
    },
    {
      'id': 2,
      'nombre': 'Fauna',
      'descripcion': 'Animales silvestres y sus evidencias.',
      'image': 'assets/images/Fauna.jpg',
      'color': '#9A6735',
      'estado': true,
    },
    {
      'id': 3,
      'nombre': 'Suelo',
      'descripcion': 'Estado del suelo, erosión y cambios en el terreno.',
      'image': 'assets/images/Suelo.jpg',
      'color': '#8C5E48',
      'estado': true,
    },
    {
      'id': 4,
      'nombre': 'Agua',
      'descripcion': 'Fuentes hídricas, calidad del agua y alteraciones.',
      'image': 'assets/images/Agua.jpg',
      'color': '#2563EB',
      'estado': true,
    },
    {
      'id': 5,
      'nombre': 'Aire',
      'descripcion': 'Calidad del aire, humo, quemas y condiciones atmosféricas.',
      'image': 'assets/images/Aire.jpg',
      'color': '#0284C7',
      'estado': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadCategorias();
  }

  Future<void> _loadCategorias() async {
    debugPrint('>>> GET Categorias solicitado');
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/categorias'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 50));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        List<dynamic> list = [];
        if (body is List) {
          list = body;
        } else if (body is Map && body.containsKey('content')) {
          list = (body['content'] as List?) ?? [];
        }

        // Filtrar solo categorías con estado == true
        final activas = list.where((cat) {
          final estado = cat['estado'];
          if (estado == null) return true;
          if (estado is bool) return estado;
          final s = estado.toString().toLowerCase();
          return s == 'true' || s == 'activo';
        }).toList();

        setState(() {
          _categorias = activas.isNotEmpty ? activas : _defaultCategorias;
          _isLoading = false;
        });
      } else {
        setState(() {
          _categorias = _defaultCategorias;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categorias = _defaultCategorias;
        _isLoading = false;
      });
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return const Color(0xFF1E5E3A);
    try {
      String cleanHex = hex.replaceAll('#', '').trim();
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      return Color(int.parse(cleanHex, radix: 16));
    } catch (_) {
      return const Color(0xFF1E5E3A);
    }
  }

  IconData _getIconForCategory(String nombre) {
    final lower = nombre.toLowerCase().trim();
    if (lower.contains('flora') || lower.contains('vegetal') || lower.contains('planta')) {
      return Icons.eco;
    } else if (lower.contains('fauna') || lower.contains('animal') || lower.contains('oso') || lower.contains('ave')) {
      return Icons.pets;
    } else if (lower.contains('agua') || lower.contains('hidric') || lower.contains('hídric') || lower.contains('rio') || lower.contains('río') || lower.contains('laguna')) {
      return Icons.water_drop;
    } else if (lower.contains('aire') || lower.contains('clima') || lower.contains('viento') || lower.contains('atmos')) {
      return Icons.air;
    } else if (lower.contains('suelo') || lower.contains('tierra') || lower.contains('erosion') || lower.contains('erosión') || lower.contains('terreno')) {
      return Icons.landscape;
    }
    return Icons.category_rounded;
  }

  String? _getFallbackAsset(String nombre) {
    final lower = nombre.toLowerCase().trim();
    if (lower.contains('flora')) return 'assets/images/Flora.jpg';
    if (lower.contains('fauna')) return 'assets/images/Fauna.jpg';
    if (lower.contains('suelo')) return 'assets/images/Suelo.jpg';
    if (lower.contains('agua')) return 'assets/images/Agua.jpg';
    if (lower.contains('aire')) return 'assets/images/Aire.jpg';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBg = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F3A22);

    return Scaffold(
      backgroundColor: primaryBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildInstitutionalHeader(context, titleColor, isDark),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadCategorias,
                color: const Color(0xFF1E5E3A),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    _buildStepIndicator(1, "Selección de categoría"),
                    const SizedBox(height: 12),
                    Text(
                      "Nuevo reporte",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Selecciona la categoría del reporte que deseas registrar",
                      style: TextStyle(
                        fontSize: 13.5,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading && _categorias.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF1E5E3A),
                          ),
                        ),
                      )
                    else
                      ..._categorias.map((cat) => _buildCategoryCard(context, cat, isDark)),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstitutionalHeader(BuildContext context, Color titleColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: isDark ? Colors.white : const Color(0xFF0F3A22),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          ClipOval(
            child: Image.asset(
              'assets/images/Logo verde.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E5E3A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.park, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Goblin Park",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  "PNR Páramo del Duende",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF2E4F3E),
                  ),
                ),
              ],
            ),
          ),
          const NotificationBellButton(size: 24),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int currentStep, String stepTitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (index) {
            final stepNum = index + 1;
            final isDone = stepNum < currentStep;
            final isCurrent = stepNum == currentStep;
            final color = isDone || isCurrent ? const Color(0xFF1E5E3A) : const Color(0xFFD1D5DB);

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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E5E3A),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(BuildContext context, dynamic cat, bool isDark) {
    final String nombre = (cat['nombre'] ?? cat['title'] ?? '').toString();
    final String? descripcion = (cat['descripcion'] ?? cat['desc'])?.toString();
    final String? imageUrl = (cat['imagenUrl'] ?? cat['imagen_url'])?.toString();
    final String colorHex = (cat['color'] ?? '#1E5E3A').toString();
    final Color accentColor = _parseColor(colorHex);
    final String? localAsset = (cat['image'] ?? _getFallbackAsset(nombre))?.toString();
    final IconData icon = _getIconForCategory(nombre);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      height: 105,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: accentColor.withValues(alpha: 0.15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 1. Imagen de fondo dinámica con CachedNetworkImage y memCacheWidth: 600
          if (imageUrl != null &&
              imageUrl.isNotEmpty &&
              (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')))
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 600,
                placeholder: (context, url) => Container(
                  color: accentColor.withValues(alpha: 0.2),
                ),
                errorWidget: (context, url, error) => localAsset != null
                    ? Image.asset(localAsset, fit: BoxFit.cover)
                    : Container(color: accentColor.withValues(alpha: 0.3)),
              ),
            )
          else if (localAsset != null)
            Positioned.fill(
              child: Image.asset(
                localAsset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: accentColor.withValues(alpha: 0.3),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                color: accentColor.withValues(alpha: 0.35),
              ),
            ),

          // 2. Gradiente translúcido para legibilidad del texto
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.black.withValues(alpha: 0.35),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 3. Borde sutil institucional
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
          ),

          // 4. Contenido interactivo con InkWell
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CompleteReportFormScreen(category: nombre),
                  ),
                );
                if (context.mounted && result == true) {
                  Navigator.pop(context, true);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Círculo del icono temático
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.35),
                        border: Border.all(
                          color: Colors.white30,
                          width: 1.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x4D000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Título y descripción
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            nombre,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black87,
                                  offset: Offset(0, 1.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          if (descripcion != null && descripcion.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              descripcion,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.25,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    offset: Offset(0, 1),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
