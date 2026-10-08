import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/api_service.dart';
import '../widgets/ios_glass_card.dart';

class TrazabilidadScreen extends StatefulWidget {
  const TrazabilidadScreen({super.key});

  @override
  State<TrazabilidadScreen> createState() => _TrazabilidadScreenState();
}

class _TrazabilidadScreenState extends State<TrazabilidadScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _logs = [];
  Map<String, dynamic> _stats = {'hoy': 0, 'semana': 0, 'total_filtrados': 0};
  
  String _searchQuery = '';
  String _actionType = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _apiService.getGlobalAuditLogs(search: _searchQuery, action: _actionType);
    if (mounted) {
      setState(() {
        if (data != null) {
          _logs = data['logs'] ?? [];
          _stats = data['stats'] ?? {'hoy': 0, 'semana': 0, 'total_filtrados': 0};
        } else {
          _logs = [];
        }
        _isLoading = false;
      });
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
              'Trazabilidad y Auditoría',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            IconButton(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, color: Colors.white70),
              tooltip: 'Actualizar',
            )
          ],
        ),
        const SizedBox(height: 24),
        
        // CONTADORES
        Row(
          children: [
            Expanded(
              child: _buildStatCard('Movimientos Hoy', _stats['hoy'].toString(), Icons.today_rounded, const Color(0xff10b981)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard('Movimientos en 7 días', _stats['semana'].toString(), Icons.date_range_rounded, const Color(0xff06b6d4)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard('Total Filtrados', _stats['total_filtrados'].toString(), Icons.filter_list_rounded, const Color(0xff8b5cf6)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // FILTROS
        IosGlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Buscar por código, nombre o sección...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xff2a2f4a),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) {
                    _searchQuery = val;
                  },
                  onSubmitted: (_) => _loadData(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  value: _actionType.isEmpty ? null : _actionType,
                  dropdownColor: const Color(0xff2a2f4a),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Todas las acciones',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xff2a2f4a),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todas las acciones')),
                    const DropdownMenuItem(value: 'CREACIÓN', child: Text('Creación')),
                    const DropdownMenuItem(value: 'MODIFICACIÓN', child: Text('Modificación')),
                    const DropdownMenuItem(value: 'PRÉSTAMO', child: Text('Préstamo')),
                    const DropdownMenuItem(value: 'DEVOLUCIÓN', child: Text('Devolución')),
                    const DropdownMenuItem(value: 'RECERTIFICACIÓN', child: Text('Recertificación')),
                  ],
                  onChanged: (val) {
                    _actionType = val ?? '';
                    _loadData();
                  },
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.filter_alt_outlined, size: 18),
                label: const Text('Filtrar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff4f46e5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // TABLA / TIMELINE
        Expanded(
          child: IosGlassCard(
            padding: EdgeInsets.zero,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xff4f46e5)))
                : _logs.isEmpty
                    ? const Center(child: Text('No hay registros de movimientos.', style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return _buildLogItem(_logs[index]);
                        },
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return IosGlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    final actionType = log['action_type'].toString().toUpperCase();
    
    Color iconColor = Colors.white54;
    IconData iconData = Icons.info_outline;
    if (actionType.contains('CREACIÓN')) {
      iconColor = const Color(0xff10b981);
      iconData = Icons.add_circle_outline;
    } else if (actionType.contains('PRÉSTAMO')) {
      iconColor = const Color(0xfff59e0b);
      iconData = Icons.outbox_rounded;
    } else if (actionType.contains('DEVOLUCIÓN')) {
      iconColor = const Color(0xff3b82f6);
      iconData = Icons.move_to_inbox_rounded;
    } else if (actionType.contains('RECERTIFICACIÓN') || actionType.contains('CALIBRACIÓN')) {
      iconColor = const Color(0xff06b6d4);
      iconData = Icons.verified_rounded;
    } else if (actionType.contains('MODIFICACIÓN')) {
      iconColor = const Color(0xff8b5cf6);
      iconData = Icons.edit_note_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff2a2f4a).withOpacity(0.3),
        border: Border(left: BorderSide(color: iconColor, width: 4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(actionType, style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            '${log['codigo_instrumento']} - ${log['nombre_instrumento']}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    Text(log['timestamp'], style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  log['details']?.toString().isNotEmpty == true ? log['details'] : 'Sin detalles adicionales',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text('Operador: ${log['performed_by']}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    if (log['section_assigned']?.toString().isNotEmpty == true) ...[
                      const SizedBox(width: 16),
                      const Icon(Icons.business_center_outlined, size: 14, color: Colors.white38),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Asignado a: ${log['section_assigned']}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
