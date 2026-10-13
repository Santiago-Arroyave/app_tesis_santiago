import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ReportSubmittedSuccessScreen extends StatelessWidget {
  final Map<String, dynamic> reporteData;

  const ReportSubmittedSuccessScreen({
    super.key,
    required this.reporteData,
  });

  String _formatDateTime(dynamic dt) {
    if (dt == null) return 'Hoy';
    try {
      final date = DateTime.parse(dt.toString());
      const months = [
        'ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
      ];
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return '${date.day} ${months[date.month - 1]} ${date.year} · $hour:$minute';
    } catch (_) {
      return dt.toString();
    }
  }

  String _categoryAsset(String? categoria) {
    final c = (categoria ?? '').toLowerCase();
    if (c.contains('fauna') || c.contains('animal')) return 'assets/images/Fauna.jpg';
    if (c.contains('suelo') || c.contains('tierra')) return 'assets/images/Suelo.jpg';
    if (c.contains('agua') || c.contains('hídric')) return 'assets/images/Agua.jpg';
    if (c.contains('aire') || c.contains('clima')) return 'assets/images/Aire.jpg';
    return 'assets/images/Flora.jpg';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryBg = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    final id = reporteData['id']?.toString() ?? '1';
    final code = 'MD-2024-${id.padLeft(4, '0')}';
    final titulo = reporteData['titulo']?.toString().isNotEmpty == true
        ? reporteData['titulo'].toString()
        : 'Observación en el Páramo';
    final categoria = reporteData['categoriaNombre']?.toString() ??
        reporteData['categoria']?['nombre']?.toString() ??
        'Flora';
    final String? imgUrl = reporteData['fotoPrincipalUrl']?.toString().isNotEmpty == true
        ? reporteData['fotoPrincipalUrl'].toString()
        : null;
    final fecha = _formatDateTime(reporteData['fechaReporte'] ?? reporteData['createdAt'] ?? DateTime.now());

    return Scaffold(
      backgroundColor: primaryBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 10),

              // Círculo verde grande con icono de check institucional
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1E5E3A).withAlpha(80), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F1E5E3A),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF1E5E3A),
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                "Reporte enviado",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F3A22),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Tu observación ha sido registrada exitosamente.\nTe notificaremos sobre su estado de revisión.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF4B5563),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),

              // Tarjeta Resumen del Reporte
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0C000000),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: imgUrl != null
                            ? CachedNetworkImage(
                                imageUrl: imgUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: 600,
                                placeholder: (context, url) => Container(color: Colors.grey[200]),
                                errorWidget: (context, url, error) => Image.asset(
                                  _categoryAsset(categoria),
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Image.asset(
                                _categoryAsset(categoria),
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              categoria,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E5E3A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            titulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Código: $code",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E5E3A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Línea de tiempo vertical de 3 estados
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Estado del seguimiento",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F3A22),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildTimelineItem(
                      step: 1,
                      title: "Enviado",
                      subtitle: "Recibido en la plataforma institucional · $fecha",
                      isDone: true,
                      isCurrent: false,
                      isLast: false,
                    ),
                    _buildTimelineItem(
                      step: 2,
                      title: "En revisión",
                      subtitle: "Equipo técnico validando evidencias y ubicación",
                      isDone: false,
                      isCurrent: true,
                      isLast: false,
                    ),
                    _buildTimelineItem(
                      step: 3,
                      title: "Validado",
                      subtitle: "Aprobación oficial e integración al sistema de monitoreo",
                      isDone: false,
                      isCurrent: false,
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Información del Área Responsable
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C2820) : const Color(0xFFF3F9F5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF1E5E3A).withAlpha(50),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E5E3A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Área responsable",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            "Equipo de Guardabosques y Monitoreo Páramo del Duende",
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F3A22),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Botones de acción
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Regresar a la pantalla de mapa principal
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  icon: const Icon(Icons.map_outlined, color: Colors.white, size: 18),
                  label: const Text(
                    "Ver en el mapa",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E5E3A),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    "Entendido",
                    style: TextStyle(
                      color: Color(0xFF374151),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem({
    required int step,
    required String title,
    required String subtitle,
    required bool isDone,
    required bool isCurrent,
    required bool isLast,
  }) {
    Color circleColor;
    Widget icon;

    if (isDone) {
      circleColor = const Color(0xFF1E5E3A);
      icon = const Icon(Icons.check, color: Colors.white, size: 14);
    } else if (isCurrent) {
      circleColor = const Color(0xFF2563EB);
      icon = const Icon(Icons.access_time_filled, color: Colors.white, size: 14);
    } else {
      circleColor = const Color(0xFFD1D5DB);
      icon = Text(
        step.toString(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: icon,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isDone ? const Color(0xFF1E5E3A) : const Color(0xFFE5E7EB),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isCurrent
                        ? const Color(0xFF2563EB)
                        : (isDone ? const Color(0xFF0F3A22) : const Color(0xFF9CA3AF)),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
