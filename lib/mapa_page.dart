import 'dart:convert'; // Necesario para jsonDecode
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http; // DESCOMENTAR PARA API REAL
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Si usas dotenv

import 'ruta_model.dart';

class MapaPage extends StatefulWidget {
  const MapaPage({super.key});

  @override
  _MapaPageState createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  // Configuración inicial del mapa (Santa Cruz)
  final _posicionInicial = const CameraPosition(
    target: LatLng(-17.7845, -63.1840),
    zoom: 13.5,
  );

  GoogleMapController? controller;
  
  // Elementos del mapa
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  // Estado de la UI
  int _modoActual = 0; 
  final TextEditingController _searchController = TextEditingController();
  
  // DATOS: Ahora son dinámicos, inician vacíos
  List<LineaRuta> listadoDeRutas = [];
  List<LineaRuta> _rutasFiltradas = [];
  bool _cargando = true; // Para mostrar indicador de carga
  
  // Para el Planificador
  LatLng? _origen;
  LatLng? _destino;
  List<Map<String, dynamic>> _planesDeViaje = []; 

  @override
  void initState() {
    super.initState();
    // Cargar datos al iniciar
    _cargarDatosDeApi();
  }

  // ------------------------------------------------------------------------
  // LÓGICA DE CARGA DE DATOS (INTEGRACIÓN API)
  // ------------------------------------------------------------------------
Future<void> _cargarDatosDeApi() async {
    try {
      // OPCIÓN B: Petición Real
      final String? baseUrl = dotenv.env['API_BASE_URL'];
      
      // Validación rápida por si falta el .env
      if (baseUrl == null || baseUrl.isEmpty) {
        throw Exception('API_BASE_URL no encontrado en .env');
      }

      final url = Uri.parse('$baseUrl/lineas/api/rutas/'); 
      final response = await http.get(url);
      
      // --- CORRECCIÓN AQUÍ ---
      String jsonResponse; // 1. Declaramos la variable primero

      if (response.statusCode == 200) {
        jsonResponse = response.body; // 2. Asignamos el valor
      } else {
        throw Exception('Error al cargar API: ${response.statusCode}');
      }
      
      // 2. PARSEO DE DATOS
      List<dynamic> dataList = jsonDecode(jsonResponse); // 3. Ahora sí se puede usar

      // Usamos el factory .fromJson
      List<LineaRuta> rutasParseadas = dataList.map((json) => LineaRuta.fromJson(json)).toList();

      if (!mounted) return;

      setState(() {
        listadoDeRutas = rutasParseadas;
        _rutasFiltradas = rutasParseadas;
        _cargando = false;
        
        // Dibujar las líneas recién cargadas
        _dibujarTodasLasLineas(idResaltado: null);
      });

    } catch (e) {
      print("Error cargando rutas: $e");
      if(mounted) {
        setState(() => _cargando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }
  // ------------------------------------------------------------------------
  // LÓGICA DE DIBUJADO (Igual que antes, pero adaptado a la lista dinámica)
  // ------------------------------------------------------------------------

  void _dibujarTodasLasLineas({int? idResaltado}) {
    Set<Polyline> nuevasLineas = {};

    for (var ruta in listadoDeRutas) {
      bool esLaSeleccionada = (idResaltado == ruta.id);
      bool modoNormal = (idResaltado == null);

      nuevasLineas.add(
        Polyline(
          polylineId: PolylineId(ruta.id.toString()),
          points: ruta.puntos,
          color: modoNormal 
              ? ruta.color.withOpacity(0.8) 
              : esLaSeleccionada 
                  ? ruta.color 
                  : ruta.color.withOpacity(0.15), 
          width: esLaSeleccionada ? 7 : 4,
          zIndex: esLaSeleccionada ? 10 : 0,
          jointType: JointType.round,
          onTap: () {
            _seleccionarLineaDesdeMapa(ruta);
          }
        ),
      );
    }

    setState(() {
      _polylines = nuevasLineas;
    });
  }

  void _seleccionarLineaDesdeMapa(LineaRuta ruta) {
    setState(() {
      _modoActual = 1; 
      _mostrarRutaSeleccionada(ruta);
    });
  }

  void _mostrarRutaSeleccionada(LineaRuta ruta) {
    _dibujarTodasLasLineas(idResaltado: ruta.id);

    setState(() {
      _markers.clear();
      if (ruta.puntos.isNotEmpty) {
        _markers.add(Marker(
          markerId: const MarkerId("inicio"),
          position: ruta.puntoInicio,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: "Partida - ${ruta.nombre}", snippet: ruta.descripcion),
        ));

        _markers.add(Marker(
          markerId: const MarkerId("fin"),
          position: ruta.puntoFin,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: "Llegada - ${ruta.nombre}", snippet: ruta.descripcion),
        ));
        _ajustarCamaraAPuntos(ruta.puntos);
      }
      
      _rutasFiltradas = []; 
      _searchController.text = ruta.nombre; 
    });
  }

  void _filtrarRutas(String query) {
    setState(() {
      if (query.isEmpty) {
        _rutasFiltradas = listadoDeRutas;
      } else {
        _rutasFiltradas = listadoDeRutas
            .where((r) => r.nombre.toLowerCase().contains(query.toLowerCase()) || 
                          r.descripcion.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  // ------------------------------------------------------------------------
  // LÓGICA MODO PLANIFICADOR Y UTILIDADES (Sin cambios mayores)
  // ------------------------------------------------------------------------

  void _activarModoPlanificador() {
    setState(() {
      _modoActual = 2;
      _planesDeViaje.clear();
      _markers.clear();
      _dibujarTodasLasLineas(idResaltado: null);
      _origen = const LatLng(-17.7830, -63.1800);
      _destino = const LatLng(-17.7930, -63.1850);
      _actualizarMarcadoresPlanificador();
    });
  }

  void _actualizarMarcadoresPlanificador() {
    Set<Marker> nuevosMarcadores = {};
    if (_origen != null) {
      nuevosMarcadores.add(Marker(
        markerId: const MarkerId("origen"),
        position: _origen!,
        draggable: true,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: "Origen"),
        onDragEnd: (newPos) => setState(() => _origen = newPos),
      ));
    }
    if (_destino != null) {
      nuevosMarcadores.add(Marker(
        markerId: const MarkerId("destino"),
        position: _destino!,
        draggable: true,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: "Destino"),
        onDragEnd: (newPos) => setState(() => _destino = newPos),
      ));
    }
    setState(() {
      _markers = nuevosMarcadores;
    });
  }

  void _calcularViaje() {
    if (_origen == null || _destino == null) return;
    List<Map<String, dynamic>> resultados = [];

    for (var rutaRaw in listadoDeRutas) {
      double distanciaAlOrigen = _distanciaMinimaPuntoLinea(_origen!, rutaRaw.puntos);
      double distanciaAlDestino = _distanciaMinimaPuntoLinea(_destino!, rutaRaw.puntos);
      double umbral = 0.004; 

      if (distanciaAlOrigen < umbral && distanciaAlDestino < umbral) {
        int tiempoEstimado = 15 + Random().nextInt(20);
        resultados.add({
          "tipo": "DIRECTO",
          "ruta": rutaRaw,
          "tiempo": "$tiempoEstimado min",
          "descripcion": "${rutaRaw.nombre} (${rutaRaw.descripcion})"
        });
      }
    }
    resultados.sort((a, b) => (a['tiempo'] as String).compareTo(b['tiempo'] as String));

    setState(() {
      _planesDeViaje = resultados;
      if (resultados.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No hay rutas directas cercanas.")));
      } else {
        _mostrarRutaSeleccionada(resultados[0]['ruta']);
        _actualizarMarcadoresPlanificador(); 
      }
    });
  }

  void _resetearMapa() {
    setState(() {
      _modoActual = 0;
      _markers.clear();
      _planesDeViaje.clear();
      _searchController.clear();
      _dibujarTodasLasLineas(idResaltado: null);
      controller?.animateCamera(CameraUpdate.newCameraPosition(_posicionInicial));
    });
  }

  double _distanciaMinimaPuntoLinea(LatLng punto, List<LatLng> ruta) {
    double minDistance = double.infinity;
    for (var p in ruta) {
      double d = sqrt(pow(punto.latitude - p.latitude, 2) + pow(punto.longitude - p.longitude, 2));
      if (d < minDistance) minDistance = d;
    }
    return minDistance;
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

    controller!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(minLat - 0.005, minLng - 0.005),
        northeast: LatLng(maxLat + 0.005, maxLng + 0.005),
      ),
      50,
    ));
  }

  // ------------------------------------------------------------------------
  // UI
  // ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _cargando 
        ? const Center(child: CircularProgressIndicator()) 
        : Stack(
            children: [
              // 1. MAPA
              GoogleMap(
                initialCameraPosition: _posicionInicial,
                onMapCreated: (c) => controller = c,
                polylines: _polylines,
                markers: _markers,
                myLocationEnabled: true,
                zoomControlsEnabled: false,
                onTap: (pos) {
                  if (_modoActual == 2) {
                     // Lógica para mover marcadores al toque si se desea
                  }
                },
              ),

              // 2. PANELES SUPERIORES SEGÚN MODO
              if (_modoActual == 1) // BUSCADOR
                SafeArea(
                  child: Column(children: [
                    _buildSearchPanel(),
                    if (_searchController.text.isNotEmpty && _rutasFiltradas.isNotEmpty)
                      _buildSearchResults(),
                  ]),
                ),

              if (_modoActual == 2) // PLANIFICADOR
                SafeArea(child: _buildPlannerPanel()),

              // 3. RESULTADOS DEL PLANIFICADOR
              if (_modoActual == 2 && _planesDeViaje.isNotEmpty)
                Positioned(
                  bottom: 80,
                  left: 10,
                  right: 10,
                  child: _buildTripPlansList(),
                ),

              // 4. BOTONES INFERIORES
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _botonInferior(
                        icon: Icons.map, 
                        label: "Ver Todo", 
                        activo: _modoActual == 0, 
                        onTap: _resetearMapa
                      ),
                      _botonInferior(
                        icon: Icons.search, 
                        label: "Buscar", 
                        activo: _modoActual == 1, 
                        onTap: () {
                          setState(() {
                            _modoActual = 1;
                            _dibujarTodasLasLineas(idResaltado: null);
                            _searchController.clear();
                          });
                        }
                      ),
                      _botonInferior(
                        icon: Icons.directions, 
                        label: "Planificar", 
                        activo: _modoActual == 2, 
                        onTap: _activarModoPlanificador
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
    );
  }

  // WIDGETS AUXILIARES (Sin cambios lógicos profundos)
  Widget _botonInferior({required IconData icon, required String label, required bool activo, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: activo ? Colors.deepPurple : Colors.grey, size: 28),
          Text(label, style: TextStyle(color: activo ? Colors.deepPurple : Colors.grey, fontSize: 12, fontWeight: activo ? FontWeight.bold : FontWeight.normal))
        ],
      ),
    );
  }

  Widget _buildSearchPanel() {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [const BoxShadow(blurRadius: 5, color: Colors.black12)]),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: "Buscar Línea (ej. L001)",
          border: InputBorder.none,
          icon: Icon(Icons.search),
        ),
        onChanged: _filtrarRutas,
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(10)),
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _rutasFiltradas.length,
        itemBuilder: (ctx, i) {
          final r = _rutasFiltradas[i];
          return ListTile(
            leading: Icon(Icons.directions_bus, color: r.color),
            title: Text(r.nombre),
            subtitle: Text(r.descripcion), // Mostramos descripción también
            onTap: () {
              FocusScope.of(context).unfocus();
              _mostrarRutaSeleccionada(r);
            },
          );
        },
      ),
    );
  }

  Widget _buildPlannerPanel() {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [const BoxShadow(blurRadius: 5, color: Colors.black12)]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: const [Icon(Icons.trip_origin, color: Colors.green), SizedBox(width: 8), Text("Origen (Mover marcador verde)")]),
          const Divider(height: 15),
          Row(children: const [Icon(Icons.location_on, color: Colors.red), SizedBox(width: 8), Text("Destino (Mover marcador rojo)")]),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 40)),
            onPressed: _calcularViaje,
            child: const Text("CALCULAR RUTA"),
          )
        ],
      ),
    );
  }

  Widget _buildTripPlansList() {
    return Container(
      height: 160,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [const BoxShadow(blurRadius: 10, color: Colors.black26)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.all(10), child: Text("Opciones de Viaje:", style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
            child: ListView.builder(
              itemCount: _planesDeViaje.length,
              itemBuilder: (ctx, i) {
                final plan = _planesDeViaje[i];
                final ruta = plan['ruta'] as LineaRuta;
                return ListTile(
                  leading: Icon(Icons.directions_bus, color: ruta.color),
                  title: Text(plan['tiempo']),
                  subtitle: Text(plan['descripcion'], maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _mostrarRutaSeleccionada(ruta),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}