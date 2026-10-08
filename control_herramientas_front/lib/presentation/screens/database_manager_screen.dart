import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/services/api_service.dart';
import '../widgets/ios_glass_card.dart';

class DatabaseManagerScreen extends StatefulWidget {
  const DatabaseManagerScreen({super.key});

  @override
  State<DatabaseManagerScreen> createState() => _DatabaseManagerScreenState();
}

class _DatabaseManagerScreenState extends State<DatabaseManagerScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  List<dynamic> _tables = [];
  String? _selectedTable;
  bool _isLoadingTables = true;
  String? _errorMessage;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    // Ejecutar asíncronamente después del build inicial
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTables();
    });
  }

  Future<void> _fetchTables() async {
    if (!mounted) return;
    setState(() {
      _isLoadingTables = true;
      _errorMessage = null;
    });
    
    try {
      final response = await _apiService.client.get('database/tables/');
      if (response.statusCode == 200) {
        final data = response.data;
        if (mounted) {
          setState(() {
            _tables = data['tables'] ?? [];
            if (_tables.isNotEmpty && _selectedTable == null) {
              _selectedTable = _tables[0]['name'];
            }
          });
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          if (e.response != null && e.response?.data is Map) {
            _errorMessage = e.response?.data['error'] ?? e.response?.data['message'] ?? 'Error de servidor (${e.response?.statusCode})';
          } else {
            _errorMessage = e.message ?? 'Error de conexión con el servidor.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingTables = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Panel Izquierdo: Lista de Tablas
        Container(
          width: 280,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.storage, color: Color(0xff06b6d4)),
                    const SizedBox(width: 8),
                    const Text(
                      'Tablas DB',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      onPressed: _fetchTables,
                      tooltip: 'Recargar Tablas',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white10),
              Expanded(
                child: _isLoadingTables
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _tables.length,
                            itemBuilder: (context, index) {
                              final table = _tables[index];
                              final isSelected = _selectedTable == table['name'];
                              return ListTile(
                                selected: isSelected,
                                selectedTileColor: const Color(0xff4f46e5).withOpacity(0.15),
                                leading: Icon(
                                  Icons.table_chart,
                                  color: isSelected ? const Color(0xff06b6d4) : Colors.grey,
                                ),
                                title: Text(
                                  table['name'],
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.grey,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${table['rows']}',
                                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                                  ),
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedTable = table['name'];
                                  });
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
        
        // Panel Derecho: Tabs de Trabajo
        Expanded(
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xff06b6d4),
                labelColor: const Color(0xff06b6d4),
                unselectedLabelColor: Colors.grey,
                tabs: const [
                  Tab(icon: Icon(Icons.grid_on), text: 'Explorador de Datos'),
                  Tab(icon: Icon(Icons.code), text: 'Consola SQL'),
                  Tab(icon: Icon(Icons.schema), text: 'Estructura (Schema)'),
                  Tab(icon: Icon(Icons.build), text: 'Mantenimiento'),
                ],
              ),
              const Divider(height: 1, color: Colors.white10),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _DataExplorerTab(tableName: _selectedTable),
                    const _SqlConsoleTab(),
                    _SchemaTab(tableName: _selectedTable),
                    const _MaintenanceTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Pestaña 1: Explorador de Datos
// -----------------------------------------------------------------------------
class _DataExplorerTab extends StatefulWidget {
  final String? tableName;
  const _DataExplorerTab({this.tableName});

  @override
  State<_DataExplorerTab> createState() => _DataExplorerTabState();
}

class _DataExplorerTabState extends State<_DataExplorerTab> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  List<dynamic> _data = [];
  List<dynamic> _columns = [];
  int _totalRows = 0;
  int _page = 1;
  final int _limit = 50;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _errorMessage;

  @override
  void didUpdateWidget(covariant _DataExplorerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tableName != oldWidget.tableName) {
      _page = 1;
      _searchController.clear();
      _searchQuery = '';
      if (widget.tableName != null) {
        _fetchData();
      } else {
        setState(() {
          _data = [];
          _columns = [];
          _totalRows = 0;
          _errorMessage = null;
        });
      }
    }
  }

  Future<void> _fetchData() async {
    if (widget.tableName == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final response = await _apiService.client.get(
        'database/tables/${widget.tableName}/',
        queryParameters: {
          'page': _page,
          'limit': _limit,
          'search': _searchQuery,
        },
      );
      
      if (response.statusCode == 200) {
        final resData = response.data;
        if (mounted) {
          setState(() {
            _data = resData['data'] ?? [];
            _columns = resData['columns'] ?? [];
            _totalRows = resData['total'] ?? 0;
          });
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          if (e.response != null && e.response?.data is Map) {
            _errorMessage = e.response?.data['error'] ?? 'Error de servidor (${e.response?.statusCode})';
          } else {
            _errorMessage = e.message ?? 'Error de conexión con el servidor.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tableName == null) {
      return const Center(child: Text('Seleccione una tabla del panel izquierdo', style: TextStyle(color: Colors.grey)));
    }

    return Column(
      children: [
        // Toolbar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Buscar en tabla...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                  onSubmitted: (value) {
                    setState(() {
                      _searchQuery = value;
                      _page = 1;
                    });
                    _fetchData();
                  },
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _fetchData,
                tooltip: 'Actualizar',
              ),
            ],
          ),
        ),
        // Data Grid
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)))
                  : _data.isEmpty
                      ? const Center(child: Text('No hay datos en esta tabla', style: TextStyle(color: Colors.grey)))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
                              columns: _columns.map((c) => DataColumn(label: Text(c.toString(), style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                              rows: _data.map((row) {
                                return DataRow(
                                  cells: _columns.map((c) {
                                    return DataCell(Text(row[c]?.toString() ?? 'NULL'));
                                  }).toList(),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
        ),
        // Paginación
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Total: $_totalRows registros | Página $_page', style: const TextStyle(color: Colors.grey)),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: _page > 1 ? () {
                  setState(() => _page--);
                  _fetchData();
                } : null,
                child: const Icon(Icons.chevron_left),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: (_page * _limit) < _totalRows ? () {
                  setState(() => _page++);
                  _fetchData();
                } : null,
                child: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Pestaña 2: Consola SQL
// -----------------------------------------------------------------------------
class _SqlConsoleTab extends StatefulWidget {
  const _SqlConsoleTab();

  @override
  State<_SqlConsoleTab> createState() => _SqlConsoleTabState();
}

class _SqlConsoleTabState extends State<_SqlConsoleTab> {
  final ApiService _apiService = ApiService();
  final TextEditingController _sqlController = TextEditingController();
  bool _isExecuting = false;
  List<dynamic> _data = [];
  List<dynamic> _columns = [];
  String _message = '';
  bool _isError = false;

  Future<void> _executeSql() async {
    final sql = _sqlController.text.trim();
    if (sql.isEmpty) return;

    setState(() {
      _isExecuting = true;
      _message = '';
      _isError = false;
    });

    try {
      final response = await _apiService.client.post(
        'database/execute/',
        data: {'sql': sql},
      );
      
      final resData = response.data;
      
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            if (resData['columns'] != null) {
              _columns = resData['columns'];
              _data = resData['data'] ?? [];
              _message = '${_data.length} filas devueltas.';
            } else {
              _columns = [];
              _data = [];
              _message = resData['message'] ?? 'Consulta ejecutada con éxito.';
            }
          });
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
          if (e.response != null && e.response?.data is Map) {
            _message = e.response?.data['error'] ?? 'Error de servidor (${e.response?.statusCode})';
          } else {
            _message = e.message ?? 'Error de conexión con el servidor.';
          }
          _columns = [];
          _data = [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isError = true;
          _message = 'Error inesperado: $e';
          _columns = [];
          _data = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isExecuting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Editor SQL', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: _sqlController,
                maxLines: 5,
                style: const TextStyle(fontFamily: 'monospace', color: Colors.greenAccent),
                decoration: const InputDecoration(
                  hintText: 'SELECT * FROM metrologia_instrumento LIMIT 10;',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.black12,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: _isExecuting 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.play_arrow),
                label: const Text('Ejecutar Consulta'),
                onPressed: _isExecuting ? null : _executeSql,
              ),
              if (_message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _message,
                    style: TextStyle(color: _isError ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: Colors.white10),
        Expanded(
          child: _columns.isEmpty && _data.isEmpty
              ? const Center(child: Text('Resultados de la consulta', style: TextStyle(color: Colors.white24)))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
                      columns: _columns.map((c) => DataColumn(label: Text(c.toString(), style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                      rows: _data.map((row) {
                        return DataRow(
                          cells: _columns.map((c) {
                            return DataCell(Text(row[c]?.toString() ?? 'NULL'));
                          }).toList(),
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Pestaña 3: Estructura (Schema)
// -----------------------------------------------------------------------------
class _SchemaTab extends StatefulWidget {
  final String? tableName;
  const _SchemaTab({this.tableName});

  @override
  State<_SchemaTab> createState() => _SchemaTabState();
}

class _SchemaTabState extends State<_SchemaTab> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  List<dynamic> _schema = [];
  String? _errorMessage;

  @override
  void didUpdateWidget(covariant _SchemaTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tableName != oldWidget.tableName) {
      if (widget.tableName != null) {
        _fetchSchema();
      } else {
        setState(() {
          _schema = [];
          _errorMessage = null;
        });
      }
    }
  }

  Future<void> _fetchSchema() async {
    if (widget.tableName == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final response = await _apiService.client.get('database/tables/${widget.tableName}/schema/');
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _schema = response.data['schema'] ?? [];
          });
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          if (e.response != null && e.response?.data is Map) {
            _errorMessage = e.response?.data['error'] ?? 'Error de servidor (${e.response?.statusCode})';
          } else {
            _errorMessage = e.message ?? 'Error de conexión con el servidor.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tableName == null) {
      return const Center(child: Text('Seleccione una tabla del panel izquierdo', style: TextStyle(color: Colors.grey)));
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)));
    }

    return SingleChildScrollView(
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.05)),
        columns: const [
          DataColumn(label: Text('Nombre de Columna')),
          DataColumn(label: Text('Tipo de Dato')),
          DataColumn(label: Text('Nullable')),
          DataColumn(label: Text('Clave Primaria (PK)')),
          DataColumn(label: Text('Valor por Defecto')),
        ],
        rows: _schema.map((col) {
          return DataRow(cells: [
            DataCell(Text(col['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text(col['type'], style: const TextStyle(color: Color(0xff06b6d4)))),
            DataCell(Icon(col['notnull'] ? Icons.close : Icons.check, color: col['notnull'] ? Colors.redAccent : Colors.greenAccent, size: 18)),
            DataCell(Icon(col['pk'] ? Icons.vpn_key : Icons.remove, color: col['pk'] ? Colors.amber : Colors.grey, size: 18)),
            DataCell(Text(col['dflt_value']?.toString() ?? '-')),
          ]);
        }).toList(),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Pestaña 4: Mantenimiento
// -----------------------------------------------------------------------------
class _MaintenanceTab extends StatefulWidget {
  const _MaintenanceTab();

  @override
  State<_MaintenanceTab> createState() => _MaintenanceTabState();
}

class _MaintenanceTabState extends State<_MaintenanceTab> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _stats;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchStats();
    });
  }

  Future<void> _fetchStats() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _apiService.client.get('database/maintenance/', queryParameters: {'action': 'stats'});
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _stats = response.data;
          });
        }
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          if (e.response != null && e.response?.data is Map) {
            _errorMessage = e.response?.data['error'] ?? 'Error de servidor (${e.response?.statusCode})';
          } else {
            _errorMessage = e.message ?? 'Error de conexión con el servidor.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _runAction(String action, String title) async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.client.post(
        'database/maintenance/',
        data: {'action': action},
      );
      final resData = response.data;
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(resData['success'] == true ? '$title finalizado exitosamente. Resultado: ${resData['result'] ?? resData['message']}' : 'Error: ${resData['error']}'),
        backgroundColor: resData['success'] == true ? Colors.green : Colors.red,
      ));
      
      if (action == 'vacuum') {
        _fetchStats();
      }
    } on DioException catch (e) {
      if (!mounted) return;
      String errMsg = e.message ?? 'Error de conexión';
      if (e.response != null && e.response?.data is Map) {
        errMsg = e.response?.data['error'] ?? e.response?.data['message'] ?? errMsg;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $errMsg'), backgroundColor: Colors.red));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmAndClearSystemTables() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff1e2235),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
              SizedBox(width: 8),
              Text('¡ADVERTENCIA CRÍTICA!', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Estás a punto de VACIAR el catálogo de instrumentos.\n\n'
            'Solo se eliminarán los instrumentos y sus registros vinculados (como los préstamos e historial asociados a estos).\n'
            'El resto de los datos (personal, configuraciones, usuarios) permanecerán intactos.\n\n'
            '¿Estás seguro de querer proceder con esta acción?',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              child: const Text('Sí, VACIAR INSTRUMENTOS'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final response = await _apiService.client.post('database/clear-system-tables/');
      final resData = response.data;
      if (!mounted) return;
      
      if (resData['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Limpieza exitosa. Tablas vaciadas: ${resData['tables'].join(", ")}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ));
        _fetchStats();
      } else {
        throw Exception(resData['error'] ?? 'Error desconocido');
      }
    } on DioException catch (e) {
      if (!mounted) return;
      String errMsg = e.response?.data['error'] ?? e.message ?? 'Error de conexión';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $errMsg'), backgroundColor: Colors.red));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _downloadInstrumentTemplate() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.client.get(
        'database/instrument-template/',
        options: Options(responseType: ResponseType.bytes),
      );
      
      final appDir = Directory(Platform.resolvedExecutable).parent;
      final dir = Directory('${appDir.path}\\Plantillas');
      if (!await dir.exists()) await dir.create(recursive: true);
      
      final file = File('${dir.path}\\plantilla_instrumentos.xlsx');
      await file.writeAsBytes(response.data);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Plantilla descargada en: ${file.path}'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al descargar plantilla: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadAndImportInstruments() async {
    try {
      var result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.isNotEmpty && result.first.path != null) {
        setState(() => _isLoading = true);
        
        final filePath = result.first.path!;
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(filePath, filename: 'import.xlsx'),
        });

        final response = await _apiService.client.post(
          'database/import-instruments/',
          data: formData,
        );

        final resData = response.data;
        if (!mounted) return;

        if (resData['success'] == true) {
          int creados = resData['creados'] ?? 0;
          int actualizados = resData['actualizados'] ?? 0;
          List<dynamic> errores = resData['errores'] ?? [];

          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                backgroundColor: const Color(0xff1e2235),
                title: const Text('Resultados de Importación', style: TextStyle(color: Colors.white)),
                content: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Creados: $creados', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Actualizados: $actualizados', style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (errores.isNotEmpty) ...[
                        const Text('Errores de Fila:', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: errores.length,
                            itemBuilder: (context, i) => Text('• ${errores[i]}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  )
                ],
              );
            }
          );
        } else {
          throw Exception(resData['error'] ?? 'Error desconocido al importar');
        }
      }
    } on DioException catch (e) {
      if (!mounted) return;
      String errMsg = e.response?.data['error'] ?? e.message ?? 'Error de conexión';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $errMsg'), backgroundColor: Colors.red));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al importar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null && _stats == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchStats, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Estadísticas de Base de Datos', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_isLoading && _stats == null) 
              const CircularProgressIndicator()
            else if (_stats != null) ...[
              _StatCard(title: 'Ruta del Archivo', value: _stats!['path']),
              const SizedBox(height: 8),
              _StatCard(title: 'Tamaño (MB)', value: '${_stats!['size_mb']} MB'),
            ],
            const SizedBox(height: 32),
            const Text('Herramientas de Mantenimiento', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MaintenanceActionCard(
                    icon: Icons.security,
                    title: 'Verificación de Integridad',
                    description: 'Ejecuta PRAGMA integrity_check para buscar corrupción en la BD.',
                    onPressed: _isLoading ? null : () => _runAction('integrity_check', 'Verificación de Integridad'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _MaintenanceActionCard(
                    icon: Icons.cleaning_services,
                    title: 'Optimizar DB (VACUUM)',
                    description: 'Reconstruye el archivo de la base de datos para liberar espacio muerto.',
                    onPressed: _isLoading ? null : () => _runAction('vacuum', 'Optimización VACUUM'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _MaintenanceActionCard(
                    icon: Icons.delete_forever,
                    title: 'Vaciar Tabla de Instrumentos',
                    description: 'Limpia solo los instrumentos y sus dependencias. Mantiene intactos personal y configuración.',
                    isDanger: true,
                    onPressed: _isLoading ? null : _confirmAndClearSystemTables,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Herramientas de Importación', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.upload_file, size: 32, color: Color(0xff10b981)),
                        const SizedBox(height: 16),
                        const Text('Importar Instrumentos (Excel)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Importa instrumentos masivamente mediante un archivo .xlsx validado.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : _downloadInstrumentTemplate,
                              icon: const Icon(Icons.download),
                              label: const Text('Descargar Plantilla'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: _isLoading ? null : _uploadAndImportInstruments,
                              icon: const Icon(Icons.upload),
                              label: const Text('Seleccionar y Subir'),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff10b981), foregroundColor: Colors.white),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return IosGlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

class _MaintenanceActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isDanger;
  final VoidCallback? onPressed;

  const _MaintenanceActionCard({
    required this.icon,
    required this.title,
    required this.description,
    this.isDanger = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger ? Colors.redAccent : const Color(0xff06b6d4);
    return IosGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onPressed,
            style: isDanger ? ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.8), foregroundColor: Colors.white) : null,
            child: const Text('Ejecutar Acción'),
          ),
        ],
      ),
    );
  }
}
