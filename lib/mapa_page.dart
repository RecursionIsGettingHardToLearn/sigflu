import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'ruta_model.dart';
import 'mis_rutas_data.dart'; 

class MapaPage extends StatefulWidget {
  const MapaPage({super.key});

  @override
  _MapaPageState createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  // Configuración inicial del mapa (Santa Cruz)
  final _posicionInicial = const CameraPosition(
    target: LatLng(-17.795, -63.190), // Centro aproximado de los puntos
    zoom: 13.0,
  );

  GoogleMapController? controller;
  
  // Elementos del mapa
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  // Estado de la UI: 0 = Ver Todo, 1 = Buscar Línea, 2 = Planificador
  int _modoActual = 0; 

  final TextEditingController _searchController = TextEditingController();
  
  // Datos procesados
  List<LineaRuta> _rutasFiltradas = [];
  
  // Para el Planificador
  LatLng? _origen;
  LatLng? _destino;
  List<Map<String, dynamic>> _planesDeViaje = []; 

  // --- NUEVO: DATOS DE LA TABLA (Imagen) ---
  final List<Map<String, dynamic>> _puntosDeTabla = [
    {"id": 2, "lat": -17.800659, "lng": -63.185692, "desc": "P 2"},
    {"id": 3, "lat": -17.783154, "lng": -63.172292, "desc": "P 3"},
    {"id": 4, "lat": -17.797887, "lng": -63.215916, "desc": "P 4"},
    {"id": 5, "lat": -17.797690, "lng": -63.216896, "desc": "P 5"},
    {"id": 6, "lat": -17.773615, "lng": -63.191947, "desc": "P 6"},
    {"id": 7, "lat": -17.798871, "lng": -63.168768, "desc": "P 7"},
    {"id": 8, "lat": -17.812585, "lng": -63.190361, "desc": "P 8"},
    {"id": 9, "lat": -17.794373, "lng": -63.162225, "desc": "P 9"},
    {"id": 10,"lat": -17.823166, "lng": -63.210237, "desc": "P 10"},
  ];

  @override
  void initState() {
    super.initState();
    
    // 1. Cargar lista para el buscador
    _rutasFiltradas = listadoDeRutas.map((r) {
      return LineaRuta(
        id: r.id,
        nombre: r.nombre.isEmpty ? "Línea ${r.id}" : r.nombre, 
        color: r.color,
        puntos: r.puntos,
      );
    }).toList();

    // 2. Mostrar TODAS las líneas y los Puntos de la tabla al iniciar
    _dibujarTodasLasLineas(idResaltado: null);
    _mostrarPuntosEstaticos(); // <--- LLAMADA A LA NUEVA FUNCIÓN
  }

  // ------------------------------------------------------------------------
  // NUEVO: FUNCIÓN PARA DIBUJAR LOS PUNTOS DE LA TABLA
  // ------------------------------------------------------------------------
  void _mostrarPuntosEstaticos() {
    Set<Marker> marcadoresPuntos = {};

    for (var punto in _puntosDeTabla) {
      marcadoresPuntos.add(
        Marker(
          markerId: MarkerId("punto_${punto['id']}"),
          position: LatLng(punto['lat'], punto['lng']),
          infoWindow: InfoWindow(
            title: punto['desc'], 
            snippet: "Lat: ${punto['lat']}, Lng: ${punto['lng']}"
          ),
          // Usamos un color Azul (Azure) para diferenciar de Rutas (Verde/Rojo)
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }

    // Agregamos a los marcadores existentes sin borrarlos
    setState(() {
      _markers.addAll(marcadoresPuntos);
    });
  }

  // ------------------------------------------------------------------------
  // LÓGICA DE DIBUJADO DE LÍNEAS
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

  // ------------------------------------------------------------------------
  // LÓGICA MODO 1: BUSCADOR
  // ------------------------------------------------------------------------

  void _mostrarRutaSeleccionada(LineaRuta ruta) {
    _dibujarTodasLasLineas(idResaltado: ruta.id);

    setState(() {
      _markers.clear(); // Limpiamos para mostrar solo Inicio/Fin de la ruta
      
      _markers.add(Marker(
        markerId: const MarkerId("inicio"),
        position: ruta.puntoInicio,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: "Partida - ${ruta.nombre}"),
      ));

      _markers.add(Marker(
        markerId: const MarkerId("fin"),
        position: ruta.puntoFin,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: "Llegada - ${ruta.nombre}"),
      ));

      _ajustarCamaraAPuntos(ruta.puntos);
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
            .where((r) => r.nombre.toLowerCase().contains(query.toLowerCase()) || "línea ${r.id}".contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  // ------------------------------------------------------------------------
  // LÓGICA MODO 2: PLANIFICADOR
  // ------------------------------------------------------------------------

  void _activarModoPlanificador() {
    setState(() {
      _modoActual = 2;
      _planesDeViaje.clear();
      _markers.clear(); // Limpiamos puntos de la tabla para enfocar en Origen/Destino
      
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
          "descripcion": "Ruta Directa con ${rutaRaw.nombre}"
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

  // ------------------------------------------------------------------------
  // LÓGICA MODO 0: RESET / VER TODO
  // ------------------------------------------------------------------------
  void _resetearMapa() {
    setState(() {
      _modoActual = 0;
      _markers.clear();
      _planesDeViaje.clear();
      _searchController.clear();
      _dibujarTodasLasLineas(idResaltado: null);
      
      // Volver a mostrar los puntos de la tabla
      _mostrarPuntosEstaticos(); 
      
      controller?.animateCamera(CameraUpdate.newCameraPosition(_posicionInicial));
    });
  }

  // ------------------------------------------------------------------------
  // UTILIDADES
  // ------------------------------------------------------------------------
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
      body: Stack(
        children: [
          // MAPA
          GoogleMap(
            initialCameraPosition: _posicionInicial,
            onMapCreated: (c) => controller = c,
            polylines: _polylines,
            markers: _markers,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            onTap: (pos) {
              if (_modoActual == 2) {
                 // Lógica opcional
              }
            },
          ),

          // PANELES
          if (_modoActual == 1) 
            SafeArea(
              child: Column(children: [
                _buildSearchPanel(),
                if (_searchController.text.isNotEmpty && _rutasFiltradas.isNotEmpty)
                  _buildSearchResults(),
              ]),
            ),

          if (_modoActual == 2) 
            SafeArea(child: _buildPlannerPanel()),

          // RESULTADOS PLANIFICADOR
          if (_modoActual == 2 && _planesDeViaje.isNotEmpty)
            Positioned(
              bottom: 80, 
              left: 10,
              right: 10,
              child: _buildTripPlansList(),
            ),

          // BOTONES INFERIORES
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
                        _polylines.clear(); 
                        _dibujarTodasLasLineas(idResaltado: null);
                        _searchController.clear();
                        _markers.clear(); // Limpiar puntos en modo búsqueda
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black12)]),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          hintText: "Buscar Línea (ej. Línea 1)",
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black12)]),
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.all(10), child: Text("Opciones de Viaje:", style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(
            child: ListView.builder(
              itemCount: _planesDeViaje.length,
              itemBuilder: (ctx, i) {
                final plan = _planesDeViaje[i];
                return ListTile(
                  leading: Icon(Icons.directions_bus, color: (plan['ruta'] as LineaRuta).color),
                  title: Text(plan['tiempo']),
                  subtitle: Text(plan['descripcion']),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _mostrarRutaSeleccionada(plan['ruta']),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}