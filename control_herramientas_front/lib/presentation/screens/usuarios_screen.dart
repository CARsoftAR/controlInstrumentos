import 'package:flutter/material.dart';
import '../../core/services/api_service.dart';
import '../widgets/ios_glass_card.dart';

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _usuarios = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    setState(() => _isLoading = true);
    final users = await _apiService.getUsuarios();
    setState(() {
      _usuarios = users;
      _isLoading = false;
    });
  }

  void _mostrarModalNuevoUsuario() {
    String username = '';
    String password = '';
    bool isStaff = false;
    bool saving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: IosGlassCard(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Nuevo Usuario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                      const SizedBox(height: 24),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Nombre de Usuario',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) => username = val,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) => password = val,
                    ),
                    const SizedBox(height: 24),
                    SwitchListTile(
                      title: const Text('Rol Administrador', style: TextStyle(color: Colors.white70)),
                      subtitle: const Text('Permite gestionar backups y usuarios', style: TextStyle(color: Colors.white30, fontSize: 11)),
                      value: isStaff,
                      activeColor: const Color(0xff06b6d4),
                      onChanged: (val) => setModalState(() => isStaff = val),
                    ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(foregroundColor: Colors.white54),
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            onPressed: saving ? null : () async {
                              if (username.isEmpty || password.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Usuario y contraseña son obligatorios'), backgroundColor: Colors.red)
                                );
                                return;
                              }
                              setModalState(() => saving = true);
                              final res = await _apiService.crearUsuario(username, password, isStaff);
                              setModalState(() => saving = false);
                              if (res['success'] == true) {
                                Navigator.pop(context);
                                _cargarUsuarios();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Usuario creado correctamente'), backgroundColor: Colors.green)
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: ${res['message']}'), backgroundColor: Colors.red)
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff10b981),
                              foregroundColor: Colors.white,
                            ),
                            child: saving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Guardar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarModalEditarUsuario(dynamic user) {
    final int id = user['id'] ?? 0;
    String username = user['username'] ?? '';
    String password = '';
    bool isStaff = user['is_staff'] ?? false;
    bool saving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: IosGlassCard(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Editar Usuario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                      const SizedBox(height: 24),
                    TextFormField(
                      initialValue: username,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de Usuario',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) => username = val,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Nueva Contraseña (dejar vacío para mantener actual)',
                        labelStyle: TextStyle(color: Colors.white70),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      ),
                      style: const TextStyle(color: Colors.white),
                      onChanged: (val) => password = val,
                    ),
                    const SizedBox(height: 24),
                    SwitchListTile(
                      title: const Text('Rol Administrador', style: TextStyle(color: Colors.white70)),
                      subtitle: const Text('Permite gestionar backups y usuarios', style: TextStyle(color: Colors.white30, fontSize: 11)),
                      value: isStaff,
                      activeColor: const Color(0xff06b6d4),
                      onChanged: (val) => setModalState(() => isStaff = val),
                    ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(foregroundColor: Colors.white54),
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            onPressed: saving ? null : () async {
                              if (username.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('El nombre de usuario no puede estar vacío'), backgroundColor: Colors.red)
                                );
                                return;
                              }
                              setModalState(() => saving = true);
                              final res = await _apiService.editarUsuario(id, username, password, isStaff);
                              setModalState(() => saving = false);
                              if (res['success'] == true) {
                                Navigator.pop(context);
                                _cargarUsuarios();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Usuario actualizado correctamente'), backgroundColor: Colors.green)
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: ${res['message']}'), backgroundColor: Colors.red)
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff10b981),
                              foregroundColor: Colors.white,
                            ),
                            child: saving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Guardar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _eliminarUsuario(int id, String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xff1a1d29),
          title: const Text('¿Eliminar usuario?', style: TextStyle(color: Colors.white)),
          content: Text('¿Seguro que deseas eliminar permanentemente al usuario "$name"?', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                final res = await _apiService.eliminarUsuario(id);
                if (mounted) {
                  Navigator.pop(context);
                  if (res['success'] == true) {
                    _cargarUsuarios();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Usuario eliminado correctamente'), backgroundColor: Colors.green)
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al eliminar usuario: ${res['message']}'), backgroundColor: Colors.red)
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
      return const Center(child: CircularProgressIndicator(color: Color(0xff4f46e5)));
    }

    final filteredUsers = _usuarios.where((u) {
      final name = (u['username'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Buscar usuario...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                        filled: true,
                        fillColor: const Color(0xff1e2235),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                        ),
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff10b981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: _mostrarModalNuevoUsuario,
                    icon: const Icon(Icons.person_add),
                    label: const Text('Nuevo Usuario'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff4f46e5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: _cargarUsuarios,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: IosGlassCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView(
                  children: [
                    DataTable(
                      headingRowColor: MaterialStateProperty.all(const Color(0xff1e2235)),
                      dataRowHeight: 52,
                      columns: const [
                        DataColumn(label: Text('ID', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Nombre de Usuario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Rol / Permisos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Acciones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      ],
                      rows: filteredUsers.map((u) {
                        final id = u['id'] ?? 0;
                        final name = u['username'] ?? '';
                        final isStaff = u['is_staff'] ?? false;

                        return DataRow(
                          cells: [
                            DataCell(Text(id.toString(), style: const TextStyle(color: Colors.white70))),
                            DataCell(Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isStaff ? const Color(0xff06b6d4).withOpacity(0.15) : const Color(0xff4f46e5).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isStaff ? 'Administrador' : 'Operador / Usuario',
                                  style: TextStyle(
                                    color: isStaff ? const Color(0xff06b6d4) : const Color(0xffa5b4fc),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blueAccent, size: 20),
                                    tooltip: 'Editar Usuario',
                                    onPressed: () => _mostrarModalEditarUsuario(u),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                    tooltip: 'Eliminar Usuario',
                                    onPressed: () => _eliminarUsuario(id, name),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
