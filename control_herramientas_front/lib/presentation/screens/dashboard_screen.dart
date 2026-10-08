import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../../core/services/api_service.dart';
import 'instrumentos_screen.dart';
import '../../features/personal/presentation/operarios_screen.dart';
import '../../features/prestamos/presentation/prestamos_screen.dart';
import '../../../core/utils/status_colors.dart';
import '../widgets/ios_glass_card.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _dbPath;
  
  int _totalInstrumentos = 0;
  int _instrumentosAprobados = 0;
  int _instrumentosVencidos = 0;
  int _instrumentosReparacion = 0;
  int _instrumentosEnUso = 0;
  int _instrumentosBaja = 0;
  int _instrumentosReferencia = 0;
  int _instrumentosNoExiste = 0;
  int _instrumentosNoApto = 0;
  
  int _prestamosActivos = 0;
  int _totalOperarios = 0;

  Map<String, int> _distribucionEstados = {};
  List<Map<String, dynamic>> _proximosVencimientos = [];
  int _alertDaysThreshold = 45;

  @override
  void initState() {
    super.initState();
    _cargarDatosDashboard();
  }

  // Regla centralizada: un instrumento está vencido si su fecha de vencimiento es anterior a hoy
  // y no está formalmente dado de BAJA o en REPARACION.
  static bool _esVencidoPorFecha(Map<String, dynamic> inst) {
    final estado = (inst['estado'] ?? '').toString().toUpperCase();
    if (estado == 'BAJA' || estado == 'REPARACION') return false;
    final vtoStr = inst['vencimiento_calibracion'];
    if (vtoStr == null || vtoStr.toString().isEmpty) return false;
    final vtoDate = DateTime.tryParse(vtoStr.toString());
    if (vtoDate == null) return false;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final vtoDay = DateTime(vtoDate.year, vtoDate.month, vtoDate.day);
    return vtoDay.isBefore(today);
  }

  Future<void> _cargarDatosDashboard() async {
    setState(() => _isLoading = true);

    final dbPath = await _apiService.getDebugDbPath();

    // Intento 1: endpoint dedicado del backend (más eficiente)
    final stats = await _apiService.getDashboardStats();

    if (mounted && stats != null) {
      setState(() {
        _totalInstrumentos = stats['total_instrumentos'] ?? 0;
        _instrumentosAprobados = stats['instrumentos_aprobados'] ?? 0;
        _instrumentosVencidos = stats['instrumentos_vencidos'] ?? 0;
        _instrumentosReparacion = stats['instrumentos_reparacion'] ?? 0;
        _instrumentosEnUso = stats['instrumentos_en_uso'] ?? 0;
        _instrumentosBaja = stats['instrumentos_baja'] ?? 0;
        _instrumentosReferencia = stats['instrumentos_referencia'] ?? 0;
        _instrumentosNoExiste = stats['instrumentos_no_existe'] ?? 0;
        _instrumentosNoApto = stats['instrumentos_no_apto'] ?? 0;
        _prestamosActivos = stats['prestamos_activos'] ?? 0;
        _totalOperarios = stats['total_operarios'] ?? 0;
        _proximosVencimientos = List<Map<String, dynamic>>.from(stats['proximos_vencimientos'] ?? []);
        
        // Parsear distribución
        final dynamic distObj = stats['distribucion_estados'];
        if (distObj != null && distObj is Map) {
          _distribucionEstados = distObj.map((key, value) => MapEntry(key.toString().toUpperCase(), (value as num).toInt()));
        } else {
          _distribucionEstados = {};
        }
        _alertDaysThreshold = stats['alert_days_threshold'] ?? 45;
        _dbPath = dbPath;
        _isLoading = false;
      });
      return;
    }

    // Fallback: si el endpoint dedicado falla, calcular localmente desde la lista de instrumentos
    final config = await _apiService.getConfig();
    final instrumentos = await _apiService.getInstrumentos();
    final prestamos = await _apiService.getPrestamos();
    final operarios = await _apiService.getOperarios();

    int aprobados = 0, vencidos = 0, reparacion = 0, enUso = 0, baja = 0;
    int deReferencia = 0, noExiste = 0, noApto = 0;
    final List<Map<String, dynamic>> proximos = [];
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    for (var inst in instrumentos) {
      final estadoRaw = (inst['estado'] ?? '').toString().toUpperCase();
      final esVencido = _esVencidoPorFecha(inst);

      if (estadoRaw == 'BAJA') {
        baja++;
      } else if (estadoRaw == 'DE REFERENCIA') {
        deReferencia++;
      } else if (estadoRaw == 'NO EXISTE') {
        noExiste++;
      } else if (estadoRaw == 'NO APTO') {
        noApto++;
      } else if (esVencido) {
        vencidos++;
      } else if (estadoRaw == 'REPARACION') {
        reparacion++;
      } else if (estadoRaw == 'EN USO') {
        enUso++;
      } else {
        aprobados++;
      }

      final vtoStr = inst['vencimiento_calibracion'];
      if (vtoStr != null && vtoStr.toString().isNotEmpty && estadoRaw != 'BAJA') {
        final vtoDate = DateTime.tryParse(vtoStr.toString());
        if (vtoDate != null) {
          final vtoDay = DateTime(vtoDate.year, vtoDate.month, vtoDate.day);
          final dias = vtoDay.difference(today).inDays;
          // Filtro estricto: Sólo instrumentos a vencer en el futuro dentro del umbral
          if (dias >= 0 && dias <= _alertDaysThreshold) {
            proximos.add({
              'codigo': inst['codigo'],
              'nombre': inst['nombre'],
              'dias': dias,
              'fecha': vtoStr,
              'estado': esVencido ? 'VENCIDO' : estadoRaw,
              'is_vencido': esVencido,
            });
          }
        }
      }
    }

    proximos.sort((a, b) => (a['dias'] as int).compareTo(b['dias'] as int));

    int prestamosActivos = 0;
    for (var p in prestamos) {
      final fd = p['fecha_devolucion'];
      if (fd == null || fd.toString().trim().isEmpty) {
        prestamosActivos++;
      }
    }

    final Map<String, int> distribucionFallback = {
      'APTO': aprobados,
      'VENCIDO': vencidos,
      'EN USO': enUso,
      'REPARACION': reparacion,
      'DE REFERENCIA': deReferencia,
      'NO APTO': noApto,
      'NO EXISTE': noExiste,
      'BAJA': baja,
    };

    if (mounted) {
      setState(() {
        _totalInstrumentos = instrumentos.length;
        _instrumentosAprobados = aprobados;
        _instrumentosVencidos = vencidos;
        _instrumentosReparacion = _distribucionEstados['REPARACION'] ?? reparacion;
        _instrumentosEnUso = _distribucionEstados['EN USO'] ?? enUso;
        _instrumentosBaja = _distribucionEstados['BAJA'] ?? baja;
        _instrumentosReferencia = _distribucionEstados['DE REFERENCIA'] ?? deReferencia;
        _instrumentosNoExiste = _distribucionEstados['NO EXISTE'] ?? noExiste;
        _instrumentosNoApto = _distribucionEstados['NO APTO'] ?? noApto;
        _prestamosActivos = prestamosActivos;
        _totalOperarios = operarios.length;
        _proximosVencimientos = proximos;
        _distribucionEstados = distribucionFallback;
        _alertDaysThreshold = config['alert_days_threshold'] ?? 45;
        _dbPath = dbPath;
        _isLoading = false;
      });
    }
  }

  void _abrirModalCard(String title, Widget screen) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: IosGlassCard(
            padding: EdgeInsets.zero,
            customColor: const Color(0xfff4f6f9),
            borderColor: const Color(0xffcbd5e1),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.88,
              height: MediaQuery.of(context).size.height * 0.88,
              child: Scaffold(
                backgroundColor: const Color(0xfff4f6f9),
                appBar: AppBar(
                  backgroundColor: const Color(0xfff1f5f9),
                  elevation: 0,
                  iconTheme: const IconThemeData(color: Color(0xff0f172a)),
                  title: Text(title, style: GoogleFonts.inter(color: const Color(0xff0f172a), fontWeight: FontWeight.bold, fontSize: 18)),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xff0f172a)),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                body: screen,
              ),
            ),
          ),
        );
      },
    );
  }

  List<dynamic> _backups = [];
  bool _loadingBackups = false;

  String _formatearTamano(int bytes) {
    if (bytes >= 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
    }
    return "${(bytes / 1024).toStringAsFixed(2)} KB";
  }

  Future<void> _exportarPDF(BuildContext context, String filenamePrefix, Future<List<int>?> Function() apiCall) async {
    try {
      final bytes = await apiCall();
      if (bytes == null || bytes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo generar el documento PDF.'), backgroundColor: Colors.red)
        );
        return;
      }
      
      final appDir = Directory(Platform.resolvedExecutable).parent;
      final dir = Directory('${appDir.path}\\Reportes');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final file = File('${dir.path}\\${filenamePrefix}_$timestamp.pdf');
      
      await file.writeAsBytes(bytes);
      
      if (Platform.isWindows) {
        try {
          await Process.run('cmd', ['/c', 'start', '', file.path], runInShell: true);
        } catch (e) {
          print("Error al abrir PDF: $e");
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF generado y abierto automáticamente: ${file.path}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar PDF: $e'), backgroundColor: Colors.red)
      );
    }
  }

  Future<void> _cargarBackups() async {
    setState(() => _loadingBackups = true);
    final list = await _apiService.getBackups();
    setState(() {
      _backups = list;
      _loadingBackups = false;
    });
  }

  void _mostrarModalBackups() {
    _loadingBackups = true;

    showDialog(
      context: context,
      builder: (context) {
        bool initialLoad = true;
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (initialLoad) {
              initialLoad = false;
              _apiService.getBackups().then((list) {
                if (context.mounted) {
                  setModalState(() {
                    _backups = list;
                    _loadingBackups = false;
                  });
                }
              });
            }

            Future<void> actualizarModal() async {
              setModalState(() => _loadingBackups = true);
              final list = await _apiService.getBackups();
              if (context.mounted) {
                setModalState(() {
                  _backups = list;
                  _loadingBackups = false;
                });
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xfff8fafc),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Copias de Seguridad (Backups)', style: TextStyle(color: Color(0xff0f172a), fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: _loadingBackups ? null : () async {
                      setModalState(() => _loadingBackups = true);
                      final res = await _apiService.crearBackup();
                      if (res) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Backup creado correctamente'), backgroundColor: Colors.green)
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Error al crear el backup'), backgroundColor: Colors.red)
                        );
                      }
                      await actualizarModal();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Crear Nueva Copia'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff10b981),
                      foregroundColor: Colors.white,
                    ),
                  )
                ],
              ),
              content: SizedBox(
                width: 650,
                height: 400,
                child: _loadingBackups 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xff4f46e5)))
                    : _backups.isEmpty
                        ? const Center(child: Text('No hay copias de seguridad creadas aún.', style: TextStyle(color: Color(0xff64748b))))
                        : ListView.builder(
                            itemCount: _backups.length,
                            itemBuilder: (context, index) {
                              final b = _backups[index];
                              final String nombre = b['nombre'] ?? '';
                              final int tamano = b['tamano'] ?? 0;
                              final String fecha = b['fecha_creacion'] ?? '';
                              
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xfff1f5f9),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xffe2e8f0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.archive_outlined, color: Color(0xff4f46e5), size: 28),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(nombre, style: const TextStyle(color: Color(0xff0f172a), fontWeight: FontWeight.bold, fontSize: 13)),
                                          const SizedBox(height: 4),
                                          Text('Fecha: $fecha  |  Tamaño: ${_formatearTamano(tamano)}', style: const TextStyle(color: Color(0xff64748b), fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                                      tooltip: 'Eliminar esta copia',
                                      onPressed: () async {
                                        final messenger = ScaffoldMessenger.of(context);
                                        
                                        bool? confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (c) => AlertDialog(
                                            backgroundColor: const Color(0xfff8fafc),
                                            title: const Text('¿Eliminar copia?', style: TextStyle(color: Color(0xff0f172a))),
                                            content: const Text('¿Seguro que deseas eliminar permanentemente este archivo de copia de seguridad?', style: TextStyle(color: Color(0xff475569))),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar', style: TextStyle(color: Color(0xff64748b)))),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(c, true),
                                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
                                              )
                                            ],
                                          )
                                        );

                                        if (confirm == true) {
                                          setModalState(() => _loadingBackups = true);
                                          final success = await _apiService.eliminarBackup(nombre);
                                          if (success) {
                                            messenger.showSnackBar(
                                              const SnackBar(content: Text('Backup eliminado correctamente'), backgroundColor: Colors.green)
                                            );
                                          } else {
                                            messenger.showSnackBar(
                                              const SnackBar(content: Text('Error al eliminar backup'), backgroundColor: Colors.red)
                                            );
                                          }
                                          await actualizarModal();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cerrar', style: TextStyle(color: Color(0xff4f46e5))),
                )
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(color: Color(0xff334155), fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xff4f46e5)),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visión General',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff0f172a),
                    ),
                  ),
                  if (_dbPath != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xffe2e8f0),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xffcbd5e1)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.storage, size: 14, color: Color(0xff64748b)),
                          const SizedBox(width: 8),
                          Text(
                            _dbPath!,
                            style: const TextStyle(color: Color(0xff475569), fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _mostrarModalBackups,
                    icon: const Icon(Icons.settings_backup_restore, size: 18),
                    label: const Text("Copias de Seguridad"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff4f46e5),
                      foregroundColor: Colors.white,
                      elevation: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Color(0xff475569)),
                    onPressed: _cargarDatosDashboard,
                    tooltip: 'Actualizar',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // SECCIÓN DESTACADA SUPERIOR (2 COLUMNAS): APTO Y PRÓX. A VENCER
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'APTO',
                  value: (_distribucionEstados['APTO'] ?? _instrumentosAprobados).toString(),
                  icon: Icons.check_circle_outline,
                  color: StatusColors.getColor('APTO'),
                  isFeatured: true,
                  onTap: () => _abrirModalCard('Instrumentos APTO', const InstrumentosScreen(initialSearchQuery: 'APTO')),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'PRÓX. A VENCER',
                  value: _proximosVencimientos.length.toString(),
                  icon: Icons.notification_important_outlined,
                  color: Colors.orangeAccent,
                  isFeatured: true,
                  onTap: () => _abrirModalCard('Instrumentos PRÓX. A VENCER', const InstrumentosScreen(initialSearchQuery: 'PRÓX. A VENCER')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // RESTO DE MÉTRICAS EN GRID DE 4 COLUMNAS
          GridView.count(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.85,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatCard(
                title: 'TOTAL INSTRUMENTOS',
                value: _totalInstrumentos.toString(),
                icon: Icons.precision_manufacturing,
                color: const Color(0xff4f46e5),
                onTap: () => _abrirModalCard('TOTAL INSTRUMENTOS', const InstrumentosScreen()),
              ),
              ...[
                'VENCIDO', 'EN USO', 'REPARACION', 
                'DE REFERENCIA', 'NO APTO', 'NO EXISTE', 'BAJA'
              ].map((estadoUpper) {
                final int count = _distribucionEstados[estadoUpper] ?? 0;
                IconData icon;
                switch (estadoUpper) {
                  case 'VENCIDO': icon = Icons.warning_amber_rounded; break;
                  case 'REPARACION': icon = Icons.build_circle_outlined; break;
                  case 'EN USO': icon = Icons.handyman_outlined; break;
                  case 'BAJA': icon = Icons.delete_outline; break;
                  case 'DE REFERENCIA': icon = Icons.menu_book_outlined; break;
                  case 'NO EXISTE': icon = Icons.do_not_disturb_alt_outlined; break;
                  case 'NO APTO': icon = Icons.cancel_outlined; break;
                  default: icon = Icons.help_outline;
                }
                return _buildStatCard(
                  title: estadoUpper,
                  value: count.toString(),
                  icon: icon,
                  color: StatusColors.getColor(estadoUpper),
                  onTap: () => _abrirModalCard('Instrumentos $estadoUpper', InstrumentosScreen(initialSearchQuery: estadoUpper)),
                );
              }),
              _buildStatCard(
                title: 'PRÉSTAMOS ACTIVOS',
                value: _prestamosActivos.toString(),
                icon: Icons.assignment_return_outlined,
                color: const Color(0xff06b6d4),
                onTap: () => _abrirModalCard('PRÉSTAMOS ACTIVOS', const PrestamosScreen(initialSearchQuery: 'ACTIVO')),
              ),
              _buildStatCard(
                title: 'OPERARIOS REGISTRADOS',
                value: _totalOperarios.toString(),
                icon: Icons.engineering_outlined,
                color: const Color(0xFF276CF5),
                onTap: () => _abrirModalCard('OPERARIOS REGISTRADOS', const OperariosScreen()),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gráfico circular
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 340,
                  child: IosGlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      const Text(
                        'Distribución de Instrumentos',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xff0f172a)),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _totalInstrumentos == 0
                                  ? const Center(child: Text('Sin datos', style: TextStyle(color: Color(0xff64748b))))
                                  : PieChart(
                                      PieChartData(
                                        sectionsSpace: 4,
                                        centerSpaceRadius: 40,
                                        sections: _distribucionEstados.entries.map((entry) {
                                          final value = entry.value.toDouble();
                                          return PieChartSectionData(
                                            color: StatusColors.getColor(entry.key),
                                            value: value < 6 && _totalInstrumentos > 0 ? 6.0 : value,
                                            showTitle: false,
                                            radius: 40,
                                          );
                                        }).toList(),
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _distribucionEstados.entries.map((entry) {
                                return _buildLegendItem('${entry.key} (${entry.value})', StatusColors.getColor(entry.key));
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
              // Alertas / Próximos Vencimientos
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 340,
                  child: IosGlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Control y Vencimientos de Calibración ($_alertDaysThreshold días)',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xff0f172a)),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Opciones de Exportación',
                            color: const Color(0xffffffff),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xffe2e8f0))),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.08),
                                border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 18),
                                  SizedBox(width: 8),
                                  Text('Exportar Reporte', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_drop_down, color: Colors.redAccent, size: 18),
                                ],
                              ),
                            ),
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'vencidos',
                                child: Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18), SizedBox(width: 12), Text('Reporte Crítico (Vencidos)', style: TextStyle(color: Color(0xff0f172a)))]),
                              ),
                              const PopupMenuItem(
                                value: 'inventario',
                                child: Row(children: [Icon(Icons.inventory_2_outlined, color: Colors.cyan, size: 18), SizedBox(width: 12), Text('Inventario General', style: TextStyle(color: Color(0xff0f172a)))]),
                              ),
                              PopupMenuItem(
                                value: 'filtrado',
                                child: Row(children: [Icon(Icons.access_time_rounded, color: Colors.green, size: 18), SizedBox(width: 12), Text('Próximos a Vencer (${_proximosVencimientos.length})', style: TextStyle(color: Color(0xff0f172a)))]),
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'vencidos') {
                                _exportarPDF(context, 'Vencimientos', () => _apiService.exportarReporteVencidosPdf());
                              } else if (value == 'inventario') {
                                _exportarPDF(context, 'Inventario_General', () => _apiService.exportarInventarioPdf());
                              } else if (value == 'filtrado') {
                                _exportarPDF(context, 'Inventario_Proximos_Vencer', () => _apiService.exportarInventarioPdf(search: 'PRÓX. A VENCER'));
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _proximosVencimientos.isEmpty
                            ? Center(
                                child: Text('No hay vencimientos próximos en los siguientes $_alertDaysThreshold días.', style: const TextStyle(color: Color(0xff64748b), fontSize: 13)),
                              )
                            : ListView.builder(
                                itemCount: _proximosVencimientos.length,
                                itemBuilder: (context, index) {
                                  final item = _proximosVencimientos[index];
                                  final dias = item['dias'] as int;
                                  final isVencido = item['is_vencido'] == true;
                                  final color = isVencido ? Colors.redAccent : (dias <= 15 ? Colors.orange : const Color(0xff0284c7));
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xfff8fafc),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: color.withOpacity(0.25)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(isVencido ? Icons.dangerous : Icons.warning_amber_rounded, color: color, size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${item['codigo']} - ${item['nombre']}',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xff0f172a)),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                isVencido ? 'Venció el ${item['fecha']}' : 'Vence el ${item['fecha']}',
                                                style: const TextStyle(color: Color(0xff64748b), fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isVencido ? 'VENCIDO' : 'Vence en $dias d',
                                            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
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
            ),
          ],
        ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isFeatured = false,
    VoidCallback? onTap,
  }) {
    final double iconSize = isFeatured ? 38.0 : 32.0;
    final double containerPadding = isFeatured ? 16.0 : 12.0;
    final double titleFontSize = isFeatured ? 15.0 : 12.0;
    final double valueFontSize = isFeatured ? 36.0 : 28.0;

    // Use vibrant neon icon color for title & value
    final Color textColor = (color == Colors.grey || color == const Color(0xff9e9e9e))
        ? const Color(0xff475569)
        : color;

    // Soft pastel tint background color mixing state color with white glass
    final Color cardBackground = Color.alphaBlend(
      color.withOpacity(0.09),
      Colors.white,
    );

    // Fluor / Neon glowing border color matching status color
    final Color fluorBorder = color.withOpacity(0.55);

    return IosGlassCard(
      onTap: onTap,
      customColor: cardBackground,
      borderColor: fluorBorder,
      padding: EdgeInsets.symmetric(
        horizontal: isFeatured ? 24 : 16,
        vertical: isFeatured ? 20 : 14,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(containerPadding),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.25), width: 1.2),
            ),
            child: Icon(icon, color: textColor, size: iconSize),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: textColor,
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
