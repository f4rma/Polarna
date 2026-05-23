import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/entities/warehouse_entity.dart';

/// Google Maps widget yang menampilkan marker gudang.
class WarehouseMapWidget extends StatelessWidget {
  const WarehouseMapWidget({
    super.key,
    this.warehouses = const [],
    this.height = 200,
    this.initialPosition,
    this.onMapTap,
  });

  final List<WarehouseEntity> warehouses;
  final double height;
  final LatLng? initialPosition;
  final void Function(LatLng)? onMapTap;

  // Default: Padang
  static const _defaultPosition = LatLng(-0.9247542207020228, 100.3624012909291);

  @override
  Widget build(BuildContext context) {
    final center = initialPosition ?? _defaultPosition;

    final markers = <Marker>{};
    for (final w in warehouses) {
      markers.add(
        Marker(
          markerId: MarkerId(w.id),
          position: LatLng(w.latitude, w.longitude),
          infoWindow: InfoWindow(
            title: w.name,
            snippet: w.address,
          ),
        ),
      );
    }

    final mapWidget = GoogleMap(
      initialCameraPosition: CameraPosition(
        target: center,
        zoom: 12,
      ),
      markers: markers,
      onTap: onMapTap,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
    );

    // If height is infinite, let parent constrain it (e.g. inside Expanded)
    if (height == double.infinity) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: mapWidget,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: mapWidget,
      ),
    );
  }
}
