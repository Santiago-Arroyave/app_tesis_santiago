import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'observation_edit_screen.dart';

class ObservationDetailScreen extends StatelessWidget {
  final Map<String, dynamic> obs;

  const ObservationDetailScreen({super.key, required this.obs});

  String _categoryImage(String? categoria) {
    const map = {
      'Fauna': 'assets/images/Oso de anteojos-2.jpeg',
      'Flora': 'assets/images/Flora.jpeg',
      'Agua':  'assets/images/Agua.jpeg',
      'Aire':  'assets/images/Aire.jpeg',
      'Suelo': 'assets/images/Suelo.jpeg',
    };
    return map[categoria] ?? 'assets/images/Oso de anteojos-2.jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final evidencias = (obs['evidencias'] as List?) ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Observación',
            style: TextStyle(fontWeight: FontWeight.w500)),
        actions: [
          // Botón editar
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.blue),
            onPressed: () async {
              final updated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ObservationEditScreen(obs: obs),
                ),
              );
              if (updated == true && context.mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Categoría y título ───────────────────────
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    _categoryImage(obs['categoriaNombre']),
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        obs['categoriaNombre'] ?? '',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade500),
                      ),
                      Text(
                        obs['titulo'] ?? '',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28),

            // ── Chips de info ────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                    icon: Icons.flag,
                    label: obs['prioridadNombre'] ?? ''),
                _InfoChip(
                    icon: Icons.info_outline,
                    label: obs['estadoReporteNombre'] ?? ''),
              ],
            ),
            const SizedBox(height: 16),

            // ── Descripción ──────────────────────────────
            const Text('Descripción',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                obs['descripcion'] ?? 'Sin descripción',
                style: TextStyle(
                    color: Colors.grey.shade700, fontSize: 14),
              ),
            ),
            const SizedBox(height: 16),

            // ── Ubicación ────────────────────────────────
            const Text('Ubicación',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on,
                    size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  '${obs['latitud']?.toStringAsFixed(6)}, '
                  '${obs['longitud']?.toStringAsFixed(6)}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Fecha ────────────────────────────────────
            if (obs['fechaEvento'] != null) ...[
              const Text('Fecha',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    obs['fechaEvento'].toString().length >= 10
                        ? obs['fechaEvento'].toString().substring(0, 10)
                        : obs['fechaEvento'].toString(),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // ── Evidencias fotográficas ──────────────────
            if (evidencias.isNotEmpty) ...[
              const Text('Fotos',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: evidencias.length,
                itemBuilder: (_, i) {
                  final ev = evidencias[i];
                  final urlArchivo = ev['urlArchivo']?.toString() ??
                      ev['archivoUrl']?.toString() ??
                      ev['url']?.toString() ??
                      '';
                  final base64Str =
                      ev['archivoBase64']?.toString() ?? '';

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: urlArchivo.isNotEmpty &&
                            (urlArchivo.startsWith('http://') ||
                                urlArchivo.startsWith('https://'))
                        ? CachedNetworkImage(
                            imageUrl: urlArchivo,
                            fit: BoxFit.cover,
                            memCacheWidth: 600,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade200,
                              child: Icon(Icons.broken_image,
                                  color: Colors.grey.shade400),
                            ),
                          )
                        : base64Str.isNotEmpty
                            ? Image.memory(
                                base64Decode(base64Str),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.grey.shade200,
                                  child: Icon(Icons.broken_image,
                                      color: Colors.grey.shade400),
                                ),
                              )
                            : Container(
                                color: Colors.grey.shade200,
                                child: Icon(Icons.image_not_supported,
                                    color: Colors.grey.shade400),
                              ),
                  );
                },
              ),
            ] else ...[
              const Text('Fotos',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_library_outlined,
                        color: Colors.grey.shade400, size: 28),
                    const SizedBox(height: 4),
                    Text('Sin fotos',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.green.shade700),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: Colors.green.shade700)),
        ],
      ),
    );
  }
}

/*import 'package:flutter/material.dart';

class ObservationDetailScreen extends StatelessWidget {
  final Map<String, dynamic> obs;

  const ObservationDetailScreen({super.key, required this.obs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Observación')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Text(obs['titulo'] ?? '',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Chips de info
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                    icon: Icons.category,
                    label: obs['categoriaNombre'] ?? ''),
                _InfoChip(
                    icon: Icons.flag,
                    label: obs['prioridadNombre'] ?? ''),
                _InfoChip(
                    icon: Icons.info_outline,
                    label: obs['estadoReporteNombre'] ?? ''),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),

            // Descripción
            const Text('Descripción',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(obs['descripcion'] ?? 'Sin descripción',
                style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 16),

            // Coordenadas
            const Text('Ubicación',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on,
                    size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  '${obs['latitud']?.toStringAsFixed(6)}, '
                  '${obs['longitud']?.toStringAsFixed(6)}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Fecha
            if (obs['fechaEvento'] != null) ...[
              const Text('Fecha',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    obs['fechaEvento'].toString().substring(0, 10),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.green.shade700),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: Colors.green.shade700)),
        ],
      ),
    );
  }
}*/