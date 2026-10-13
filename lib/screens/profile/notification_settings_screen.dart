import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:goblink_park/providers/theme_provider.dart';
import 'package:goblink_park/widgets/notification_bell_button.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  static const _storage = FlutterSecureStorage();

  bool _recordatoriosActividades = true;
  bool _reportesAsignados = true;
  bool _novedadesProyecto = true;
  bool _alertasAmbientales = true;

  String _ultimaSincronizacion = "10 de octubre de 2026, 11:30 PM";
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final act = await _storage.read(key: 'pref_notif_actividades');
    final rep = await _storage.read(key: 'pref_notif_reportes');
    final nov = await _storage.read(key: 'pref_notif_novedades');
    final amb = await _storage.read(key: 'pref_notif_ambientales');
    final sync = await _storage.read(key: 'pref_ultima_sync');

    if (!mounted) return;
    setState(() {
      if (act != null) _recordatoriosActividades = act == 'true';
      if (rep != null) _reportesAsignados = rep == 'true';
      if (nov != null) _novedadesProyecto = nov == 'true';
      if (amb != null) _alertasAmbientales = amb == 'true';
      if (sync != null) {
        _ultimaSincronizacion = sync;
      } else {
        _ultimaSincronizacion = _formatCurrentDateTime();
      }
    });
  }

  String _formatCurrentDateTime() {
    final now = DateTime.now();
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    final hourFormat = DateFormat('hh:mm a');
    return "${now.day} de ${months[now.month - 1]} de ${now.year}, ${hourFormat.format(now)}";
  }

  Future<void> _updatePref(String key, bool value) async {
    await _storage.write(key: key, value: value.toString());
  }

  Future<void> _sincronizarDatos() async {
    setState(() => _isSyncing = true);

    await Future.delayed(const Duration(milliseconds: 1200));

    final newDateStr = _formatCurrentDateTime();
    await _storage.write(key: 'pref_ultima_sync', value: newDateStr);

    if (!mounted) return;
    setState(() {
      _ultimaSincronizacion = newDateStr;
      _isSyncing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.cloud_done_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Datos sincronizados correctamente con la base del PNR Páramo del Duende.",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFF1E5E3A),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();
    final isDarkModeActive = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header Institucional Oficial
              _buildInstitutionalHeader(),
              const SizedBox(height: 16),

              // 2. Título de pantalla
              Text(
                "Notificaciones y preferencias",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                "Configura las alertas que deseas recibir y personaliza tu experiencia.",
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),

              // 3. Sección Notificaciones
              Text(
                "Notificaciones",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              _buildNotificationsCard(),
              const SizedBox(height: 20),

              // 4. Sección Preferencias
              Text(
                "Preferencias",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              _buildPreferencesCard(
                isDark: isDarkModeActive,
                onThemeChanged: (val) {
                  context.read<ThemeProvider>().toggleTheme(val);
                },
              ),
              const SizedBox(height: 20),

              // 5. Tarjeta de Sincronización de Datos
              _buildSyncCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // COMPONENTES MODULARES
  // ===========================================================================

  Widget _buildInstitutionalHeader() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: isDark ? const Color(0xFFE8F5E9) : const Color(0xFF0F3A22),
              size: 20,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          ClipOval(
            child: Image.asset(
              'assets/images/Logo verde.png',
              width: 36,
              height: 36,
              fit: BoxFit.contain,
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
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 1),
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
          const NotificationBellButton(size: 25),
        ],
      ),
    );
  }

  Widget _buildNotificationsCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dividerColor = isDark ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dividerColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Recordatorios de actividades
          _buildSwitchTile(
            icon: Icons.calendar_today_outlined,
            title: "Recordatorios de actividades",
            subtitle: "Fechas, tareas y seguimientos",
            value: _recordatoriosActividades,
            onChanged: (v) {
              setState(() => _recordatoriosActividades = v);
              _updatePref('pref_notif_actividades', v);
            },
          ),
          Divider(height: 1, indent: 64, endIndent: 16, color: dividerColor),

          // 2. Reportes asignados
          _buildSwitchTile(
            icon: Icons.assignment_outlined,
            title: "Reportes asignados",
            subtitle: "Nuevos reportes y cambios de estado",
            value: _reportesAsignados,
            onChanged: (v) {
              setState(() => _reportesAsignados = v);
              _updatePref('pref_notif_reportes', v);
            },
          ),
          Divider(height: 1, indent: 64, endIndent: 16, color: dividerColor),

          // 3. Novedades del proyecto
          _buildSwitchTile(
            icon: Icons.campaign_outlined,
            title: "Novedades del proyecto",
            subtitle: "Actualizaciones y anuncios",
            value: _novedadesProyecto,
            onChanged: (v) {
              setState(() => _novedadesProyecto = v);
              _updatePref('pref_notif_novedades', v);
            },
          ),
          Divider(height: 1, indent: 64, endIndent: 16, color: dividerColor),

          // 4. Alertas ambientales
          _buildSwitchTile(
            icon: Icons.warning_amber_rounded,
            title: "Alertas ambientales",
            subtitle: "Eventos importantes del área protegida",
            value: _alertasAmbientales,
            onChanged: (v) {
              setState(() => _alertasAmbientales = v);
              _updatePref('pref_notif_ambientales', v);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard({
    required bool isDark,
    required ValueChanged<bool> onThemeChanged,
  }) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final borderColor = isDarkMode ? const Color(0x1AFFFFFF) : const Color(0xFFE5E7EB);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: _buildSwitchTile(
        icon: Icons.dark_mode_outlined,
        title: "Modo oscuro",
        subtitle: "Interfaz en tonos oscuros",
        value: isDark,
        onChanged: onThemeChanged,
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B4332) : const Color(0xFFE8F5E9),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
        ),
      ),
      trailing: Switch(
        value: value,
        activeThumbColor: const Color(0xFF52B788),
        activeTrackColor: isDark ? const Color(0xFF2D6A4F) : const Color(0xFFDCFCE7),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSyncCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2620) : const Color(0xFFEBF3EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0x3352B788) : const Color(0xFFD1E3D7),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF22352B) : const Color(0xFFD6EBE0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_sync_outlined,
                  color: isDark ? const Color(0xFF52B788) : const Color(0xFF1E5E3A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Sincronización de datos",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Mantén tus datos actualizados en todos tus dispositivos.",
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF4B5563),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Última sincronización: $_ultimaSincronizacion",
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: _isSyncing ? null : _sincronizarDatos,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync_rounded, color: Colors.white, size: 18),
              label: Text(
                _isSyncing ? "Sincronizando..." : "Sincronizar ahora",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF2D6A4F) : const Color(0xFF1E5E3A),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
