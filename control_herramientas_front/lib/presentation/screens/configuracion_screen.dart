import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/api_service.dart';
import 'package:file_picker/file_picker.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();
  
  int _alertDaysThreshold = 45;
  String _companyName = '';
  String _plantName = '';
  final TextEditingController _reportsBasePathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  Future<void> _cargarConfiguracion() async {
    setState(() => _isLoading = true);
    final config = await _apiService.getConfig();
    if (mounted) {
      setState(() {
        _alertDaysThreshold = config['alert_days_threshold'] ?? 45;
        _companyName = config['company_name'] ?? '';
        _plantName = config['plant_name'] ?? '';
        _reportsBasePathController.text = config['reports_base_path'] ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _guardarConfiguracion() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    
    setState(() => _isSaving = true);
    
    final success = await _apiService.updateConfig({
      'alert_days_threshold': _alertDaysThreshold,
      'company_name': _companyName,
      'plant_name': _plantName,
      'reports_base_path': _reportsBasePathController.text,
    });
    
    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Configuración guardada correctamente.' : 'Error al guardar la configuración.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xff4f46e5)));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Configuración y Ajustes del Sistema',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Datos Institucionales', Icons.domain),
                const SizedBox(height: 16),
                _buildCard([
                  _buildTextField(
                    label: 'Nombre de la Empresa',
                    initialValue: _companyName,
                    icon: Icons.business,
                    onSaved: (val) => _companyName = val ?? '',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Nombre de la Planta / Sucursal',
                    initialValue: _plantName,
                    icon: Icons.factory,
                    onSaved: (val) => _plantName = val ?? '',
                  ),
                ]),
                const SizedBox(height: 32),
                
                _buildSectionTitle('Almacenamiento de Reportes', Icons.folder_special),
                const SizedBox(height: 16),
                _buildCard([
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _reportsBasePathController,
                          style: const TextStyle(color: Colors.white),
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Carpeta Base de Reportes / PDFs',
                            prefixIcon: const Icon(Icons.folder_open, color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xff12141c),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            helperText: 'Ruta local o de red donde se buscarán los PDFs de instrumentos por defecto.',
                            helperStyle: const TextStyle(color: Colors.white60),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            String? selectedDirectory = await FilePicker.getDirectoryPath();
                            if (selectedDirectory != null) {
                              setState(() {
                                _reportsBasePathController.text = selectedDirectory;
                              });
                            }
                          },
                          icon: const Icon(Icons.search),
                          label: const Text('Examinar...'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff374151),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          ),
                        ),
                      ),
                    ],
                  )
                ]),
                const SizedBox(height: 32),
                
                _buildSectionTitle('Parámetros Operativos de Metrología', Icons.settings_applications),
                const SizedBox(height: 16),
                _buildCard([
                  _buildNumberField(
                    label: 'Umbral de Alerta de Calibración (Días)',
                    initialValue: _alertDaysThreshold.toString(),
                    icon: Icons.warning_amber_rounded,
                    onSaved: (val) => _alertDaysThreshold = int.tryParse(val ?? '45') ?? 45,
                    helperText: 'Días de anticipación con los que el dashboard alertará próximos vencimientos.',
                  ),
                ]),
                
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _guardarConfiguracion,
                    icon: _isSaving 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save),
                    label: Text(_isSaving ? 'Guardando...' : 'Guardar Configuración'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff4f46e5),
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xff06b6d4), size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xff1e2230),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String initialValue,
    required IconData icon,
    required FormFieldSetter<String> onSaved,
  }) {
    return TextFormField(
      initialValue: initialValue,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xff12141c),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      validator: (val) => (val == null || val.trim().isEmpty) ? 'Requerido' : null,
      onSaved: onSaved,
    );
  }

  Widget _buildNumberField({
    required String label,
    required String initialValue,
    required IconData icon,
    required FormFieldSetter<String> onSaved,
    required String helperText,
  }) {
    return TextFormField(
      initialValue: initialValue,
      style: const TextStyle(color: Colors.white),
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        helperText: helperText,
        filled: true,
        fillColor: const Color(0xff12141c),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) return 'Requerido';
        if (int.tryParse(val) == null) return 'Debe ser un número válido';
        return null;
      },
      onSaved: onSaved,
    );
  }

  @override
  void dispose() {
    _reportsBasePathController.dispose();
    super.dispose();
  }
}
