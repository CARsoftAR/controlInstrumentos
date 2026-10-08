import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/personal/presentation/operarios_screen.dart';
import 'features/prestamos/presentation/prestamos_screen.dart';
import 'presentation/screens/instrumentos_screen.dart'; 
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/usuarios_screen.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/configuracion_screen.dart';
import 'presentation/screens/estadisticas_screen.dart';
import 'presentation/screens/ubicaciones_screen.dart';
import 'presentation/screens/trazabilidad_screen.dart';
import 'presentation/screens/reportes_screen.dart';
import 'presentation/screens/backups_screen.dart';
import 'presentation/screens/database_manager_screen.dart';
import 'presentation/widgets/ios_glass_card.dart';

void main() {
  runApp(const ControlHerramientasApp());
}

class ControlHerramientasApp extends StatelessWidget {
  const ControlHerramientasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Control de Herramientas y Metrología',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xff12141c),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xff4f46e5),
          secondary: Color(0xff06b6d4),
          surface: Color(0xff1e2230),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ).copyWith(
          bodySmall: GoogleFonts.inter(color: Colors.white70),
          labelSmall: GoogleFonts.inter(color: Colors.white70),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.white, fontSize: 14),
          floatingLabelStyle: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          helperStyle: TextStyle(color: Colors.white70, fontSize: 13),
          hintStyle: TextStyle(color: Colors.white60, fontSize: 14),
          prefixIconColor: Colors.white70,
          suffixIconColor: Colors.white70,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(const Color(0xFF276CF5)),
            foregroundColor: WidgetStateProperty.all(Colors.white),
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            shadowColor: WidgetStateProperty.all(Colors.transparent),
            surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
            elevation: WidgetStateProperty.all(0),
            splashFactory: NoSplash.splashFactory,
            mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
            minimumSize: WidgetStateProperty.all(const Size(64, 50)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
            minimumSize: WidgetStateProperty.all(const Size(64, 50)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: ButtonStyle(
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
            shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
            minimumSize: WidgetStateProperty.all(const Size(64, 50)),
          ),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            mouseCursor: WidgetStateProperty.all(SystemMouseCursors.click),
          ),
        ),
        dataTableTheme: DataTableThemeData(
          dataRowCursor: WidgetStateProperty.all(SystemMouseCursors.click),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class RootGatekeeper extends StatefulWidget {
  const RootGatekeeper({super.key});

  @override
  State<RootGatekeeper> createState() => _RootGatekeeperState();
}

class _RootGatekeeperState extends State<RootGatekeeper> {
  bool _isAuthenticated = false;
  Map<String, dynamic>? _loggedUser;

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated || _loggedUser == null) {
      return LoginScreen(
        onLoginSuccess: (user) {
          setState(() {
            _isAuthenticated = true;
            _loggedUser = user;
          });
        },
      );
    }
    return MainShellScreen(
      loggedUser: _loggedUser!,
      onLogout: () {
        setState(() {
          _isAuthenticated = false;
          _loggedUser = null;
        });
      },
    );
  }
}

class MainShellScreen extends StatefulWidget {
  final Map<String, dynamic> loggedUser;
  final VoidCallback onLogout;
  const MainShellScreen({super.key, required this.loggedUser, required this.onLogout});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    'Panel General de Instrumentos',
    'Nómina de Operarios asignables',
    'Inventario de Metrología',
    'Registro de Movimientos y Préstamos',
    'Gestión de Usuarios y Roles',
    'Configuración y Ajustes',
    'Estadísticas y Métricas',
    'Gestión de Ubicaciones',
    'Trazabilidad Global (Auditoría)',
    'Centro de Reportes (PDF/Excel)',
    'Copias de Seguridad (Backups)',
    'Gestor de Base de Datos',
  ];

  Widget _getScreenBody() {
    switch (_selectedIndex) {
      case 1:
        return const OperariosScreen();
      case 2:
        return const InstrumentosScreen(); 
      case 3:
        return const PrestamosScreen();
      case 4:
        return const UsuariosScreen();
      case 5:
        return const ConfiguracionScreen();
      case 6:
        return const EstadisticasScreen();
      case 7:
        return const UbicacionesScreen();
      case 8:
        return const TrazabilidadScreen();
      case 9:
        return const ReportesScreen();
      case 10:
        return const BackupsScreen();
      case 11:
        return const DatabaseManagerScreen();
      case 0:
      default:
        return const DashboardScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          IosGlassCard(
            padding: EdgeInsets.zero,
            borderRadius: 0,
            child: SizedBox(
              width: 260,
              child: Column(
                children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      const Icon(Icons.precision_manufacturing, color: Color(0xff06b6d4), size: 28),
                      const SizedBox(width: 12),
                      ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFFFC7D17), Color(0xFFFDCA01)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ).createShader(bounds),
                        child: Text(
                          'ABBAMAT',
                          style: GoogleFonts.orbitron(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildMenuItem(0, Icons.dashboard_rounded, 'Dashboard'),
                        _buildMenuItem(1, Icons.badge_rounded, 'Operarios (Planta)'),
                        _buildMenuItem(2, Icons.construction_rounded, 'Instrumentos (Metrología)'),
                        _buildMenuItem(3, Icons.swap_horiz_rounded, 'Préstamos y Asignaciones'),
                        _buildMenuItem(4, Icons.people_alt_rounded, 'Usuarios y Roles'),
                        _buildMenuItem(5, Icons.settings_applications, 'Configuración'),
                        _buildMenuItem(6, Icons.pie_chart_rounded, 'Estadísticas'),
                        _buildMenuItem(7, Icons.location_on, 'Ubicaciones'),
                        _buildMenuItem(8, Icons.history_rounded, 'Trazabilidad y Auditoría'),
                        _buildMenuItem(9, Icons.picture_as_pdf_rounded, 'Reportes y Descargas'),
                        _buildMenuItem(10, Icons.backup_rounded, 'Copias de Seguridad'),
                        _buildMenuItem(11, Icons.storage_rounded, 'Gestor de Base de Datos'),
                      ],
                    ),
                  ),
                ),
                const Divider(color: Colors.white10, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: widget.loggedUser['is_staff'] == true
                            ? const Color(0xff06b6d4).withOpacity(0.2)
                            : const Color(0xff4f46e5).withOpacity(0.2),
                        child: Icon(
                          widget.loggedUser['is_staff'] == true ? Icons.admin_panel_settings : Icons.person,
                          size: 18,
                          color: widget.loggedUser['is_staff'] == true ? const Color(0xff06b6d4) : const Color(0xffa5b4fc),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.loggedUser['username'] ?? '',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.loggedUser['is_staff'] == true ? 'Administrador' : 'Operador',
                              style: const TextStyle(color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                        tooltip: 'Cerrar Sesión',
                        onPressed: widget.onLogout,
                      )
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Servidor API Online', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _titles[_selectedIndex],
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: IosGlassCard(
                      padding: (_selectedIndex == 1 || _selectedIndex == 2 || _selectedIndex == 8 || _selectedIndex == 9) ? EdgeInsets.zero : const EdgeInsets.all(16),
                      child: _getScreenBody(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(int index, IconData icon, String title) {
    final isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: () => setState(() => _selectedIndex = index),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selected: isSelected,
        selectedTileColor: const Color(0xff4f46e5).withOpacity(0.15),
        leading: Icon(icon, color: isSelected ? const Color(0xff06b6d4) : Colors.grey),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
