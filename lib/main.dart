import 'package:flutter/material.dart';
import 'mapa_page.dart';
import 'config.dart';

void main() {
  // ✅ Inicializar Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Configuración centralizada (ver config.dart)
  print('🚀 Iniciando app con configuración:');
  print('   📡 API URL: ${AppConfig.apiBaseUrl}');
  print('   🚌 Velocidad promedio: ${AppConfig.velocidadPromedioKmH} km/h');
  print(
    '   🔄 Tiempo por transbordo: ${AppConfig.tiempoPorTransbordoMinutos} min',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rutas Santa Cruz',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),

      home: MapaPage(),
    );
  }
}
