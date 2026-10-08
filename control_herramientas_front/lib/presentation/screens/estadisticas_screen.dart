import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/api_service.dart';
import '../widgets/ios_glass_card.dart';

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _statsData;
  String? _selectedCategoria;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final data = await _apiService.getDashboardStats(categoria: _selectedCategoria);
    if (mounted) {
      setState(() {
        _statsData = data;
        _isLoading = false;
      });
    }
  }

  void _onCategorySelected(String? categoria) {
    if (_selectedCategoria == categoria) return;
    setState(() {
      _selectedCategoria = categoria;
    });
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _statsData == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xff4f46e5)));
    }

    if (_statsData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
            const SizedBox(height: 16),
            const Text('Error al cargar las estadísticas', style: TextStyle(color: Color(0xff64748b), fontSize: 18)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            )
          ],
        ),
      );
    }

    final distribucionEstados = _statsData!['distribucion_estados'] as Map<String, dynamic>? ?? {};
    final distribucionCategorias = _statsData!['distribucion_categorias'] as Map<String, dynamic>? ?? {};
    final globalCategorias = _statsData!['global_categorias'] as Map<String, dynamic>? ?? distribucionCategorias;
    final proximosVencimientos = _statsData!['proximos_vencimientos'] as List<dynamic>? ?? [];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // PANEL LATERAL IZQUIERDO (Categorías)
        Container(
          width: 250,
          margin: const EdgeInsets.only(right: 24),
          child: IosGlassCard(
            padding: EdgeInsets.zero,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Filtro por Categoría',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xff64748b)),
                ),
              ),
              _buildCategoryItem(null, 'Vista Global / Todos', Icons.dashboard_rounded, null),
              const Divider(color: Color(0xffe2e8f0), height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: globalCategorias.keys.length,
                  itemBuilder: (context, index) {
                    final cat = globalCategorias.keys.elementAt(index);
                    final val = globalCategorias[cat];
                    return _buildCategoryItem(cat, cat, Icons.build_circle_outlined, val);
                  },
                ),
              ),
            ],
          ),
          ),
        ),
        
        // CONTENIDO PRINCIPAL (Dashboard)
        Expanded(
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _selectedCategoria != null ? 'Métricas: $_selectedCategoria' : 'Métricas Globales',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xff0f172a),
                          ),
                        ),
                        IconButton(
                          onPressed: _loadStats,
                          icon: const Icon(Icons.refresh, color: Color(0xff64748b)),
                          tooltip: 'Actualizar',
                        )
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildChartCard(
                            title: 'Distribución por Estado',
                            icon: Icons.donut_large_rounded,
                            child: _buildPieChartWithLegend(distribucionEstados),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildChartCard(
                            title: 'Instrumentos por Tipo/Categoría',
                            icon: Icons.bar_chart_rounded,
                            child: _buildBarChart(distribucionCategorias),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildChartCard(
                            title: 'Próximos Vencimientos (Alertas)',
                            icon: Icons.timeline_rounded,
                            child: _buildVencimientosChart(proximosVencimientos),
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildChartCard(
                            title: 'Tasa de Aprobación de Calibraciones',
                            icon: Icons.rule_rounded,
                            child: _buildTasaAprobacionChart(distribucionEstados),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              if (_isLoading)
                Positioned.fill(
                  child: Container(
                    color: Colors.white.withOpacity(0.3),
                    child: const Center(child: CircularProgressIndicator(color: Color(0xff4f46e5))),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryItem(String? categoryId, String title, IconData icon, dynamic count) {
    final isSelected = _selectedCategoria == categoryId;
    return InkWell(
      onTap: () => _onCategorySelected(categoryId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xff4f46e5).withOpacity(0.1) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? const Color(0xff4f46e5) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xff4f46e5) : const Color(0xff64748b),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? const Color(0xff4f46e5) : const Color(0xff334155),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (count != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xff4f46e5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(color: Color(0xff4f46e5), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({required String title, required IconData icon, required Widget child}) {
    return SizedBox(
      height: 400,
      child: IosGlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xff0284c7), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xff0f172a)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(child: child),
        ],
      ),
      ),
    );
  }

  Widget _buildPieChartWithLegend(Map<String, dynamic> data) {
    if (data.isEmpty) return const Center(child: Text('Sin datos', style: TextStyle(color: Color(0xff64748b))));

    final colors = [
      const Color(0xff4f46e5),
      const Color(0xff0284c7),
      const Color(0xff10b981),
      const Color(0xfff59e0b),
      const Color(0xffef4444),
      const Color(0xff8b5cf6),
      const Color(0xffec4899),
      const Color(0xfff97316),
    ];

    List<PieChartSectionData> sections = [];
    List<Widget> legendItems = [];
    
    int i = 0;
    data.forEach((key, value) {
      final double val = (value is int) ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
      if (val > 0) {
        final color = colors[i % colors.length];
        
        sections.add(
          PieChartSectionData(
            color: color,
            value: val,
            title: '',
            showTitle: false,
            radius: 80,
          )
        );

        legendItems.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              children: [
                Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$key (${val.toInt()})',
                    style: const TextStyle(color: Color(0xff334155), fontSize: 13, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
        i++;
      }
    });

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 50,
              sections: sections,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: legendItems,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart(Map<String, dynamic> data) {
    if (data.isEmpty) return const Center(child: Text('Sin datos', style: TextStyle(color: Color(0xff64748b))));

    var sortedEntries = data.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));
    
    if (sortedEntries.length > 8) {
      sortedEntries = sortedEntries.sublist(0, 8);
    }

    double maxY = 0;
    for (var entry in sortedEntries) {
      if ((entry.value as int) > maxY) maxY = (entry.value as int).toDouble();
    }
    maxY = (maxY + (maxY * 0.2)).ceilToDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipPadding: const EdgeInsets.all(8),
            getTooltipColor: (group) => const Color(0xff0f172a),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                '${sortedEntries[group.x.toInt()].key}\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                children: <TextSpan>[
                  TextSpan(
                    text: (rod.toY).toInt().toString(),
                    style: const TextStyle(color: Color(0xff38bdf8), fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value.toInt() >= sortedEntries.length) return const SizedBox.shrink();
                final String text = sortedEntries[value.toInt()].key;
                final String shortText = text.length > 8 ? '${text.substring(0, 7)}.' : text;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    shortText,
                    style: const TextStyle(color: Color(0xff64748b), fontSize: 10),
                    textAlign: TextAlign.center,
                  ),
                );
              },
              reservedSize: 40,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value % 1 != 0) return const SizedBox.shrink();
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(color: Color(0xff64748b), fontSize: 11),
                );
              },
              reservedSize: 28,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 10 ? (maxY / 5).ceilToDouble() : 1,
          getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xffe2e8f0), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          sortedEntries.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: (sortedEntries[i].value as int).toDouble(),
                gradient: const LinearGradient(
                  colors: [Color(0xff4f46e5), Color(0xff0284c7)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 20,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVencimientosChart(List<dynamic> vencimientos) {
    if (vencimientos.isEmpty) {
      return const Center(child: Text('No hay vencimientos próximos', style: TextStyle(color: Color(0xff64748b))));
    }

    Map<int, int> grouped = {
      10: 0, 20: 0, 30: 0, 60: 0,
    };
    
    for (var v in vencimientos) {
      int dias = v['dias'] ?? 0;
      if (dias <= 10) grouped[10] = grouped[10]! + 1;
      else if (dias <= 20) grouped[20] = grouped[20]! + 1;
      else if (dias <= 30) grouped[30] = grouped[30]! + 1;
      else grouped[60] = grouped[60]! + 1;
    }

    final spots = [
      FlSpot(1, grouped[10]!.toDouble()),
      FlSpot(2, grouped[20]!.toDouble()),
      FlSpot(3, grouped[30]!.toDouble()),
      FlSpot(4, grouped[60]!.toDouble()),
    ];

    double maxY = 0;
    for (var spot in spots) {
      if (spot.y > maxY) maxY = spot.y;
    }
    maxY = (maxY + 2).ceilToDouble();

    return LineChart(
      LineChartData(
        minX: 1, maxX: 4,
        minY: 0, maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 5 ? (maxY / 5).ceilToDouble() : 1,
          getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xffe2e8f0), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                switch(value.toInt()) {
                  case 1: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('< 10d', style: TextStyle(color: Color(0xff64748b), fontSize: 11)));
                  case 2: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('10-20d', style: TextStyle(color: Color(0xff64748b), fontSize: 11)));
                  case 3: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('20-30d', style: TextStyle(color: Color(0xff64748b), fontSize: 11)));
                  case 4: return const Padding(padding: EdgeInsets.only(top: 8), child: Text('> 30d', style: TextStyle(color: Color(0xff64748b), fontSize: 11)));
                  default: return const SizedBox.shrink();
                }
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                if (value % 1 != 0) return const SizedBox.shrink();
                return Text(value.toInt().toString(), style: const TextStyle(color: Color(0xff64748b), fontSize: 11));
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xfff59e0b),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xfff59e0b).withOpacity(0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasaAprobacionChart(Map<String, dynamic> data) {
    if (data.isEmpty) return const Center(child: Text('Sin datos', style: TextStyle(color: Color(0xff64748b))));

    double total = 0;
    double aprobados = 0;
    double noAprobados = 0;

    data.forEach((key, value) {
      double val = (value is int) ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
      total += val;
      if (key == 'APTO' || key == 'EN USO') {
        aprobados += val;
      } else {
        noAprobados += val;
      }
    });

    if (total == 0) return const Center(child: Text('Sin datos válidos', style: TextStyle(color: Color(0xff64748b))));

    double pctAprobados = (aprobados / total) * 100;
    double pctNoAprobados = (noAprobados / total) * 100;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Aprobados', pctAprobados, const Color(0xff10b981), aprobados.toInt()),
            _buildStatItem('No Aprobados', pctNoAprobados, const Color(0xffef4444), noAprobados.toInt()),
          ],
        ),
        const SizedBox(height: 40),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 24,
            width: double.infinity,
            decoration: const BoxDecoration(color: Color(0xffe2e8f0)),
            child: Row(
              children: [
                if (pctAprobados > 0)
                  Expanded(
                    flex: pctAprobados.toInt(),
                    child: Container(color: const Color(0xff10b981)),
                  ),
                if (pctNoAprobados > 0)
                  Expanded(
                    flex: pctNoAprobados.toInt(),
                    child: Container(color: const Color(0xffef4444)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'El progreso indica la proporción de instrumentos en estado APTO frente al total registrado.',
          style: TextStyle(color: Color(0xff64748b), fontSize: 12),
          textAlign: TextAlign.center,
        )
      ],
    );
  }

  Widget _buildStatItem(String label, double pct, Color color, int count) {
    return Column(
      children: [
        Text(
          '${pct.toStringAsFixed(1)}%',
          style: TextStyle(color: color, fontSize: 32, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xff0f172a), fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(
          '($count instrumentos)',
          style: const TextStyle(color: Color(0xff64748b), fontSize: 12),
        ),
      ],
    );
  }
}
