import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:goblink_park/screens/api_connection/api_config.dart';
import 'package:goblink_park/screens/login_screen/auth_service.dart';
import 'package:goblink_park/screens/reports/my_reports_screen.dart';
import 'package:goblink_park/screens/reports/new_report_category_screen.dart';
import 'package:goblink_park/screens/reports/report_detail_screen.dart';
import 'package:goblink_park/widgets/notification_bell_button.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const _baseUrl = ApiConfig.baseUrl;

  List<dynamic> _reportes = [];
  bool _isLoading = true;
  String _selectedCategory = 'Todos';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReportes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReportes() async {
    debugPrint('>>> GET Reportes solicitado');
    setState(() => _isLoading = true);
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/reportes'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 50));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        List<dynamic> data;
        if (body is List) {
          data = body;
        } else if (body is Map && body.containsKey('content')) {
          data = body['content'] as List;
        } else {
          data = [];
        }

        setState(() {
          _reportes = data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _matchesCategory(dynamic r, String catKey) {
    final cat = (r['categoriaNombre'] ?? r['categoria']?['nombre'] ?? '')
        .toString()
        .toLowerCase();
    switch (catKey.toLowerCase()) {
      case 'flora':
        return cat.contains('flora') ||
            cat.contains('vegetal') ||
            cat.contains('árbol') ||
            cat.contains('bosque');
      case 'fauna':
        return cat.contains('fauna') ||
            cat.contains('animal') ||
            cat.contains('avistamiento') ||
            cat.contains('ave');
      case 'suelo':
        return cat.contains('suelo') || cat.contains('tierra');
      case 'agua':
        return cat.contains('agua') ||
            cat.contains('hídric') ||
            cat.contains('río') ||
            cat.contains('quebrada') ||
            cat.contains('laguna');
      case 'aire':
        return cat.contains('aire') ||
            cat.contains('clima') ||
            cat.contains('viento') ||
            cat.contains('atmósfer');
      default:
        return true;
    }
  }

  int get _countTodos => _reportes.length;
  int get _countFlora => _reportes.where((r) => _matchesCategory(r, 'flora')).length;
  int get _countFauna => _reportes.where((r) => _matchesCategory(r, 'fauna')).length;
  int get _countSuelo => _reportes.where((r) => _matchesCategory(r, 'suelo')).length;
  int get _countAgua => _reportes.where((r) => _matchesCategory(r, 'agua')).length;
  int get _countAire => _reportes.where((r) => _matchesCategory(r, 'aire')).length;

  List<dynamic> get _filteredReportes {
    return _reportes.where((r) {
      if (_selectedCategory != 'Todos' && !_matchesCategory(r, _selectedCategory)) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final titulo = (r['titulo'] ?? '').toString().toLowerCase();
        final desc = (r['descripcion'] ?? '').toString().toLowerCase();
        final sector = (r['sector'] ?? r['ubicacionTexto'] ?? r['direccionReferencia'] ?? '').toString().toLowerCase();
        final cat = (r['categoriaNombre'] ?? '').toString().toLowerCase();
        if (!titulo.contains(q) && !desc.contains(q) && !sector.contains(q) && !cat.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  String _categoryAsset(String? categoria) {
    final c = (categoria ?? '').toLowerCase();
    if (c.contains('fauna') || c.contains('animal')) return 'assets/images/Fauna.jpg';
    if (c.contains('suelo') || c.contains('tierra')) return 'assets/images/Suelo.jpg';
    if (c.contains('agua') || c.contains('hídric')) return 'assets/images/Agua.jpg';
    if (c.contains('aire') || c.contains('clima')) return 'assets/images/Aire.jpg';
    return 'assets/images/Flora.jpg';
  }

  Color _getCategoryColor(String? cat) {
    final c = cat?.toLowerCase() ?? '';
    if (c.contains('fauna') || c.contains('animal')) return const Color(0xFF9A6735);
    if (c.contains('flora') || c.contains('vegetal')) return const Color(0xFF1E5E3A);
    if (c.contains('suelo') || c.contains('tierra')) return const Color(0xFF8C5E48);
    if (c.contains('agua') || c.contains('hídric')) return const Color(0xFF2563EB);
    if (c.contains('aire') || c.contains('clima')) return const Color(0xFF0284C7);
    return const Color(0xFF1E5E3A);
  }

  Color _getStatusColor(String? status) {
    final s = status?.toLowerCase() ?? '';
    if (s.contains('valid') || s.contains('aprob')) return const Color(0xFF15803D);
    if (s.contains('revis')) return const Color(0xFF2563EB);
    return const Color(0xFFD97706);
  }

  Color _getStatusBgColor(String? status) {
    final s = status?.toLowerCase() ?? '';
    if (s.contains('valid') || s.contains('aprob')) return const Color(0xFFDCFCE7);
    if (s.contains('revis')) return const Color(0xFFEFF6FF);
    return const Color(0xFFFEF3C7);
  }

  String? _getReportImageUrl(Map<String, dynamic> r) {
    final fotoPrincipal = r['fotoPrincipalUrl'] ?? r['fotoUrl'] ?? r['imagenUrl'] ?? r['urlFoto'] ?? r['foto'];
    if (fotoPrincipal != null && fotoPrincipal.toString().trim().isNotEmpty) {
      final str = fotoPrincipal.toString().trim();
      if (str.startsWith('http://') || str.startsWith('https://')) {
        return str;
      }
    }
    final evidencias = r['evidencias'];
    if (evidencias is List && evidencias.isNotEmpty) {
      for (final ev in evidencias) {
        if (ev is Map) {
          final evUrl = ev['archivoUrl'] ?? ev['url'] ?? ev['urlArchivo'];
          if (evUrl != null && evUrl.toString().trim().isNotEmpty) {
            final str = evUrl.toString().trim();
            if (str.startsWith('http://') || str.startsWith('https://')) {
              return str;
            }
          }
        }
      }
    }
    return null;
  }

  int _getEvidenceCount(Map<String, dynamic> r) {
    final ev = r['evidencias'];
    if (ev is List) return ev.length;
    if (r['fotoPrincipalUrl'] != null && r['fotoPrincipalUrl'].toString().isNotEmpty) {
      return 1;
    }
    return 0;
  }

  int _getCommentCount(Map<String, dynamic> r) {
    final c = r['comentarios'];
    if (c is List) return c.length;
    return 0;
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return 'Reciente';
    try {
      final dt = DateTime.parse(dateVal.toString());
      const months = [
        'ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      final str = dateVal.toString();
      if (str.length >= 10) return str.substring(0, 10);
      return str;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryBg = theme.scaffoldBackgroundColor;
    final cardBg = theme.colorScheme.surface;
    final titleColor = isDark ? theme.colorScheme.onSurface : const Color(0xFF0F3A22);

    return Scaffold(
      backgroundColor: primaryBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildInstitutionalHeader(titleColor),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF1E5E3A),
                onRefresh: _loadReportes,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitleSection(titleColor, isDark),
                          _buildMyReportsBanner(cardBg, isDark),
                          _buildSearchField(cardBg, isDark),
                          _buildFilterChips(),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                    if (_isLoading)
                      const SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(color: Color(0xFF1E5E3A)),
                        ),
                      )
                    else if (_filteredReportes.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(isDark),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = Map<String, dynamic>.from(_filteredReportes[index]);
                              return _buildReportCard(item, cardBg, isDark);
                            },
                            childCount: _filteredReportes.length,
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 80),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1E5E3A),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add, size: 22),
        label: const Text(
          'Nuevo reporte',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const NewReportCategoryScreen(),
            ),
          ).then((value) {
            if (value == true) _loadReportes();
          });
        },
      ),
    );
  }

  Widget _buildInstitutionalHeader(Color titleColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          ClipOval(
            child: Image.asset(
              'assets/images/Logo verde.png',
              width: 38,
              height: 38,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E5E3A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.park, color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Goblin Park",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFFE8F5E9) : const Color(0xFF0F3A22),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  "PNR Páramo del Duende",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFFA3B899) : const Color(0xFF2E4F3E),
                  ),
                ),
              ],
            ),
          ),
          const NotificationBellButton(),
        ],
      ),
    );
  }

  Widget _buildTitleSection(Color titleColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Reportes",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: titleColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            "Observaciones de flora, fauna, suelo, agua y aire del Páramo del Duende",
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyReportsBanner(Color cardBg, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2D24) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1E5E3A).withAlpha(60),
          width: 1.2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyReportsScreen()),
            ).then((_) => _loadReportes());
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E5E3A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_pin_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Mis reportes",
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFE8F5E9) : const Color(0xFF0F3A22),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        "Consulta y gestiona las observaciones registradas por ti",
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFFA3B899) : const Color(0xFF2E4F3E),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(Color cardBg, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF1F2937),
        ),
        decoration: InputDecoration(
          hintText: "Buscar reportes por título, sector...",
          hintStyle: TextStyle(
            fontSize: 13.5,
            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
          ),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280), size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF9CA3AF), size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).colorScheme.surface;

    final categories = [
      {'name': 'Todos', 'count': _countTodos, 'icon': null},
      {'name': 'Flora', 'count': _countFlora, 'icon': Icons.eco},
      {'name': 'Fauna', 'count': _countFauna, 'icon': Icons.pets},
      {'name': 'Suelo', 'count': _countSuelo, 'icon': Icons.landscape},
      {'name': 'Agua', 'count': _countAgua, 'icon': Icons.water_drop},
      {'name': 'Aire', 'count': _countAire, 'icon': Icons.air},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: categories.map((cat) {
          final name = cat['name'] as String;
          final count = cat['count'] as int;
          final icon = cat['icon'] as IconData?;
          final isSelected = _selectedCategory == name;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedCategory = name),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1E5E3A) : (isDark ? cardBg : Colors.white),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1E5E3A)
                          : (isDark ? const Color(0x26FFFFFF) : const Color(0xFFE5E7EB)),
                      width: 1.2,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          size: 14,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A)),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? const Color(0xFFE8F5E9) : const Color(0xFF374151)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withAlpha(50)
                              : (isDark ? const Color(0xFF222E27) : const Color(0xFFF3F4F6)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          count.toString(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? Colors.white
                                : (isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> r, Color cardBg, bool isDark) {
    final catNombre = r['categoriaNombre'] ?? r['categoria']?['nombre'] ?? 'Flora';
    final estadoNombre = r['estadoReporteNombre'] ?? r['estado']?['nombre'] ?? 'Validado';
    final titulo = r['titulo']?.toString().isNotEmpty == true
        ? r['titulo'].toString()
        : 'Observación en el Páramo';
    final sector = r['sector'] ?? r['ubicacionTexto'] ?? r['direccionReferencia'] ?? 'Sector Páramo del Duende';
    final fecha = _formatDate(r['fechaReporte'] ?? r['fechaCreacion']);
    final imgUrl = _getReportImageUrl(r);
    final evCount = _getEvidenceCount(r);
    final comCount = _getCommentCount(r);

    final catColor = _getCategoryColor(catNombre);
    final statusColor = _getStatusColor(estadoNombre);
    final statusBg = isDark ? statusColor.withAlpha(40) : _getStatusBgColor(estadoNombre);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0x26FFFFFF) : const Color(0xFFE5E7EB),
          width: 1.1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReportDetailScreen(reporte: r),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Imagen a la izquierda (90x90)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: imgUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imgUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 600,
                            placeholder: (context, url) => Container(
                              color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[200],
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E5E3A)),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Image.asset(
                              _categoryAsset(catNombre),
                              fit: BoxFit.cover,
                            ),
                          )
                        : Image.asset(
                            _categoryAsset(catNombre),
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // 2. Información en columna
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fila de Badges
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: catColor.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              catNombre,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: catColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              estadoNombre,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Título
                      Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFFE8F5E9) : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Ubicación
                      Row(
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 13,
                            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              sector,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Fecha y contadores de evidencia y comentarios
                      Row(
                        children: [
                          Text(
                            fecha,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Icon(
                                Icons.camera_alt_outlined,
                                size: 13,
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                evCount.toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 12,
                                color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                comCount.toString(),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B2620) : const Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 36,
                color: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "No se encontraron reportes",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFE8F5E9) : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? "No hay coincidencias con \"$_searchQuery\" en esta categoría."
                  : "Sé el primero en registrar una observación en esta categoría.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}
