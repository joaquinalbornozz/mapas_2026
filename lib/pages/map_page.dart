import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late final MapController _mapController;
  late final Future<LatLng> _ubicacionInicialFuture;
  StreamSubscription<Position>? _positionStreamSubscription;

  LatLng? _ubicacionActual;
  List<LatLng> _ruta = [];
  final LatLng unsj = const LatLng(-31.5336419722084, -68.54444177635682);
  final String apiKeyORS =
      '5b3ce3597851110001cf6248627feed9a1c04d9f81e7b717bb1d3107';

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
      _positionStreamSubscription = Geolocator.getPositionStream(
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

  Future<void> _calcularRuta() async {
    if (_ubicacionActual == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ubicación actual no disponible para calcular la ruta.'),
          ),
        );
      }
      return;
    }

    final url = Uri.parse(
      'https://api.openrouteservice.org/v2/directions/driving-car',
    );

    final body = {
      'coordinates': [
        [_ubicacionActual!.longitude, _ubicacionActual!.latitude],
        [unsj.longitude, unsj.latitude],
      ],
      'instructions': false,
      'geometry': true,
    };

    final headers = {
      'Authorization': apiKeyORS,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(body),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null &&
            (data['routes'] as List).isNotEmpty &&
            data['routes'][0]['geometry'] != null) {
          final String encoded = data['routes'][0]['geometry'];

          // Compatible con flutter_polyline_points ^3.1.0 (método estático decodePolyline)
          final points = PolylinePoints.decodePolyline(encoded);

          setState(() {
            _ruta = points.map((p) => LatLng(p.latitude, p.longitude)).toList();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontró geometría o la ruta está vacía.'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error OpenRouteService: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión al obtener ruta: $e')),
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
              onTap: (_, __) => FocusScope.of(context).unfocus(),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mapas',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: unsj,
                    width: 80,
                    height: 80,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_pin,
                      size: 40,
                      color: Colors.red,
                    ),
                  ),
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
              PolylineLayer(
                polylines: [
                  if (_ruta.isNotEmpty)
                    Polyline(
                      points: _ruta,
                      strokeWidth: 4.0,
                      color: Colors.blueAccent,
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
          FloatingActionButton.extended(
            heroTag: 'btnGenerarRuta',
            onPressed: _calcularRuta,
            label: const Text('Generar Ruta'),
            icon: const Icon(Icons.alt_route),
          ),
        ],
      ),
    );
  }
}