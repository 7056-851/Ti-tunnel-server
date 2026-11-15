
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dartssh2/dartssh2.dart';

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
  bool connectingSsh = false;
  SSHClient? sshClient;

  // Opciones de conexión de Mi Tunnel
  final sniController = TextEditingController();
  final hostHeaderController = TextEditingController();
  final serverNameController = TextEditingController();

  String selectedMode = 'Custom SNI';
  int selectedTabIndex = 0;
  bool customSetup = true;

  final List<String> connectionModes = [
    'Direct Connection',
    'Custom Payload',
    'Custom Host Header',
    'Custom SNI',
    'DNSTT Tunnel',
    'Imported Config',
  ];


  Future<void> connectSsh() async {
    final host = hostController.text.trim();
    final port = int.tryParse(portController.text.trim());
    final username = usernameController.text.trim();
    final password = passwordController.text;

    if (host.isEmpty || username.isEmpty || password.isEmpty ||
        port == null || port < 1 || port > 65535) {
      setState(() {
        result = 'Completa servidor, puerto, usuario y contraseña.';
      });
      return;
    }

    setState(() {
      connectingSsh = true;
      result = 'Conectando al servidor SSH...';
    });

    SSHClient? candidate;

    try {
      final socket = await SSHSocket.connect(
        host,
        port,
        timeout: const Duration(seconds: 15),
      );

      final newClient = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
        handshakeTimeout: const Duration(seconds: 15),
        authTimeout: const Duration(seconds: 20),
        onVerifyHostKey: (type, fingerprint) async {
          final fingerprintText = utf8.decode(fingerprint);

          if (!mounted) return false;

          final accepted = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Verificar servidor SSH'),
              content: SelectableText(
                'Tipo de clave: $type\n\n'
                'Huella SHA256:\n$fingerprintText\n\n'
                'Compara esta huella con la proporcionada '
                'por tu proveedor mediante un canal confiable. '
                'Si no puedes verificarla, rechaza la conexión.',
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, false),
                  child: const Text('Rechazar'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext, true),
                  child: const Text('Huella verificada'),
                ),
              ],
            ),
          );

          return accepted ?? false;
        },
      );

      candidate = newClient;

      await newClient.authenticated.timeout(
        const Duration(seconds: 25),
      );

      if (!mounted) {
        await newClient.close();
        return;
      }

      await sshClient?.close();

      setState(() {
        sshClient = newClient;
        result = '¡Conexión SSH autenticada correctamente!\n'
            'Servidor: $host\n'
            'Puerto: $port\n'
            'Usuario: $username\n'
            'Estado: conectado';
      });
    } catch (e) {
      await candidate?.close();

      if (!mounted) return;

      setState(() {
        result = 'No se pudo establecer la conexión SSH.\n\n'
            'Detalle: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          connectingSsh = false;
        });
      }
    }
  }

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
    sshClient?.close();
    sshClient = null;
    hostController.dispose();
    portController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    payloadController.dispose();
    configController.dispose();
    sniController.dispose();
    hostHeaderController.dispose();
    serverNameController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF38BDF8);
    const panel = Color(0xFF142238);

    Widget modeTile(String mode, IconData icon) {
      final selected = selectedMode == mode;

      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() {
            selectedMode = mode;
          });
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 9),
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 15,
          ),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF123D70) : panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? blue : Colors.white12,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? blue : Colors.white70),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mode,
                  style: TextStyle(
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected ? blue : Colors.white38,
              ),
            ],
          ),
        ),
      );
    }

    Widget sectionTitle(String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 18),
        child: Text(
          value,
          style: const TextStyle(
            color: blue,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      );
    }

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
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      setState(() => selectedTabIndex = 0);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: selectedTabIndex == 0
                          ? const Color(0xFF123D70)
                          : panel,
                    ),
                    child: const Text('HOME'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      setState(() => selectedTabIndex = 1);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: selectedTabIndex == 1
                          ? const Color(0xFF123D70)
                          : panel,
                    ),
                    child: const Text('LOG'),
                  ),
                ),
              ],
            ),

            if (selectedTabIndex == 0) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF123D70),
                      Color(0xFF10243D),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_rounded, size: 38, color: blue),
                    SizedBox(height: 10),
                    Text(
                      'Tu conexión segura',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Configura tu modo de conexión.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),

              sectionTitle('SERVIDOR'),
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

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('CUSTOM SETUP'),
                  subtitle: const Text(
                    'Mostrar opciones de configuración',
                    style: TextStyle(color: Colors.white60),
                  ),
                  value: customSetup,
                  activeColor: blue,
                  onChanged: (value) {
                    setState(() => customSetup = value);
                  },
                ),
              ),

              if (customSetup) ...[
                sectionTitle('MODO DE CONEXIÓN'),
                modeTile(
                  'Direct Connection',
                  Icons.public,
                ),
                modeTile(
                  'Custom Payload',
                  Icons.code,
                ),
                modeTile(
                  'Custom Host Header',
                  Icons.http,
                ),
                modeTile(
                  'Custom SNI',
                  Icons.security,
                ),
                modeTile(
                  'DNSTT Tunnel',
                  Icons.dns,
                ),
                modeTile(
                  'Imported Config',
                  Icons.file_open,
                ),

                sectionTitle('CONFIGURACIÓN DEL MODO'),

                if (selectedMode == 'Direct Connection') ...[
                  const Text(
                    'Conexión directa a Internet. '
                    'El motor de conexión todavía no está instalado.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],

                if (selectedMode == 'Custom Payload')
                  buildField(
                    label: 'Payload',
                    hint: 'Introduce tu payload',
                    controller: payloadController,
                  ),

                if (selectedMode == 'Custom Host Header')
                  buildField(
                    label: 'Host Header',
                    hint: 'www.ejemplo.com',
                    controller: hostHeaderController,
                  ),

                if (selectedMode == 'Custom SNI') ...[
                  buildField(
                    label: 'SNI',
                    hint: 'servidor.ejemplo.com',
                    controller: sniController,
                  ),
                  buildField(
                    label: 'Nombre del servidor',
                    hint: 'Nombre TLS del servidor',
                    controller: serverNameController,
                  ),
                ],

                if (selectedMode == 'DNSTT Tunnel')
                  buildField(
                    label: 'Dominio DNSTT',
                    hint: 'tunel.ejemplo.com',
                    controller: serverNameController,
                  ),

                if (selectedMode == 'Imported Config') ...[
                  DropdownButtonFormField<String>(
                    value: selectedProtocol,
                    decoration: InputDecoration(
                      labelText: 'Protocolo',
                      filled: true,
                      fillColor: panel,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: protocols.map((protocol) {
                      return DropdownMenuItem<String>(
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
                  const SizedBox(height: 14),

                  if (selectedProtocol == 'SSH') ...[
                    buildField(
                      label: 'Usuario SSH',
                      hint: 'Tu usuario',
                      controller: usernameController,
                    ),
                    buildField(
                      label: 'Contraseña SSH',
                      hint: 'Tu contraseña',
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
                  ] else
                    TextField(
                      controller: configController,
                      minLines: 6,
                      maxLines: 10,
                      decoration: InputDecoration(
                        labelText: 'Configuración importada',
                        hintText: 'Pega aquí tu configuración...',
                        filled: true,
                        fillColor: panel,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                  const SizedBox(height: 14),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: analyzing ? null : analyzeConfig,
                      icon: analyzing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
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

                  if (selectedProtocol == 'SSH') ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed:
                            connectingSsh ? null : connectSsh,
                        icon: connectingSsh
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.vpn_key),
                        label: Text(
                          connectingSsh
                              ? 'Conectando SSH...'
                              : 'Probar acceso SSH',
                        ),
                      ),
                    ),
                  ],
                ],
              ],

              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: blue),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tráfico: disponible cuando se instale '
                        'un motor VPN compatible.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 18),
              const Text(
                'REGISTRO DE ACTIVIDAD',
                style: TextStyle(
                  color: blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SelectableText(
                  result,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),
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

