import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

import 'config.dart';
import 'ruta_model.dart';
import 'route_calculator_fast.dart';
import 'widgets/buscar_view.dart';
import 'widgets/planificar_view.dart';

class MapaPage extends StatefulWidget {
  const MapaPage({super.key});

  @override
  _MapaPageState createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  final _posicionInicial = const CameraPosition(
    target: LatLng(-17.7845, -63.1840),
    zoom: 13.5,
  );

  GoogleMapController? controller;

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  int _modoActual = 0;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _destinoController = TextEditingController();

  List<LineaRuta> listadoDeRutas = [];
  List<LineaRuta> _rutasFiltradas = [];
  bool _cargando = true;
  bool _buscandoLugar = false;
  bool _obteniendoUbicacion = false;

  LatLng? _origen;
  LatLng? _destino;
  List<Map<String, dynamic>> _planesDeViaje = [];

  // Para selección manual de puntos
  bool _seleccionandoOrigen = false;
  bool _seleccionandoDestino = false;

  // Control de visibilidad del panel planificador
  bool _panelPlanificadorVisible = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosDeApi();
  }

  // ------------------------------------------------------------------------
  // CARGA DE DATOS
  // ------------------------------------------------------------------------
  Future<void> _cargarDatosDeApi() async {
    try {
      // Usar configuración centralizada
      final url = Uri.parse(AppConfig.rutasUrl);

      // Add timeout to prevent infinite loading
      final response = await http
          .get(url)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw Exception(
                'Tiempo de espera agotado. Verifica tu conexión.',
              );
            },
          );

      String jsonResponse;

      if (response.statusCode == 200) {
        jsonResponse = response.body;
      } else {
        throw Exception('Error al cargar API: ${response.statusCode}');
      }

      List<dynamic> dataList = jsonDecode(jsonResponse);
      List<LineaRuta> rutasParseadas =
          dataList.map((json) => LineaRuta.fromJson(json)).toList();

      if (!mounted) return;

      setState(() {
        listadoDeRutas = rutasParseadas;
        _rutasFiltradas = rutasParseadas;
        _cargando = false;
        // Lines will be drawn when map is created
      });
    } catch (e) {
      print("Error cargando rutas: $e");
      if (mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('Tiempo de espera')
                  ? 'Error de conexión. Verifica tu internet.'
                  : 'Error cargando rutas. Intenta de nuevo.',
            ),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Reintentar',
              onPressed: _cargarDatosDeApi,
            ),
          ),
        );
      }
    }
  }

  // ------------------------------------------------------------------------
  // FUNCIONES DE GEOLOCALIZACIÓN Y GEOCODING
  // ------------------------------------------------------------------------

  /// Solicita permisos de ubicación
  Future<bool> _solicitarPermisosUbicacion() async {
    var status = await Permission.location.status;

    if (status.isDenied) {
      status = await Permission.location.request();
    }

    if (status.isPermanentlyDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Los permisos de ubicación están deshabilitados. Habilítalos en Configuración.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
      await openAppSettings();
      return false;
    }

    return status.isGranted;
  }

  /// Obtiene la ubicación actual del dispositivo GPS
  Future<void> _obtenerUbicacionActual() async {
    setState(() => _obteniendoUbicacion = true);

    try {
      // Verificar permisos
      bool permisosConcedidos = await _solicitarPermisosUbicacion();
      if (!permisosConcedidos) {
        setState(() => _obteniendoUbicacion = false);
        return;
      }

      // Verificar si el GPS está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El GPS está desactivado. Por favor actívalo.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        setState(() => _obteniendoUbicacion = false);
        return;
      }

      // Obtener posición actual
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _origen = LatLng(position.latitude, position.longitude);
        _obteniendoUbicacion = false;
        _actualizarMarcadoresPlanificador();
      });

      // Centrar cámara en la ubicación actual
      if (controller != null) {
        controller!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _origen!, zoom: 15),
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Ubicación actual establecida como origen'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error obteniendo ubicación: $e');
      setState(() => _obteniendoUbicacion = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error obteniendo ubicación: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Busca un lugar por nombre usando geocoding
  Future<void> _buscarLugarPorNombre(String nombreLugar) async {
    if (nombreLugar.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa un nombre de lugar')),
      );
      return;
    }

    setState(() => _buscandoLugar = true);

    try {
      // Buscar con el contexto de Santa Cruz, Bolivia
      List<Location> locations = await locationFromAddress(
        '$nombreLugar, Santa Cruz de la Sierra, Bolivia',
      );

      if (locations.isNotEmpty) {
        Location location = locations.first;
        LatLng coordenadas = LatLng(location.latitude, location.longitude);

        setState(() {
          _destino = coordenadas;
          _buscandoLugar = false;
          _actualizarMarcadoresPlanificador();
        });

        // Centrar cámara en el destino
        if (controller != null) {
          controller!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: coordenadas, zoom: 15),
            ),
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Destino encontrado: $nombreLugar'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() => _buscandoLugar = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se encontró el lugar. Intenta con otro nombre.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error buscando lugar: $e');
      setState(() => _buscandoLugar = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error buscando el lugar. Verifica el nombre e intenta de nuevo.',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Maneja la selección de un lugar desde el campo de búsqueda
  void _onPlaceSelected(String place, double lat, double lng) {
    setState(() {
      _destino = LatLng(lat, lng);
      _buscandoLugar = false;
      _planesDeViaje.clear(); // Limpiar resultados anteriores
      _actualizarMarcadoresPlanificador();
    });

    // Centrar cámara en el destino
    if (controller != null) {
      controller!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(lat, lng), zoom: 15),
        ),
      );
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Destino: ${place.split(',').first}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ------------------------------------------------------------------------
  // DIBUJADO DEL MAPA
  // ------------------------------------------------------------------------
  void _dibujarTodasLasLineas({int? idResaltado, List<int>? idsResaltados}) {
    Set<Polyline> nuevasLineas = {};

    // Show all lines now that backend returns only 20 routes (manageable)
    for (var ruta in listadoDeRutas) {
      bool esLaSeleccionada = (idResaltado == ruta.id);
      bool esParteDePlan = (idsResaltados?.contains(ruta.id) ?? false);
      bool modoNormal = (idResaltado == null && idsResaltados == null);

      nuevasLineas.add(
        Polyline(
          polylineId: PolylineId(ruta.id.toString()),
          points: ruta.puntos,
          color:
              modoNormal
                  ? ruta.color.withOpacity(0.6)
                  : (esLaSeleccionada || esParteDePlan)
                  ? ruta.color.withOpacity(0.95)
                  : ruta.color.withOpacity(0.15),
          width: (esLaSeleccionada || esParteDePlan) ? 7 : 3,
          zIndex: (esLaSeleccionada || esParteDePlan) ? 10 : 0,
          jointType: JointType.round,
          onTap: () {
            _seleccionarLineaDesdeMapa(ruta);
          },
        ),
      );
    }

    if (mounted) {
      setState(() {
        _polylines = nuevasLineas;
      });
    }
  }

  void _seleccionarLineaDesdeMapa(LineaRuta ruta) {
    setState(() {
      _modoActual = 1;
      _mostrarRutaSeleccionada(ruta);
    });
  }

  void _mostrarRutaSeleccionada(
    LineaRuta ruta, {
    bool mantenerMarcadores = false,
  }) {
    _dibujarTodasLasLineas(idResaltado: ruta.id);

    if (!mantenerMarcadores) {
      setState(() {
        _markers.clear();
        if (ruta.puntos.isNotEmpty) {
          _markers.add(
            Marker(
              markerId: const MarkerId("inicio"),
              position: ruta.puntoInicio,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueGreen,
              ),
              infoWindow: InfoWindow(
                title: "Partida - ${ruta.nombre}",
                snippet: ruta.descripcion,
              ),
            ),
          );

          _markers.add(
            Marker(
              markerId: const MarkerId("fin"),
              position: ruta.puntoFin,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
              infoWindow: InfoWindow(
                title: "Llegada - ${ruta.nombre}",
                snippet: ruta.descripcion,
              ),
            ),
          );
          _ajustarCamaraAPuntos(ruta.puntos);
        }

        _rutasFiltradas = [];
        _searchController.text = ruta.nombre;
      });
    }
  }

  void _filtrarRutas(String query) {
    setState(() {
      if (query.isEmpty) {
        _rutasFiltradas = listadoDeRutas;
      } else {
        _rutasFiltradas =
            listadoDeRutas
                .where(
                  (r) =>
                      r.nombre.toLowerCase().contains(query.toLowerCase()) ||
                      r.descripcion.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
      }
    });
  }

  // ------------------------------------------------------------------------
  // MODO PLANIFICADOR
  // ------------------------------------------------------------------------
  void _activarModoPlanificador() {
    setState(() {
      _modoActual = 2;
      _planesDeViaje.clear();
      _markers.clear();
      _dibujarTodasLasLineas(idResaltado: null);
      // No establecer origen/destino por defecto, el usuario los configurará
      _origen = null;
      _destino = null;
      _seleccionandoOrigen = false;
      _seleccionandoDestino = false;
      _destinoController.clear();
      _panelPlanificadorVisible = true; // Mostrar panel al activar modo
    });
  }

  void _actualizarMarcadoresPlanificador() {
    Set<Marker> nuevosMarcadores = {};
    if (_origen != null) {
      nuevosMarcadores.add(
        Marker(
          markerId: const MarkerId("origen"),
          position: _origen!,
          draggable: true,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: "🟢 Origen (Arrástralo)"),
          onDragEnd: (newPos) {
            setState(() {
              _origen = newPos;
              _planesDeViaje.clear(); // Limpiar resultados al mover
            });
          },
        ),
      );
    }
    if (_destino != null) {
      nuevosMarcadores.add(
        Marker(
          markerId: const MarkerId("destino"),
          position: _destino!,
          draggable: true,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: "🔴 Destino (Arrástralo)"),
          onDragEnd: (newPos) {
            setState(() {
              _destino = newPos;
              _planesDeViaje.clear(); // Limpiar resultados al mover
            });
          },
        ),
      );
    }
    setState(() {
      _markers = nuevosMarcadores;
    });
  }

  /// Maneja clics en el mapa para seleccionar origen o destino
  void _onMapTap(LatLng position) {
    if (_modoActual != 2) return; // Solo en modo planificador

    if (_seleccionandoOrigen) {
      setState(() {
        _origen = position;
        _seleccionandoOrigen = false;
        _planesDeViaje.clear();
        _actualizarMarcadoresPlanificador();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Origen establecido'),
          duration: Duration(seconds: 1),
        ),
      );
    } else if (_seleccionandoDestino) {
      setState(() {
        _destino = position;
        _seleccionandoDestino = false;
        _planesDeViaje.clear();
        _actualizarMarcadoresPlanificador();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Destino establecido'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // ------------------------------------------------------------------------
  // ALGORITMO DE PLANIFICACIÓN ÓPTIMA DE RUTAS
  // ------------------------------------------------------------------------
  void _calcularViaje() {
    if (_origen == null || _destino == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor establece origen y destino')),
      );
      return;
    }

    // Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => WillPopScope(
            onWillPop: () async => false,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Calculando rutas óptimas...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );

    // Ejecutar cálculo después de mostrar el diálogo
    Future.delayed(const Duration(milliseconds: 100), () {
      try {
        print('⚡ Iniciando cálculo con FastRouteCalculator...');
        final calculador = FastRouteCalculator(listadoDeRutas);
        final resultados = calculador.calcularRutas(
          origen: _origen!,
          destino: _destino!,
          maxResultados: 5,
        );
        print('⚡ Cálculo completado: ${resultados.length} resultados');

        // Cerrar diálogo de carga
        Navigator.of(context, rootNavigator: true).pop();

        if (resultados.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No se encontraron rutas'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }

        // Guardar resultados y mostrar modal
        setState(() {
          _planesDeViaje = resultados;
        });

        // Mostrar modal con todas las rutas
        _mostrarModalRutas(resultados);
      } catch (e) {
        print('❌ Error: $e');
        // Cerrar diálogo de carga
        Navigator.of(context, rootNavigator: true).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    });
  }

  void _mostrarModalRutas(List<Map<String, dynamic>> rutas) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder:
                (context, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle del modal
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Título
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.route, color: Colors.deepPurple),
                            const SizedBox(width: 8),
                            Text(
                              '${rutas.length} Rutas Encontradas',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Lista de rutas
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: rutas.length,
                          itemBuilder: (context, index) {
                            final ruta = rutas[index];
                            return _buildRutaCard(ruta, index);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  Widget _buildRutaCard(Map<String, dynamic> ruta, int index) {
    int transbordos = ruta['transbordos'] ?? 0;
    int tiempo = ruta['tiempo'] ?? 0;
    double distancia = ruta['distancia'] ?? 0.0;
    String detalles = ruta['detalles'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título con número de opción
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: index == 0 ? Colors.green : Colors.deepPurple,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    index == 0 ? '⭐ MEJOR OPCIÓN' : 'Opción ${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Información principal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoChip(Icons.access_time, '$tiempo min', Colors.blue),
                _buildInfoChip(
                  Icons.route,
                  '${distancia.toStringAsFixed(1)} km',
                  Colors.orange,
                ),
                _buildInfoChip(
                  Icons.swap_horiz,
                  '$transbordos',
                  transbordos == 0 ? Colors.green : Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // Detalles de la ruta
            Text(detalles, style: const TextStyle(fontSize: 14, height: 1.5)),

            const SizedBox(height: 16),

            // Botón para ver en el mapa
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _panelPlanificadorVisible = false; // Solo ocultar el panel
                  });
                  _mostrarPlanEnMapa(ruta);
                },
                icon: const Icon(Icons.map),
                label: const Text('Ver Ruta en el Mapa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _mostrarPlanEnMapa(Map<String, dynamic> plan) {
    List<LineaRuta> rutasDelPlan = List<LineaRuta>.from(plan['rutas']);
    List<int> idsRutas = rutasDelPlan.map((r) => r.id).toList();

    _dibujarTodasLasLineas(idsResaltados: idsRutas);

    Set<Marker> nuevosMarcadores = {};

    // Marcador de origen
    nuevosMarcadores.add(
      Marker(
        markerId: const MarkerId("origen"),
        position: _origen!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: "🟢 Origen"),
      ),
    );

    // Marcador de destino
    nuevosMarcadores.add(
      Marker(
        markerId: const MarkerId("destino"),
        position: _destino!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: "🔴 Destino"),
      ),
    );

    // Marcadores de transbordo
    if (plan['tipo'] == "1 TRANSBORDO" && plan['puntoTransbordo'] != null) {
      nuevosMarcadores.add(
        Marker(
          markerId: const MarkerId("transbordo1"),
          position: plan['puntoTransbordo'],
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: "🔄 Transbordo",
            snippet:
                "Cambiar de ${rutasDelPlan[0].nombre} a ${rutasDelPlan[1].nombre}",
          ),
        ),
      );
    }

    setState(() {
      _markers = nuevosMarcadores;
    });

    // Ajustar cámara para mostrar toda la ruta
    List<LatLng> todosPuntos = [_origen!, _destino!];
    for (var ruta in rutasDelPlan) {
      todosPuntos.addAll(ruta.puntos);
    }
    _ajustarCamaraAPuntos(todosPuntos);
  }

  // ------------------------------------------------------------------------
  // FUNCIONES AUXILIARES
  // ------------------------------------------------------------------------
  void _resetearMapa() {
    setState(() {
      _modoActual = 0;
      _markers.clear();
      _planesDeViaje.clear();
      _searchController.clear();
      _rutasFiltradas = listadoDeRutas;
      _dibujarTodasLasLineas(idResaltado: null);
      controller?.animateCamera(
        CameraUpdate.newCameraPosition(_posicionInicial),
      );
    });
  }

  void _ajustarCamaraAPuntos(List<LatLng> puntos) {
    if (puntos.isEmpty || controller == null) return;
    double minLat = puntos.first.latitude;
    double maxLat = puntos.first.latitude;
    double minLng = puntos.first.longitude;
    double maxLng = puntos.first.longitude;

    for (var p in puntos) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    controller!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat - 0.005, minLng - 0.005),
          northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
        ),
        50,
      ),
    );
  }

  // ------------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _cargando
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(),
                    SizedBox(height: 20),
                    Text(
                      'Cargando mapa de rutas...',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Esto puede tomar unos segundos',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              )
              : Stack(
                children: [
                  // 1. MAPA
                  GoogleMap(
                    initialCameraPosition: _posicionInicial,
                    onMapCreated: (c) {
                      controller = c;
                      // Draw lines after map is ready
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (mounted) _dibujarTodasLasLineas(idResaltado: null);
                      });
                    },
                    onTap: _onMapTap,
                    polylines: _polylines,
                    markers: _markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    // Performance optimizations
                    liteModeEnabled: false,
                    tiltGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    buildingsEnabled: false,
                    trafficEnabled: false,
                  ),

                  // 2. PANELES SUPERIORES SEGÚN MODO
                  if (_modoActual == 1) ...[
                    Positioned(
                      top: 10,
                      left: 0,
                      right: 0,
                      child: BuscarView(
                        searchController: _searchController,
                        rutasFiltradas: _rutasFiltradas,
                        onSearchChanged: _filtrarRutas,
                        onRutaSelected: _mostrarRutaSeleccionada,
                      ),
                    ),
                  ],

                  if (_modoActual == 2)
                    PlanificarView(
                      panelVisible: _panelPlanificadorVisible,
                      obteniendoUbicacion: _obteniendoUbicacion,
                      buscandoLugar: _buscandoLugar,
                      seleccionandoOrigen: _seleccionandoOrigen,
                      seleccionandoDestino: _seleccionandoDestino,
                      origen: _origen,
                      destino: _destino,
                      destinoController: _destinoController,
                      planesDeViaje: _planesDeViaje,
                      onObtenerUbicacion: _obtenerUbicacionActual,
                      onMarcarOrigen: () {
                        setState(() {
                          _seleccionandoOrigen = !_seleccionandoOrigen;
                          _seleccionandoDestino = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _seleccionandoOrigen
                                  ? 'Toca el mapa para marcar el origen'
                                  : 'Selección cancelada',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      onMarcarDestino: () {
                        setState(() {
                          _seleccionandoDestino = !_seleccionandoDestino;
                          _seleccionandoOrigen = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _seleccionandoDestino
                                  ? 'Toca el mapa para marcar el destino'
                                  : 'Selección cancelada',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      onBuscarDestino: _buscarLugarPorNombre,
                      onPlaceSelected: _onPlaceSelected,
                      onCalcularViaje: _calcularViaje,
                      onTogglePanel: () {
                        setState(() {
                          _panelPlanificadorVisible =
                              !_panelPlanificadorVisible;
                        });
                      },
                      onLimpiarResultados: () {
                        setState(() {
                          _planesDeViaje.clear();
                          _dibujarTodasLasLineas(idResaltado: null);
                        });
                      },
                      onMostrarPlanEnMapa: _mostrarPlanEnMapa,
                    ),

                  // 4. BOTONES INFERIORES
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 15,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(blurRadius: 10, color: Colors.black26),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _botonInferior(
                            icon: Icons.explore,
                            label: "Explorar",
                            activo: _modoActual == 0,
                            onTap: _resetearMapa,
                          ),
                          _botonInferior(
                            icon: Icons.search,
                            label: "Buscar",
                            activo: _modoActual == 1,
                            onTap: () {
                              setState(() {
                                _modoActual = 1;
                                _planesDeViaje.clear();
                                _markers.clear();
                                _dibujarTodasLasLineas(idResaltado: null);
                                _rutasFiltradas = listadoDeRutas;
                              });
                            },
                          ),
                          _botonInferior(
                            icon: Icons.directions,
                            label: "Planificar",
                            activo: _modoActual == 2,
                            onTap: _activarModoPlanificador,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  // ------------------------------------------------------------------------
  // WIDGETS AUXILIARES
  // ------------------------------------------------------------------------
  Widget _botonInferior({
    required IconData icon,
    required String label,
    required bool activo,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: activo ? Colors.deepPurple : Colors.grey, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: activo ? Colors.deepPurple : Colors.grey,
              fontSize: 12,
              fontWeight: activo ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
