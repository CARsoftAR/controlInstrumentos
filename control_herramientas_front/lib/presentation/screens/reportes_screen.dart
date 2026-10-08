import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../../core/services/api_service.dart';
import '../widgets/ios_glass_card.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  final ApiService _apiService = ApiService();
  bool _isDownloading = false;

  Future<void> _exportarPDF(BuildContext context, String filenamePrefix, Future<List<int>?> Function() apiCall) async {
    setState(() => _isDownloading = true);
    try {
      final bytes = await apiCall();
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo generar el documento PDF.'), backgroundColor: Colors.red)
          );
        }
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF generado y abierto automáticamente: ${file.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar PDF: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Centro de Reportes y Exportaciones',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xff0f172a),
              ),
            ),
            if (_isDownloading)
              const CircularProgressIndicator(color: Color(0xff6366f1))
          ],
        ),
        const SizedBox(height: 32),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          childAspectRatio: 1.5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildReportCard(
              title: 'Inventario General',
              description: 'Listado completo de todos los instrumentos registrados en el pañol.',
              icon: Icons.inventory_2_outlined,
              color: const Color(0xff0284c7),
              onTap: () => _exportarPDF(context, 'Inventario_General', () => _apiService.exportarInventarioPdf()),
            ),
            _buildReportCard(
              title: 'Instrumentos Vencidos',
              description: 'Reporte crítico de instrumentos con calibración ya caducada.',
              icon: Icons.warning_amber_rounded,
              color: Colors.redAccent,
              onTap: () => _exportarPDF(context, 'Vencimientos', () => _apiService.exportarReporteVencidosPdf()),
            ),
            _buildReportCard(
              title: 'Próximos a Vencer',
              description: 'Reporte preventivo de instrumentos que caducarán en los próximos 45 días.',
              icon: Icons.access_time_rounded,
              color: Colors.orange,
              onTap: () => _exportarPDF(context, 'Inventario_Proximos_Vencer', () => _apiService.exportarInventarioPdf(search: 'PRÓX. A VENCER')),
            ),
            _buildReportCard(
              title: 'Catálogo a Excel',
              description: 'Exportar la base de datos completa de instrumentos a formato XLSX.',
              icon: Icons.table_view_rounded,
              color: const Color(0xff10b981),
              onTap: () async {
                setState(() => _isDownloading = true);
                try {
                  final bytes = await _apiService.exportarInstrumentosXLSX('');
                  if (bytes != null) {
                    final appDir = Directory(Platform.resolvedExecutable).parent;
                    final dir = Directory('${appDir.path}\\Reportes');
                    if (!await dir.exists()) await dir.create(recursive: true);
                    final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
                    final file = File('${dir.path}\\Inventario_$timestamp.xlsx');
                    await file.writeAsBytes(bytes);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Excel guardado en: ${file.path}'),
                          backgroundColor: Colors.green,
                          action: SnackBarAction(label: 'ABRIR', textColor: Colors.white, onPressed: () => OpenFile.open(file.path)),
                        )
                      );
                    }
                  }
                } finally {
                  if (mounted) setState(() => _isDownloading = false);
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return IosGlassCard(
      padding: const EdgeInsets.all(24),
      onTap: _isDownloading ? null : onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 36),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xff0f172a),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xff64748b),
              fontSize: 13,
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'GENERAR REPORTE',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: color, size: 16),
            ],
          ),
        ],
      ),
    );
  }
}
