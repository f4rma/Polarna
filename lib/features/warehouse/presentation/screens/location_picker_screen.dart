import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Screen untuk memilih lokasi gudang di peta.
/// Mengembalikan Map {'lat': double, 'lng': double, 'address': String} via Navigator.pop.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  final double? initialLat;
  final double? initialLng;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedPosition;
  String _address = 'Ketuk peta untuk memilih lokasi';
  bool _loading = false;

  static const _defaultPosition = LatLng(-6.2088, 106.8456);

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selectedPosition = LatLng(widget.initialLat!, widget.initialLng!);
      _reverseGeocode(_selectedPosition!);
    } else {
      _goToCurrentLocation();
    }
  }

  Future<void> _goToCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final latLng = LatLng(pos.latitude, pos.longitude);
      setState(() => _selectedPosition = latLng);
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      _reverseGeocode(latLng);
    } catch (_) {
      // Fallback ke default jika gagal
    }
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _loading = true);
    try {
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [
          p.street,
          p.subLocality,
          p.locality,
          p.subAdministrativeArea,
          p.administrativeArea,
        ].where((s) => s != null && s.isNotEmpty);
        setState(() => _address = parts.join(', '));
      }
    } catch (_) {
      setState(() => _address = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onMapTap(LatLng pos) {
    setState(() => _selectedPosition = pos);
    _reverseGeocode(pos);
  }

  void _confirmLocation() {
    if (_selectedPosition == null) return;
    Navigator.of(context).pop({
      'lat': _selectedPosition!.latitude,
      'lng': _selectedPosition!.longitude,
      'address': _address,
    });
  }

  @override
  Widget build(BuildContext context) {
    final initial = _selectedPosition ?? _defaultPosition;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Lokasi Gudang'),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initial,
              zoom: 14,
            ),
            onMapCreated: (c) => _mapController = c,
            onTap: _onMapTap,
            markers: _selectedPosition != null
                ? {
                    Marker(
                      markerId: const MarkerId('selected'),
                      position: _selectedPosition!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure,
                      ),
                    ),
                  }
                : {},
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
          ),
          // Address bar di bawah
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.cyan),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _loading
                              ? const Text('Mencari alamat...')
                              : Text(
                                  _address,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            _selectedPosition != null ? _confirmLocation : null,
                        child: const Text('Konfirmasi Lokasi'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
