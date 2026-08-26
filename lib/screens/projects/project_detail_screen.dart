import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:app_tesis/screens/login_screen/auth_service.dart';
import 'package:app_tesis/screens/projects/schedule_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'package:app_tesis/screens/api_connection/api_config.dart';

class ProjectDetailScreen extends StatefulWidget {
  final int projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  static const _baseUrl = '${ApiConfig.baseUrl}';
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/api/proyectos/${widget.projectId}/detalle-completo',
        ),
        //Uri.parse('$_baseUrl/api/proyectos/${widget.projectId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (!mounted) return;
      debugPrint('>>> Status detalle: ${response.statusCode}');
      debugPrint('>>> Body detalle: ${response.body}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        // El backend puede devolver el detalle directamente o dentro de {proyecto: ...}
        Map<String, dynamic> data;
        if (body is Map<String, dynamic> && body.containsKey('proyecto')) {
          data = body as Map<String, dynamic>;
        } else if (body is Map<String, dynamic>) {
          // Envuelve si viene sin la clave 'proyecto'
          data = {
            'proyecto': body,
            'miembros': body['miembros'] ?? [],
            'objetivos': body['objetivos'] ?? [],
            'metas': body['metas'] ?? [],
            'presupuesto': body['presupuesto'] ?? [],
            'cronogramaActividades': body['cronogramaActividades'] ?? [],
            'reportesAsociados': body['reportesAsociados'] ?? [],
            'seguimientos': body['seguimientos'] ?? [],
          };
        } else {
          setState(() {
            _error = 'Formato de respuesta inesperado';
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _data = data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Error ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = 'Error de conexión: $e';
          _isLoading = false;
        });
    }
  }

  /*Future<void> _loadDetail() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/proyectos/${widget.projectId}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() { _data = jsonDecode(response.body); _isLoading = false; });
      } else {
        setState(() { _error = 'Error ${response.statusCode}'; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Error de conexión: $e'; _isLoading = false; });
    }
  }*/

  Future<void> _leaveProject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_rounded, color: Colors.red.shade600, size: 56),
            const SizedBox(height: 12),
            const Text(
              '¿Quieres salir del proyecto?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, salir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final token = await AuthService.getToken();
      final userId = await AuthService.getUserId();
      final miembros = (_data?['miembros'] as List?) ?? [];
      debugPrint('>>> userId: $userId (${userId.runtimeType})');
      debugPrint('>>> Miembros: ${miembros.map((m) => "id:${m['id']} usuarioId:${m['usuarioId']} tipo:${m['usuarioId'].runtimeType}").toList()}');
      final miembro = miembros.firstWhere(
        (m) => m['usuarioId'] == userId,
        orElse: () => null,
      );
      debugPrint('>>> Miembro encontrado: $miembro');

      if (miembro == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró tu membresía')),
        );
        return;
      }
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/proyecto-miembros/${miembro['id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      debugPrint('>>> Status DELETE: ${response.statusCode}');
      debugPrint('>>> Body DELETE: "${response.body}"');

      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saliste del proyecto'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al salir'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _downloadPdf() async {
  try {
    final token = await AuthService.getToken();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Generando PDF..."),
        duration: Duration(seconds: 1),
      ),
    );

    final response = await http.get(
      Uri.parse(
          '$_baseUrl/api/proyectos/${widget.projectId}/pdf'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (!mounted) return;

    if (response.statusCode == 200) {
      final directory = await getTemporaryDirectory();

      final file = File(
          '${directory.path}/proyecto_${widget.projectId}.pdf');

      await file.writeAsBytes(response.bodyBytes);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("PDF descargado correctamente"),
          backgroundColor: Colors.green,
        ),
      );

      await OpenFilex.open(file.path);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("Error al descargar PDF (${response.statusCode})"),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Error: $e"),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  // ── Helpers UI ─────────────────────────────────────────────
  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Colors.green.shade800,
      ),
    ),
  );

  Widget _infoRow(String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(value ?? '-', style: const TextStyle(fontSize: 13)),
        ),
      ],
    ),
  );

  Widget _chip(String label, Color color) => Container(
    margin: const EdgeInsets.only(right: 6, bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
    ),
  );

  void _showOptionsMenu(BuildContext context, List miembros, List reportes) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ProjectOptionsScreen(
          miembros: miembros,
          reportes: reportes,
          onLeave: _leaveProject,
        ),
      ),
    );
  }

  /*void _showOptionsMenu(BuildContext context, List miembros, List reportes) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.people_outline,
                  color: Colors.grey.shade700,
                ),
                title: const Text('Ver miembros'),
                onTap: () {
                  Navigator.pop(context);
                  _showMembersSheet(miembros);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.visibility_outlined,
                  color: Colors.grey.shade700,
                ),
                title: const Text('Observaciones relacionadas'),
                onTap: () {
                  Navigator.pop(context);
                  _showRelatedObservations(reportes);
                },
              ),
              ListTile(
                leading: Icon(Icons.exit_to_app, color: Colors.red.shade400),
                title: Text(
                  'Salir del proyecto',
                  style: TextStyle(color: Colors.red.shade600),
                ),
                onTap: () {
                  Navigator.pop(context);
                 // _leaveProject();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }*/

  void _showMembersSheet(List miembros) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                '${miembros.length} miembros',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...miembros.map(
              (m) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade50,
                  child: Text(
                    (m['usuarioNombre'] ?? '?')[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  m['usuarioNombre'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  m['rolEnProyecto'] ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                dense: true,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showRelatedObservations(List reportes) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                'Observaciones relacionadas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: reportes.isEmpty
                  ? Center(
                      child: Text(
                        'No hay observaciones relacionadas',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    )
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: reportes.length,
                      itemBuilder: (_, i) {
                        final r = reportes[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange.shade50,
                              child: Icon(
                                Icons.article_outlined,
                                color: Colors.orange.shade700,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              r['reporteTitulo'] ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              r['estadoReporte'] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                              ),
                              child: Text(
                                r['prioridad'] ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            dense: true,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDetail,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final proyecto = (_data!['proyecto'] as Map<String, dynamic>?) ?? {};
    final miembros = (_data!['miembros'] as List?) ?? [];
    final objetivos = (_data!['objetivos'] as List?) ?? [];
    final metas = (_data!['metas'] as List?) ?? [];
    final presupuesto = (_data!['presupuesto'] as List?) ?? [];
    final cronograma = (_data!['cronogramaActividades'] as List?) ?? [];
    final reportes = (_data!['reportesAsociados'] as List?) ?? [];
    final seguimientos = (_data!['seguimientos'] as List?) ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mis Proyectos',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Descargar',
            onPressed: _downloadPdf,
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showOptionsMenu(context, miembros, reportes),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info principal ──────────────────────────────
            _infoRow('Nombre:', proyecto['nombre']),
            _infoRow('Categoría:', proyecto['categoriaNombre']),
            _infoRow('Estado:', proyecto['estadoProyectoNombre']),
            _infoRow('Del:', proyecto['fechaInicio']),
            const SizedBox(height: 16),

            // ── Objetivos ───────────────────────────────────
            if (objetivos.isNotEmpty) ...[
              _sectionTitle('Objetivos'),
              ...objetivos.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${e.key + 1}- ${e.value['descripcion']}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // ── Metas ───────────────────────────────────────
            if (metas.isNotEmpty) ...[
              _sectionTitle('Metas'),
              ...metas.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${e.key + 1}- ${e.value['descripcion']}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // ── Presupuesto ─────────────────────────────────
            if (presupuesto.isNotEmpty) ...[
              _sectionTitle('Presupuesto'),
              ...presupuesto.asMap().entries.map((e) {
                final p = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${e.key + 1}- ${p['rubro']} (${p['observaciones'] ?? ''})',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        '\$${(p['monto'] as num).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total estimada:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    '\$${(proyecto['presupuestoEstimado'] as num?)?.toStringAsFixed(0) ?? '0'}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // ── Cronograma ──────────────────────────────────────────
            if (cronograma.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionTitle('Cronograma'),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScheduleScreen(
                          actividades: cronograma,
                          projectName: proyecto['nombre'] ?? '',
                          projectId: widget.projectId,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Ver todo'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: cronograma.asMap().entries.map((e) {
                    final a = e.value;
                    final done = a['estado'] == 'completada';
                    return InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ScheduleScreen(
                            actividades: cronograma,
                            projectName: proyecto['nombre'] ?? '',
                            projectId: widget.projectId,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: done
                                    ? Colors.green.shade600
                                    : Colors.grey.shade200,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: done
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 14,
                                      )
                                    : Text(
                                        '${e.key + 1}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${e.key + 1}- ${a['nombre'] ?? ''}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              color: Colors.grey.shade400,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey.shade400,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],

            /*if (cronograma.isNotEmpty) ...[
              _sectionTitle('Cronograma'),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(3),
                    1: FlexColumnWidth(2),
                    2: FlexColumnWidth(2),
                    3: FixedColumnWidth(28),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                      children: ['Actividades', 'Inicio', 'Fin', '']
                          .map(
                            (h) => Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                h,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    ...cronograma.asMap().entries.map((e) {
                      final a = e.value;
                      final done = a['estado'] == 'completada';
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              '${e.key + 1}- ${a['nombre']}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              a['fechaInicio'] ?? '',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              a['fechaFin'] ?? '',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: done
                                ? Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade600,
                                    size: 18,
                                  )
                                : const SizedBox(),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],*/

            // ── Responsables ────────────────────────────────
            if (miembros.isNotEmpty) ...[
              _sectionTitle('Responsables'),
              ...miembros.asMap().entries.map((e) {
                final m = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${e.key + 1}. ${m['usuarioNombre']} - ${m['rolEnProyecto']}',
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],

            // ── Seguimientos ────────────────────────────────
            if (seguimientos.isNotEmpty) ...[
              _sectionTitle('Seguimientos'),
              ...seguimientos.map(
                (s) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.green.shade50,
                              child: Text(
                                (s['usuarioNombre'] ?? '?')[0].toUpperCase(),
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s['usuarioNombre'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '${s['porcentajeAvance']?.toStringAsFixed(0) ?? 0}%',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: ((s['porcentajeAvance'] as num?) ?? 0) / 100,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(
                            Colors.green.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s['descripcionAvance'] ?? '',
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (s['observaciones'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            s['observaciones'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// ─── Pantalla de opciones del proyecto ──────────────────────────────────────
class _ProjectOptionsScreen extends StatelessWidget {
  final List miembros;
  final List reportes;
  final VoidCallback onLeave;

  const _ProjectOptionsScreen({
    required this.miembros,
    required this.reportes,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${miembros.length} miembros',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Miembros ──────────────────────────────────
            ...miembros.map(
              (m) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green.shade50,
                  child: Text(
                    (m['usuarioNombre'] ?? '?')[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  m['usuarioNombre'] ?? '',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  m['rolEnProyecto'] ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                dense: true,
              ),
            ),

            const Divider(),

            // ── Observaciones relacionadas ────────────────
            ListTile(
              leading: Icon(
                Icons.visibility_outlined,
                color: Colors.grey.shade700,
              ),
              title: const Text('Observaciones relacionadas'),
              trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      _RelatedObservationsScreen(reportes: reportes),
                ),
              ),
            ),

            // ── Salir del proyecto ────────────────────────
            ListTile(
              leading: Icon(Icons.exit_to_app, color: Colors.red.shade400),
              title: Text(
                'Salir del proyecto',
                style: TextStyle(color: Colors.red.shade600),
              ),
              onTap: () {
                Navigator.pop(context);
                onLeave();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pantalla observaciones relacionadas ─────────────────────────────────────
class _RelatedObservationsScreen extends StatelessWidget {
  final List reportes;
  const _RelatedObservationsScreen({required this.reportes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Observaciones relacionadas',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      body: reportes.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No hay observaciones relacionadas',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reportes.length,
              itemBuilder: (_, i) {
                final r = reportes[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 1,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade50,
                      child: Icon(
                        Icons.article_outlined,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      r['reporteTitulo'] ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      r['estadoReporte'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Text(
                        r['prioridad'] ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    dense: true,
                  ),
                );
              },
            ),
    );
  }
}
    

  /*Future<void> _leaveProject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_rounded, color: Colors.red.shade600, size: 56),
            const SizedBox(height: 12),
            const Text(
              '¿Quieres salir del proyecto?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, salir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final token = await AuthService.getToken();
      final userId = await AuthService.getUserId();
      final miembros = (_data?['miembros'] as List?) ?? [];
      final miembro = miembros.firstWhere(
        (m) => m['usuarioId'] == userId,
        orElse: () => null,
      );
      if (miembro == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró tu membresía')),
        );
        return;
      }
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/proyecto-miembros/${miembro['id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saliste del proyecto'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al salir'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // ── Helpers UI ─────────────────────────────────────────────
  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Colors.green.shade800,
      ),
    ),
  );

  Widget _infoRow(String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(value ?? '-', style: const TextStyle(fontSize: 13)),
        ),
      ],
    ),
  );

  Widget _chip(String label, Color color) => Container(
    margin: const EdgeInsets.only(right: 6, bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDetail,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final proyecto = _data!['proyecto'] as Map<String, dynamic>;
    final miembros = (_data!['miembros'] as List?) ?? [];
    final objetivos = (_data!['objetivos'] as List?) ?? [];
    final metas = (_data!['metas'] as List?) ?? [];
    final presupuesto = (_data!['presupuesto'] as List?) ?? [];
    final cronograma = (_data!['cronogramaActividades'] as List?) ?? [];
    final reportes = (_data!['reportesAsociados'] as List?) ?? [];
    final seguimientos = (_data!['seguimientos'] as List?) ?? [];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Mis Proyectos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            onPressed: () {},
            tooltip: 'Descargar',
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'salir') _leaveProject();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'salir',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Salir del proyecto',
                      style: TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info principal ──────────────────────────────
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      proyecto['nombre'] ?? '',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _infoRow('Nombre:', proyecto['nombre']),
                    _infoRow('Categoría:', proyecto['categoriaNombre']),
                    _infoRow('Estado:', proyecto['estadoProyectoNombre']),
                    _infoRow('Del:', proyecto['fechaInicio']),
                    _infoRow('Creado por:', proyecto['creadoPorNombre']),
                    if (proyecto['descripcion'] != null &&
                        proyecto['descripcion'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        proyecto['descripcion'],
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Miembros ────────────────────────────────────
            if (miembros.isNotEmpty) ...[
              _sectionTitle('${miembros.length} miembros'),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
                child: Column(
                  children: [
                    ...miembros.map(
                      (m) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.green.shade50,
                          child: Text(
                            (m['usuarioNombre'] ?? '?')[0].toUpperCase(),
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          m['usuarioNombre'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          m['rolEnProyecto'] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        dense: true,
                      ),
                    ),
                    const Divider(height: 1),
                    // Observaciones relacionadas
                    ListTile(
                      leading: Icon(
                        Icons.visibility_outlined,
                        color: Colors.grey.shade600,
                        size: 20,
                      ),
                      title: const Text(
                        'Observaciones relacionadas',
                        style: TextStyle(fontSize: 13),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: Colors.grey.shade400,
                      ),
                      dense: true,
                      onTap: () {},
                    ),
                    ListTile(
                      leading: Icon(
                        Icons.exit_to_app,
                        color: Colors.red.shade400,
                        size: 20,
                      ),
                      title: Text(
                        'Salir del proyecto',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade600,
                        ),
                      ),
                      dense: true,
                      onTap: _leaveProject,
                    ),
                  ],
                ),
              ),
            ],

            // ── Objetivos ───────────────────────────────────
            if (objetivos.isNotEmpty) ...[
              _sectionTitle('Objetivos'),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: objetivos
                        .asMap()
                        .entries
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${e.key + 1}. ${e.value['descripcion']}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],

            // ── Metas ───────────────────────────────────────
            if (metas.isNotEmpty) ...[
              _sectionTitle('Metas'),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: metas
                        .asMap()
                        .entries
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${e.key + 1}. ${e.value['descripcion']}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],

            // ── Presupuesto ─────────────────────────────────
            if (presupuesto.isNotEmpty) ...[
              _sectionTitle('Presupuesto'),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...presupuesto.asMap().entries.map((e) {
                        final p = e.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${e.key + 1}. ${p['rubro']} (${p['observaciones'] ?? ''})',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              Text(
                                '\$${(p['monto'] as num).toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total estimada:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '\$${(proyecto['presupuestoEstimado'] as num?)?.toStringAsFixed(0) ?? '0'}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // ── Cronograma ──────────────────────────────────
            if (cronograma.isNotEmpty) ...[
              _sectionTitle('Cronograma'),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(2),
                      3: FixedColumnWidth(28),
                    },
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: Colors.grey.shade100),
                        children: ['Actividades', 'Inicio', 'Fin', '']
                            .map(
                              (h) => Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  h,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      ...cronograma.asMap().entries.map((e) {
                        final a = e.value;
                        final done = a['estado'] == 'completada';
                        return TableRow(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                '${e.key + 1}. ${a['nombre']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                a['fechaInicio'] ?? '',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: Text(
                                a['fechaFin'] ?? '',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: done
                                  ? Icon(
                                      Icons.check_circle,
                                      color: Colors.green.shade600,
                                      size: 18,
                                    )
                                  : const SizedBox(),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],

            // ── Reportes asociados ──────────────────────────
            if (reportes.isNotEmpty) ...[
              _sectionTitle('Reportes asociados'),
              ...reportes.map(
                (r) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 1,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade50,
                      child: Icon(
                        Icons.article_outlined,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      r['reporteTitulo'] ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      r['estadoReporte'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    trailing: _chip(
                      r['prioridad'] ?? '',
                      Colors.orange.shade700,
                    ),
                    dense: true,
                  ),
                ),
              ),
            ],

            // ── Seguimientos ────────────────────────────────
            if (seguimientos.isNotEmpty) ...[
              _sectionTitle('Seguimientos'),
              ...seguimientos.map(
                (s) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.green.shade50,
                              child: Text(
                                (s['usuarioNombre'] ?? '?')[0].toUpperCase(),
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s['usuarioNombre'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '${s['porcentajeAvance']?.toStringAsFixed(0) ?? 0}%',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: ((s['porcentajeAvance'] as num?) ?? 0) / 100,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(
                            Colors.green.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          s['descripcionAvance'] ?? '',
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (s['observaciones'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            s['observaciones'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }*/

