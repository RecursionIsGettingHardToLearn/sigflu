import 'package:flutter/material.dart';
import 'mapa_page.dart'; // 👈 IMPORTANTE
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  // ✅ Necesario para operaciones async antes de runApp
  WidgetsFlutterBinding.ensureInitialized();
  
  // ✅ Cargar el archivo .env
  await dotenv.load(fileName: ".env");
  
  print('\n');
  final String? baseUrl = dotenv.env['API_BASE_URL'];
  if (baseUrl != null && baseUrl.isNotEmpty) {
    print('is 000000000000000000000000000c0000' + baseUrl);
  } else {
    print('API_BASE_URL no está definida o está vacía.');
  }
  
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
