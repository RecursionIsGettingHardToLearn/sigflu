/// Configuración centralizada de la aplicación
class AppConfig {
  // URL base del backend en Railway
  static const String apiBaseUrl = 'https://microbk-production.up.railway.app';

  // Endpoints
  static const String rutasEndpoint = '/lineas/api/rutas/';

  // Configuración del mapa
  static const String googleMapsApiKey =
      'AIzaSyD-ekGivTaa8tUZLt9DfDgjimAsao7HUhU';

  // Configuración de rutas
  static const double velocidadPromedioKmH = 25.0; // km/h en ciudad
  static const int tiempoPorTransbordoMinutos = 5; // minutos de espera
  static const double distanciaMaximaCaminataKm =
      0.8; // 800 metros máximo (más flexible)
  static const double distanciaMaximaTransbordoKm =
      0.5; // 500 metros máximo (más flexible)

  // Configuración de búsqueda - AUMENTADO para encontrar TODAS las rutas cercanas
  static const int maxResultadosRutas = 20; // Más opciones de rutas
  static const int maxRutasOrigen =
      20; // Analizar TODAS las rutas cercanas al origen
  static const int maxRutasDestino =
      20; // Analizar TODAS las rutas cercanas al destino
  static const int maxPuntosTransbordo =
      10; // Más puntos de transbordo para mejor cobertura

  // Configuración de voz
  static const String localeVoz = 'es_ES';
  static const int tiempoEscuchaSegundos = 10;
  static const int tiempoPausaSegundos = 3;

  /// Obtiene la URL completa para el endpoint de rutas
  static String get rutasUrl => '$apiBaseUrl$rutasEndpoint';

  /// Calcula el tiempo estimado de viaje en minutos
  static int calcularTiempoViaje(double distanciaKm, int transbordos) {
    int tiempoViaje = ((distanciaKm / velocidadPromedioKmH) * 60).ceil();
    int tiempoTransbordos = transbordos * tiempoPorTransbordoMinutos;
    return tiempoViaje + tiempoTransbordos;
  }

  /// Verifica si una distancia de caminata es aceptable
  static bool esCaminataAceptable(double distanciaKm) {
    return distanciaKm <= distanciaMaximaCaminataKm;
  }

  /// Verifica si una distancia de transbordo es aceptable
  static bool esTransbordoAceptable(double distanciaKm) {
    return distanciaKm <= distanciaMaximaTransbordoKm;
  }

  /// Calcula el costo de una ruta (menor es mejor)
  /// Prioridad: 1. Distancia caminata (DEBE estar cerca) > 2. Transbordos > 3. Tiempo
  static double calcularCostoRuta({
    required int tiempoMinutos,
    required int transbordos,
    required double distanciaCaminataKm,
  }) {
    // CRÍTICO: La ruta DEBE pasar cerca del origen y destino
    // Penalizar FUERTEMENTE si hay que caminar mucho
    const pesoCaminata = 10000.0; // MÁS IMPORTANTE: minimizar caminata
    const pesoTransbordo = 800.0; // Segundo: evitar muchos transbordos
    const pesoTiempo = 50.0; // Tercero: tiempo de viaje

    return (distanciaCaminataKm * pesoCaminata) +
        (transbordos * pesoTransbordo) +
        (tiempoMinutos * pesoTiempo);
  }
}
