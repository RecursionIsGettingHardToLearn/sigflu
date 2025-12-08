import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LineaRuta {
  final int id;
  final String nombre;
  final String descripcion; // Agregado para aprovechar el JSON
  final Color color;
  final List<LatLng> puntos;

  LineaRuta({
    required this.id,
    this.nombre = '',
    this.descripcion = '',
    required this.color,
    required this.puntos,
  });

  // Helpers para el PDF/Mapa
  LatLng get puntoInicio =>
      puntos.isNotEmpty ? puntos.first : const LatLng(0, 0);
  LatLng get puntoFin => puntos.isNotEmpty ? puntos.last : const LatLng(0, 0);

  // ----------------------------------------------------------------------
  // MÉTODO FACTORY PARA CREAR DESDE JSON (Lo que devuelve tu endpoint)
  // ----------------------------------------------------------------------
  factory LineaRuta.fromJson(Map<String, dynamic> json) {
    String nombreLinea = json['nombre_linea'] ?? 'Sin Nombre';
    Color colorOriginal = _hexToColor(json['color']);

    // Si el color es rojo puro (#FF0000), generar color único por línea
    Color colorFinal =
        (json['color']?.toUpperCase() == '#FF0000' ||
                json['color']?.toUpperCase() == '#FFFF0000')
            ? _generarColorPorLinea(nombreLinea)
            : colorOriginal;

    return LineaRuta(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      // Mapeamos 'nombre_linea' del JSON a 'nombre' del modelo
      nombre: nombreLinea,
      // Mapeamos 'descripcion_ruta' del JSON
      descripcion: json['descripcion_ruta'] ?? '',
      // Usar color generado si todas son rojas
      color: colorFinal,
      // Convertimos la lista de strings lat/lng a objetos LatLng
      puntos: _parsePoints(json['puntos']),
    );
  }

  // Utilidad: Convierte "#FF0000" -> Color(0xFFFF0000)
  static Color _hexToColor(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) return Colors.black;
    try {
      hexColor = hexColor.toUpperCase().replaceAll("#", "");
      if (hexColor.length == 6) {
        hexColor = "FF$hexColor"; // Agregar opacidad completa si falta
      }
      return Color(int.parse(hexColor, radix: 16));
    } catch (e) {
      return Colors.black; // Color por defecto si falla
    }
  }

  // Generar color único basado en el nombre de línea (L001, L002, etc.)
  static Color _generarColorPorLinea(String nombreLinea) {
    // Extraer número de línea (L001 -> 001)
    final match = RegExp(r'L0*(\d+)').firstMatch(nombreLinea);
    if (match == null) return Colors.blue;

    final numeroLinea = int.tryParse(match.group(1) ?? '0') ?? 0;

    // Paleta de colores vibrantes para líneas de transporte
    final colores = [
      const Color(0xFFE53935), // Rojo brillante
      const Color(0xFF1E88E5), // Azul
      const Color(0xFF43A047), // Verde
      const Color(0xFFFB8C00), // Naranja
      const Color(0xFF8E24AA), // Púrpura
      const Color(0xFF00ACC1), // Cyan
      const Color(0xFFD81B60), // Rosa
      const Color(0xFF3949AB), // Índigo
      const Color(0xFF7CB342), // Verde lima
      const Color(0xFFF4511E), // Naranja oscuro
      const Color(0xFF00897B), // Verde azulado
      const Color(0xFFC0CA33), // Lima
      const Color(0xFFFFB300), // Ámbar
      const Color(0xFF6A1B9A), // Púrpura oscuro
      const Color(0xFF00695C), // Verde azulado oscuro
      const Color(0xFF5E35B1), // Violeta profundo
      const Color(0xFFEF6C00), // Naranja profundo
      const Color(0xFF2E7D32), // Verde oscuro
    ];

    return colores[numeroLinea % colores.length];
  }

  // Utilidad: Convierte [["-17.78", "-63.17"], ...] -> [LatLng(-17.78, -63.17), ...]
  static List<LatLng> _parsePoints(List<dynamic>? puntosJson) {
    if (puntosJson == null) return [];
    List<LatLng> listaCoords = [];

    for (var punto in puntosJson) {
      // El JSON trae ["lat", "lng"] como Strings
      if (punto is List && punto.length >= 2) {
        double lat = double.tryParse(punto[0].toString()) ?? 0.0;
        double lng = double.tryParse(punto[1].toString()) ?? 0.0;
        listaCoords.add(LatLng(lat, lng));
      }
    }
    return listaCoords;
  }
}
