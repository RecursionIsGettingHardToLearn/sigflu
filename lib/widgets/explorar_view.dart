import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Widget para la vista de exploración del mapa
class ExplorarView extends StatelessWidget {
  final GoogleMapController? controller;
  final Set<Polyline> polylines;
  final Set<Marker> markers;
  final CameraPosition posicionInicial;
  final Function(GoogleMapController) onMapCreated;
  final Function(LatLng)? onMapTap;

  const ExplorarView({
    Key? key,
    required this.controller,
    required this.polylines,
    required this.markers,
    required this.posicionInicial,
    required this.onMapCreated,
    this.onMapTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: posicionInicial,
      onMapCreated: onMapCreated,
      onTap: onMapTap,
      polylines: polylines,
      markers: markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      liteModeEnabled: false,
      tiltGesturesEnabled: false,
      rotateGesturesEnabled: false,
      buildingsEnabled: false,
      trafficEnabled: false,
    );
  }
}
