# Reglas de Agente para la Carpeta `app_tesis/` (Flutter Móvil)

Este directorio es administrado exclusivamente por el agente **`FLUTTER`**.

## Responsabilidades
- Interfaz gráfica en Flutter/Dart, Provider/state y navegación.
- Pantallas de reportes ambientales: **Fauna, Flora, Agua, Suelo**.
- Captura de fotos con compresión (`image_picker`), geolocalización GPS (`geolocator`) y mapas.
- Almacenamiento local con `shared_preferences`.
- Consumo seguro de endpoints Spring Boot (`/api/...`) enviando token Bearer JWT.

## Restricciones
- **PROHIBIDO** modificar o crear archivos fuera de `app_tesis/`.
- Mantener `flutter analyze` libre de advertencias y errores.
- Notificar al `ORQUESTADOR` si se detecta un contrato de API discordante.
