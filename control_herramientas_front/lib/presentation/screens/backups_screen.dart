import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/api_service.dart';
import '../widgets/ios_glass_card.dart';

class BackupsScreen extends StatefulWidget {
  const BackupsScreen({super.key});

  @override
  State<BackupsScreen> createState() => _BackupsScreenState();
}

class _BackupsScreenState extends State<BackupsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isActionRunning = false;
  List<dynamic> _backups = [];

  @override
  void initState() {
    super.initState();
    _cargarBackups();
  }

  Future<void> _cargarBackups() async {
    setState(() => _isLoading = true);
    final backups = await _apiService.getBackups();
    if (mounted) {
      setState(() {
        _backups = backups;
        _isLoading = false;
      });
    }
  }

  Future<void> _crearBackup() async {
    setState(() => _isActionRunning = true);
    final success = await _apiService.crearBackup();
    if (mounted) {
      setState(() => _isActionRunning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Backup creado correctamente.' : 'Error al crear backup.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) _cargarBackups();
    }
  }

  void _confirmarRestauracion(String filename) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xffe2e8f0))),
          title: const Text('Restaurar Copia de Seguridad', style: TextStyle(color: Color(0xff0f172a), fontWeight: FontWeight.bold)),
          content: Text(
            'ATENCIÓN: Se reemplazará la base de datos actual con la versión del archivo "$filename". '
            'Todos los cambios realizados después de esta copia se perderán. ¿Deseas continuar?',
            style: const TextStyle(color: Color(0xff475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Color(0xff64748b))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isActionRunning = true);
                final success = await _apiService.restaurarBackup(filename);
                if (mounted) {
                  setState(() => _isActionRunning = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Backup restaurado correctamente.' : 'Error al restaurar backup.'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                  if (success) _cargarBackups();
                }
              },
              child: const Text('Restaurar Datos', style: TextStyle(color: Colors.white)),
            )
          ],
        );
      },
    );
  }

  void _confirmarEliminacion(String filename) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xffe2e8f0))),
          title: const Text('Eliminar Backup', style: TextStyle(color: Color(0xff0f172a), fontWeight: FontWeight.bold)),
          content: Text('¿Seguro que deseas eliminar permanentemente el archivo "$filename"?', style: const TextStyle(color: Color(0xff475569))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Color(0xff64748b))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isActionRunning = true);
                final success = await _apiService.eliminarBackup(filename);
                if (mounted) {
                  setState(() => _isActionRunning = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Backup eliminado.' : 'Error al eliminar backup.'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                  if (success) _cargarBackups();
                }
              },
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
      return const Center(child: CircularProgressIndicator(color: Color(0xff6366f1)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Copias de Seguridad (SQLite)',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xff0f172a),
                    ),
                    softWrap: true,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Gestión de respaldos lógicos de la base de datos.',
                    style: TextStyle(color: Color(0xff64748b), fontSize: 14),
                    softWrap: true,
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _isActionRunning ? null : _crearBackup,
              icon: _isActionRunning
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.backup_rounded),
              label: const Text('Crear Nuevo Backup'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff6366f1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: IosGlassCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _backups.isEmpty
                  ? const Center(
                      child: Text('No hay backups creados todavía.', style: TextStyle(color: Color(0xff64748b))),
                    )
                  : ListView(
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(const Color(0xfff1f5f9)),
                            dataRowHeight: 56,
                            columns: const [
                              DataColumn(label: Text('Archivo', style: TextStyle(color: Color(0xff0f172a), fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Tamaño', style: TextStyle(color: Color(0xff0f172a), fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Fecha de Creación', style: TextStyle(color: Color(0xff0f172a), fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Acciones', style: TextStyle(color: Color(0xff0f172a), fontWeight: FontWeight.bold))),
                            ],
                            rows: _backups.map((b) {
                              final nombre = b['nombre']?.toString() ?? 'Sin nombre';
                              final fecha = b['fecha_creacion']?.toString() ?? '-';
                              final tamanoBytes = b['tamano'] ?? 0;
                              final tamanoStr = '${(tamanoBytes / 1024 / 1024).toStringAsFixed(2)} MB';
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.storage_rounded, color: Color(0xFFFC7D17), size: 20),
                                        const SizedBox(width: 12),
                                        Flexible(child: Text(nombre, style: const TextStyle(color: Color(0xff0f172a), fontWeight: FontWeight.w600))),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(tamanoStr, style: const TextStyle(color: Color(0xff64748b)))),
                                  DataCell(Text(fecha, style: const TextStyle(color: Color(0xff64748b)))),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: _isActionRunning ? null : () => _confirmarRestauracion(nombre),
                                          icon: const Icon(Icons.restore_rounded, size: 16),
                                          label: const Text('Restaurar', style: TextStyle(fontSize: 12)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xff6366f1),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                          tooltip: 'Eliminar Backup',
                                          onPressed: _isActionRunning ? null : () => _confirmarEliminacion(nombre),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
