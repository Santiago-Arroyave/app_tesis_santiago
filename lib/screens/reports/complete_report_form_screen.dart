import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:goblink_park/screens/reports/report_location_screen.dart';
import 'package:goblink_park/services/local_database_service.dart';

class CompleteReportFormScreen extends StatefulWidget {
  final String category;

  const CompleteReportFormScreen({
    super.key,
    required this.category,
  });

  @override
  State<CompleteReportFormScreen> createState() => _CompleteReportFormScreenState();
}

class _CompleteReportFormScreenState extends State<CompleteReportFormScreen> {
  final _formKey = GlobalKey<FormState>();

  // Campos Comunes
  late DateTime _selectedDateTime;
  final TextEditingController _descController = TextEditingController();
  final List<File> _photos = [];
  String _selectedPriority = 'Media';

  // Campos Específicos FLORA (Campos de texto libres)
  final TextEditingController _floraEspecieController = TextEditingController();
  final TextEditingController _floraCantidadController = TextEditingController();
  final TextEditingController _floraEstadoController = TextEditingController();

  // Campos Específicos FAUNA (Campos de texto libres)
  final TextEditingController _faunaEspecieController = TextEditingController();
  final TextEditingController _faunaIndividuosController = TextEditingController();
  final TextEditingController _faunaComportamientoController = TextEditingController();
  final TextEditingController _faunaEstadoController = TextEditingController();

  // Campos Específicos SUELO (Campos de texto libres)
  final TextEditingController _sueloTipoHallazgoController = TextEditingController();
  final TextEditingController _sueloCondicionController = TextEditingController();
  final TextEditingController _sueloHumedadController = TextEditingController();
  final TextEditingController _sueloAfectacionController = TextEditingController();

  // Campos Específicos AGUA (Campos de texto libres)
  final TextEditingController _aguaFuenteController = TextEditingController();
  final TextEditingController _aguaNovedadController = TextEditingController();
  final TextEditingController _aguaAfectacionController = TextEditingController();
  final TextEditingController _aguaDescController = TextEditingController();

  // Campos Específicos AIRE (Campos de texto libres)
  final TextEditingController _aireNovedadController = TextEditingController();
  final TextEditingController _aireIntensidadController = TextEditingController();
  final TextEditingController _aireCondicionController = TextEditingController();
  final TextEditingController _aireDireccionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDateTime = DateTime.now();
  }

  @override
  void dispose() {
    _descController.dispose();
    _floraEspecieController.dispose();
    _floraCantidadController.dispose();
    _floraEstadoController.dispose();
    _faunaEspecieController.dispose();
    _faunaIndividuosController.dispose();
    _faunaComportamientoController.dispose();
    _faunaEstadoController.dispose();
    _sueloTipoHallazgoController.dispose();
    _sueloCondicionController.dispose();
    _sueloHumedadController.dispose();
    _sueloAfectacionController.dispose();
    _aguaFuenteController.dispose();
    _aguaNovedadController.dispose();
    _aguaAfectacionController.dispose();
    _aguaDescController.dispose();
    _aireNovedadController.dispose();
    _aireIntensidadController.dispose();
    _aireCondicionController.dispose();
    _aireDireccionController.dispose();
    super.dispose();
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

  IconData _categoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'fauna':
        return Icons.pets;
      case 'suelo':
        return Icons.landscape;
      case 'agua':
        return Icons.water_drop;
      case 'aire':
        return Icons.air;
      default:
        return Icons.eco;
    }
  }

  Color _categoryColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'fauna':
        return const Color(0xFF9A6735);
      case 'suelo':
        return const Color(0xFF8C5E48);
      case 'agua':
        return const Color(0xFF2563EB);
      case 'aire':
        return const Color(0xFF0284C7);
      default:
        return const Color(0xFF1E5E3A);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_photos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Límite de 5 evidencias fotográficas alcanzado')),
      );
      return;
    }
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (picked != null) {
        final compressedFile =
            await LocalDatabaseService.compressAndSavePhoto(File(picked.path));
        if (!mounted) return;
        setState(() {
          _photos.add(compressedFile);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al capturar imagen: $e')),
        );
      }
    }
  }

  Future<void> _selectDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E5E3A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF111827),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF1E5E3A),
                onPrimary: Colors.white,
                onSurface: Color(0xFF111827),
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
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

  String _synthesizeTitle() {
    switch (widget.category) {
      case 'Flora':
        final esp = _floraEspecieController.text.trim();
        return esp.isNotEmpty ? esp : 'Registro de Flora';
      case 'Fauna':
        final esp = _faunaEspecieController.text.trim();
        return esp.isNotEmpty ? esp : 'Avistamiento de Fauna';
      case 'Suelo':
        final hallazgo = _sueloTipoHallazgoController.text.trim();
        return hallazgo.isNotEmpty ? '$hallazgo - Páramo' : 'Hallazgo en suelo - Páramo';
      case 'Agua':
        final fuente = _aguaFuenteController.text.trim();
        return fuente.isNotEmpty ? '$fuente - Novedad' : 'Fuente hídrica - Novedad';
      case 'Aire':
        final nov = _aireNovedadController.text.trim();
        return nov.isNotEmpty ? 'Reporte de $nov' : 'Condición atmosférica';
      default:
        return 'Observación en el Páramo';
    }
  }

  Map<String, dynamic> _collectCategorySpecificData() {
    final map = <String, dynamic>{};
    if (widget.category == 'Flora') {
      if (_floraEspecieController.text.trim().isNotEmpty) {
        map['especie'] = _floraEspecieController.text.trim();
      }
      if (_floraCantidadController.text.trim().isNotEmpty) {
        map['cantidad'] = _floraCantidadController.text.trim();
      }
      if (_floraEstadoController.text.trim().isNotEmpty) {
        map['estadoVegetal'] = _floraEstadoController.text.trim();
      }
    } else if (widget.category == 'Fauna') {
      if (_faunaEspecieController.text.trim().isNotEmpty) {
        map['especie'] = _faunaEspecieController.text.trim();
      }
      if (_faunaIndividuosController.text.trim().isNotEmpty) {
        map['individuos'] = _faunaIndividuosController.text.trim();
      }
      if (_faunaComportamientoController.text.trim().isNotEmpty) {
        map['comportamiento'] = _faunaComportamientoController.text.trim();
      }
      if (_faunaEstadoController.text.trim().isNotEmpty) {
        map['estadoAnimal'] = _faunaEstadoController.text.trim();
      }
    } else if (widget.category == 'Suelo') {
      if (_sueloTipoHallazgoController.text.trim().isNotEmpty) {
        map['tipoHallazgo'] = _sueloTipoHallazgoController.text.trim();
      }
      if (_sueloCondicionController.text.trim().isNotEmpty) {
        map['condicion'] = _sueloCondicionController.text.trim();
      }
      if (_sueloHumedadController.text.trim().isNotEmpty) {
        map['humedad'] = _sueloHumedadController.text.trim();
      }
      if (_sueloAfectacionController.text.trim().isNotEmpty) {
        map['nivelAfectacion'] = _sueloAfectacionController.text.trim();
      }
    } else if (widget.category == 'Agua') {
      if (_aguaFuenteController.text.trim().isNotEmpty) {
        map['tipoFuente'] = _aguaFuenteController.text.trim();
      }
      if (_aguaNovedadController.text.trim().isNotEmpty) {
        map['novedades'] = _aguaNovedadController.text.trim();
      }
      if (_aguaAfectacionController.text.trim().isNotEmpty) {
        map['nivelAfectacion'] = _aguaAfectacionController.text.trim();
      }
      if (_aguaDescController.text.trim().isNotEmpty) {
        map['observacionAgua'] = _aguaDescController.text.trim();
      }
    } else if (widget.category == 'Aire') {
      if (_aireNovedadController.text.trim().isNotEmpty) {
        map['novedades'] = _aireNovedadController.text.trim();
      }
      if (_aireIntensidadController.text.trim().isNotEmpty) {
        map['intensidad'] = _aireIntensidadController.text.trim();
      }
      if (_aireCondicionController.text.trim().isNotEmpty) {
        map['condicionAire'] = _aireCondicionController.text.trim();
      }
      if (_aireDireccionController.text.trim().isNotEmpty) {
        map['direccion'] = _aireDireccionController.text.trim();
      }
    }
    return map;
  }

  Future<void> _onNext() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa una descripción de la observación')),
      );
      return;
    }

    final specificData = _collectCategorySpecificData();
    final generatedTitle = _synthesizeTitle();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReportLocationScreen(
          category: widget.category,
          title: generatedTitle,
          description: _descController.text.trim(),
          dateTime: _selectedDateTime,
          priority: _selectedPriority,
          photos: _photos,
          specificData: specificData,
        ),
      ),
    );

    if (!mounted) return;
    if (result == true) {
      Navigator.pop(context, true);
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
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF0F3A22)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Información del registro",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F3A22),
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStepIndicator(2, "Información del registro"),
                      const SizedBox(height: 12),
                      _buildCategoryBanner(),
                      const SizedBox(height: 16),

                      // Campos Específicos
                      if (widget.category == 'Flora') _buildFloraFields(cardBg, isDark),
                      if (widget.category == 'Fauna') _buildFaunaFields(cardBg, isDark),
                      if (widget.category == 'Suelo') _buildSueloFields(cardBg, isDark),
                      if (widget.category == 'Agua') _buildAguaFields(cardBg, isDark),
                      if (widget.category == 'Aire') _buildAireFields(cardBg, isDark),

                      const SizedBox(height: 16),
                      _buildCommonFields(cardBg, isDark, titleColor),
                      const SizedBox(height: 16),
                      _buildPhotosSection(cardBg, isDark),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
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

  Widget _buildCategoryBanner() {
    final catColor = _categoryColor(widget.category);
    final catIcon = _categoryIcon(widget.category);
    final catAsset = _categoryAsset(widget.category);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: catColor.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: catColor.withAlpha(70), width: 1.2),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 50,
              height: 50,
              child: Image.asset(
                catAsset,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: catColor,
                  child: Icon(catIcon, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(catIcon, size: 16, color: catColor),
                    const SizedBox(width: 5),
                    Text(
                      "Categoría: ${widget.category}",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: catColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  "Completa los datos técnicos de tu observación",
                  style: TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // FORMULARIO FLORA (Campos de texto libres)
  // ==========================================
  Widget _buildFloraFields(Color cardBg, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _floraEspecieController,
          label: 'Especie o nombre común *',
          hint: 'Ej. Frailejón, Encenillo, musgo...',
          cardBg: cardBg,
          isDark: isDark,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa la especie o nombre común' : null,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _floraCantidadController,
          label: 'Cantidad u observación',
          hint: 'Ej. Entre 6 y 10 individuos, parche denso...',
          cardBg: cardBg,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _floraEstadoController,
          label: 'Estado vegetal',
          hint: 'Ej. En floración, adulto, en crecimiento...',
          cardBg: cardBg,
          isDark: isDark,
        ),
      ],
    );
  }

  // ==========================================
  // FORMULARIO FAUNA (Campos de texto libres)
  // ==========================================
  Widget _buildFaunaFields(Color cardBg, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _faunaEspecieController,
          label: 'Especie o nombre común *',
          hint: 'Ej. Oso andino, Venado soche, Cóndor...',
          cardBg: cardBg,
          isDark: isDark,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa la especie o animal observado' : null,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _faunaIndividuosController,
          label: 'Cantidad de individuos',
          hint: 'Ej. 1, 2, grupo de 4...',
          cardBg: cardBg,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _faunaComportamientoController,
          label: 'Comportamiento u observación',
          hint: 'Ej. En desplazamiento, huellas, rastros...',
          cardBg: cardBg,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _faunaEstadoController,
          label: 'Estado del animal',
          hint: 'Ej. En avistamiento, saludable, herido...',
          cardBg: cardBg,
          isDark: isDark,
        ),
      ],
    );
  }

  // ==========================================
  // FORMULARIO SUELO (Campos de texto libres)
  // ==========================================
  Widget _buildSueloFields(Color cardBg, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _sueloTipoHallazgoController,
          label: 'Tipo de hallazgo *',
          hint: 'Ej. Erosión, deslizamiento, pérdida de capa orgánica...',
          cardBg: cardBg,
          isDark: isDark,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el tipo de hallazgo en suelo' : null,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _sueloCondicionController,
          label: 'Condición del suelo',
          hint: 'Ej. Moderada, severa, leve...',
          cardBg: cardBg,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _sueloHumedadController,
          label: 'Humedad del suelo',
          hint: 'Ej. Húmedo, seco, saturado...',
          cardBg: cardBg,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _sueloAfectacionController,
          label: 'Nivel de afectación',
          hint: 'Ej. Medio, alto, bajo...',
          cardBg: cardBg,
          isDark: isDark,
        ),
      ],
    );
  }

  // ==========================================
  // FORMULARIO AGUA (Campos de texto libres)
  // ==========================================
  Widget _buildAguaFields(Color cardBg, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _aguaFuenteController,
          label: 'Tipo de fuente hídrica *',
          hint: 'Ej. Quebrada, acequia, laguna, humedal, nacimiento...',
          cardBg: cardBg,
          isDark: isDark,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el tipo de fuente hídrica' : null,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _aguaNovedadController,
          label: 'Tipo de novedad o contaminación',
          hint: 'Ej. Basura, turbidez, espuma, olor anormal...',
          cardBg: cardBg,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _aguaAfectacionController,
          label: 'Nivel de afectación',
          hint: 'Ej. Medio, alto, bajo...',
          cardBg: cardBg,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _aguaDescController,
          label: 'Descripción adicional del cauce',
          hint: 'Ej. Alteración del caudal tras lluvias...',
          cardBg: cardBg,
          isDark: isDark,
        ),
      ],
    );
  }

  // ==========================================
  // FORMULARIO AIRE (Campos de texto libres)
  // ==========================================
  Widget _buildAireFields(Color cardBg, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _aireNovedadController,
          label: 'Tipo de novedad *',
          hint: 'Ej. Humo, quema, olores fuertes, polvo...',
          cardBg: cardBg,
          isDark: isDark,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa la novedad o fenómeno observado' : null,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _aireIntensidadController,
          label: 'Intensidad',
          hint: 'Ej. Media, alta, baja...',
          cardBg: cardBg,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _aireCondicionController,
          label: 'Condición del aire',
          hint: 'Ej. Presencia de humo, partículas visibles...',
          cardBg: cardBg,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _aireDireccionController,
          label: 'Dirección o alcance',
          hint: 'Ej. Hacia el norte, hacia el cañón...',
          cardBg: cardBg,
          isDark: isDark,
        ),
      ],
    );
  }

  // ==========================================
  // CAMPOS COMUNES
  // ==========================================
  Widget _buildCommonFields(Color cardBg, bool isDark, Color titleColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector de Prioridad
        const Text(
          "Prioridad de atención *",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedPriority,
              isExpanded: true,
              items: ['Baja', 'Media', 'Alta'].map((p) {
                return DropdownMenuItem<String>(
                  value: p,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _getPriorityColor(p),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        p,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _getPriorityColor(p),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedPriority = val);
              },
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Fecha y Hora
        const Text(
          "Fecha y hora del registro *",
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: _selectDateTime,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF1E5E3A)),
                const SizedBox(width: 10),
                Text(
                  _formatDateTime(_selectedDateTime),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const Spacer(),
                const Text(
                  "Cambiar",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E5E3A),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Descripción con contador 0/500
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Descripción detallada *",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _descController,
              builder: (context, value, child) {
                return Text(
                  "${value.text.length}/500",
                  style: TextStyle(
                    fontSize: 11.5,
                    color: value.text.length > 500 ? Colors.red : const Color(0xFF9CA3AF),
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            ),
          ),
          child: TextFormField(
            controller: _descController,
            maxLines: 4,
            maxLength: 500,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
            decoration: const InputDecoration(
              hintText: "Escribe las características, condiciones climáticas o detalles relevantes observados en campo...",
              hintStyle: TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
              contentPadding: EdgeInsets.all(12),
              border: InputBorder.none,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'La descripción es obligatoria';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // EVIDENCIAS FOTOGRÁFICAS
  // ==========================================
  Widget _buildPhotosSection(Color cardBg, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Evidencias fotográficas *",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF374151)),
            ),
            Text(
              "(${_photos.length}/5)",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E5E3A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Botones de Cámara y Galería
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined, size: 18, color: Color(0xFF1E5E3A)),
                label: const Text(
                  "Tomar foto",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E5E3A),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1E5E3A), width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18, color: Color(0xFF1E5E3A)),
                label: const Text(
                  "Agregar foto",
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E5E3A),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1E5E3A), width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),

        // Cuadrícula de fotos
        if (_photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _photos.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_photos[index], fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _photos.removeAt(index));
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                  if (index == 0)
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E5E3A),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          "Principal",
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  // ==========================================
  // HELPERS DE INPUTS
  // ==========================================
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required Color cardBg,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
            ),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF9CA3AF)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
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
          onPressed: _onNext,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E5E3A),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Siguiente",
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
