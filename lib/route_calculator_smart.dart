import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'ruta_model.dart';
import 'config.dart';

/// Calculador de rutas INTELIGENTE con análisis de intersecciones
/// - Considera dirección de rutas (IDA/RETORNO)
/// - Analiza intersecciones entre líneas
/// - Evalúa si conviene trasbordar en cada intersección
/// - Genera marcadores visuales para transbordos
class SmartRouteCalculator {
  final List<LineaRuta> todasLasRutas;
  final Map<String, double> _cacheDistancias = {};

  SmartRouteCalculator(this.todasLasRutas);

  /// Calcula las mejores rutas considerando TODAS las posibilidades
  List<Map<String, dynamic>> calcularRutas({
    required LatLng origen,
    required LatLng destino,
    int maxResultados = 15,
  }) {
    print('🧠 INICIO CÁLCULO INTELIGENTE');
    final stopwatch = Stopwatch()..start();

    List<Map<String, dynamic>> resultados = [];

    // 1. RUTAS DIRECTAS (sin transbordos)
    print('📍 Analizando rutas directas...');
    _analizarRutasDirectas(origen, destino, resultados);
    print('   ✅ ${resultados.length} rutas directas encontradas');

    // Identificar la mejor ruta inicial (la más cercana al origen)
    int? mejorRutaInicialId;
    if (resultados.isNotEmpty) {
      resultados.sort((a, b) {
        double distA = (a['distanciaCaminataOrigen'] ?? 999.0) as double;
        double distB = (b['distanciaCaminataOrigen'] ?? 999.0) as double;
        return distA.compareTo(distB);
      });
      var mejorRuta = resultados.first['rutas'][0] as LineaRuta;
      mejorRutaInicialId = mejorRuta.id;
      print(
        '   🌟 Mejor ruta inicial identificada: ${_extraerNumeroLinea(mejorRuta.nombre)}',
      );
    }

    // 2. RUTAS CON TRANSBORDOS (analizar intersecciones)
    print('📍 Analizando rutas con transbordos en intersecciones...');
    _analizarRutasConTransbordos(
      origen,
      destino,
      resultados,
      mejorRutaInicial: mejorRutaInicialId,
    );
    print('   ✅ ${resultados.length} rutas totales encontradas');

    // 3. Ordenar por eficiencia (PRIORIDAD: distancia caminata mínima)
    print('\n🔢 Calculando costos y ordenando rutas...');
    for (int i = 0; i < resultados.length && i < 5; i++) {
      var ruta = resultados[i];
      double costo = _calcularCostoRuta(ruta);
      int transbordos = ruta['transbordos'] ?? 0;
      print(
        '   Ruta ${i + 1}: transbordos=$transbordos, costo=${costo.toStringAsFixed(0)}',
      );
    }

    resultados.sort((a, b) {
      double costoA = _calcularCostoRuta(a);
      double costoB = _calcularCostoRuta(b);
      return costoA.compareTo(costoB);
    });

    print('\n📊 DESPUÉS DE ORDENAR:');
    for (int i = 0; i < resultados.length && i < 5; i++) {
      var ruta = resultados[i];
      double costo = _calcularCostoRuta(ruta);
      double distOrigen = ruta['distanciaCaminataOrigen'] ?? 0.0;
      double distDestino = ruta['distanciaCaminataDestino'] ?? 0.0;
      int transbordos = ruta['transbordos'] ?? 0;
      print(
        '   ${i + 1}° MEJOR: origen=${distOrigen.toStringAsFixed(3)}km, destino=${distDestino.toStringAsFixed(3)}km, transbordos=$transbordos, costo=${costo.toStringAsFixed(0)}',
      );
    }

    stopwatch.stop();

    // Determinar cuántas opciones válidas tenemos
    int rutasEncontradas = resultados.length;

    print(
      '\n✅ CÁLCULO COMPLETO: $rutasEncontradas rutas válidas encontradas en ${stopwatch.elapsedMilliseconds}ms',
    ); // NO forzar un número específico, retornar lo que se encontró
    // Si hay pocas rutas, mostrar solo esas. Si hay muchas, limitar a maxResultados
    if (rutasEncontradas > maxResultados) {
      print('   ℹ️  Limitando a las $maxResultados mejores opciones');
      return resultados.take(maxResultados).toList();
    } else {
      print(
        '   ℹ️  Mostrando todas las $rutasEncontradas opciones disponibles',
      );
      return resultados; // Retornar TODAS las rutas encontradas
    }
  }

  /// Analiza rutas directas (sin transbordos)
  void _analizarRutasDirectas(
    LatLng origen,
    LatLng destino,
    List<Map<String, dynamic>> resultados,
  ) {
    print('\n🔍 PASO 1: Analizando ${todasLasRutas.length} rutas directas...');
    print(
      '   📍 Origen: (${origen.latitude.toStringAsFixed(6)}, ${origen.longitude.toStringAsFixed(6)})',
    );
    print(
      '   📍 Destino: (${destino.latitude.toStringAsFixed(6)}, ${destino.longitude.toStringAsFixed(6)})',
    );
    print('   ⚖️  Máximo caminata: ${AppConfig.distanciaMaximaCaminataKm}km\n');

    for (var ruta in todasLasRutas) {
      // Buscar el punto MÁS CERCANO al origen en TODA la ruta
      var infoOrigen = _encontrarPuntoMasCercano(origen, ruta.puntos);
      // Buscar el punto MÁS CERCANO al destino en TODA la ruta
      var infoDestino = _encontrarPuntoMasCercano(destino, ruta.puntos);

      int indiceOrigen = infoOrigen['indice'];
      int indiceDestino = infoDestino['indice'];
      double distOrigen = infoOrigen['distancia'];
      double distDestino = infoDestino['distancia'];

      String numeroLinea = _extraerNumeroLinea(ruta.nombre);
      print('   🚌 Línea $numeroLinea (${ruta.nombre}):');
      print(
        '      • Punto más cercano al ORIGEN: índice $indiceOrigen, dist=${distOrigen.toStringAsFixed(3)}km',
      );
      print(
        '      • Punto más cercano al DESTINO: índice $indiceDestino, dist=${distDestino.toStringAsFixed(3)}km',
      );

      // Verificar que el origen esté CERCA de la ruta (no importa si es inicio o fin)
      if (!AppConfig.esCaminataAceptable(distOrigen)) {
        print(
          '      ❌ RECHAZADA: origen muy lejos (${distOrigen.toStringAsFixed(3)}km > ${AppConfig.distanciaMaximaCaminataKm}km)\n',
        );
        continue;
      }

      // Verificar que el destino esté CERCA de la ruta
      if (!AppConfig.esCaminataAceptable(distDestino)) {
        print(
          '      ⚠️  Origen CERCA, destino LEJOS (${distDestino.toStringAsFixed(3)}km > ${AppConfig.distanciaMaximaCaminataKm}km)',
        );
        print('      → Esta ruta será considerada para TRANSBORDOS\n');
        continue;
      }

      // Verificar que haya un trayecto (índices diferentes)
      if (indiceDestino == indiceOrigen) {
        print('      ❌ Rechazada: mismo punto (origen=destino)\n');
        continue;
      }

      // VALIDAR DIRECCIÓN: Verificar que la ruta vaya en el sentido correcto
      String direccionTrayecto = ruta.detectarDireccionTrayecto(
        indiceOrigen,
        indiceDestino,
      );

      // Si la ruta tiene dirección específica (IDA o RETORNO), validar
      if (ruta.direccion != 'BIDIRECCIONAL') {
        if (!ruta.esDireccionValida(indiceOrigen, indiceDestino)) {
          print(
            '      ❌ Rechazada: dirección incorrecta (ruta es ${ruta.direccion}, trayecto sería $direccionTrayecto)\n',
          );
          continue;
        }
      }

      print('      ✅ ACEPTADA como ruta DIRECTA!\n');

      // Extraer el segmento de la ruta que va del punto más cercano al origen
      // hasta el punto más cercano al destino (en cualquier dirección)
      List<LatLng> segmento = ruta.puntos.sublist(
        min(indiceOrigen, indiceDestino),
        max(indiceOrigen, indiceDestino) + 1,
      );
      double distanciaEnRuta = _calcularDistanciaTotal(segmento);
      int tiempo = AppConfig.calcularTiempoViaje(distanciaEnRuta, 0);

      String direccion = ruta.detectarDireccionTrayecto(
        indiceOrigen,
        indiceDestino,
      );

      resultados.add({
        'tipo': 'DIRECTO',
        'rutas': [ruta],
        'tiempo': tiempo,
        'transbordos': 0,
        'descripcion': 'Sin transbordos',
        'detalles': '🚌 Línea $numeroLinea ($direccion)\n${ruta.descripcion}',
        'distancia': distanciaEnRuta,
        'distanciaTotal': distOrigen + distDestino,
        'distanciaCaminataOrigen': distOrigen,
        'distanciaCaminataDestino': distDestino,
        'segmentos': [
          {
            'puntos': segmento,
            'ruta': ruta,
            'color': ruta.color,
            'nombreLinea': numeroLinea,
            'direccion': direccion,
          },
        ],
        'puntosTransbordo': [], // Sin transbordos
      });
    }
  }

  /// Analiza rutas con transbordos buscando intersecciones reales entre líneas
  /// ESTRATEGIA: Primero usa las rutas MÁS CERCANAS al origen, luego busca alternativas
  void _analizarRutasConTransbordos(
    LatLng origen,
    LatLng destino,
    List<Map<String, dynamic>> resultados, {
    int? mejorRutaInicial,
  }) {
    print('\n🔍 PASO 2: Analizando rutas con transbordos...\n');

    int combinacionesAnalizadas = 0;
    int interseccionesEncontradas = 0;

    // Set para evitar combinaciones duplicadas de líneas
    // Formato: "idRuta1-idRuta2" para identificar combinaciones únicas
    Set<String> combinacionesUsadas = {};

    // PASO 1: Identificar y ORDENAR rutas por cercanía al origen
    List<Map<String, dynamic>> rutasOrigen = [];
    for (var ruta in todasLasRutas) {
      var infoOrigen = _encontrarPuntoMasCercano(origen, ruta.puntos);
      double distOrigen = infoOrigen['distancia'];

      if (AppConfig.esCaminataAceptable(distOrigen)) {
        rutasOrigen.add({
          'ruta': ruta,
          'infoOrigen': infoOrigen,
          'distOrigen': distOrigen,
        });
      }
    }

    // ORDENAR: Primero la mejor ruta inicial, luego por distancia al origen
    rutasOrigen.sort((a, b) {
      var rutaA = a['ruta'] as LineaRuta;
      var rutaB = b['ruta'] as LineaRuta;

      // Si tenemos una mejor ruta inicial identificada, darle MÁXIMA prioridad
      if (mejorRutaInicial != null) {
        if (rutaA.id == mejorRutaInicial && rutaB.id != mejorRutaInicial)
          return -1;
        if (rutaB.id == mejorRutaInicial && rutaA.id != mejorRutaInicial)
          return 1;
      }

      // Luego ordenar por distancia al origen
      return (a['distOrigen'] as double).compareTo(b['distOrigen'] as double);
    });

    print(
      '   ✓ ${rutasOrigen.length} rutas cercanas al origen (ordenadas: óptima primero)\n',
    );

    // PASO 2: Para cada ruta (empezando por la ÓPTIMA, luego por cercanía)
    for (var rutaOrigenData in rutasOrigen) {
      var rutaOrigen = rutaOrigenData['ruta'] as LineaRuta;
      bool esRutaOptima =
          mejorRutaInicial != null && rutaOrigen.id == mejorRutaInicial;
      var infoOrigen = rutaOrigenData['infoOrigen'] as Map<String, dynamic>;
      double distOrigen = rutaOrigenData['distOrigen'] as double;
      int indiceOrigen = infoOrigen['indice'];

      String numeroOrigen = _extraerNumeroLinea(rutaOrigen.nombre);
      String marcador = esRutaOptima ? '⭐' : '🚌';
      String extra = esRutaOptima ? ' (RUTA ÓPTIMA - prioridad máxima)' : '';
      print(
        '   $marcador Línea $numeroOrigen: origen a ${distOrigen.toStringAsFixed(3)}km (punto $indiceOrigen)$extra',
      );

      // Para cada ruta que pase cerca del destino (distinta a la primera)
      for (var rutaDestino in todasLasRutas) {
        // NO permitir transbordo a la misma ruta (mismo id)
        if (rutaDestino.id == rutaOrigen.id) continue;

        // IMPORTANTE: Extraer número de línea para comparar
        String numOrigen = _extraerNumeroLinea(rutaOrigen.nombre);
        String numDestino = _extraerNumeroLinea(rutaDestino.nombre);

        // NO permitir transbordo entre IDA y RETORNO de la MISMA línea
        // Ejemplo: NO permitir L016 (IDA) → L016 (RETORNO)
        if (numOrigen == numDestino &&
            rutaOrigen.direccion != rutaDestino.direccion) {
          continue; // Mismo número de línea pero diferente dirección = INVÁLIDO
        }

        // Buscar punto MÁS CERCANO al destino en esta ruta
        var infoDestino = _encontrarPuntoMasCercano(
          destino,
          rutaDestino.puntos,
        );
        int indiceDestino = infoDestino['indice'];
        double distDestino = infoDestino['distancia'];

        // Si el destino está muy lejos de esta ruta, descartarla
        if (!AppConfig.esCaminataAceptable(distDestino)) continue;

        combinacionesAnalizadas++;

        // Buscar INTERSECCIONES entre rutaOrigen y rutaDestino
        // IMPORTANTE: Buscar desde el punto cercano al origen, no desde el inicio
        List<Map<String, dynamic>> intersecciones = _encontrarIntersecciones(
          rutaOrigen,
          rutaDestino,
          indiceOrigen, // Empezar desde donde está el origen
        );

        if (intersecciones.isEmpty) {
          print('      ⊗ No hay intersecciones con Línea $numDestino');
          continue;
        }

        interseccionesEncontradas += intersecciones.length;
        print(
          '      ✓ Intersecciones con Línea $numDestino: ${intersecciones.length}',
        );

        // Verificar si esta combinación de líneas ya fue usada
        String combinacionKey = '${rutaOrigen.id}-${rutaDestino.id}';
        if (combinacionesUsadas.contains(combinacionKey)) {
          print(
            '      ⚠️  Combinación $numOrigen→$numDestino ya existe, omitiendo...',
          );
          continue;
        }

        // Para cada intersección encontrada, evaluar si conviene trasbordar
        // SOLO usar la PRIMERA intersección válida para evitar duplicados
        bool combinacionAgregada = false;
        for (var interseccion in intersecciones) {
          if (combinacionAgregada)
            break; // Solo una ruta por combinación de líneas

          int idxOrigen1 = indiceOrigen; // Punto cercano al origen
          int idxOrigen2 =
              interseccion['indiceRuta1']; // Punto de transbordo en ruta 1
          int idxDestino1 =
              interseccion['indiceRuta2']; // Punto de transbordo en ruta 2
          int idxDestino2 = indiceDestino; // Punto cercano al destino

          // VALIDAR DIRECCIÓN de ambos segmentos
          // Segmento 1: desde origen hasta transbordo en ruta1
          if (rutaOrigen.direccion != 'BIDIRECCIONAL') {
            if (!rutaOrigen.esDireccionValida(idxOrigen1, idxOrigen2)) {
              continue; // Dirección incorrecta en primer segmento
            }
          }

          // Segmento 2: desde transbordo hasta destino en ruta2
          if (rutaDestino.direccion != 'BIDIRECCIONAL') {
            if (!rutaDestino.esDireccionValida(idxDestino1, idxDestino2)) {
              continue; // Dirección incorrecta en segundo segmento
            }
          }

          // Verificar que el transbordo tenga sentido (no trasbordar antes de subir)
          // Si indiceOrigen > intersección, significa que el transbordo está ANTES del origen
          int distanciaOrigenATransbordo = (idxOrigen2 - idxOrigen1).abs();
          int distanciaTransbordoADestino = (idxDestino2 - idxDestino1).abs();

          // El transbordo debe estar DESPUÉS del punto de origen y ANTES del destino
          if (distanciaOrigenATransbordo < 3)
            continue; // Muy cerca, no vale la pena
          if (distanciaTransbordoADestino < 3)
            continue; // Muy cerca del destino

          // Calcular si esta combinación es eficiente
          var resultado = _construirRutaConTransbordo(
            origen,
            destino,
            rutaOrigen,
            rutaDestino,
            idxOrigen1,
            idxOrigen2,
            idxDestino1,
            idxDestino2,
            distOrigen,
            distDestino,
            interseccion['distancia'],
            interseccion['puntoInterseccion'],
            esRutaOptima: esRutaOptima,
          );

          if (resultado != null) {
            resultados.add(resultado);
            combinacionesUsadas.add(combinacionKey); // Marcar como usada
            combinacionAgregada =
                true; // Marcar que ya agregamos esta combinación
            print('      ✅ Agregada combinación $numOrigen→$numDestino');
            break; // Solo agregar UNA ruta por cada combinación de líneas
          }
        }

        // NO limitar artificialmente - dejar que encuentre todas las válidas
      }
    }

    print('\n   📊 Resumen transbordos:');
    print('      • Rutas cerca del origen: ${rutasOrigen.length}');
    print('      • Combinaciones analizadas: $combinacionesAnalizadas');
    print('      • Intersecciones encontradas: $interseccionesEncontradas');
    print(
      '      • Rutas con transbordo válidas: ${resultados.where((r) => r['transbordos'] == 1).length}\n',
    );

    // BONUS: Rutas con 2 transbordos (si hay pocas opciones)
    if (resultados.length < 5) {
      print('📍 Buscando rutas con 2 transbordos...');
      _analizarRutasCon2Transbordos(origen, destino, resultados);
    }
  }

  /// Encuentra intersecciones reales entre dos rutas
  List<Map<String, dynamic>> _encontrarIntersecciones(
    LineaRuta ruta1,
    LineaRuta ruta2,
    int indiceInicioRuta1,
  ) {
    List<Map<String, dynamic>> intersecciones = [];
    const double distanciaMaximaInterseccion =
        0.5; // 500 metros (más permisivo)

    // Usar configuración para determinar cuántos puntos evaluar
    int step = max(
      3,
      (ruta1.puntos.length - indiceInicioRuta1) ~/
          AppConfig.maxPuntosTransbordo,
    );

    // Recorrer puntos de ruta1 desde el índice de inicio
    for (int i = indiceInicioRuta1; i < ruta1.puntos.length; i += step) {
      LatLng puntoRuta1 = ruta1.puntos[i];

      // Buscar punto más cercano en ruta2
      var infoCercano = _encontrarPuntoMasCercano(puntoRuta1, ruta2.puntos);
      double distancia = infoCercano['distancia'];

      // Si están muy cerca, es una intersección
      if (distancia <= distanciaMaximaInterseccion) {
        intersecciones.add({
          'indiceRuta1': i,
          'indiceRuta2': infoCercano['indice'],
          'puntoInterseccion': puntoRuta1,
          'distancia': distancia,
        });

        // Limitar intersecciones por ruta
        if (intersecciones.length >= 10) break;
      }
    }

    return intersecciones;
  }

  /// Construye una ruta con 1 transbordo
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
    LatLng puntoTransbordo, {
    bool esRutaOptima = false,
  }) {
    // Extraer segmentos
    List<LatLng> seg1 = ruta1.puntos.sublist(
      min(idx1Inicio, idx1Fin),
      max(idx1Inicio, idx1Fin) + 1,
    );
    List<LatLng> seg2 = ruta2.puntos.sublist(
      min(idx2Inicio, idx2Fin),
      max(idx2Inicio, idx2Fin) + 1,
    );

    // Calcular distancias
    double dist1 = _calcularDistanciaTotal(seg1);
    double dist2 = _calcularDistanciaTotal(seg2);
    double distTotal = dist1 + dist2;

    // Calcular tiempo (incluye espera de transbordo)
    int tiempo = AppConfig.calcularTiempoViaje(distTotal, 1);

    String num1 = _extraerNumeroLinea(ruta1.nombre);
    String num2 = _extraerNumeroLinea(ruta2.nombre);
    String dir1 = ruta1.detectarDireccionTrayecto(idx1Inicio, idx1Fin);
    String dir2 = ruta2.detectarDireccionTrayecto(idx2Inicio, idx2Fin);

    return {
      'tipo': '1 TRANSBORDO',
      'rutas': [ruta1, ruta2],
      'tiempo': tiempo,
      'transbordos': 1,
      'descripcion': 'Con 1 transbordo',
      'detalles':
          '🚌 Línea $num1 ($dir1)\n'
          '   ${ruta1.descripcion}\n'
          '🔄 Transbordo en intersección\n'
          '🚌 Línea $num2 ($dir2)\n'
          '   ${ruta2.descripcion}',
      'distancia': distTotal,
      'distanciaTotal': distOrigen + distDestino + distTransbordo,
      'distanciaCaminataOrigen': distOrigen,
      'distanciaCaminataDestino': distDestino,
      'distanciaTransbordo': distTransbordo,
      'usaRutaOptima': esRutaOptima, // Marca si usa la ruta óptima como inicio
      'puntosTransbordo': [
        {
          'punto': puntoTransbordo,
          'desde': '$num1 ($dir1)',
          'hacia': '$num2 ($dir2)',
        },
      ],
      'segmentos': [
        {
          'puntos': seg1,
          'ruta': ruta1,
          'color': ruta1.color,
          'nombreLinea': num1,
          'direccion': dir1,
        },
        {
          'puntos': seg2,
          'ruta': ruta2,
          'color': ruta2.color,
          'nombreLinea': num2,
          'direccion': dir2,
        },
      ],
    };
  }

  /// Analiza rutas con 2 transbordos (solo si hay pocas opciones)
  void _analizarRutasCon2Transbordos(
    LatLng origen,
    LatLng destino,
    List<Map<String, dynamic>> resultados,
  ) {
    // Implementación simplificada: combinar 3 rutas
    int count = 0;

    for (var ruta1 in todasLasRutas) {
      if (count >= 5) break; // Limitar para no demorar

      var infoOrigen = _encontrarPuntoMasCercano(origen, ruta1.puntos);
      if (!AppConfig.esCaminataAceptable(infoOrigen['distancia'])) continue;

      for (var ruta2 in todasLasRutas) {
        if (ruta2.id == ruta1.id) continue;

        var intersecciones1 = _encontrarIntersecciones(
          ruta1,
          ruta2,
          infoOrigen['indice'],
        );
        if (intersecciones1.isEmpty) continue;

        for (var ruta3 in todasLasRutas) {
          if (ruta3.id == ruta1.id || ruta3.id == ruta2.id) continue;

          var infoDestino = _encontrarPuntoMasCercano(destino, ruta3.puntos);
          if (!AppConfig.esCaminataAceptable(infoDestino['distancia']))
            continue;

          var intersecciones2 = _encontrarIntersecciones(
            ruta2,
            ruta3,
            intersecciones1.first['indiceRuta2'],
          );
          if (intersecciones2.isEmpty) continue;

          // Construir ruta con 2 transbordos
          var resultado = _construirRutaCon2Transbordos(
            origen,
            destino,
            ruta1,
            ruta2,
            ruta3,
            infoOrigen,
            intersecciones1.first,
            intersecciones2.first,
            infoDestino,
          );

          if (resultado != null) {
            resultados.add(resultado);
            count++;
            if (count >= 5) return;
          }
        }
      }
    }
  }

  /// Construye una ruta con 2 transbordos
  Map<String, dynamic>? _construirRutaCon2Transbordos(
    LatLng origen,
    LatLng destino,
    LineaRuta ruta1,
    LineaRuta ruta2,
    LineaRuta ruta3,
    Map<String, dynamic> infoOrigen,
    Map<String, dynamic> interseccion1,
    Map<String, dynamic> interseccion2,
    Map<String, dynamic> infoDestino,
  ) {
    int idx1_i = infoOrigen['indice'];
    int idx1_f = interseccion1['indiceRuta1'];
    int idx2_i = interseccion1['indiceRuta2'];
    int idx2_f = interseccion2['indiceRuta1'];
    int idx3_i = interseccion2['indiceRuta2'];
    int idx3_f = infoDestino['indice'];

    // NO validar direcciones - permitir todas las combinaciones

    List<LatLng> seg1 = ruta1.puntos.sublist(
      min(idx1_i, idx1_f),
      max(idx1_i, idx1_f) + 1,
    );
    List<LatLng> seg2 = ruta2.puntos.sublist(
      min(idx2_i, idx2_f),
      max(idx2_i, idx2_f) + 1,
    );
    List<LatLng> seg3 = ruta3.puntos.sublist(
      min(idx3_i, idx3_f),
      max(idx3_i, idx3_f) + 1,
    );

    double dist =
        _calcularDistanciaTotal(seg1) +
        _calcularDistanciaTotal(seg2) +
        _calcularDistanciaTotal(seg3);
    int tiempo = AppConfig.calcularTiempoViaje(dist, 2);

    String num1 = _extraerNumeroLinea(ruta1.nombre);
    String num2 = _extraerNumeroLinea(ruta2.nombre);
    String num3 = _extraerNumeroLinea(ruta3.nombre);

    return {
      'tipo': '2 TRANSBORDOS',
      'rutas': [ruta1, ruta2, ruta3],
      'tiempo': tiempo,
      'transbordos': 2,
      'descripcion': 'Con 2 transbordos',
      'detalles':
          '🚌 Línea $num1\n'
          '🔄 Transbordo\n'
          '🚌 Línea $num2\n'
          '🔄 Transbordo\n'
          '🚌 Línea $num3',
      'distancia': dist,
      'distanciaTotal': infoOrigen['distancia'] + infoDestino['distancia'],
      'puntosTransbordo': [
        {
          'punto': interseccion1['puntoInterseccion'],
          'desde': num1,
          'hacia': num2,
        },
        {
          'punto': interseccion2['puntoInterseccion'],
          'desde': num2,
          'hacia': num3,
        },
      ],
      'segmentos': [
        {
          'puntos': seg1,
          'ruta': ruta1,
          'color': ruta1.color,
          'nombreLinea': num1,
        },
        {
          'puntos': seg2,
          'ruta': ruta2,
          'color': ruta2.color,
          'nombreLinea': num2,
        },
        {
          'puntos': seg3,
          'ruta': ruta3,
          'color': ruta3.color,
          'nombreLinea': num3,
        },
      ],
    };
  }

  /// Calcula el costo total de una ruta (menor = mejor)
  /// PRIORIDAD ABSOLUTA: Rutas directas (sin transbordo) SIEMPRE son mejores
  /// PRIORIDAD 1: Que pase CERCA del origen y destino (distancia caminata mínima)
  /// PRIORIDAD 2: Si tiene transbordo, preferir que use la ruta óptima como inicio
  double _calcularCostoRuta(Map<String, dynamic> ruta) {
    int tiempo = ruta['tiempo'] ?? 0;
    int transbordos = ruta['transbordos'] ?? 0;
    double distanciaCaminata = ruta['distanciaTotal'] ?? 0.0;
    double distOrigen = ruta['distanciaCaminataOrigen'] ?? 0.0;
    double distDestino = ruta['distanciaCaminataDestino'] ?? 0.0;
    bool usaRutaOptima = ruta['usaRutaOptima'] ?? false;

    // PENALIZACIÓN MASIVA para rutas con transbordos (siempre peores que directas)
    // Esto asegura que CUALQUIER ruta directa sea mejor que CUALQUIER ruta con transbordo
    double penalizacionTransbordos =
        transbordos > 0 ? 100000.0 * transbordos : 0.0;

    // PENALIZACIÓN EXTRA si origen o destino están muy lejos
    double penalizacion = 0.0;
    if (distOrigen > 0.5) penalizacion += 50000.0; // Muy lejos del origen
    if (distDestino > 0.5) penalizacion += 50000.0; // Muy lejos del destino

    // BONUS: Si es ruta con transbordo que usa la línea óptima, reducir costo
    double bonus = 0.0;
    if (usaRutaOptima && transbordos > 0) {
      bonus = -2000.0; // Bonus significativo para aparecer antes en la lista
    }

    return AppConfig.calcularCostoRuta(
          tiempoMinutos: tiempo,
          transbordos: transbordos,
          distanciaCaminataKm: distanciaCaminata,
        ) +
        penalizacionTransbordos + // CRÍTICO: Asegurar que directas sean mejores
        penalizacion +
        bonus;
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

  /// Calcula distancia entre dos puntos (Haversine)
  double _calcularDistancia(LatLng p1, LatLng p2) {
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

  double _gradosARadianes(double grados) => grados * pi / 180.0;

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
