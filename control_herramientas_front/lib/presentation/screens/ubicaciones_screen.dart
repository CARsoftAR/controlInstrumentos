import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../widgets/ios_glass_card.dart';

class UbicacionesScreen extends StatefulWidget {
  const UbicacionesScreen({super.key});

  @override
  State<UbicacionesScreen> createState() => _UbicacionesScreenState();
}

class _UbicacionesScreenState extends State<UbicacionesScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _ubicaciones = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _cargarUbicaciones();
  }

  Future<void> _cargarUbicaciones() async {
    setState(() => _isLoading = true);
    final ubicaciones = await _apiService.getUbicaciones();
    setState(() {
      _ubicaciones = ubicaciones;
      _isLoading = false;
    });
  }

  void _mostrarModalNuevaUbicacion() {
    String nombre = '';
    String pasillo = '';
    String estante = '';
    String observaciones = '';
    bool saving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xff1e2230),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Nueva Ubicación', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Nombre / Depósito',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) => nombre = val,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Pasillo (Opcional)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) => pasillo = val,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Estante (Opcional)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) => estante = val,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Observaciones',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) => observaciones = val,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: Colors.white54),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : () async {
                    if (nombre.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('El nombre de la ubicación es obligatorio'), backgroundColor: Colors.red)
                      );
                      return;
                    }
                    setModalState(() => saving = true);
                    final res = await _apiService.createUbicacion({
                      'nombre': nombre,
                      'pasillo': pasillo,
                      'estante': estante,
                      'observaciones': observaciones,
                    });
                    setModalState(() => saving = false);
                    if (res['success'] == true) {
                      Navigator.pop(context);
                      _cargarUbicaciones();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ubicación creada correctamente'), backgroundColor: Colors.green)
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${res['message']}'), backgroundColor: Colors.red)
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff10b981),
                    foregroundColor: Colors.white,
                  ),
                  child: saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarModalEditarUbicacion(dynamic u) {
    final int id = u['id'] ?? 0;
    String nombre = u['nombre'] ?? '';
    String pasillo = u['pasillo'] ?? '';
    String estante = u['estante'] ?? '';
    String observaciones = u['observaciones'] ?? '';
    bool saving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xff1e2230),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Editar Ubicación', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: nombre,
                      decoration: const InputDecoration(
                        labelText: 'Nombre / Depósito',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) => nombre = val,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: pasillo,
                      decoration: const InputDecoration(
                        labelText: 'Pasillo',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) => pasillo = val,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: estante,
                      decoration: const InputDecoration(
                        labelText: 'Estante',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) => estante = val,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: observaciones,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) => observaciones = val,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: Colors.white54),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : () async {
                    if (nombre.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('El nombre es obligatorio'), backgroundColor: Colors.red)
                      );
                      return;
                    }
                    setModalState(() => saving = true);
                    final res = await _apiService.updateUbicacion(id, {
                      'nombre': nombre,
                      'pasillo': pasillo,
                      'estante': estante,
                      'observaciones': observaciones,
                    });
                    setModalState(() => saving = false);
                    if (res['success'] == true) {
                      Navigator.pop(context);
                      _cargarUbicaciones();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ubicación actualizada correctamente'), backgroundColor: Colors.green)
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${res['message']}'), backgroundColor: Colors.red)
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff10b981),
                    foregroundColor: Colors.white,
                  ),
                  child: saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _eliminarUbicacion(int id, String nombre) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff1a1d29),
          title: const Text('¿Eliminar ubicación?', style: TextStyle(color: Colors.white)),
          content: Text('¿Seguro que deseas eliminar la ubicación "$nombre"?', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                final res = await _apiService.deleteUbicacion(id);
                if (mounted) {
                  Navigator.pop(context);
                  if (res['success'] == true) {
                    _cargarUbicaciones();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ubicación eliminada correctamente'), backgroundColor: Colors.green)
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al eliminar: ${res['message']}'), backgroundColor: Colors.red)
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xff4f46e5)));
    }

    final filteredData = _ubicaciones.where((u) {
      final name = (u['nombre'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Buscar ubicación...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                        filled: true,
                        fillColor: const Color(0xff1e2235),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff10b981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: _mostrarModalNuevaUbicacion,
                    icon: const Icon(Icons.add_location_alt),
                    label: const Text('Nueva Ubicación'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff4f46e5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: _cargarUbicaciones,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: IosGlassCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView(
                  children: [
                    DataTable(
                      headingRowColor: MaterialStateProperty.all(const Color(0xff1e2235)),
                      dataRowHeight: 52,
                      columns: const [
                        DataColumn(label: Text('Nombre / Depósito', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Pasillo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Estante', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Observaciones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Acciones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ],
                      rows: filteredData.map((u) {
                        final id = u['id'] ?? 0;
                        final name = u['nombre'] ?? '';
                        final pasillo = u['pasillo'] ?? '-';
                        final estante = u['estante'] ?? '-';
                        final obs = u['observaciones'] ?? '';

                        return DataRow(
                          cells: [
                            DataCell(Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
                            DataCell(Text(pasillo.isEmpty ? '-' : pasillo, style: const TextStyle(color: Colors.white70))),
                            DataCell(Text(estante.isEmpty ? '-' : estante, style: const TextStyle(color: Colors.white70))),
                            DataCell(Text(obs, style: const TextStyle(color: Colors.white70))),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                                    tooltip: 'Editar Ubicación',
                                    onPressed: () => _mostrarModalEditarUbicacion(u),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                    tooltip: 'Eliminar Ubicación',
                                    onPressed: () => _eliminarUbicacion(id, name),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
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
