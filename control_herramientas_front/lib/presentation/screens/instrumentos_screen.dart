import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/status_colors.dart';

class InstrumentosScreen extends StatefulWidget {
  final String? initialSearchQuery;
  const InstrumentosScreen({super.key, this.initialSearchQuery});

  @override
  State<InstrumentosScreen> createState() => _InstrumentosScreenState();
}

class _InstrumentosScreenState extends State<InstrumentosScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _instrumentos = [];
  bool _isLoading = true;
  String _searchQuery = '';

  /// Determina el estado real del instrumento de forma dinámica.
  /// Si la fecha de vencimiento ya pasó y el instrumento no está dado de BAJA ni en REPARACION,
  /// devuelve 'VENCIDO' sin importar el valor estático guardado en la DB.
  static String _estadoEfectivo(Map<String, dynamic> inst) {
    final estado = (inst['estado'] ?? '').toString().toUpperCase();
    if (estado == 'BAJA' || estado == 'REPARACION') return estado;
    final vtoStr = inst['vencimiento_calibracion'];
    if (vtoStr == null || vtoStr.toString().isEmpty) return estado;
    final vtoDate = DateTime.tryParse(vtoStr.toString());
    if (vtoDate == null) return estado;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final vtoDay = DateTime(vtoDate.year, vtoDate.month, vtoDate.day);
    return vtoDay.isBefore(today) ? 'VENCIDO' : estado;
  }

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
    _cargarInstrumentos();
  }

  Future<void> _cargarInstrumentos() async {
    setState(() => _isLoading = true);
    final datos = await _apiService.getInstrumentos();
    setState(() {
      _instrumentos = datos;
      _isLoading = false;
    });
  }



  Widget _buildField(String label, ValueChanged<String> onChanged, {String initialValue = '', bool isNumber = false, int maxLines = 1}) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        filled: true,
        fillColor: const Color(0xff2a2f4a),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
    );
  }

  void _mostrarDetalleInstrumento(Map<String, dynamic> inst) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff1e2235),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Instrumento: ${inst['codigo']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: StatusColors.getColor(inst['estado'] ?? '').withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: StatusColors.getColor(inst['estado'] ?? '').withOpacity(0.5)),
                ),
                child: Text(
                  inst['estado'] ?? 'APTO',
                  style: TextStyle(color: StatusColors.getColor(inst['estado'] ?? ''), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 650,
            height: 480,
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    indicatorColor: Color(0xff06b6d4),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white38,
                    tabs: [
                      Tab(text: 'Detalles Generales'),
                      Tab(text: 'Historial de Calibraciones'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // PESTAÑA 1: DETALLES GENERALES
                        SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailRow('Nombre / Descripción:', inst['nombre'] ?? '-'),
                              _buildDetailRow('Marca:', inst['marca'] ?? '-'),
                              _buildDetailRow('Modelo:', inst['modelo'] ?? '-'),
                              _buildDetailRow('Número de Serie:', inst['serie'] ?? '-'),
                              _buildDetailRow('Rango de Medición:', inst['rango'] ?? '-'),
                              _buildDetailRow('Unidad de Medida:', inst['unidad_medida'] ?? '-'),
                              _buildDetailRow('Ubicación:', inst['ubicacion'] ?? '-'),
                              _buildDetailRow('Frecuencia de Control:', inst['frecuencia_control'] != null ? "${inst['frecuencia_control']} meses" : '-'),
                              _buildDetailRow('Número de Certificado:', inst['num_certificado'] ?? '-'),
                              _buildDetailRow('Última Calibración:', inst['ultima_calibracion'] ?? 'N/A'),
                              _buildDetailRow('Vencimiento de Calibración:', inst['vencimiento_calibracion'] ?? 'N/A'),
                              const SizedBox(height: 12),
                              const Text('Observaciones:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 6),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xff2a2f4a),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  (inst['observacion'] ?? '').toString().isEmpty ? 'Sin observaciones.' : inst['observacion'],
                                  style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // PESTAÑA 2: HISTORIAL DE CALIBRACIONES
                        _buildHistorialCalibracionesTab(inst['codigo'].toString()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff4f46e5), foregroundColor: Colors.white),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistorialCalibracionesTab(String codigo) {
    return FutureBuilder<List<dynamic>>(
      future: _apiService.getHistorialCalibracion(codigo),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xff06b6d4)));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
        }
        final list = snapshot.data ?? [];
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Historial registrado', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                ElevatedButton.icon(
                  onPressed: () => _registrarNuevaCalibracion(context, codigo),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Registrar Calibración', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff10b981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('No hay calibraciones registradas aún.', style: TextStyle(color: Colors.white30)))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final c = list[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xff2a2f4a),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Fecha Cal: ${c['fecha_calibracion']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('Vence: ${c['fecha_vencimiento']}', style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w500)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('Certificado: ${c['num_certificado'].toString().isEmpty ? 'N/A' : c['num_certificado']}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              if (c['observacion'].toString().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text('Obs: ${c['observacion']}', style: const TextStyle(color: Colors.white30, fontSize: 11)),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _registrarNuevaCalibracion(BuildContext context, String codigo) {
    String fechaCal = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String fechaVen = '';
    String numCert = '';
    String obs = '';
    bool saving = false;

    showDialog(
      context: context,
      builder: (c) {
        return StatefulBuilder(
          builder: (c, setSubState) {
            return AlertDialog(
              backgroundColor: const Color(0xff1e2235),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Registrar Calibración', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: TextEditingController(text: fechaCal)..selection = TextSelection.collapsed(offset: fechaCal.length),
                      decoration: const InputDecoration(
                        labelText: 'Fecha Calibración (YYYY-MM-DD)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) => fechaCal = val,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Fecha Vencimiento (YYYY-MM-DD)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) => fechaVen = val,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Número de Certificado',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) => numCert = val,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Observación',
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) => obs = val,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: saving ? null : () async {
                    if (fechaCal.isEmpty || fechaVen.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Las fechas de calibración y vencimiento son obligatorias'), backgroundColor: Colors.red)
                      );
                      return;
                    }
                    setSubState(() => saving = true);
                    final res = await _apiService.crearHistorialCalibracion(codigo, fechaCal, fechaVen, numCert, obs);
                    if (res['success'] == true) {
                      Navigator.pop(c);
                      Navigator.pop(context);
                      _cargarInstrumentos();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Calibración registrada correctamente y estado actualizado'), backgroundColor: Colors.green)
                      );
                    } else {
                      setSubState(() => saving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${res['message']}'), backgroundColor: Colors.red)
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff10b981)),
                  child: saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Registrar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  void _mostrarModalNuevoInstrumento() {
    String codigo = '';
    String nombre = '';
    String marca = '';
    String modelo = '';
    String serie = '';
    String rango = '';
    String unidadMedida = '';
    String ubicacion = '';
    String frecuenciaControl = '';
    String numCertificado = '';
    String ultimaCal = '';
    String vtoCal = '';
    String estado = 'APTO';
    String observacion = '';
    String rutaPdf = '';
    bool saving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xff1e2235),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Nuevo Instrumento', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 750,
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Columna 1
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildField('Código (ej: AL4)', (val) => codigo = val),
                            const SizedBox(height: 12),
                            _buildField('Nombre / Descripción', (val) => nombre = val),
                            const SizedBox(height: 12),
                            _buildField('Marca', (val) => marca = val),
                            const SizedBox(height: 12),
                            _buildField('Modelo', (val) => modelo = val),
                            const SizedBox(height: 12),
                            _buildField('Número de Serie', (val) => serie = val),
                            const SizedBox(height: 12),
                            _buildField('Rango de Medición', (val) => rango = val),
                            const SizedBox(height: 12),
                            _buildField('Unidad de Medida (ej: mm, ºC)', (val) => unidadMedida = val),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Columna 2
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildField('Ubicación (ej: Estante B)', (val) => ubicacion = val),
                            const SizedBox(height: 12),
                            _buildField('Frecuencia Control (meses)', (val) => frecuenciaControl = val, isNumber: true),
                            const SizedBox(height: 12),
                            _buildField('Número de Certificado', (val) => numCertificado = val),
                            const SizedBox(height: 12),
                            _buildField('Última Calibración (YYYY-MM-DD)', (val) => ultimaCal = val),
                            const SizedBox(height: 12),
                            _buildField('Vencimiento Calibración (YYYY-MM-DD)', (val) => vtoCal = val),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: estado,
                              dropdownColor: const Color(0xff2a2f4a),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Estado Inicial',
                                filled: true,
                                fillColor: const Color(0xff2a2f4a),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                              items: ['APTO', 'EN USO', 'REPARACION', 'VENCIDO', 'BAJA'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (val) => estado = val!,
                            ),
                            const SizedBox(height: 12),
                            _buildField('Observaciones', (val) => observacion = val, maxLines: 2),
                            const SizedBox(height: 12),
                            Builder(
                              builder: (ctx) {
                                final hasFile = rutaPdf.isNotEmpty;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Certificado PDF asociado:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () async {
                                              final config = await _apiService.getConfig();
                                              final basePath = config['reports_base_path']?.toString() ?? '';
                                              var result = await FilePicker.pickFiles(
                                                type: FileType.custom,
                                                allowedExtensions: ['pdf'],
                                                initialDirectory: basePath.isNotEmpty ? basePath : null,
                                              );
                                              if (result.isNotEmpty && result.first.path != null) {
                                                setModalState(() => rutaPdf = result.first.path!);
                                              }
                                            },
                                            icon: Icon(hasFile ? Icons.picture_as_pdf : Icons.attach_file, color: hasFile ? Colors.redAccent : Colors.white70),
                                            label: Text(
                                              hasFile ? rutaPdf.split('\\').last.split('/').last : 'Buscar PDF',
                                              style: TextStyle(color: hasFile ? Colors.redAccent : Colors.white70),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xff2a2f4a),
                                              alignment: Alignment.centerLeft,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            ),
                                          ),
                                        ),
                                        if (hasFile) ...[
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.close, color: Colors.white54),
                                            tooltip: 'Desasociar PDF',
                                            onPressed: () => setModalState(() => rutaPdf = ''),
                                          ),
                                        ]
                                      ],
                                    ),
                                  ],
                                );
                              }
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                    if (codigo.isEmpty || nombre.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código y nombre son obligatorios')));
                      return;
                    }
                    setModalState(() => saving = true);
                    final payload = {
                      'codigo': codigo,
                      'nombre': nombre,
                      'marca': marca,
                      'modelo': modelo,
                      'serie': serie,
                      'rango': rango,
                      'unidad_medida': unidadMedida,
                      'ubicacion': ubicacion,
                      'frecuencia_control': frecuenciaControl.isEmpty ? null : int.tryParse(frecuenciaControl),
                      'num_certificado': numCertificado,
                      'ultima_calibracion': ultimaCal.isEmpty ? null : ultimaCal,
                      'vencimiento_calibracion': vtoCal.isEmpty ? null : vtoCal,
                      'estado': estado,
                      'observacion': observacion,
                      'ruta_pdf': rutaPdf.isEmpty ? null : rutaPdf,
                    };
                    print('JSON CREAR INSTRUMENTO: \$payload');
                    final res = await _apiService.createInstrumento(payload);
                    if (res['success'] == true) {
                      Navigator.pop(context);
                      _cargarInstrumentos();
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

  void _mostrarModalEditarInstrumento(Map<String, dynamic> inst) {
    String nombre = inst['nombre'] ?? '';
    String marca = inst['marca'] ?? '';
    String modelo = inst['modelo'] ?? '';
    String serie = inst['serie'] ?? '';
    String rango = inst['rango'] ?? '';
    String unidadMedida = inst['unidad_medida'] ?? '';
    String ubicacion = inst['ubicacion'] ?? '';
    String frecuenciaControl = inst['frecuencia_control']?.toString() ?? '';
    String numCertificado = inst['num_certificado'] ?? '';
    String ultimaCal = inst['ultima_calibracion'] ?? '';
    String vtoCal = inst['vencimiento_calibracion'] ?? '';
    String estado = inst['estado'] ?? 'APTO';
    String observacion = inst['observacion'] ?? '';
    String rutaPdf = inst['ruta_pdf'] ?? '';
    bool saving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xff1e2235),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Editar Instrumento: ${inst['codigo']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 750,
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Columna 1
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildField('Nombre / Descripción', (val) => nombre = val, initialValue: nombre),
                            const SizedBox(height: 12),
                            _buildField('Marca', (val) => marca = val, initialValue: marca),
                            const SizedBox(height: 12),
                            _buildField('Modelo', (val) => modelo = val, initialValue: modelo),
                            const SizedBox(height: 12),
                            _buildField('Número de Serie', (val) => serie = val, initialValue: serie),
                            const SizedBox(height: 12),
                            _buildField('Rango de Medición', (val) => rango = val, initialValue: rango),
                            const SizedBox(height: 12),
                            _buildField('Unidad de Medida (ej: mm, ºC)', (val) => unidadMedida = val, initialValue: unidadMedida),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Columna 2
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildField('Ubicación (ej: Estante B)', (val) => ubicacion = val, initialValue: ubicacion),
                            const SizedBox(height: 12),
                            _buildField('Frecuencia Control (meses)', (val) => frecuenciaControl = val, initialValue: frecuenciaControl, isNumber: true),
                            const SizedBox(height: 12),
                            _buildField('Número de Certificado', (val) => numCertificado = val, initialValue: numCertificado),
                            const SizedBox(height: 12),
                            _buildField('Última Calibración (YYYY-MM-DD)', (val) => ultimaCal = val, initialValue: ultimaCal),
                            const SizedBox(height: 12),
                            _buildField('Vencimiento Calibración (YYYY-MM-DD)', (val) => vtoCal = val, initialValue: vtoCal),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: ['APTO', 'EN USO', 'REPARACION', 'VENCIDO', 'BAJA'].contains(estado.toUpperCase()) ? estado.toUpperCase() : 'APTO',
                              dropdownColor: const Color(0xff2a2f4a),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Estado',
                                filled: true,
                                fillColor: const Color(0xff2a2f4a),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                              ),
                              items: ['APTO', 'EN USO', 'REPARACION', 'VENCIDO', 'BAJA'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                              onChanged: (val) => estado = val!,
                            ),
                            const SizedBox(height: 12),
                            _buildField('Observaciones', (val) => observacion = val, initialValue: observacion, maxLines: 2),
                            const SizedBox(height: 12),
                            Builder(
                              builder: (ctx) {
                                final hasFile = rutaPdf.isNotEmpty;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Certificado PDF asociado:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () async {
                                              final config = await _apiService.getConfig();
                                              final basePath = config['reports_base_path']?.toString() ?? '';
                                              var result = await FilePicker.pickFiles(
                                                type: FileType.custom,
                                                allowedExtensions: ['pdf'],
                                                initialDirectory: basePath.isNotEmpty ? basePath : null,
                                              );
                                              if (result.isNotEmpty && result.first.path != null) {
                                                setModalState(() => rutaPdf = result.first.path!);
                                              }
                                            },
                                            icon: Icon(hasFile ? Icons.picture_as_pdf : Icons.attach_file, color: hasFile ? Colors.redAccent : Colors.white70),
                                            label: Text(
                                              hasFile ? rutaPdf.split('\\').last.split('/').last : 'Buscar PDF',
                                              style: TextStyle(color: hasFile ? Colors.redAccent : Colors.white70),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xff2a2f4a),
                                              alignment: Alignment.centerLeft,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            ),
                                          ),
                                        ),
                                        if (hasFile) ...[
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.close, color: Colors.white54),
                                            tooltip: 'Desasociar PDF',
                                            onPressed: () => setModalState(() => rutaPdf = ''),
                                          ),
                                        ]
                                      ],
                                    ),
                                  ],
                                );
                              }
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El nombre es obligatorio')));
                      return;
                    }
                    setModalState(() => saving = true);
                    final payload = {
                      'nombre': nombre,
                      'marca': marca,
                      'modelo': modelo,
                      'serie': serie,
                      'rango': rango,
                      'unidad_medida': unidadMedida,
                      'ubicacion': ubicacion,
                      'frecuencia_control': frecuenciaControl.isEmpty ? null : int.tryParse(frecuenciaControl),
                      'num_certificado': numCertificado,
                      'ultima_calibracion': ultimaCal.isEmpty ? null : ultimaCal,
                      'vencimiento_calibracion': vtoCal.isEmpty ? null : vtoCal,
                      'estado': estado,
                      'observacion': observacion,
                      'ruta_pdf': rutaPdf.isEmpty ? null : rutaPdf,
                    };
                    print('JSON EDITAR INSTRUMENTO: \$payload');
                    final res = await _apiService.updateInstrumento(inst['codigo'].toString(), payload);
                    if (res['success'] == true) {
                      Navigator.pop(context);
                      _cargarInstrumentos();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff121420),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // <-- Corregido acá
              children: [
                const Text(
                  'Control de Instrumentos (Metrología)',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
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
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Buscar por código, nombre, marca o estado...',
                          hintStyle: const TextStyle(color: Colors.white54),
                          prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                          filled: true,
                          fillColor: const Color(0xff1e2235),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                          ),
                        ),
                      ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff10b981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: _mostrarModalNuevoInstrumento,
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo Instrumento'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF276CF5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () => _exportarXLSX(context, 'inventario_instrumentos', () => _apiService.exportarInstrumentosXLSX(_searchQuery)),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Exportar Excel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff4f46e5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: _cargarInstrumentos,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final instrumentosFiltrados = _instrumentos.where((inst) {
                  final estadoEfec = _estadoEfectivo(inst as Map<String, dynamic>);
                  if (_searchQuery.isEmpty) return true;
                  final q = _searchQuery.toLowerCase().trim();
                  final queryUpper = _searchQuery.trim().toUpperCase();
                  // Matching exacto por estado efectivo (dinámico)
                  // Permitimos que la búsqueda filtre directamente cualquier estado exacto que provenga de los tap cards
                  if (queryUpper == estadoEfec) return true;
                  
                  // Para evitar falsos positivos cuando el query es específicamente un estado válido (ej: buscando APTO y devuelve también nombres con 'apto')
                  final List<String> estadosValidos = ['APTO', 'VENCIDO', 'REPARACION', 'EN USO', 'BAJA', 'DE REFERENCIA', 'NO EXISTE', 'NO APTO', 'SIN DEFINIR'];
                  if (estadosValidos.contains(queryUpper)) return false;
                  
                  return (inst['codigo'] ?? '').toString().toLowerCase().contains(q) ||
                         (inst['nombre'] ?? '').toString().toLowerCase().contains(q) ||
                         (inst['marca'] ?? '').toString().toLowerCase().contains(q) ||
                         estadoEfec.toLowerCase().contains(q);
                }).toList();
                return Expanded(
                  child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xff4f46e5)))
                  : _instrumentos.isEmpty
                      ? const Center(
                          child: Text(
                            'No se encontraron instrumentos registrados.',
                            style: TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: const Color(0xff1e2235),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              )
                            ],
                          ),
                          child: Column(
                            children: [
                              // ENCABEZADOS DE LA TABLA
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                decoration: const BoxDecoration(
                                  color: Color(0xff2a2f4a),
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                ),
                                child: Row(
                                  children: [
                                    _buildHeaderCell('Código', flex: 2),
                                    _buildHeaderCell('Instrumento', flex: 4),
                                    _buildHeaderCell('Marca', flex: 2),
                                    _buildHeaderCell('U. Calibración', flex: 3),
                                    _buildHeaderCell('Vencimiento', flex: 3),
                                    _buildHeaderCell('Estado', flex: 2),
                                    _buildHeaderCell('Acciones', flex: 2),
                                  ],
                                ),
                              ),
                              // CUERPO DE LA TABLA
                              Expanded(
                                child: ListView.builder(
                                  itemCount: instrumentosFiltrados.length,
                                  itemBuilder: (context, index) {
                                    final inst = instrumentosFiltrados[index];
                                    final isEven = index % 2 == 0;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                      decoration: BoxDecoration(
                                        color: isEven ? Colors.transparent : Colors.white.withOpacity(0.02),
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.white.withOpacity(0.05),
                                            width: 1,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          _buildDataCell(inst['codigo'] ?? '-', flex: 2, isBold: true),
                                          _buildDataCell(inst['nombre'] ?? '-', flex: 4),
                                          _buildDataCell(inst['marca'] ?? '-', flex: 2, isFaded: true),
                                          _buildDataCell(inst['ultima_calibracion'] ?? 'N/A', flex: 3, isFaded: true),
                                          _buildDataCell(inst['vencimiento_calibracion'] ?? 'N/A', flex: 3, isFaded: true),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.centerLeft,
                                              child: Builder(builder: (context) {
                                                final estadoMostrar = _estadoEfectivo(inst as Map<String, dynamic>);
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: StatusColors.getColor(estadoMostrar).withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: StatusColors.getColor(estadoMostrar).withOpacity(0.5)),
                                                  ),
                                                  child: Text(
                                                    estadoMostrar,
                                                    style: TextStyle(
                                                      color: StatusColors.getColor(estadoMostrar),
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                );
                                              }),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Align(
                                              alignment: Alignment.center,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.info_outline, color: Colors.cyanAccent),
                                                    tooltip: 'Ver Detalles',
                                                    onPressed: () => _mostrarDetalleInstrumento(inst),
                                                  ),
                                                  if ((inst['ruta_pdf'] ?? '').toString().isNotEmpty)
                                                    IconButton(
                                                      icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                                                      tooltip: 'Abrir PDF Asociado',
                                                      onPressed: () async {
                                                        String path = (inst['ruta_pdf'] ?? '').toString();
                                                        path = path.replaceAll('/', '\\');
                                                        
                                                        if (!File(path).existsSync()) {
                                                          if (mounted) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(content: Text('El archivo PDF ya no se encuentra en la ruta especificada')),
                                                            );
                                                          }
                                                          return;
                                                        }

                                                        if (Platform.isWindows) {
                                                          await Process.run('explorer.exe', [path]);
                                                        } else {
                                                          final result = await OpenFile.open(path);
                                                          if (result.type != ResultType.done && mounted) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(content: Text('No se pudo abrir el PDF: ${result.message}')),
                                                            );
                                                          }
                                                        }
                                                      },
                                                    ),
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                                    tooltip: 'Editar Instrumento',
                                                    onPressed: () => _mostrarModalEditarInstrumento(inst),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                                                    tooltip: 'Eliminar Instrumento',
                                                    onPressed: () async {
                                                      bool? confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                                                        backgroundColor: const Color(0xff1e2235),
                                                        title: const Text('Eliminar', style: TextStyle(color: Colors.white)),
                                                        content: const Text('¿Seguro que deseas eliminar este instrumento de forma permanente?', style: TextStyle(color: Colors.white70)),
                                                        actions: [
                                                          TextButton(onPressed: () => Navigator.pop(c, false), style: TextButton.styleFrom(foregroundColor: Colors.white54), child: const Text('Cancelar')),
                                                          ElevatedButton(onPressed: () => Navigator.pop(c, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xffef4444), foregroundColor: Colors.white), child: const Text('Eliminar'))
                                                        ],
                                                      ));
                                                      if (confirm == true) {
                                                        await _apiService.deleteInstrumento(inst['codigo']);
                                                        _cargarInstrumentos();
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ), // closes Column
                        ), // closes Container
                ); // closes Expanded
              }, // closes Builder function
            ), // closes Builder
          ], // closes main Column children
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
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDataCell(String text, {required int flex, bool isBold = false, bool isFaded = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(
          color: isFaded ? Colors.white70 : Colors.white,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
