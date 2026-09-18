import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    String baseUrl = "http://localhost:8000/api/";
    try {
      final appDir = Directory(Platform.resolvedExecutable).parent.path;
      final configFile = File('$appDir\\config.json');
      if (configFile.existsSync()) {
        final configData = json.decode(configFile.readAsStringSync());
        if (configData['api_url'] != null) {
          baseUrl = configData['api_url'];
          if (!baseUrl.endsWith('/')) baseUrl += '/';
        }
      } else {
        configFile.writeAsStringSync(json.encode({"api_url": "http://localhost:8000/api/"}));
      }
    } catch (e) {
      print("Error loading config.json: $e");
    }

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 3),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
      ),
    );
  }

  Dio get client => _dio;
  
  Future<bool> crearBackup() async {
    try {
      final response = await _dio.post(
        'sistema/backup/',
        options: Options(receiveTimeout: const Duration(seconds: 120)),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error al crear backup: $e");
      return false;
    }
  }

  Future<List<dynamic>> getBackups() async {
    try {
      final response = await _dio.get('sistema/backups/');
      if (response.statusCode == 200) {
        return response.data['backups'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      print("Error al listar backups: $e");
      return [];
    }
  }

  Future<bool> eliminarBackup(String nombre) async {
    try {
      final response = await _dio.post(
        'sistema/backup/eliminar/',
        data: {'nombre': nombre},
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error al eliminar backup: $e");
      return false;
    }
  }

  Future<bool> restaurarBackup(String nombre) async {
    try {
      final response = await _dio.post(
        'sistema/backup/restaurar/',
        data: {'nombre': nombre},
        options: Options(receiveTimeout: const Duration(seconds: 120)),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error al restaurar backup: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _dio.post(
        'auth/login/',
        data: {
          'username': username,
          'password': password,
        },
      );
      
      if (response.statusCode == 200) {
        return {
          'success': true,
          'user': response.data['user'],
        };
      }
      return {
        'success': false,
        'message': response.data['message'] ?? 'Error desconocido',
      };
    } on DioException catch (e) {
      String msg = 'Error de comunicación con el servidor';
      if (e.response != null && e.response?.data != null) {
        msg = e.response?.data['message'] ?? msg;
      }
      return {
        'success': false,
        'message': msg,
      };
    }
  }

  Future<Map<String, dynamic>?> getDashboardStats() async {
    try {
      final response = await _dio.get('dashboard/stats/');
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print("Error al conectar con la API de Dashboard Stats: $e");
      return null;
    }
  }

  Future<List<dynamic>> getInstrumentos() async {
    try {
      final response = await _dio.get('instrumentos/');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      print("Error al conectar con la API de Instrumentos: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> createInstrumento(Map<String, dynamic> datos) async {
    try {
      final response = await _dio.post(
        'instrumentos/crear/',
        data: datos,
      );
      if (response.statusCode == 200) return {'success': true};
      return {'success': false, 'message': 'Error del servidor'};
    } catch (e) {
      return {'success': false, 'message': _handleError(e)};
    }
  }

  Future<Map<String, dynamic>> updateInstrumento(String codigoOriginal, Map<String, dynamic> datos) async {
    try {
      final response = await _dio.post(
        'instrumentos/editar/$codigoOriginal/',
        data: datos,
      );
      if (response.statusCode == 200) return {'success': true};
      return {'success': false, 'message': 'Error del servidor'};
    } catch (e) {
      return {'success': false, 'message': _handleError(e)};
    }
  }

  Future<Map<String, dynamic>> deleteInstrumento(String codigo) async {
    try {
      final response = await _dio.delete('instrumentos/eliminar/$codigo/');
      if (response.statusCode == 200) return {'success': true};
      return {'success': false, 'message': 'Error del servidor'};
    } catch (e) {
      return {'success': false, 'message': _handleError(e)};
    }
  }

  Future<List<dynamic>> getOperarios() async {
    try {
      final response = await _dio.get('operarios/');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      print("Error al conectar con la API de Operarios: $e");
      return [];
    }
  }

  Future<List<dynamic>> getPrestamos() async {
    try {
      final response = await _dio.get('prestamos/');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      print("Error al conectar con la API de Prestamos: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> createPrestamo(String codigoInstrumento, String legajoOperario, String observaciones) async {
    try {
      final response = await _dio.post(
        'prestamos/crear/',
        data: {
          'codigo_instrumento': codigoInstrumento,
          'legajo_operario': legajoOperario,
          'observaciones': observaciones,
        },
      );
      if (response.statusCode == 200) {
        return {'success': true};
      }
      return {'success': false, 'message': 'Error del servidor'};
    } catch (e) {
      return {'success': false, 'message': _handleError(e)};
    }
  }

  Future<Map<String, dynamic>> devolverPrestamo(int id) async {
    try {
      final response = await _dio.post('prestamos/devolver/$id/');
      if (response.statusCode == 200) return {'success': true};
      return {'success': false, 'message': 'Error del servidor'};
    } catch (e) {
      return {'success': false, 'message': _handleError(e)};
    }
  }

  Future<Map<String, dynamic>> deletePrestamo(int id) async {
    try {
      final response = await _dio.delete('prestamos/eliminar/$id/');
      if (response.statusCode == 200) return {'success': true};
      return {'success': false, 'message': 'Error del servidor'};
    } catch (e) {
      return {'success': false, 'message': _handleError(e)};
    }
  }

  Future<Map<String, dynamic>> createOperario(String legajo, String nombre, String cargo, bool activo) async {
    try {
      final response = await _dio.post(
        'operarios/crear/',
        data: {'legajo': legajo, 'nombre': nombre, 'cargo': cargo, 'activo': activo},
      );
      if (response.statusCode == 200) return {'success': true};
      return {'success': false, 'message': 'Error del servidor'};
    } catch (e) {
      return {'success': false, 'message': _handleError(e)};
    }
  }

  Future<Map<String, dynamic>> updateOperario(String legajoOriginal, String nombre, String cargo, bool activo) async {
    try {
      final response = await _dio.post(
        'operarios/editar/$legajoOriginal/',
        data: {'nombre': nombre, 'cargo': cargo, 'activo': activo},
      );
      if (response.statusCode == 200) return {'success': true};
      return {'success': false, 'message': 'Error del servidor'};
    } catch (e) {
      return {'success': false, 'message': _handleError(e)};
    }
  }

  Future<Map<String, dynamic>> deleteOperario(String legajo) async {
    try {
      final response = await _dio.delete('operarios/eliminar/$legajo/');
      if (response.statusCode == 200) return {'success': true};
      return {'success': false, 'message': 'Error del servidor'};
    } catch (e) {
      return {'success': false, 'message': _handleError(e)};
    }
  }

  Future<List<int>?> exportarInstrumentosXLSX([String? q]) async {
    try {
      final queryParam = q != null && q.isNotEmpty ? '?q=${Uri.encodeComponent(q)}' : '';
      final response = await _dio.get(
        'sistema/exportar/instrumentos/$queryParam',
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 200) {
        return response.data as List<int>;
      }
      return null;
    } catch (e) {
      print("Error al exportar instrumentos: $e");
      return null;
    }
  }

  Future<List<int>?> exportarPrestamosXLSX([String? q]) async {
    try {
      final queryParam = q != null && q.isNotEmpty ? '?q=${Uri.encodeComponent(q)}' : '';
      final response = await _dio.get(
        'sistema/exportar/prestamos/$queryParam',
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 200) {
        return response.data as List<int>;
      }
      return null;
    } catch (e) {
      print("Error al exportar prestamos: $e");
      return null;
    }
  }

  Future<List<dynamic>> getUsuarios() async {
    try {
      final response = await _dio.get('usuarios/');
      if (response.statusCode == 200) {
        return response.data['usuarios'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      print("Error al listar usuarios: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> crearUsuario(String username, String password, bool isStaff) async {
    try {
      final response = await _dio.post(
        'usuarios/crear/',
        data: {'username': username, 'password': password, 'is_staff': isStaff},
      );
      if (response.statusCode == 200) return {'success': true};
      return {'success': false, 'message': response.data['message'] ?? 'Error del servidor'};
    } catch (e) {
      return {'success': false, 'message': _handleError(e)};
    }
  }

  Future<Map<String, dynamic>> editarUsuario(int id, String username, String password, bool isStaff) async {
    try {
      final response = await _dio.post(
        'usuarios/editar/$id/',
        data: {'username': username, 'password': password, 'is_staff': isStaff},
      );
      if (response.statusCode == 200) return {'success': true};
      return {'success': false, 'message': response.data['message'] ?? 'Error del servidor'};
    } catch (e) {
      return {'success': false, 'message': _handleError(e)};
    }
  }

  Future<Map<String, dynamic>> eliminarUsuario(int id) async {
    try {
      final response = await _dio.delete('usuarios/eliminar/$id/');
      if (response.statusCode == 200) return {'success': true};
      return {'success': false, 'message': response.data['message'] ?? 'Error del servidor'};
    } catch (e) {
      return {'success': false, 'message': _handleError(e)};
    }
  }

  Future<List<dynamic>> getHistorialCalibracion(String codigo) async {
    try {
      final response = await _dio.get('instrumentos/historial-calibracion/$codigo/');
      if (response.statusCode == 200) {
        return response.data['historial'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      print("Error al listar historial de calibracion: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> crearHistorialCalibracion(String codigo, String fechaCal, String fechaVen, String numCert, String obs) async {
    try {
      final response = await _dio.post(
        'instrumentos/historial-calibracion/$codigo/crear/',
        data: {
          'fecha_calibracion': fechaCal,
          'fecha_vencimiento': fechaVen,
          'num_certificado': numCert,
          'observacion': obs
        },
      );
      if (response.statusCode == 200) return {'success': true};
      return {'success': false, 'message': response.data['message'] ?? 'Error del servidor'};
    } catch (e) {
      return {'success': false, 'message': _handleError(e)};
    }
  }

  Future<Map<String, dynamic>> getConfig() async {
    try {
      final response = await _dio.get('config/');
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return {};
    } catch (e) {
      print("Error fetching config: $e");
      return {};
    }
  }

  Future<bool> updateConfig(Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('config/', data: data);
      return response.statusCode == 200 && response.data['success'] == true;
    } catch (e) {
      print("Error updating config: $e");
      return false;
    }
  }

  String _handleError(dynamic e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout || 
          e.type == DioExceptionType.receiveTimeout || 
          e.type == DioExceptionType.connectionError) {
        return "No se pudo conectar con el servidor local. Verifique que el servicio esté activo.";
      }
      if (e.response != null && e.response?.data is Map && e.response?.data['message'] != null) {
        return e.response!.data['message'];
      }
    }
    return "Ocurrió un error inesperado de comunicación.";
  }

  Future<String> getDebugDbPath() async {
    try {
      final response = await _dio.get('debug-db/');
      if (response.statusCode == 200 && response.data['db_path'] != null) {
        return response.data['db_path'].toString();
      }
    } catch (e) {
      print("Error fetching debug db path: $e");
    }
    return 'Desconocida o no accesible';
  }
}
