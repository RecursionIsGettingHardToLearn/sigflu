import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'ruta_model.dart';

/// Calculador de rutas ultra-optimizado
class FastRouteCalculator {
  final List<LineaRuta> todasLasRutas;

  // Cache de distancias para evitar recalcular
  final Map<String, double> _cacheDistancias = {};

  FastRouteCalculator(this.todasLasRutas);

  /// Calcula las mejores rutas - VERSION OPTIMIZADA
  List<Map<String, dynamic>> calcularRutas({
    required LatLng origen,
    required LatLng destino,
    int maxResultados = 5,
  }) {
    print('🚀 INICIO CÁLCULO RÁPIDO');
    final stopwatch = Stopwatch()..start();

    List<Map<String, dynamic>> resultados = [];

    // 1. RUTAS DIRECTAS - Probar todas (es rápido, solo 20 rutas)
    print('📍 Paso 1: Rutas directas...');
    for (var ruta in todasLasRutas) {
      var info = _analizarRutaDirecta(origen, destino, ruta);
      if (info != null) {
        resultados.add(info);
      }
    }
    print(
      '   ✅ ${resultados.length} rutas directas (${stopwatch.elapsedMilliseconds}ms)',
    );

    // 2. RUTAS CON 1 TRANSBORDO - Buscar siempre para tener más opciones
    print('📍 Paso 2: Rutas con 1 transbordo...');
    _buscarRutasConTransbordoRapido(origen, destino, resultados);
    print(
      '   ✅ ${resultados.length} rutas totales (${stopwatch.elapsedMilliseconds}ms)',
    );

    if (resultados.isEmpty) {
      print('⚠️ No se encontraron rutas');
    }

    // Ordenar por costo
    resultados.sort((a, b) => _calcularCosto(a).compareTo(_calcularCosto(b)));

    stopwatch.stop();
    print(
      '✅ CÁLCULO COMPLETO: ${resultados.length} rutas en ${stopwatch.elapsedMilliseconds}ms',
    );

    return resultados.take(maxResultados).toList();
  }

  /// Busca rutas con 1 transbordo - VERSION OPTIMIZADA
  void _buscarRutasConTransbordoRapido(
    LatLng origen,
    LatLng destino,
    List<Map<String, dynamic>> resultados,
  ) {
    // Encontrar las 5 mejores rutas para el origen
    List<MapEntry<LineaRuta, Map<String, dynamic>>> rutasOrigen = [];
    for (var ruta in todasLasRutas) {
      var info = _encontrarPuntoMasCercano(origen, ruta.puntos);
      rutasOrigen.add(MapEntry(ruta, info));
    }
    rutasOrigen.sort(
      (a, b) => (a.value['distancia'] as double).compareTo(
        b.value['distancia'] as double,
      ),
    );

    // Encontrar las 5 mejores rutas para el destino
    List<MapEntry<LineaRuta, Map<String, dynamic>>> rutasDestino = [];
    for (var ruta in todasLasRutas) {
      var info = _encontrarPuntoMasCercano(destino, ruta.puntos);
      rutasDestino.add(MapEntry(ruta, info));
    }
    rutasDestino.sort(
      (a, b) => (a.value['distancia'] as double).compareTo(
        b.value['distancia'] as double,
      ),
    );

    // Probar todas las rutas para encontrar las mejores combinaciones
    int maxRutasOrigen = min(12, rutasOrigen.length);
    int maxRutasDestino = min(12, rutasDestino.length);

    for (int i = 0; i < maxRutasOrigen; i++) {
      if (resultados.length >= 15) break; // Buscar más opciones

      var ruta1 = rutasOrigen[i].key;
      var origenInfo = rutasOrigen[i].value;
      int indiceOrigen = origenInfo['indice'];

      // Probar más puntos de transbordo en ruta1 para mayor cobertura
      int step = max(10, (ruta1.puntos.length - indiceOrigen) ~/ 5);

      for (int j = 0; j < 5; j++) {
        int idx = indiceOrigen + step * (j + 1);
        if (idx >= ruta1.puntos.length) break;

        LatLng transbordo = ruta1.puntos[idx];

        // Probar con las rutas cercanas al destino
        for (int k = 0; k < maxRutasDestino; k++) {
          var ruta2 = rutasDestino[k].key;
          if (ruta2.id == ruta1.id) continue;

          // Verificar si ruta2 pasa cerca del transbordo
          var transbordoInfo = _encontrarPuntoMasCercano(
            transbordo,
            ruta2.puntos,
          );
          // Umbral más amplio: aceptar transbordos hasta 1km
          if (transbordoInfo['distancia'] > 1.0) continue;

          var destinoInfo = rutasDestino[k].value;
          int indiceTransbordo = transbordoInfo['indice'];
          int indiceDestino = destinoInfo['indice'];

          // Verificar dirección
          if (indiceDestino <= indiceTransbordo) continue;

          // Construir resultado
          var resultado = _construirRutaConTransbordo(
            origen,
            destino,
            ruta1,
            ruta2,
            indiceOrigen,
            idx,
            indiceTransbordo,
            indiceDestino,
            origenInfo['distancia'],
            destinoInfo['distancia'],
            transbordoInfo['distancia'],
          );

          if (resultado != null) {
            resultados.add(resultado);
          }
        }
      }
    }
  }

  Map<String, dynamic>? _construirRutaConTransbordo(
    LatLng origen,
    LatLng destino,
    LineaRuta ruta1,
    LineaRuta ruta2,
    int idx1Inicio,
    int idx1Fin,
    int idx2Inicio,
    int idx2Fin,
    double distOrigen,
    double distDestino,
    double distTransbordo,
  ) {
    List<LatLng> seg1 = ruta1.puntos.sublist(idx1Inicio, idx1Fin + 1);
    List<LatLng> seg2 = ruta2.puntos.sublist(idx2Inicio, idx2Fin + 1);

    double dist1 = _calcularDistanciaTotal(seg1);
    double dist2 = _calcularDistanciaTotal(seg2);
    double distTotal = dist1 + dist2;

    int tiempo = ((distTotal / 20.0) * 60).ceil() + 8;

    String num1 = _extraerNumeroLinea(ruta1.nombre);
    String num2 = _extraerNumeroLinea(ruta2.nombre);

    return {
      'tipo': '1 TRANSBORDO',
      'rutas': [ruta1, ruta2],
      'tiempo': tiempo,
      'transbordos': 1,
      'descripcion': 'Con 1 transbordo',
      'detalles':
          '🚌 Línea $num1 (${ruta1.descripcion})\n'
          '🔄 Transbordo\n'
          '🚌 Línea $num2 (${ruta2.descripcion})',
      'distancia': distTotal,
      'distanciaTotal': distOrigen + distDestino + distTransbordo,
      'puntoTransbordo': ruta1.puntos[idx1Fin],
      'segmentos': [
        {'puntos': seg1, 'ruta': ruta1},
        {'puntos': seg2, 'ruta': ruta2},
      ],
    };
  }

  Map<String, dynamic>? _analizarRutaDirecta(
    LatLng origen,
    LatLng destino,
    LineaRuta ruta,
  ) {
    var puntoCercanoOrigen = _encontrarPuntoMasCercano(origen, ruta.puntos);
    var puntoCercanoDestino = _encontrarPuntoMasCercano(destino, ruta.puntos);

    int indiceOrigen = puntoCercanoOrigen['indice'];
    int indiceDestino = puntoCercanoDestino['indice'];

    // Verificar dirección
    if (indiceDestino <= indiceOrigen) return null;

    List<LatLng> segmento = ruta.puntos.sublist(
      indiceOrigen,
      indiceDestino + 1,
    );
    double distanciaEnRuta = _calcularDistanciaTotal(segmento);

    int tiempoViaje = ((distanciaEnRuta / 20.0) * 60).ceil();
    String numeroLinea = _extraerNumeroLinea(ruta.nombre);

    return {
      'tipo': 'DIRECTO',
      'rutas': [ruta],
      'tiempo': tiempoViaje,
      'transbordos': 0,
      'descripcion': 'Sin transbordos',
      'detalles': '🚌 Línea $numeroLinea (${ruta.descripcion})',
      'distancia': distanciaEnRuta,
      'distanciaTotal':
          puntoCercanoOrigen['distancia'] + puntoCercanoDestino['distancia'],
      'segmentos': [
        {'puntos': segmento, 'ruta': ruta},
      ],
    };
  }

  double _calcularCosto(Map<String, dynamic> ruta) {
    int transbordos = ruta['transbordos'] ?? 0;
    double distanciaCaminata = ruta['distanciaTotal'] ?? 0.0;
    int tiempo = ruta['tiempo'] ?? 0;

    // Priorizar rutas que te dejen más cerca del destino (menor distancia de caminata)
    // La distancia de caminata es el factor más importante
    // Penalizar transbordos moderadamente (mejor 1 transbordo cerca que directo lejos)
    return distanciaCaminata * 200.0 + transbordos * 600.0 + tiempo * 0.3;
  }

  Map<String, dynamic> _encontrarPuntoMasCercano(
    LatLng punto,
    List<LatLng> puntos,
  ) {
    int indiceCercano = 0;
    double minDistancia = _calcularDistancia(punto, puntos[0]);

    // Optimización: solo revisar cada N puntos si la lista es muy larga
    int step = puntos.length > 150 ? 2 : 1;

    for (int i = step; i < puntos.length; i += step) {
      double dist = _calcularDistancia(punto, puntos[i]);
      if (dist < minDistancia) {
        minDistancia = dist;
        indiceCercano = i;
      }
    }

    // Refinamiento: buscar en vecindad del punto encontrado
    int inicio = max(0, indiceCercano - step);
    int fin = min(puntos.length, indiceCercano + step + 1);

    for (int i = inicio; i < fin; i++) {
      if (i == indiceCercano) continue;
      double dist = _calcularDistancia(punto, puntos[i]);
      if (dist < minDistancia) {
        minDistancia = dist;
        indiceCercano = i;
      }
    }

    return {
      'indice': indiceCercano,
      'distancia': minDistancia,
      'punto': puntos[indiceCercano],
    };
  }

  double _calcularDistancia(LatLng p1, LatLng p2) {
    // Usar cache para evitar recalcular
    String key =
        '${p1.latitude},${p1.longitude}-${p2.latitude},${p2.longitude}';
    if (_cacheDistancias.containsKey(key)) {
      return _cacheDistancias[key]!;
    }

    const double radioTierra = 6371.0;
    double dLat = _gradosARadianes(p2.latitude - p1.latitude);
    double dLon = _gradosARadianes(p2.longitude - p1.longitude);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_gradosARadianes(p1.latitude)) *
            cos(_gradosARadianes(p2.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double dist = radioTierra * c;

    _cacheDistancias[key] = dist;
    return dist;
  }

  double _gradosARadianes(double grados) {
    return grados * pi / 180.0;
  }

  double _calcularDistanciaTotal(List<LatLng> puntos) {
    if (puntos.length < 2) return 0.0;

    double distancia = 0.0;
    for (int i = 0; i < puntos.length - 1; i++) {
      distancia += _calcularDistancia(puntos[i], puntos[i + 1]);
    }
    return distancia;
  }

  String _extraerNumeroLinea(String nombre) {
    final match = RegExp(r'L0*(\d+)').firstMatch(nombre);
    return match?.group(1) ?? nombre;
  }
}
