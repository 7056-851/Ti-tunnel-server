
import 'package:flutter/material.dart';

void main() {
  runApp(const MiTunnelApp());
}

class MiTunnelApp extends StatelessWidget {
  const MiTunnelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mi Tunnel',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08111F),
      appBar: AppBar(
        title: const Text('🛡️ MI TUNNEL'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'MI TUNNEL\n\nTu conexión segura comienza aquí.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

