import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:goblink_park/screens/report_map/report_service.dart';
import 'package:goblink_park/screens/reports/new_report_category_screen.dart';
import 'package:goblink_park/screens/reports/report_detail_screen.dart';
import 'package:goblink_park/services/local_database_service.dart';
import 'package:goblink_park/services/sync_service.dart';
import 'package:goblink_park/widgets/notification_bell_button.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  List<dynamic> _myReports = [];
  bool _isLoading = true;
  String _selectedStatus = 'Todos';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<SyncResult>? _syncSub;

  @override
  void initState() {
    super.initState();
    SyncService.instance.refreshPendingCount();
    _syncSub = SyncService.instance.onSyncCompleted.listen((result) {
      if (!mounted) return;
      _loadMyReports();
      if (result.syncedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.syncedCount == 1
                  ? '1 reporte pendiente se sincronizó exitosamente.'
                  : '${result.syncedCount} reportes pendientes se sincronizaron exitosamente.',
            ),
            backgroundColor: const Color(0xFF1E5E3A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
    _loadMyReports();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMyReports() async {
    debugPrint('>>> GET Mis Reportes solicitado');
    setState(() => _isLoading = true);
    try {
      final offlineRows = await LocalDatabaseService.instance.getAllOfflineReports();
      await SyncService.instance.refreshPendingCount();

      final List<Map<String, dynamic>> offlineMapped = offlineRows.map((row) {
        final String localPhoto = (row['foto_ruta_local'] ?? '').toString();
        return <String, dynamic>{
          'id': row['id'],
          'clientUuid': row['client_uuid'],
          'titulo': row['titulo'],
          'descripcion': row['descripcion'],
          'categoriaNombre': row['categoria'],
          'prioridadNombre': row['prioridad'],
          'latitud': row['latitud'],
          'longitud': row['longitud'],
          'sector': (row['sector'] != null && row['sector'].toString().trim().isNotEmpty)
              ? row['sector']
              : 'Guardado en teléfono (Sin señal)',
          'municipio': row['municipio'],
          'fechaReporte': row['fecha_creacion'],
          'fechaCreacion': row['fecha_creacion'],
          'estadoReporteNombre': 'Pendiente',
          'fotoRutaLocal': localPhoto,
          'estadoSincronizacion': row['estado_sincronizacion'],
          'evidencias': localPhoto.isNotEmpty ? [{'urlArchivo': localPhoto}] : [],
          '_isOffline': true,
        };
      }).toList();

      List<dynamic> remoteReports = [];
      try {
        remoteReports = await ReportService.getMisReportes();
      } catch (e) {
        debugPrint('>>> Modo offline en Mis Reportes: $e');
      }

      if (!mounted) return;
      setState(() {
        _myReports = [...offlineMapped, ...remoteReports];
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleManualSync() async {
    final hasNet = await SyncService.hasInternetConnection();
    if (!hasNet) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aún no tienes conexión a internet. Tus reportes siguen seguros en el teléfono.',
          ),
          backgroundColor: Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final result = await SyncService.instance.syncPendingReports();
    if (!mounted) return;
    await _loadMyReports();
    if (!mounted) return;
    if (result.syncedCount == 0 && SyncService.instance.pendingCountNotifier.value > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudieron subir todos los reportes en este momento. Se reintentará automáticamente.',
          ),
          backgroundColor: Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _isConvertidoEnProyecto(dynamic r) {
    if (r is! Map) return false;
    if (r['esProyecto'] == true ||
        r['convertidoEnProyecto'] == true ||
        r['proyectoId'] != null) {
      return true;
    }
    final est = (r['estadoReporteNombre'] ??
            r['estado']?['nombre'] ??
            r['estadoReporte'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    return est == 'convertido_en_proyecto' ||
        est.contains('convertido') ||
        est.contains('proyecto');
  }

  bool _isPendiente(dynamic r) {
    if (r is! Map) return false;
    if (_isConvertidoEnProyecto(r)) return false;
    final est = (r['estadoReporteNombre'] ??
            r['estado']?['nombre'] ??
            r['estadoReporte'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();
    return est.isEmpty || est == 'pendiente' || est.contains('pendiente');
  }

  bool _matchesStatus(dynamic r, String statusKey) {
    switch (statusKey.toLowerCase()) {
      case 'pendientes':
      case 'pendiente':
        return _isPendiente(r);
      case 'convertidos en proyecto':
      case 'convertido en proyecto':
      case 'convertido_en_proyecto':
        return _isConvertidoEnProyecto(r);
      case 'todos':
      default:
        return true;
    }
  }

  int get _countTodos => _myReports.length;
  int get _countPendientes =>
      _myReports.where((r) => _matchesStatus(r, 'Pendientes')).length;
  int get _countConvertidos => _myReports
      .where((r) => _matchesStatus(r, 'Convertidos en proyecto'))
      .length;

  List<dynamic> get _filteredReports {
    return _myReports.where((r) {
      if (_selectedStatus != 'Todos' && !_matchesStatus(r, _selectedStatus)) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final titulo = (r['titulo'] ?? '').toString().toLowerCase();
        final desc = (r['descripcion'] ?? '').toString().toLowerCase();
        final sector = (r['sector'] ?? r['ubicacionTexto'] ?? r['direccionReferencia'] ?? '').toString().toLowerCase();
        if (!titulo.contains(q) && !desc.contains(q) && !sector.contains(q)) {
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
    if (s.contains('proyecto') ||
        s.contains('convertido') ||
        s.contains('valid') ||
        s.contains('aprob')) {
      return const Color(0xFF15803D);
    }
    if (s.contains('revis')) return const Color(0xFF2563EB);
    return const Color(0xFFD97706);
  }

  Color _getStatusBgColor(String? status) {
    final s = status?.toLowerCase() ?? '';
    if (s.contains('proyecto') ||
        s.contains('convertido') ||
        s.contains('valid') ||
        s.contains('aprob')) {
      return const Color(0xFFDCFCE7);
    }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBg = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F3A22);

    return Scaffold(
      backgroundColor: primaryBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildInstitutionalHeader(titleColor),
            Expanded(
              child: RefreshIndicator(
                color: const Color(0xFF1E5E3A),
                onRefresh: _loadMyReports,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitleSection(titleColor, isDark),
                          _buildOfflineSyncBanner(isDark),
                          _buildNewReportButton(),
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
                    else if (_filteredReports.isEmpty)
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
                              final item = Map<String, dynamic>.from(_filteredReports[index]);
                              return _buildReportCard(item, cardBg, isDark);
                            },
                            childCount: _filteredReports.length,
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 40),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineSyncBanner(bool isDark) {
    return ValueListenableBuilder<int>(
      valueListenable: SyncService.instance.pendingCountNotifier,
      builder: (context, pendingCount, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: SyncService.instance.isSyncingNotifier,
          builder: (context, isSyncing, _) {
            if (pendingCount <= 0 && !isSyncing) {
              return const SizedBox.shrink();
            }

            final label = pendingCount == 1
                ? 'Tienes 1 reporte guardado sin subir'
                : 'Tienes $pendingCount reportes guardados sin subir';

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2212) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFD97706),
                              ),
                            )
                          : const Icon(
                              Icons.cloud_upload_outlined,
                              color: Color(0xFFD97706),
                              size: 19,
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSyncing ? 'Sincronizando reportes...' : label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Se subirán automáticamente al recuperar señal',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? const Color(0xFFD97706) : const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: isSyncing ? null : _handleManualSync,
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF1E5E3A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF1E5E3A).withAlpha(120),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      isSyncing ? 'Subiendo...' : 'Sincronizar ahora',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInstitutionalHeader(Color titleColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.8),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF0F3A22)),
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Goblin Park",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F3A22),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  "PNR Páramo del Duende",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2E4F3E),
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

  Widget _buildTitleSection(Color titleColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Mis reportes",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: titleColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            "Consulta y gestiona los reportes que has registrado",
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewReportButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const NewReportCategoryScreen(),
            ),
          ).then((value) {
            if (value == true) _loadMyReports();
          });
        },
        icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
        label: const Text(
          "+ Nuevo reporte",
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E5E3A),
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField(Color cardBg, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
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
          hintText: "Buscar en mis reportes...",
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
    final filters = [
      {'name': 'Todos', 'count': _countTodos},
      {'name': 'Pendientes', 'count': _countPendientes},
      {'name': 'Convertidos en proyecto', 'count': _countConvertidos},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: filters.map((f) {
          final name = f['name'] as String;
          final count = f['count'] as int;
          final isSelected = _selectedStatus == name;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _selectedStatus = name),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1B4D3E) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF1B4D3E)
                          : const Color(0xFFE5E7EB),
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
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? Colors.white : const Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withAlpha(50)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          count.toString(),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : const Color(0xFF4B5563),
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
    final bool isOffline = r['_isOffline'] == true;
    final String? localPhotoPath = r['fotoRutaLocal']?.toString();
    final bool hasLocalPhoto =
        localPhotoPath != null && localPhotoPath.isNotEmpty && File(localPhotoPath).existsSync();
    final catNombre = r['categoriaNombre'] ?? r['categoria']?['nombre'] ?? 'Flora';
    final rawEstado = (r['estadoReporteNombre'] ?? r['estado']?['nombre'] ?? '')
        .toString()
        .trim();
    final estadoNombre = isOffline
        ? 'Sin subir'
        : (_isConvertidoEnProyecto(r)
            ? (rawEstado.isNotEmpty &&
                    rawEstado.toUpperCase() != 'CONVERTIDO_EN_PROYECTO'
                ? rawEstado
                : 'Convertido en proyecto')
            : (rawEstado.isNotEmpty && rawEstado.toUpperCase() != 'PENDIENTE'
                ? rawEstado
                : 'Pendiente'));
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
    final statusBg = _getStatusBgColor(estadoNombre);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB),
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
          onTap: () async {
            if (isOffline) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Este reporte está guardado localmente y se subirá en cuanto tengas conexión.',
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }
            final updated = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReportDetailScreen(reporte: r),
              ),
            );
            if (updated != null && mounted) {
              _loadMyReports();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 85,
                    height: 85,
                    child: hasLocalPhoto
                        ? Image.file(
                            File(localPhotoPath),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Image.asset(
                              _categoryAsset(catNombre),
                              fit: BoxFit.cover,
                            ),
                          )
                        : (imgUrl != null
                            ? CachedNetworkImage(
                                imageUrl: imgUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: 600,
                                placeholder: (context, url) => Container(
                                  color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[200],
                                ),
                                errorWidget: (context, url, error) => Image.asset(
                                  _categoryAsset(catNombre),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(
                                _categoryAsset(catNombre),
                                fit: BoxFit.cover,
                              )),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
                      Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 13, color: Color(0xFF6B7280)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              sector,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
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
                              const Icon(Icons.camera_alt_outlined, size: 13, color: Color(0xFF6B7280)),
                              const SizedBox(width: 3),
                              Text(
                                evCount.toString(),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.chat_bubble_outline_rounded, size: 12, color: Color(0xFF6B7280)),
                              const SizedBox(width: 3),
                              Text(
                                comCount.toString(),
                                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.bold),
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
    final bool hasZeroTotal = _myReports.isEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.description_outlined, size: 36, color: Color(0xFF1E5E3A)),
            ),
            const SizedBox(height: 16),
            Text(
              hasZeroTotal
                  ? "Aún no has registrado ningún reporte. Presiona '+ Nuevo reporte' para comenzar."
                  : "No tienes reportes en esta sección",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            if (!hasZeroTotal) ...[
              const SizedBox(height: 6),
              const Text(
                "Registra una nueva observación para comenzar tu monitoreo en campo.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewReportCategoryScreen()),
                ).then((value) {
                  if (value == true) _loadMyReports();
                });
              },
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              label: const Text(
                "+ Nuevo reporte",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5E3A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
