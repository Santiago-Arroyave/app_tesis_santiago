import 'package:goblink_park/screens/api_connection/api_config.dart';

class ApiConstants {
  static const String baseUrl = ApiConfig.baseUrl;
  static const String apiBaseUrl = ApiConfig.apiBaseUrl;

  static const String reportesEndpoint = '$baseUrl/api/reportes';
  static const String categoriasEndpoint = '$baseUrl/api/categorias';
  static const String proyectosEndpoint = '$baseUrl/api/proyectos';
}
