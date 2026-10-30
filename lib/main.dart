import 'package:flutter/material.dart';

import 'pages/map1_page.dart';
import 'pages/map_page.dart';

//import 'services/background_service.dart';

void main() {
  //WidgetsFlutterBinding.ensureInitialized();
  //await initializeService();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Flutter Map Demo', home: MapPage());
  }
}
