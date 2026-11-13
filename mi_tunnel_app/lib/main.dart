
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

void main() {
  runApp(const MiTunnelApp());
}

class MiTunnelApp extends StatelessWidget {
  const MiTunnelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Tunnel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF08111F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF168BFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const TunnelHomePage(),
    );
  }
}

class TunnelHomePage extends StatefulWidget {
  const TunnelHomePage({super.key});

  @override
  State<TunnelHomePage> createState() => _TunnelHomePageState();
}

class _TunnelHomePageState extends State<TunnelHomePage> {
  final TextEditingController configController =
      TextEditingController();

  final String serverUrl =
      'https://ti-tunnel-server.onrender.com';

  final List<String> protocols = [
    'SSH',
    'OpenVPN',
    'WireGuard',
    'VMess',
    'VLESS',
    'Xray',
  ];

  String selectedProtocol = 'SSH';
  String result = 'Esperando configuración...';
  bool analyzing = false;

  Future<void> analyzeConfig() async {
    final content = configController.text.trim();

    if (content.isEmpty) {
      setState(() {
        result = 'Pega una configuración antes de analizar.';
      });
      return;
    }

    setState(() {
      analyzing = true;
      result = 'Conectando con el servidor Mi Tunnel...';
    });

    final client = HttpClient();

    try {
      final uri = Uri.parse('$serverUrl/api/detect');
      final request = await client.postUrl(uri);

      request.headers.contentType =
          ContentType.json;

      request.write(jsonEncode({
        'filename': '$selectedProtocol.txt',
        'content': content,
      }));

      final response =
          await request.close().timeout(
                const Duration(seconds: 60),
              );

      final responseText =
          await response.transform(utf8.decoder).join();

      final decoded = jsonDecode(responseText);

      setState(() {
        result = const JsonEncoder.withIndent('  ')
            .convert(decoded);
      });
    } catch (e) {
      setState(() {
        result = 'No se pudo analizar la configuración.\n\n'
            'Comprueba tu conexión a Internet y que el servidor '
            'Render esté activo.\n\nDetalle: $e';
      });
    } finally {
      client.close();
      if (mounted) {
        setState(() {
          analyzing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    configController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF101E32),
        centerTitle: true,
        title: const Text(
          '🛡️ MI TUNNEL',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF123D70),
                    Color(0xFF10243D),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_rounded,
                    size: 42,
                    color: Colors.lightBlueAccent,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Tu conexión segura',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Selecciona un protocolo y analiza '
                    'tu configuración.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'PROTOCOLO',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.lightBlueAccent,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: selectedProtocol,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF142238),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              items: protocols.map((protocol) {
                return DropdownMenuItem(
                  value: protocol,
                  child: Text(protocol),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedProtocol = value;
                  });
                }
              },
            ),
            const SizedBox(height: 22),
            const Text(
              'CONFIGURACIÓN',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.lightBlueAccent,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: configController,
              minLines: 7,
              maxLines: 12,
              decoration: InputDecoration(
                hintText: 'Pega aquí tu configuración...',
                filled: true,
                fillColor: const Color(0xFF142238),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed:
                    analyzing ? null : analyzeConfig,
                icon: analyzing
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.analytics),
                label: Text(
                  analyzing
                      ? 'Analizando...'
                      : 'Analizar configuración',
                ),
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF142238),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white12,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.terminal,
                        color: Colors.lightBlueAccent,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Resultado del análisis',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    result,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Center(
              child: Text(
                'Mi Tunnel • Motor VPN en desarrollo',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

