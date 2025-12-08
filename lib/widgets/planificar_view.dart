import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../ruta_model.dart';
import 'place_search_field.dart';

/// Widget para la vista de planificación de viajes
class PlanificarView extends StatelessWidget {
  final bool panelVisible;
  final bool obteniendoUbicacion;
  final bool buscandoLugar;
  final bool seleccionandoOrigen;
  final bool seleccionandoDestino;
  final LatLng? origen;
  final LatLng? destino;
  final TextEditingController destinoController;
  final List<Map<String, dynamic>> planesDeViaje;
  final VoidCallback onObtenerUbicacion;
  final VoidCallback onMarcarOrigen;
  final VoidCallback onMarcarDestino;
  final Function(String) onBuscarDestino;
  final Function(String, double, double) onPlaceSelected;
  final VoidCallback onCalcularViaje;
  final VoidCallback onTogglePanel;
  final VoidCallback onLimpiarResultados;
  final Function(Map<String, dynamic>) onMostrarPlanEnMapa;

  const PlanificarView({
    Key? key,
    required this.panelVisible,
    required this.obteniendoUbicacion,
    required this.buscandoLugar,
    required this.seleccionandoOrigen,
    required this.seleccionandoDestino,
    required this.origen,
    required this.destino,
    required this.destinoController,
    required this.planesDeViaje,
    required this.onObtenerUbicacion,
    required this.onMarcarOrigen,
    required this.onMarcarDestino,
    required this.onBuscarDestino,
    required this.onPlaceSelected,
    required this.onCalcularViaje,
    required this.onTogglePanel,
    required this.onLimpiarResultados,
    required this.onMostrarPlanEnMapa,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Panel del planificador
        if (panelVisible) buildPlannerPanel(context),

        // Botón hamburguesa flotante
        if (!panelVisible)
          Positioned(
            top: 20,
            left: 20,
            child: FloatingActionButton(
              heroTag: 'togglePlanner',
              onPressed: onTogglePanel,
              backgroundColor: Colors.deepPurple,
              child: const Icon(Icons.menu, color: Colors.white),
            ),
          ),

        // Lista de resultados
        if (planesDeViaje.isNotEmpty)
          Positioned(
            bottom: 100,
            left: 10,
            right: 10,
            child: buildTripPlansList(context),
          ),
      ],
    );
  }

  Widget buildPlannerPanel(BuildContext context) {
    return Positioned(
      top: 10,
      left: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "🗺️ Planificador de Viaje",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 20),
                      tooltip: 'Minimizar panel',
                      onPressed: onTogglePanel,
                    ),
                    if (planesDeViaje.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        tooltip: 'Limpiar resultados',
                        onPressed: onLimpiarResultados,
                      ),
                  ],
                ),
              ],
            ),
            const Divider(),

            // ORIGEN
            const Text(
              "📍 Origen",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: obteniendoUbicacion ? null : onObtenerUbicacion,
                    icon:
                        obteniendoUbicacion
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.my_location, size: 18),
                    label: Text(
                      obteniendoUbicacion ? 'Obteniendo...' : 'Mi Ubicación',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onMarcarOrigen,
                    icon: Icon(
                      seleccionandoOrigen
                          ? Icons.check_circle
                          : Icons.touch_app,
                      size: 18,
                    ),
                    label: Text(seleccionandoOrigen ? 'Tocando...' : 'Marcar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          seleccionandoOrigen
                              ? Colors.orange
                              : Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
            if (origen != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '✅ Lat: ${origen!.latitude.toStringAsFixed(4)}, Lng: ${origen!.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 11, color: Colors.green),
                ),
              ),

            const SizedBox(height: 15),

            // DESTINO
            const Text(
              "🎯 Destino",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            PlaceSearchField(
              controller: destinoController,
              hintText: 'Buscar lugar (Ej: La Ramada, Los Pozos...)',
              prefixIcon: Icons.search,
              onPlaceSelected: onPlaceSelected,
              isLoading: buscandoLugar,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: onMarcarDestino,
              icon: Icon(
                seleccionandoDestino ? Icons.check_circle : Icons.touch_app,
                size: 18,
              ),
              label: Text(
                seleccionandoDestino ? 'Tocando mapa...' : 'Marcar en Mapa',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    seleccionandoDestino ? Colors.orange : Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                minimumSize: const Size(double.infinity, 36),
              ),
            ),
            if (destino != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '✅ Lat: ${destino!.latitude.toStringAsFixed(4)}, Lng: ${destino!.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(fontSize: 11, color: Colors.red),
                ),
              ),

            const SizedBox(height: 15),

            // BOTÓN CALCULAR
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed:
                    (origen != null && destino != null)
                        ? onCalcularViaje
                        : null,
                icon: const Icon(Icons.directions),
                label: const Text(
                  "Calcular Ruta Óptima",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTripPlansList(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: const BoxDecoration(
              color: Colors.deepPurple,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.route, color: Colors.white),
                const SizedBox(width: 10),
                const Text(
                  "Opciones de Viaje",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  "${planesDeViaje.length} ${planesDeViaje.length == 1 ? 'opción' : 'opciones'}",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: planesDeViaje.length,
              itemBuilder: (ctx, idx) {
                var plan = planesDeViaje[idx];
                List<LineaRuta> rutas = List<LineaRuta>.from(plan['rutas']);
                bool esOptima = idx == 0;

                return Card(
                  elevation: esOptima ? 4 : 1,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                      color:
                          esOptima ? Colors.deepPurple : Colors.grey.shade300,
                      width: esOptima ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => onMostrarPlanEnMapa(plan),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (esOptima)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Text(
                                    "ÓPTIMA",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              if (esOptima) const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      plan['transbordos'] == 0
                                          ? Colors.blue.shade100
                                          : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  plan['tipo'],
                                  style: TextStyle(
                                    color:
                                        plan['transbordos'] == 0
                                            ? Colors.blue.shade900
                                            : Colors.orange.shade900,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.access_time,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${plan['tiempo']} min",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.straighten,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${plan['distancia'].toStringAsFixed(1)} km",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.directions_bus, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children:
                                      rutas.map((ruta) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: ruta.color,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            ruta.nombre,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                ),
                              ),
                            ],
                          ),
                          if (plan['transbordos'] > 0) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.swap_horiz,
                                  size: 16,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "${plan['transbordos']} ${plan['transbordos'] == 1 ? 'transbordo' : 'transbordos'}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            plan['detalles'],
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
