import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/services/api_service.dart';
import 'instrumentos_screen.dart';
import '../../features/personal/presentation/operarios_screen.dart';
import '../../features/prestamos/presentation/prestamos_screen.dart';
import '../../../core/utils/status_colors.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  
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
        _isLoading = false;
      });
    }
  }

  void _abrirModalCard(String title, Widget screen) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xff121420),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.85,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                backgroundColor: const Color(0xff1a1d29),
                title: Text(title),
                elevation: 0,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              body: screen,
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
              backgroundColor: const Color(0xff1e2235),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Copias de Seguridad (Backups)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                        ? const Center(child: Text('No hay copias de seguridad creadas aún.', style: TextStyle(color: Colors.white54)))
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
                                  color: const Color(0xff1a1d29),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.archive_outlined, color: Color(0xFF276CF5), size: 28),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                          const SizedBox(height: 4),
                                          Text('Fecha: $fecha  |  Tamaño: ${_formatearTamano(tamano)}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                                      tooltip: 'Eliminar esta copia',
                                      onPressed: () async {
                                        // Cache ScaffoldMessenger using the outer dashboard context
                                        final messenger = ScaffoldMessenger.of(context);
                                        
                                        bool? confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (c) => AlertDialog(
                                            backgroundColor: const Color(0xff1a1d29),
                                            title: const Text('¿Eliminar copia?', style: TextStyle(color: Colors.white)),
                                            content: const Text('¿Seguro que deseas eliminar permanentemente este archivo de copia de seguridad?', style: TextStyle(color: Colors.white70)),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
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
                  child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
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
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
              Text(
                'Visión General',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
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
                    icon: const Icon(Icons.refresh, color: Colors.white70),
                    onPressed: _cargarDatosDashboard,
                    tooltip: 'Actualizar',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.0,
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
                'APTO', 'VENCIDO', 'EN USO', 'REPARACION', 
                'DE REFERENCIA', 'NO APTO', 'NO EXISTE', 'BAJA'
              ].map((estadoUpper) {
                final int count = _distribucionEstados[estadoUpper] ?? 0;
                IconData icon;
                switch (estadoUpper) {
                  case 'APTO': icon = Icons.check_circle_outline; break;
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
              _buildStatCard(
                title: 'PRÓX. A VENCER',
                value: _proximosVencimientos.length.toString(),
                icon: Icons.notification_important_outlined,
                color: Colors.orangeAccent,
                onTap: () {},
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
                child: Container(
                  height: 340,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xff1e2230),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Distribución de Instrumentos',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: _totalInstrumentos == 0
                                  ? const Center(child: Text('Sin datos', style: TextStyle(color: Colors.white54)))
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
              const SizedBox(width: 24),
              // Alertas / Próximos Vencimientos
              Expanded(
                flex: 5,
                child: Container(
                  height: 340,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xff1e2230),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Control y Vencimientos de Calibración ($_alertDaysThreshold días)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _proximosVencimientos.isEmpty
                            ? Center(
                                child: Text('No hay vencimientos próximos en los siguientes $_alertDaysThreshold días.', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                              )
                            : ListView.builder(
                                itemCount: _proximosVencimientos.length > 4 ? 4 : _proximosVencimientos.length,
                                itemBuilder: (context, index) {
                                  final item = _proximosVencimientos[index];
                                  final dias = item['dias'] as int;
                                  final isVencido = item['is_vencido'] == true;
                                  final color = isVencido ? Colors.redAccent : (dias <= 15 ? Colors.amberAccent : Colors.cyanAccent);
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xff1a1d29),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: color.withOpacity(0.15)),
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
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                isVencido ? 'Venció el ${item['fecha']}' : 'Vence el ${item['fecha']}',
                                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.1),
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
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xff1a1d29),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          borderRadius: BorderRadius.circular(16),
          hoverColor: color.withOpacity(0.1),
          splashColor: color.withOpacity(0.2),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        value,
                        style: GoogleFonts.orbitron(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
