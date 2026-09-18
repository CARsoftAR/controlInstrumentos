import 'package:flutter/material.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../../../core/services/api_service.dart';

class PrestamosScreen extends StatefulWidget {
  final String? initialSearchQuery;
  const PrestamosScreen({super.key, this.initialSearchQuery});

  @override
  State<PrestamosScreen> createState() => _PrestamosScreenState();
}

class _PrestamosScreenState extends State<PrestamosScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _prestamos = [];
  bool _isLoading = true;
  String _searchQuery = '';

  Future<void> _exportarXLSX(BuildContext context, String filenamePrefix, Future<List<int>?> Function() apiCall) async {
    try {
      final bytes = await apiCall();
      if (bytes == null || bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay datos para exportar.'), backgroundColor: Colors.red)
        );
        return;
      }
      
      final appDir = Directory(Platform.resolvedExecutable).parent;
      final dir = Directory('${appDir.path}\\Reportes');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final file = File('${dir.path}\\${filenamePrefix}_$timestamp.xlsx');
      
      await file.writeAsBytes(bytes);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reporte Excel guardado en: ${file.path}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar reporte: $e'), backgroundColor: Colors.red)
      );
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null) {
      _searchQuery = widget.initialSearchQuery!;
    }
    _cargarPrestamos();
  }

  Future<void> _cargarPrestamos() async {
    setState(() => _isLoading = true);
    final datos = await _apiService.getPrestamos();
    setState(() {
      _prestamos = datos;
      _isLoading = false;
    });
  }

  Future<Map<String, dynamic>?> _mostrarBuscador(String titulo, List<dynamic> items, String keyId, String keyName, String? extraName) async {
    String filtro = '';
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final filtrados = items.where((item) {
              if (filtro.isEmpty) return true;
              final term = filtro.toLowerCase();
              final idStr = item[keyId].toString().toLowerCase();
              final nameStr = item[keyName].toString().toLowerCase();
              final extraStr = extraName != null ? (item[extraName] ?? '').toString().toLowerCase() : '';
              return idStr.contains(term) || nameStr.contains(term) || extraStr.contains(term);
            }).toList();

            return AlertDialog(
              backgroundColor: const Color(0xff1a1d29),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(titulo, style: const TextStyle(color: Colors.white)),
              content: SizedBox(
                width: 500,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      onChanged: (val) => setStateModal(() => filtro = val),
                      style: const TextStyle(color: Colors.white),
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Buscar...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(Icons.search, color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xff222636),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          itemCount: filtrados.length,
                          itemBuilder: (context, index) {
                            final item = filtrados[index];
                            final id = item[keyId];
                            final name = item[keyName];
                            final extra = extraName != null ? (item[extraName] ?? '') : '';
                            return ListTile(
                              hoverColor: Colors.white.withOpacity(0.05),
                              title: Text('$id - $name $extra', style: const TextStyle(color: Colors.white)),
                              onTap: () => Navigator.pop(context, item),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarModalNuevoPrestamo() async {
    final instrumentos = await _apiService.getInstrumentos();
    final operarios = await _apiService.getOperarios();
    
    final instrumentosDisponibles = instrumentos.where((i) {
      final estado = i['estado'].toString().toUpperCase();
      return estado == 'APTO' || estado == 'APROBADO';
    }).toList();
    final operariosActivos = operarios.where((o) => o['activo'] == true).toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        Map<String, dynamic>? selectedOperario;
        Map<String, dynamic>? selectedInstrumento;
        String observaciones = '';
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xff1e2235),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Nuevo Préstamo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Boton para seleccionar Operario
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      tileColor: const Color(0xff2a2f4a),
                      leading: const Icon(Icons.person, color: Color(0xff06b6d4)),
                      title: Text(
                        selectedOperario != null 
                            ? '${selectedOperario!['legajo']} - ${selectedOperario!['nombre']} ${selectedOperario!['apellido'] ?? ''}'
                            : 'Buscar y seleccionar Operario',
                        style: TextStyle(color: selectedOperario != null ? Colors.white : Colors.white54),
                      ),
                      trailing: const Icon(Icons.search, color: Colors.white54),
                      onTap: () async {
                        final res = await _mostrarBuscador('Buscar Operario', operariosActivos, 'legajo', 'nombre', 'apellido');
                        if (res != null) setModalState(() => selectedOperario = res);
                      },
                    ),
                    const SizedBox(height: 16),
                    // Boton para seleccionar Instrumento
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      tileColor: const Color(0xff2a2f4a),
                      leading: const Icon(Icons.construction, color: Color(0xff10b981)),
                      title: Text(
                        selectedInstrumento != null 
                            ? '${selectedInstrumento!['codigo']} - ${selectedInstrumento!['nombre']}'
                            : 'Buscar y seleccionar Instrumento',
                        style: TextStyle(color: selectedInstrumento != null ? Colors.white : Colors.white54),
                      ),
                      trailing: const Icon(Icons.search, color: Colors.white54),
                      onTap: () async {
                        final res = await _mostrarBuscador('Buscar Instrumento', instrumentosDisponibles, 'codigo', 'nombre', null);
                        if (res != null) setModalState(() => selectedInstrumento = res);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      onChanged: (val) => observaciones = val,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Observaciones (Opcional)',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: const Color(0xff2a2f4a),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: saving ? null : () async {
                    if (selectedInstrumento == null || selectedOperario == null) return;
                    setModalState(() => saving = true);
                    final res = await _apiService.createPrestamo(selectedInstrumento!['codigo'].toString(), selectedOperario!['legajo'].toString(), observaciones);
                    if (res['success'] == true) {
                      Navigator.pop(context);
                      _cargarPrestamos();
                    } else {
                      setModalState(() => saving = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${res['message']}')));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff10b981),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)
                  ),
                  child: saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Guardar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xff06b6d4)));
    }

    final prestamosFiltrados = _prestamos.where((p) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final operario = '${p['operario__nombre']} ${p['operario__apellido'] ?? ''}'.toLowerCase();
      final instrumento = '${p['instrumento__codigo']} ${p['instrumento__nombre']}'.toLowerCase();
      final estado = (p['estado'] ?? '').toString().toLowerCase();
      return operario.contains(q) || instrumento.contains(q) || estado.contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Gestión de Préstamos',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 250),
                      child: SizedBox(
                        height: 44,
                        child: TextField(
                          controller: TextEditingController(text: _searchQuery)..selection = TextSelection.collapsed(offset: _searchQuery.length),
                          onChanged: (value) => setState(() => _searchQuery = value),
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Buscar...',
                            hintStyle: const TextStyle(color: Colors.white54),
                            prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                            filled: true,
                            fillColor: const Color(0xff1e2235),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _mostrarModalNuevoPrestamo,
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo Préstamo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff10b981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _exportarXLSX(context, 'historial_prestamos', () => _apiService.exportarPrestamosXLSX(_searchQuery)),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Exportar Excel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF276CF5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _cargarPrestamos,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Actualizar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff4f46e5),
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
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xff1e2235),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: _prestamos.isEmpty
                ? const Center(
                    child: Text('No hay préstamos activos o en historial.', style: TextStyle(color: Colors.white54)),
                  )
                : Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: const BoxDecoration(
                          color: Color(0xff2a2f4a),
                          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                        ),
                        child: Row(
                          children: [
                            _buildHeaderCell('Operario', flex: 3),
                            _buildHeaderCell('Instrumento', flex: 3),
                            _buildHeaderCell('F. Salida', flex: 2),
                            _buildHeaderCell('Estado', flex: 2),
                            _buildHeaderCell('Acciones', flex: 2),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: prestamosFiltrados.length,
                          itemBuilder: (context, index) {
                            final p = prestamosFiltrados[index];
                            final isEven = index % 2 == 0;
                            final isActivo = p['estado'] == 'ACTIVO';
                            
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              decoration: BoxDecoration(
                                color: isEven ? Colors.transparent : Colors.white.withOpacity(0.02),
                                border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                              ),
                              child: Row(
                                children: [
                                  _buildDataCell('${p['operario__nombre']} ${p['operario__apellido'] ?? ''}', flex: 3, isBold: true),
                                  _buildDataCell('${p['instrumento__codigo']} - ${p['instrumento__nombre']}', flex: 3, color: const Color(0xff06b6d4)),
                                  _buildDataCell(p['fecha_prestamo']?.toString().split('T').first ?? '', flex: 2),
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isActivo ? const Color(0xff06b6d4).withOpacity(0.15) : Colors.greenAccent.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: isActivo ? const Color(0xff06b6d4).withOpacity(0.3) : Colors.greenAccent.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          p['estado'] ?? '',
                                          style: TextStyle(
                                            color: isActivo ? const Color(0xff06b6d4) : Colors.greenAccent,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        if (isActivo)
                                          IconButton(
                                            icon: const Icon(Icons.assignment_return, color: Colors.greenAccent),
                                            tooltip: 'Marcar Devuelto',
                                            onPressed: () async {
                                              bool? confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                                                backgroundColor: const Color(0xff1e2235),
                                                title: const Text('Confirmar', style: TextStyle(color: Colors.white)),
                                                content: const Text('¿Marcar este instrumento como devuelto?', style: TextStyle(color: Colors.white70)),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(c, false), style: TextButton.styleFrom(foregroundColor: Colors.white54), child: const Text('No')),
                                                  ElevatedButton(onPressed: () => Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff10b981), foregroundColor: Colors.white), child: const Text('Sí'))
                                                ],
                                              ));
                                              if (confirm == true) {
                                                await _apiService.devolverPrestamo(p['id']);
                                                _cargarPrestamos();
                                              }
                                            },
                                          ),
                                        IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.redAccent),
                                          tooltip: 'Eliminar Registro',
                                          onPressed: () async {
                                            bool? confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                                              backgroundColor: const Color(0xff1e2235),
                                              title: const Text('Eliminar', style: TextStyle(color: Colors.white)),
                                              content: const Text('¿Seguro que deseas eliminar este préstamo?', style: TextStyle(color: Colors.white70)),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(c, false), style: TextButton.styleFrom(foregroundColor: Colors.white54), child: const Text('Cancelar')),
                                                ElevatedButton(onPressed: () => Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffef4444), foregroundColor: Colors.white), child: const Text('Eliminar'))
                                              ],
                                            ));
                                            if (confirm == true) {
                                              await _apiService.deletePrestamo(p['id']);
                                              _cargarPrestamos();
                                            }
                                          },
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
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildDataCell(String text, {required int flex, bool isBold = false, Color? color}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          color: color ?? Colors.white,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
