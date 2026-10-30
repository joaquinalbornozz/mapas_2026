import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class Map1Page extends StatefulWidget {
  const Map1Page({super.key});

  @override
  State<Map1Page> createState() => _Map1PageState();
}

class _Map1PageState extends State<Map1Page> {
  late final MapController _mapController;
  late final Future<LatLng> _ubicacionInicialFuture;
  StreamSubscription<Position>? _positionStreamSubscription;

  LatLng? _ubicacionActual;
  final LatLng unsj = const LatLng(-31.5336419722084, -68.54444177635682);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _ubicacionInicialFuture = _obtenerUbicacionInicial();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// Obtiene la ubicación inicial una sola vez y suscribe la escucha en tiempo real
  Future<LatLng> _obtenerUbicacionInicial() async {
    const ubicacionPorDefecto = LatLng(-31.5406, -68.5767);

    try {
      final gpsActivo = await Geolocator.isLocationServiceEnabled();
      if (!gpsActivo) {
        return ubicacionPorDefecto;
      }

      LocationPermission permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
        if (permiso == LocationPermission.denied ||
            permiso == LocationPermission.deniedForever) {
          return ubicacionPorDefecto;
        }
      } else if (permiso == LocationPermission.deniedForever) {
        return ubicacionPorDefecto;
      }

      final posicion = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      // Cancelar suscripción previa si existiese
      await _positionStreamSubscription?.cancel();
      _positionStreamSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              distanceFilter: 5,
            ),
          ).listen((pos) {
            if (mounted) {
              setState(() {
                _ubicacionActual = LatLng(pos.latitude, pos.longitude);
              });
            }
          });

      final inicial = LatLng(posicion.latitude, posicion.longitude);
      if (mounted) {
        setState(() => _ubicacionActual = inicial);
      }
      return inicial;
    } catch (e) {
      debugPrint('Error al obtener ubicación inicial: $e');
      return ubicacionPorDefecto;
    }
  }

  /// Centra la cámara del mapa en la ubicación actual del usuario
  Future<void> _centrarEnMiUbicacion() async {
    if (_ubicacionActual != null) {
      _mapController.move(_ubicacionActual!, 16.5);
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final actual = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _ubicacionActual = actual);
        _mapController.move(actual, 16.5);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo obtener la ubicación actual: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Mi ubicación',
            onPressed: _centrarEnMiUbicacion,
          ),
        ],
      ),
      body: FutureBuilder<LatLng>(
        future: _ubicacionInicialFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final centroInicial = snapshot.data!;

          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: centroInicial,
              initialZoom: 16.5,
              onTap: (_, _) => FocusScope.of(context).unfocus(),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mapas',
              ),
              MarkerLayer(
                markers: [
                  if (_ubicacionActual != null)
                    Marker(
                      point: _ubicacionActual!,
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 30,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'btnMiUbicacion',
            onPressed: _centrarEnMiUbicacion,
            tooltip: 'Centrar en mi ubicación',
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
