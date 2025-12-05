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
  LatLng get puntoInicio => puntos.isNotEmpty ? puntos.first : const LatLng(0, 0);
  LatLng get puntoFin => puntos.isNotEmpty ? puntos.last : const LatLng(0, 0);

  // ----------------------------------------------------------------------
  // MÉTODO FACTORY PARA CREAR DESDE JSON (Lo que devuelve tu endpoint)
  // ----------------------------------------------------------------------
  factory LineaRuta.fromJson(Map<String, dynamic> json) {
    return LineaRuta(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      // Mapeamos 'nombre_linea' del JSON a 'nombre' del modelo
      nombre: json['nombre_linea'] ?? 'Sin Nombre',
      // Mapeamos 'descripcion_ruta' del JSON
      descripcion: json['descripcion_ruta'] ?? '',
      // Convertimos el Hex String (#FF0000) a Color object
      color: _hexToColor(json['color']),
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