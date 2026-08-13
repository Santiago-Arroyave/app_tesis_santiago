import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'observation_form_screen.dart';
import 'package:app_tesis/screens/observations/observation_discard_dialog.dart';

class ObservationCategoryScreen extends StatefulWidget {
  final LatLng location;
  const ObservationCategoryScreen({super.key, required this.location});

  @override
  State<ObservationCategoryScreen> createState() =>
      _ObservationCategoryScreenState();
}

class _ObservationCategoryScreenState extends State<ObservationCategoryScreen> {
  String? _selected;

  final List<Map<String, dynamic>> _categories = [
    {
      'label': 'Fauna',
      'image': 'assets/images/Oso de anteojos-2.jpeg',
      'color': Color(0xFFE8A838),
    },
    {
      'label': 'Flora',
      'image': 'assets/images/Flora.jpeg',
      'color': Color(0xFF4CAF50),
    },
    {
      'label': 'Agua',
      'image': 'assets/images/Agua.jpeg',
      'color': Color(0xFF2196F3),
    },
    {
      'label': 'Aire',
      'image': 'assets/images/Aire.jpeg',
      'color': Color(0xFF90CAF9),
    },
    {
      'label': 'Suelo',
      'image': 'assets/images/Suelo.jpeg',
      'color': Color(0xFF795548),
    },
  ];

  Future<bool?> _showDiscardDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => DiscardObservationDialog(
        onDiscard: () => Navigator.pop(ctx, true),
        onContinue: () => Navigator.pop(ctx, false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _showDiscardDialog();
        if (leave == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              final leave = await _showDiscardDialog();
              if (leave == true && context.mounted) Navigator.pop(context);
            },
          ),
          title: const Text(
            'Selecciona la categoría',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 28,
              ),
              onPressed: _selected == null
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ObservationFormScreen(
                          location: widget.location,
                          category: _selected!,
                        ),
                      ),
                    ),
            ),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ── Imagen de fondo ─────────────────────────────
            Image.asset('assets/images/Fondo.png', fit: BoxFit.cover),
            // ── Overlay oscuro para legibilidad ─────────────
            Container(color: Colors.black.withValues(alpha: 0.45)),
            // ── Grid de categorías ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 230, 24, 24),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 16,
                children: _categories.map((cat) {
                  final isSelected = _selected == cat['label'];

                  return SizedBox(
                    width: (MediaQuery.of(context).size.width - 48 - 32) / 3,
                    height:
                        ((MediaQuery.of(context).size.width - 48 - 32) / 3) /
                        0.9,
                    child: GestureDetector(
                      onTap: () => setState(() => _selected = cat['label']),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (cat['color'] as Color).withValues(alpha: 0.3)
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? cat['color'] as Color
                                : Colors.white.withValues(alpha: 0.4),
                            width: 2.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.asset(
                                cat['image'] as String,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              cat['label'] as String,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? cat['color'] as Color
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            /*Padding(
              padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.9,
                ),
                itemCount: _categories.length,
                itemBuilder: (ctx, i) {
                  final cat = _categories[i];
                  final isSelected = _selected == cat['label'];
                  return GestureDetector(
                    onTap: () => setState(() => _selected = cat['label']),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (cat['color'] as Color).withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? cat['color'] as Color
                              : Colors.white.withValues(alpha: 0.4),
                          width: 2.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              cat['image'] as String,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cat['label'] as String,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? cat['color'] as Color
                                  : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),*/
          ],
        ),
      ),
    );
  }
}

/*import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'observation_form_screen.dart';
import 'package:app_tesis/screens/observations/observation_discard_dialog.dart';

class ObservationCategoryScreen extends StatefulWidget {
  final LatLng location;
  const ObservationCategoryScreen({super.key, required this.location});

  @override
  State<ObservationCategoryScreen> createState() =>
      _ObservationCategoryScreenState();
}

class _ObservationCategoryScreenState extends State<ObservationCategoryScreen> {
  String? _selected;

  final List<Map<String, dynamic>> _categories = [
    {
      'label': 'Fauna',
      'image': 'assets/images/Oso de anteojos-2.jpeg',
      'color': Color(0xFFE8A838),
    },
    {
      'label': 'Flora',
      'image': 'assets/images/Flora.jpeg',
      'color': Color(0xFF4CAF50),
    },
    {
      'label': 'Agua',
      'image': 'assets/images/Agua.jpeg',
      'color': Color(0xFF2196F3),
    },
    {
      'label': 'Aire',
      'image': 'assets/images/Aire.jpeg',
      'color': Color(0xFF90CAF9),
    },
    {
      'label': 'Suelo',
      'image': 'assets/images/Suelo.jpeg',
      'color': Color(0xFF795548),
    },
  ];

  Future<bool> _onWillPop() async {
    return await _showDiscardDialog() ?? false;
  }

  Future<bool?> _showDiscardDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => DiscardObservationDialog(
        onDiscard: () => Navigator.pop(ctx, true),
        onContinue: () => Navigator.pop(ctx, false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _showDiscardDialog();
        if (leave == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final leave = await _showDiscardDialog();
              if (leave == true && context.mounted) Navigator.pop(context);
            },
          ),
          title: const Text('Selecciona la categoría'),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 28,
              ),
              onPressed: _selected == null
                  ? null
                  : () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ObservationFormScreen(
                          location: widget.location,
                          category: _selected!,
                        ),
                      ),
                    ),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.9,
            ),
            itemCount: _categories.length,
            itemBuilder: (ctx, i) {
              final cat = _categories[i];
              final isSelected = _selected == cat['label'];
              return GestureDetector(
                onTap: () => setState(() => _selected = cat['label']),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (cat['color'] as Color).withOpacity(0.2)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? cat['color'] as Color
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          cat['image'] as String,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cat['label'] as String,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? cat['color'] as Color
                              : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            /*itemBuilder: (ctx, i) {
              final cat = _categories[i];
              final isSelected = _selected == cat['label'];
              return GestureDetector(
                onTap: () => setState(() => _selected = cat['label']),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (cat['color'] as Color).withOpacity(0.2)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? cat['color'] as Color
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor:
                            (cat['color'] as Color).withOpacity(0.15),
                        child: Icon(cat['icon'] as IconData,
                            color: cat['color'] as Color, size: 28),
                      ),
                      const SizedBox(height: 8),
                      Text(cat['label'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? cat['color'] as Color
                                : Colors.grey.shade700,
                          )),
                    ],
                  ),
                ),
              );
            },*/
          ),
        ),
      ),
    );
  }
}*/
