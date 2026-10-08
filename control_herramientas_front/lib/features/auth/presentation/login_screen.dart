import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/api_service.dart';
import '../../../../presentation/widgets/ios_glass_card.dart';

class LoginScreen extends StatefulWidget {
  final Function(Map<String, dynamic> user) onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _apiService = ApiService();
  final _userController = TextEditingController(text: '');
  final _passwordController = TextEditingController(text: '');
  bool _isLoading = false;
  String? _errorMessage;

  String? _dbPath;

  @override
  void initState() {
    super.initState();
    _fetchDbPath();
  }

  Future<void> _fetchDbPath() async {
    final path = await _apiService.getDebugDbPath();
    if (mounted) {
      setState(() {
        _dbPath = path;
      });
    }
  }

  Future<void> _conectarLogin() async {
    if (_userController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Por favor complete todos los campos');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final resultado = await _apiService.login(
        _userController.text.trim(),
        _passwordController.text.trim(),
      );

      if (mounted) {
        if (resultado['success'] == true) {
          widget.onLoginSuccess(resultado['user'] as Map<String, dynamic>);
        } else {
          setState(() {
            _errorMessage = resultado['message'] ?? 'Usuario o contraseña incorrectos';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error de comunicación con el servidor';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff4f6f9),
      body: Center(
        child: SizedBox(
          width: 420,
          child: IosGlassCard(
            padding: const EdgeInsets.all(40),
            opacity: 0.88,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.precision_manufacturing, color: Color(0xff4f46e5), size: 32),
                    const SizedBox(width: 12),
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Color(0xFFFB7185), Color(0xFFFBBF24)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds),
                      child: Text(
                        'ABBAMAT',
                        style: GoogleFonts.orbitron(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          color: const Color(0xff0f172a),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Gestión y Control de Instrumentos',
                  style: TextStyle(color: Color(0xff64748b), fontSize: 14),
                ),
                const SizedBox(height: 32),
                const Text('Usuario', style: TextStyle(color: Color(0xff334155), fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _userController,
                  style: const TextStyle(color: Color(0xff0f172a)),
                  decoration: InputDecoration(
                    hintText: 'Ingrese su operador',
                    hintStyle: const TextStyle(color: Color(0xff94a3b8)),
                    filled: true,
                    fillColor: const Color(0xfff1f5f9),
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xff64748b)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xffcbd5e1))),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xffcbd5e1)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Contraseña', style: TextStyle(color: Color(0xff334155), fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Color(0xff0f172a)),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: const TextStyle(color: Color(0xff94a3b8)),
                    filled: true,
                    fillColor: const Color(0xfff1f5f9),
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xff64748b)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xffcbd5e1))),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xffcbd5e1)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_errorMessage != null)
                  Text(_errorMessage!, style: const TextStyle(color: Color(0xffef4444), fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _conectarLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff4f46e5),
                      foregroundColor: Colors.white,
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Iniciar Sesión', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                if (_dbPath != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xfff1f5f9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xffcbd5e1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.storage, size: 14, color: Color(0xff64748b)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _dbPath!,
                            style: const TextStyle(color: Color(0xff475569), fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
