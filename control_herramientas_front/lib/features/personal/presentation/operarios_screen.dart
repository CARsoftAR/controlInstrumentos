import 'package:flutter/material.dart';
import '../../../../core/services/api_service.dart';
import '../../../presentation/widgets/ios_glass_card.dart';

class OperariosScreen extends StatefulWidget {
  final String? initialSearchQuery;
  const OperariosScreen({super.key, this.initialSearchQuery});

  @override
  State<OperariosScreen> createState() => _OperariosScreenState();
}

class _OperariosScreenState extends State<OperariosScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _operarios = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null) {
      _searchQuery = widget.initialSearchQuery!;
    }
    _cargarOperarios();
  }

  Future<void> _cargarOperarios() async {
    setState(() => _isLoading = true);
    final datos = await _apiService.getOperarios();
    setState(() {
      _operarios = datos;
      _isLoading = false;
    });
  }

  void _mostrarModalNuevoOperario() {
    String legajo = '';
    String nombre = '';
    String cargo = '';
    bool activo = true;
    bool saving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xffe2e8f0))),
              title: const Text('Nuevo Operario', style: TextStyle(color: Color(0xff0f172a), fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: (val) => legajo = val,
                      style: const TextStyle(color: Color(0xff0f172a)),
                      decoration: InputDecoration(
                        labelText: 'Legajo (Ej: OP101)',
                        labelStyle: const TextStyle(color: Color(0xff64748b)),
                        filled: true,
                        fillColor: const Color(0xfff8fafc),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xffcbd5e1))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (val) => nombre = val,
                      style: const TextStyle(color: Color(0xff0f172a)),
                      decoration: InputDecoration(
                        labelText: 'Nombre Completo',
                        labelStyle: const TextStyle(color: Color(0xff64748b)),
                        filled: true,
                        fillColor: const Color(0xfff8fafc),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xffcbd5e1))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (val) => cargo = val,
                      style: const TextStyle(color: Color(0xff0f172a)),
                      decoration: InputDecoration(
                        labelText: 'Especialidad / Cargo (Opcional)',
                        labelStyle: const TextStyle(color: Color(0xff64748b)),
                        filled: true,
                        fillColor: const Color(0xfff8fafc),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xffcbd5e1))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<bool>(
                      value: activo,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Color(0xff0f172a)),
                      decoration: InputDecoration(
                        labelText: 'Estado Inicial',
                        labelStyle: const TextStyle(color: Color(0xff64748b)),
                        filled: true,
                        fillColor: const Color(0xfff8fafc),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xffcbd5e1))),
                      ),
                      items: const [
                        DropdownMenuItem(value: true, child: Text('Activo', style: TextStyle(color: Color(0xff0f172a)))),
                        DropdownMenuItem(value: false, child: Text('Inactivo', style: TextStyle(color: Color(0xff0f172a)))),
                      ],
                      onChanged: (val) => activo = val!,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xff64748b)),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : () async {
                    if (legajo.isEmpty || nombre.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Legajo y nombre son obligatorios')));
                      return;
                    }
                    setModalState(() => saving = true);
                    final res = await _apiService.createOperario(legajo, nombre, cargo, activo);
                    if (res['success'] == true) {
                      Navigator.pop(context);
                      _cargarOperarios();
                    } else {
                      setModalState(() => saving = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${res['message']}')));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff10b981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                  ),
                  child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarModalEditarOperario(Map<String, dynamic> op) {
    String nombre = op['nombre'] ?? '';
    String cargo = op['cargo'] ?? op['especialidad'] ?? '';
    bool activo = op['activo'] ?? true;
    bool saving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xffe2e8f0))),
              title: Text('Editar Operario: ${op['legajo']}', style: const TextStyle(color: Color(0xff0f172a), fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: TextEditingController(text: nombre)..selection = TextSelection.collapsed(offset: nombre.length),
                      onChanged: (val) => nombre = val,
                      style: const TextStyle(color: Color(0xff0f172a)),
                      decoration: InputDecoration(
                        labelText: 'Nombre Completo',
                        labelStyle: const TextStyle(color: Color(0xff64748b)),
                        filled: true,
                        fillColor: const Color(0xfff8fafc),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xffcbd5e1))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: TextEditingController(text: cargo)..selection = TextSelection.collapsed(offset: cargo.length),
                      onChanged: (val) => cargo = val,
                      style: const TextStyle(color: Color(0xff0f172a)),
                      decoration: InputDecoration(
                        labelText: 'Especialidad / Cargo (Opcional)',
                        labelStyle: const TextStyle(color: Color(0xff64748b)),
                        filled: true,
                        fillColor: const Color(0xfff8fafc),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xffcbd5e1))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<bool>(
                      value: activo,
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Color(0xff0f172a)),
                      decoration: InputDecoration(
                        labelText: 'Estado',
                        labelStyle: const TextStyle(color: Color(0xff64748b)),
                        filled: true,
                        fillColor: const Color(0xfff8fafc),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xffcbd5e1))),
                      ),
                      items: const [
                        DropdownMenuItem(value: true, child: Text('Activo', style: TextStyle(color: Color(0xff0f172a)))),
                        DropdownMenuItem(value: false, child: Text('Inactivo', style: TextStyle(color: Color(0xff0f172a)))),
                      ],
                      onChanged: (val) => activo = val!,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xff64748b)),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : () async {
                    if (nombre.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre es obligatorio')));
                      return;
                    }
                    setModalState(() => saving = true);
                    final res = await _apiService.updateOperario(op['legajo'].toString(), nombre, cargo, activo);
                    if (res['success'] == true) {
                      Navigator.pop(context);
                      _cargarOperarios();
                    } else {
                      setModalState(() => saving = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${res['message']}')));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff10b981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                  ),
                  child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmarBorrado(Map<String, dynamic> op) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xffe2e8f0))),
        title: const Text('Confirmar Eliminación', style: TextStyle(color: Color(0xff0f172a), fontWeight: FontWeight.bold)),
        content: Text('¿Estás seguro que deseas eliminar al operario ${op['nombre']} (${op['legajo']})? Esto no se puede deshacer.', style: const TextStyle(color: Color(0xff475569))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), style: TextButton.styleFrom(foregroundColor: const Color(0xff64748b)), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(c);
              final res = await _apiService.deleteOperario(op['legajo'].toString());
              if (res['success'] == true) {
                _cargarOperarios();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${res['message']}')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f6f9),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Nómina de Personal Técnico',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xff0f172a)),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 300),
                          child: SizedBox(
                            height: 44,
                            child: TextField(
                              controller: TextEditingController(text: _searchQuery)..selection = TextSelection.collapsed(offset: _searchQuery.length),
                              onChanged: (value) => setState(() => _searchQuery = value),
                              style: const TextStyle(color: Color(0xff0f172a), fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Buscar por legajo, nombre o estado...',
                                hintStyle: const TextStyle(color: Color(0xff64748b)),
                                prefixIcon: const Icon(Icons.search, color: Color(0xff64748b), size: 20),
                                filled: true,
                                fillColor: const Color(0xfff8fafc),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xffe2e8f0)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _mostrarModalNuevoOperario,
                        icon: const Icon(Icons.add),
                        label: const Text('Nuevo Operario'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff10b981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _cargarOperarios,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Actualizar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff6366f1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                if (_isLoading) {
                  return const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xff6366f1)),
                    ),
                  );
                }

                final operariosFiltrados = _operarios.where((op) {
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery.toLowerCase();
                  final legajo = (op['legajo'] ?? '').toString().toLowerCase();
                  final nombreCompleto = '${op['nombre'] ?? ''} ${op['apellido'] ?? ''}'.toLowerCase();
                  return legajo.contains(q) || nombreCompleto.contains(q);
                }).toList();

                return Expanded(
                  child: IosGlassCard(
                    padding: EdgeInsets.zero,
                    customColor: Colors.white.withOpacity(0.85),
                    borderColor: const Color(0xffcbd5e1),
                    child: Column(
                      children: [
                        IosGlassCard(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          customColor: const Color(0xfff1f5f9),
                          borderColor: const Color(0xffcbd5e1),
                          borderRadius: 12.0,
                          child: Row(
                            children: [
                              _buildHeaderCell('Legajo', flex: 2),
                              _buildHeaderCell('Nombre Completo', flex: 5),
                              _buildHeaderCell('Especialidad', flex: 3),
                              _buildHeaderCell('Estado', flex: 2),
                              _buildHeaderCell('Acciones', flex: 1),
                            ],
                          ),
                        ),
                        Expanded(
                          child: operariosFiltrados.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No se encontraron operarios registrados.',
                                    style: TextStyle(
                                      color: Color(0xff64748b),
                                      fontSize: 16,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: operariosFiltrados.length,
                                  itemBuilder: (context, index) {
                                    final operario = operariosFiltrados[index];
                                    final isEven = index % 2 == 0;
                                    final bool activo = operario['activo'] ?? true;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                      decoration: BoxDecoration(
                                        color: isEven ? Colors.transparent : const Color(0xfff8fafc),
                                        border: const Border(
                                          bottom: BorderSide(
                                            color: Color(0xffe2e8f0),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          _buildDataCell(operario['legajo']?.toString() ?? '-', flex: 2, isBold: true, color: const Color(0xff0284c7)),
                                          _buildDataCell('${operario['nombre'] ?? ''} ${operario['apellido'] ?? ''}', flex: 5),
                                          _buildDataCell(operario['especialidad'] ?? 'General', flex: 3, isFaded: true),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: activo ? const Color(0xff10b981).withOpacity(0.12) : Colors.redAccent.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: activo ? const Color(0xff10b981).withOpacity(0.4) : Colors.redAccent.withOpacity(0.4)),
                                                ),
                                                child: Text(
                                                  activo ? 'Activo' : 'Inactivo',
                                                  style: TextStyle(
                                                    color: activo ? const Color(0xff10b981) : Colors.redAccent,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit, color: Color(0xff0284c7), size: 20),
                                                  onPressed: () => _mostrarModalEditarOperario(operario),
                                                  tooltip: 'Editar',
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                                  onPressed: () => _confirmarBorrado(operario),
                                                  tooltip: 'Eliminar',
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xff0f172a),
          fontWeight: FontWeight.bold,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, {required int flex, bool isBold = false, bool isFaded = false, Color? color}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          color: color ?? (isFaded ? const Color(0xff64748b) : const Color(0xff0f172a)),
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
