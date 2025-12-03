import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LineaRuta {
  final int id;
  final String nombre; // Nuevo campo
  final Color color;
  final List<LatLng> puntos;

  LineaRuta({
    required this.id,
    this.nombre = '', // Por defecto vacío, lo llenaremos dinámicamente o en la data
    required this.color,
    required this.puntos,
  });

  // Helpers para el PDF (Punto inicio y fin)
  LatLng get puntoInicio => puntos.isNotEmpty ? puntos.first : const LatLng(0, 0);
  LatLng get puntoFin => puntos.isNotEmpty ? puntos.last : const LatLng(0, 0);
}