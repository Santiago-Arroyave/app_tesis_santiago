import 'package:flutter/material.dart';

class MapFilterOptions {
  final String? category;
  final String? status;
  final String? priority;
  final DateTimeRange? dateRange;

  const MapFilterOptions({
    this.category,
    this.status,
    this.priority,
    this.dateRange,
  });

  bool get hasActiveFilters =>
      category != null || status != null || priority != null || dateRange != null;

  MapFilterOptions copyWith({
    String? Function()? category,
    String? Function()? status,
    String? Function()? priority,
    DateTimeRange? Function()? dateRange,
  }) {
    return MapFilterOptions(
      category: category != null ? category() : this.category,
      status: status != null ? status() : this.status,
      priority: priority != null ? priority() : this.priority,
      dateRange: dateRange != null ? dateRange() : this.dateRange,
    );
  }
}

class MapFilterSheet extends StatefulWidget {
  final MapFilterOptions initialFilters;
  final void Function(MapFilterOptions filters) onApply;

  const MapFilterSheet({
    super.key,
    required this.initialFilters,
    required this.onApply,
  });

  static Future<void> show({
    required BuildContext context,
    required MapFilterOptions currentFilters,
    required void Function(MapFilterOptions filters) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MapFilterSheet(
        initialFilters: currentFilters,
        onApply: onApply,
      ),
    );
  }

  @override
  State<MapFilterSheet> createState() => _MapFilterSheetState();
}

class _MapFilterSheetState extends State<MapFilterSheet> {
  late String? _selectedCategory;
  late String? _selectedStatus;
  late String? _selectedPriority;
  late DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialFilters.category;
    _selectedStatus = widget.initialFilters.status;
    _selectedPriority = widget.initialFilters.priority;
    _selectedDateRange = widget.initialFilters.dateRange;
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
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

    if (picked != null) {
      setState(() => _selectedDateRange = picked);
    }
  }

  String _formatDateRange(DateTimeRange range) {
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    final s = range.start;
    final e = range.end;
    return '${s.day} ${months[s.month - 1]} ${s.year} - ${e.day} ${months[e.month - 1]} ${e.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Manija de arrastre y Encabezado
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 6),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Filtros del mapa",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F3A22),
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategory = null;
                              _selectedStatus = null;
                              _selectedPriority = null;
                              _selectedDateRange = null;
                            });
                          },
                          child: const Text(
                            "Restablecer",
                            style: TextStyle(
                              color: Color(0xFF1E5E3A),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Color(0xFF4B5563), size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // 2. Contenido scrolleable
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- CATEGORÍAS SELECCIONABLES ---
                  const Text(
                    "Categoría Ambiental",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildCategoryChip("Flora", Icons.eco, const Color(0xFF1E5E3A)),
                      _buildCategoryChip("Fauna", Icons.pets, const Color(0xFF9A6735)),
                      _buildCategoryChip("Suelo", Icons.landscape, const Color(0xFF8C5E48)),
                      _buildCategoryChip("Agua", Icons.water_drop, const Color(0xFF2563EB)),
                      _buildCategoryChip("Aire", Icons.air, const Color(0xFF0284C7)),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // --- ESTADO DEL REPORTE ---
                  const Text(
                    "Estado de Validación",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatusChip("Todos"),
                      _buildStatusChip("En revisión"),
                      _buildStatusChip("Validado"),
                      _buildStatusChip("Pendiente"),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // --- RANGO DE FECHAS ---
                  const Text(
                    "Rango de Fechas",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _pickDateRange,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 18, color: Color(0xFF1E5E3A)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _selectedDateRange != null
                                  ? _formatDateRange(_selectedDateRange!)
                                  : "Seleccionar periodo de fechas",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: _selectedDateRange != null ? FontWeight.w600 : FontWeight.normal,
                                color: _selectedDateRange != null ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
                              ),
                            ),
                          ),
                          if (_selectedDateRange != null)
                            GestureDetector(
                              onTap: () => setState(() => _selectedDateRange = null),
                              child: const Icon(Icons.clear, size: 18, color: Color(0xFF6B7280)),
                            )
                          else
                            const Icon(Icons.chevron_right, size: 20, color: Color(0xFF9CA3AF)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // --- PRIORIDAD ---
                  const Text(
                    "Prioridad",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPriorityChip("Alta", const Color(0xFFEF4444)),
                      _buildPriorityChip("Media", const Color(0xFFF59E0B)),
                      _buildPriorityChip("Baja", const Color(0xFF10B981)),
                    ],
                  ),
                  const SizedBox(height: 22),

                  // --- LEYENDA DE MARCADORES ---
                  const Text(
                    "Leyenda de Marcadores",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildLegendItem("Flora", Icons.eco, const Color(0xFF1E5E3A)),
                          const SizedBox(width: 14),
                          _buildLegendItem("Fauna", Icons.pets, const Color(0xFF9A6735)),
                          const SizedBox(width: 14),
                          _buildLegendItem("Suelo", Icons.landscape, const Color(0xFF8C5E48)),
                          const SizedBox(width: 14),
                          _buildLegendItem("Agua", Icons.water_drop, const Color(0xFF2563EB)),
                          const SizedBox(width: 14),
                          _buildLegendItem("Aire", Icons.air, const Color(0xFF0284C7)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),

          // 3. Botón inferior ancho "Aplicar filtros"
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApply(
                      MapFilterOptions(
                        category: _selectedCategory,
                        status: _selectedStatus,
                        priority: _selectedPriority,
                        dateRange: _selectedDateRange,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E5E3A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    "Aplicar filtros",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category, IconData icon, Color color) {
    final isSelected = _selectedCategory == category;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedCategory = isSelected ? null : category;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withAlpha(20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withAlpha(80),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              category,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isSelected = (_selectedStatus == null && status == 'Todos') || _selectedStatus == status;
    return ChoiceChip(
      label: Text(status),
      selected: isSelected,
      selectedColor: const Color(0xFFE8F5E9),
      backgroundColor: const Color(0xFFF3F4F6),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF1E5E3A) : const Color(0xFF374151),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12.5,
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF1E5E3A) : const Color(0xFFE5E7EB),
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (val) {
        setState(() {
          _selectedStatus = status == 'Todos' ? null : status;
        });
      },
    );
  }

  Widget _buildPriorityChip(String priority, Color color) {
    final isSelected = _selectedPriority == priority;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedPriority = isSelected ? null : priority;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(30) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              priority,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF111827) : const Color(0xFF4B5563),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 12),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}
