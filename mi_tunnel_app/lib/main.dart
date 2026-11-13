
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
        colorSchemeSeed: Colors.blue,
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
  final String serverUrl =
      'https://ti-tunnel-server.onrender.com';

  final hostController = TextEditingController();
  final portController = TextEditingController(text: '22');
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final payloadController = TextEditingController();
  final configController = TextEditingController();

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
  bool hidePassword = true;

  Future<void> analyzeConfig() async {
    String content;

    if (selectedProtocol == 'SSH') {
      final host = hostController.text.trim();
      final port = portController.text.trim();
      final username = usernameController.text.trim();

      if (host.isEmpty || port.isEmpty || username.isEmpty) {
        setState(() {
          result = 'Completa el servidor, puerto y usuario.';
        });
        return;
      }

      final parsedPort = int.tryParse(port);

      if (parsedPort == null ||
          parsedPort < 1 ||
          parsedPort > 65535) {
        setState(() {
          result = 'El puerto debe ser un número entre 1 y 65535.';
        });
        return;
      }

      content = '''
Host: $host
Port: $port
Username: $username
Password: ${passwordController.text.isNotEmpty ? 'configured' : ''}
Payload: ${payloadController.text.trim().isNotEmpty ? 'configured' : ''}
''';
    } else {
      content = configController.text.trim();

      if (content.isEmpty) {
        setState(() {
          result = 'Pega una configuración antes de analizar.';
        });
        return;
      }
    }

    setState(() {
      analyzing = true;
      result = 'Conectando con el servidor Mi Tunnel...';
    });

    final client = HttpClient();

    try {
      final uri = Uri.parse('$serverUrl/api/detect');
      final request = await client.postUrl(uri);

      request.headers.contentType = ContentType.json;

      request.write(jsonEncode({
        'filename': '$selectedProtocol.txt',
        'content': content,
      }));

      final response = await request.close().timeout(
        const Duration(seconds: 60),
      );

      final responseText =
          await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception('Error HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(responseText);

      if (!mounted) return;

      setState(() {
        result = const JsonEncoder.withIndent('  ')
            .convert(decoded);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        result = 'No se pudo analizar la configuración.\n\n'
            'Comprueba tu conexión a Internet y el servidor Render.\n\n'
            'Detalle: $e';
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

  Widget buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: suffix,
          filled: true,
          fillColor: const Color(0xFF142238),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    hostController.dispose();
    portController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    payloadController.dispose();
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
                    'Configura tu protocolo y analiza los datos.',
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
                    result = 'Esperando configuración...';
                  });
                }
              },
            ),

            const SizedBox(height: 22),

            if (selectedProtocol == 'SSH') ...[
              const Text(
                'CONFIGURACIÓN SSH',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.lightBlueAccent,
                ),
              ),
              const SizedBox(height: 14),

              buildField(
                label: 'Host / Servidor',
                hint: 'ejemplo.com',
                controller: hostController,
              ),

              buildField(
                label: 'Puerto',
                hint: '22',
                controller: portController,
                keyboardType: TextInputType.number,
              ),

              buildField(
                label: 'Usuario',
                hint: 'Tu usuario SSH',
                controller: usernameController,
              ),

              buildField(
                label: 'Contraseña',
                hint: 'Tu contraseña SSH',
                controller: passwordController,
                obscure: hidePassword,
                suffix: IconButton(
                  icon: Icon(
                    hidePassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      hidePassword = !hidePassword;
                    });
                  },
                ),
              ),

              buildField(
                label: 'Payload (opcional)',
                hint: 'Introduce tu payload',
                controller: payloadController,
              ),
            ] else ...[
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
            ],

            const SizedBox(height: 10),

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: analyzing ? null : analyzeConfig,
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
                border: Border.all(color: Colors.white12),
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

