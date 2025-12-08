import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'ruta_model.dart';

/// Clase para calcular rutas óptimas usando algoritmo de Dijkstra adaptado
class RouteCalculator {
  final List<LineaRuta> todasLasRutas;

  RouteCalculator(this.todasLasRutas);

  /// Calcula las mejores rutas desde origen a destino
  List<Map<String, dynamic>> calcularRutas({
    required LatLng origen,
    required LatLng destino,
    int maxResultados = 5,
  }) {
    print('🚀 Inicio cálculo - ${todasLasRutas.length} rutas disponibles');
    final stopwatch = Stopwatch()..start();

    List<Map<String, dynamic>> resultados = [];

    // 1. RUTAS DIRECTAS (0 transbordos) - MÁS RÁPIDO
    print('📍 Buscando rutas directas...');
    _buscarRutasDirectas(origen, destino, resultados);
    print(
      '   ✓ Encontradas: ${resultados.length} rutas directas (${stopwatch.elapsedMilliseconds}ms)',
    );

    // 2. RUTAS CON 1 TRANSBORDO (si no hay suficientes directas)
    if (resultados.length < 3) {
      // Reducido de 5 a 3 para más velocidad
      print('📍 Buscando rutas con 1 transbordo...');
      final before = resultados.length;
      _buscarRutasConUnTransbordo(origen, destino, resultados);
      print(
        '   ✓ Encontradas: ${resultados.length - before} adicionales (${stopwatch.elapsedMilliseconds}ms)',
      );
    }

    // 3. RUTAS CON 2 TRANSBORDOS (solo si no hay nada)
    if (resultados.isEmpty) {
      print('📍 Buscando rutas con 2 transbordos...');
      _buscarRutasConDosTransbordos(origen, destino, resultados);
      print(
        '   ✓ Encontradas: ${resultados.length} (${stopwatch.elapsedMilliseconds}ms)',
      );
    }

    // Ordenar usando Dijkstra: menor costo primero
    resultados.sort((a, b) {
      double costoA = _calcularCosto(a);
      double costoB = _calcularCosto(b);
      return costoA.compareTo(costoB);
    });

    // Limitar resultados
    if (resultados.length > maxResultados) {
      resultados = resultados.sublist(0, maxResultados);
    }

    stopwatch.stop();
    print(
      '✅ CÁLCULO COMPLETO: ${resultados.length} rutas en ${stopwatch.elapsedMilliseconds}ms',
    );

    return resultados;
  }

  /// Calcula el costo total de una ruta (usado en Dijkstra)
  double _calcularCosto(Map<String, dynamic> ruta) {
    int transbordos = ruta['transbordos'] ?? 0;
    double distanciaCaminata = ruta['distanciaTotal'] ?? 0.0;
    int tiempo = ruta['tiempo'] ?? 0;

    // Penalizar transbordos y distancia de caminata
    return transbordos * 1000.0 + distanciaCaminata * 100.0 + tiempo;
  }

  /// Busca rutas directas (sin transbordos)
  void _buscarRutasDirectas(
    LatLng origen,
    LatLng destino,
    List<Map<String, dynamic>> resultados,
  ) {
    for (var ruta in todasLasRutas) {
      var info = _analizarRutaDirecta(origen, destino, ruta);

      if (info != null) {
        resultados.add(info);
      }
    }
  }

  /// Analiza si una ruta puede conectar origen y destino directamente
  Map<String, dynamic>? _analizarRutaDirecta(
    LatLng origen,
    LatLng destino,
    LineaRuta ruta,
  ) {
    // Encontrar puntos más cercanos en la ruta
    var puntoCercanoOrigen = _encontrarPuntoMasCercano(origen, ruta.puntos);
    var puntoCercanoDestino = _encontrarPuntoMasCercano(destino, ruta.puntos);

    int indiceOrigen = puntoCercanoOrigen['indice'];
    int indiceDestino = puntoCercanoDestino['indice'];
    double distOrigenReal = puntoCercanoOrigen['distancia'];
    double distDestinoReal = puntoCercanoDestino['distancia'];

    // Verificar si la ruta va en la dirección correcta
    if (indiceDestino <= indiceOrigen) {
      return null; // Esta ruta no conecta origen -> destino
    }

    // Calcular distancia en la ruta
    List<LatLng> segmento = ruta.puntos.sublist(
      indiceOrigen,
      indiceDestino + 1,
    );
    double distanciaEnRuta = _calcularDistanciaTotal(segmento);

    // Calcular tiempo: velocidad promedio 20 km/h
    int tiempoViaje = ((distanciaEnRuta / 20.0) * 60).ceil(); // minutos

    // Extraer número de línea para mostrar
    String numeroLinea = _extraerNumeroLinea(ruta.nombre);

    return {
      'tipo': 'DIRECTO',
      'rutas': [ruta],
      'tiempo': tiempoViaje,
      'transbordos': 0,
      'descripcion': 'Sin transbordos',
      'detalles': '🚌 Tomar Línea $numeroLinea\n   ${ruta.descripcion}',
      'distancia': distanciaEnRuta,
      'distanciaTotal': distOrigenReal + distDestinoReal,
      'segmentos': [
        {'puntos': segmento, 'ruta': ruta},
      ],
    };
  }

  /// Busca rutas con 1 transbordo
  void _buscarRutasConUnTransbordo(
    LatLng origen,
    LatLng destino,
    List<Map<String, dynamic>> resultados,
  ) {
    // Limitar búsqueda: solo probar 10 rutas más cercanas al origen
    List<MapEntry<int, double>> rutasConDistancia = [];
    for (int i = 0; i < todasLasRutas.length; i++) {
      var ruta = todasLasRutas[i];
      var cercania = _encontrarPuntoMasCercano(origen, ruta.puntos);
      rutasConDistancia.add(MapEntry(i, cercania['distancia']));
    }
    rutasConDistancia.sort((a, b) => a.value.compareTo(b.value));

    // Solo probar las 10 rutas más cercanas al origen
    int maxRutasOrigen =
        rutasConDistancia.length > 10 ? 10 : rutasConDistancia.length;

    for (int idx = 0; idx < maxRutasOrigen; idx++) {
      int i = rutasConDistancia[idx].key;
      var ruta1 = todasLasRutas[i];

      var inicioCercano = _encontrarPuntoMasCercano(origen, ruta1.puntos);
      int indiceInicio = inicioCercano['indice'];

      // Reducir puntos de transbordo: solo probar cada 10 puntos, máximo 5 puntos
      int paso = ruta1.puntos.length > 50 ? 10 : 5;
      int maxPuntos = 5;
      int contadorPuntos = 0;

      for (
        int j = indiceInicio + paso;
        j < ruta1.puntos.length && contadorPuntos < maxPuntos;
        j += paso
      ) {
        contadorPuntos++;
        LatLng puntoTransbordo = ruta1.puntos[j];

        // Solo probar rutas cercanas al punto de transbordo
        for (int k = 0; k < todasLasRutas.length; k++) {
          if (k == i) continue;

          var ruta2 = todasLasRutas[k];

          // Pre-filtro: verificar si ruta2 está cerca del transbordo
          var cercania = _encontrarPuntoMasCercano(
            puntoTransbordo,
            ruta2.puntos,
          );
          if (cercania['distancia'] > 0.5) continue; // Muy lejos, skip

          var info = _analizarConexionConTransbordo(
            origen,
            destino,
            ruta1,
            ruta2,
            indiceInicio,
            j,
          );

          if (info != null) {
            resultados.add(info);
            if (resultados.length >= 10) return; // Suficientes opciones
          }
        }
      }
    }
  }

  /// Analiza una conexión con transbordo
  Map<String, dynamic>? _analizarConexionConTransbordo(
    LatLng origen,
    LatLng destino,
    LineaRuta ruta1,
    LineaRuta ruta2,
    int indiceInicioRuta1,
    int indiceTransbordoRuta1,
  ) {
    LatLng puntoTransbordo = ruta1.puntos[indiceTransbordoRuta1];

    // Encontrar punto cercano al transbordo en ruta2
    var transbordoCercano = _encontrarPuntoMasCercano(
      puntoTransbordo,
      ruta2.puntos,
    );
    int indiceTransbordoRuta2 = transbordoCercano['indice'];
    double distTransbordo = transbordoCercano['distancia'];

    // El transbordo debe estar razonablemente cerca (menos de 500m)
    if (distTransbordo > 0.5) return null;

    // Encontrar punto cercano al destino en ruta2
    var destinoCercano = _encontrarPuntoMasCercano(destino, ruta2.puntos);
    int indiceDestinoRuta2 = destinoCercano['indice'];

    // Verificar que vaya en la dirección correcta
    if (indiceDestinoRuta2 <= indiceTransbordoRuta2) return null;

    // Calcular distancias
    var origenCercano = _encontrarPuntoMasCercano(origen, ruta1.puntos);
    double distOrigenReal = origenCercano['distancia'];
    double distDestinoReal = destinoCercano['distancia'];

    List<LatLng> segmento1 = ruta1.puntos.sublist(
      indiceInicioRuta1,
      indiceTransbordoRuta1 + 1,
    );
    List<LatLng> segmento2 = ruta2.puntos.sublist(
      indiceTransbordoRuta2,
      indiceDestinoRuta2 + 1,
    );

    double dist1 = _calcularDistanciaTotal(segmento1);
    double dist2 = _calcularDistanciaTotal(segmento2);
    double distanciaTotal = dist1 + dist2;

    // Tiempo: viaje + 8 min por transbordo
    int tiempoViaje = ((distanciaTotal / 20.0) * 60).ceil() + 8;

    String numero1 = _extraerNumeroLinea(ruta1.nombre);
    String numero2 = _extraerNumeroLinea(ruta2.nombre);

    return {
      'tipo': '1 TRANSBORDO',
      'rutas': [ruta1, ruta2],
      'tiempo': tiempoViaje,
      'transbordos': 1,
      'descripcion': 'Con 1 transbordo',
      'detalles':
          '🚌 Tomar Línea $numero1\n   ${ruta1.descripcion}\n'
          '🔄 Transbordo\n'
          '🚌 Tomar Línea $numero2\n   ${ruta2.descripcion}',
      'distancia': distanciaTotal,
      'distanciaTotal': distOrigenReal + distDestinoReal + distTransbordo,
      'puntoTransbordo': puntoTransbordo,
      'segmentos': [
        {'puntos': segmento1, 'ruta': ruta1},
        {'puntos': segmento2, 'ruta': ruta2},
      ],
    };
  }

  /// Busca rutas con 2 transbordos
  void _buscarRutasConDosTransbordos(
    LatLng origen,
    LatLng destino,
    List<Map<String, dynamic>> resultados,
  ) {
    // Solo si no hay otras opciones y limitar drásticamente
    if (resultados.isEmpty) {
      // Encontrar las 5 rutas más cercanas al origen
      List<MapEntry<int, double>> rutasOrdenadas = [];
      for (int i = 0; i < todasLasRutas.length; i++) {
        var cercania = _encontrarPuntoMasCercano(
          origen,
          todasLasRutas[i].puntos,
        );
        rutasOrdenadas.add(MapEntry(i, cercania['distancia']));
      }
      rutasOrdenadas.sort((a, b) => a.value.compareTo(b.value));

      // Solo probar las 5 rutas más cercanas
      int maxRutas = rutasOrdenadas.length > 5 ? 5 : rutasOrdenadas.length;

      for (int idx1 = 0; idx1 < maxRutas && resultados.isEmpty; idx1++) {
        int i = rutasOrdenadas[idx1].key;
        var ruta1 = todasLasRutas[i];
        var inicioCercano = _encontrarPuntoMasCercano(origen, ruta1.puntos);

        // Solo probar 2 puntos de transbordo en ruta1
        int paso1 = (ruta1.puntos.length - inicioCercano['indice']) ~/ 3;
        if (paso1 < 10) paso1 = 10;

        for (
          int j = inicioCercano['indice'] + paso1;
          j < ruta1.puntos.length && j < inicioCercano['indice'] + paso1 * 2;
          j += paso1
        ) {
          if (resultados.isNotEmpty) break;

          LatLng transbordo1 = ruta1.puntos[j];

          // Solo probar 5 rutas para el segundo segmento
          for (int idx2 = 0; idx2 < maxRutas; idx2++) {
            int k = rutasOrdenadas[idx2].key;
            if (k == i) continue;

            var ruta2 = todasLasRutas[k];
            var trans1Cercano = _encontrarPuntoMasCercano(
              transbordo1,
              ruta2.puntos,
            );

            if (trans1Cercano['distancia'] > 0.5) continue;

            // Solo probar 1 punto de transbordo en ruta2
            int paso2 = (ruta2.puntos.length - trans1Cercano['indice']) ~/ 2;
            if (paso2 < 15) paso2 = 15;

            int m = trans1Cercano['indice'] + paso2;
            if (m >= ruta2.puntos.length) continue;

            LatLng transbordo2 = ruta2.puntos[m];

            // Solo probar 3 rutas para el tercer segmento
            for (
              int idx3 = 0;
              idx3 < 3 && idx3 < todasLasRutas.length;
              idx3++
            ) {
              int n = rutasOrdenadas[idx3].key;
              if (n == i || n == k) continue;

              var ruta3 = todasLasRutas[n];
              var trans2Cercano = _encontrarPuntoMasCercano(
                transbordo2,
                ruta3.puntos,
              );

              if (trans2Cercano['distancia'] > 0.5) continue;

              var destinoCercano = _encontrarPuntoMasCercano(
                destino,
                ruta3.puntos,
              );

              if (destinoCercano['indice'] <= trans2Cercano['indice']) continue;

              // Construir resultado
              List<LatLng> seg1 = ruta1.puntos.sublist(
                inicioCercano['indice'],
                j + 1,
              );
              List<LatLng> seg2 = ruta2.puntos.sublist(
                trans1Cercano['indice'],
                m + 1,
              );
              List<LatLng> seg3 = ruta3.puntos.sublist(
                trans2Cercano['indice'],
                destinoCercano['indice'] + 1,
              );

              double distTotal =
                  _calcularDistanciaTotal(seg1) +
                  _calcularDistanciaTotal(seg2) +
                  _calcularDistanciaTotal(seg3);

              int tiempo =
                  ((distTotal / 20.0) * 60).ceil() +
                  16; // 8 min x 2 transbordos

              String num1 = _extraerNumeroLinea(ruta1.nombre);
              String num2 = _extraerNumeroLinea(ruta2.nombre);
              String num3 = _extraerNumeroLinea(ruta3.nombre);

              resultados.add({
                'tipo': '2 TRANSBORDOS',
                'rutas': [ruta1, ruta2, ruta3],
                'tiempo': tiempo,
                'transbordos': 2,
                'descripcion': 'Con 2 transbordos',
                'detalles':
                    '🚌 Línea $num1\n🔄 Transbordo\n'
                    '🚌 Línea $num2\n🔄 Transbordo\n'
                    '🚌 Línea $num3',
                'distancia': distTotal,
                'distanciaTotal':
                    inicioCercano['distancia'] +
                    destinoCercano['distancia'] +
                    trans1Cercano['distancia'] +
                    trans2Cercano['distancia'],
                'segmentos': [
                  {'puntos': seg1, 'ruta': ruta1},
                  {'puntos': seg2, 'ruta': ruta2},
                  {'puntos': seg3, 'ruta': ruta3},
                ],
              });

              return; // Solo encontrar una opción
            }
          }
        }
      }
    }
  }

  /// Encuentra el punto más cercano en una lista de puntos
  Map<String, dynamic> _encontrarPuntoMasCercano(
    LatLng punto,
    List<LatLng> puntos,
  ) {
    int indiceCercano = 0;
    double minDistancia = _calcularDistancia(punto, puntos[0]);

    for (int i = 1; i < puntos.length; i++) {
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

  /// Calcula distancia entre dos puntos usando Haversine (en km)
  double _calcularDistancia(LatLng p1, LatLng p2) {
    const double radioTierra = 6371.0; // km

    double dLat = _gradosARadianes(p2.latitude - p1.latitude);
    double dLon = _gradosARadianes(p2.longitude - p1.longitude);

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_gradosARadianes(p1.latitude)) *
            cos(_gradosARadianes(p2.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return radioTierra * c;
  }

  double _gradosARadianes(double grados) {
    return grados * pi / 180.0;
  }

  /// Calcula la distancia total de una secuencia de puntos
  double _calcularDistanciaTotal(List<LatLng> puntos) {
    if (puntos.length < 2) return 0.0;

    double distancia = 0.0;
    for (int i = 0; i < puntos.length - 1; i++) {
      distancia += _calcularDistancia(puntos[i], puntos[i + 1]);
    }
    return distancia;
  }

  /// Extrae el número de línea del nombre (L001 -> 1)
  String _extraerNumeroLinea(String nombre) {
    final match = RegExp(r'L0*(\d+)').firstMatch(nombre);
    return match?.group(1) ?? nombre;
  }
}
