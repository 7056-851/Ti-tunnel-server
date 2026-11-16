import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MiTunnelApp());
}

class MiTunnelApp extends StatelessWidget {
  const MiTunnelApp({super.key});

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF08111F);
    return MaterialApp(
      title: 'Mi Tunnel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: navy,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF142238),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
          ),
        ),
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
  static const Color blue = Color(0xFF38BDF8);
  static const Color panel = Color(0xFF142238);
  static const Color panelLight = Color(0xFF1A2D47);

  final String serverUrl = 'https://ti-tunnel-server.onrender.com';

  final hostController = TextEditingController();
  final portController = TextEditingController(text: '22');
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final payloadController = TextEditingController();
  final configController = TextEditingController();
  final sniController = TextEditingController();
  final hostHeaderController = TextEditingController();
  final serverNameController = TextEditingController();
  final dnsttController = TextEditingController();

  final List<String> protocols = const [
    'SSH',
    'OpenVPN',
    'WireGuard',
    'VMess',
    'VLESS',
    'Xray',
  ];

  final List<String> connectionModes = const [
    'Direct Connection',
    'Custom Payload',
    'Custom Host Header',
    'Custom SNI',
    'DNSTT Tunnel',
    'Imported Config',
  ];

  String selectedProtocol = 'SSH';
  String selectedMode = 'Custom SNI';
  String result = 'Esperando configuración...';
  String serverStatus = 'Comprobando servidor...';
  String importedFileName = '';
  int selectedTabIndex = 0;

  bool analyzing = false;
  bool checkingServer = false;
  bool connectingSsh = false;
  bool hidePassword = true;
  bool customSetup = true;
  bool serverOnline = false;

  SSHClient? sshClient;
  final List<String> activityLog = [];

  @override
  void initState() {
    super.initState();
    _addLog('Mi Tunnel iniciado.');
    checkServer();
  }

  void _addLog(String message) {
    final now = DateTime.now();
    final stamp = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    activityLog.insert(0, '[$stamp] $message');
    if (activityLog.length > 50) activityLog.removeLast();
  }

  Future<void> checkServer() async {
    if (checkingServer) return;
    setState(() {
      checkingServer = true;
      serverStatus = 'Comprobando servidor...';
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse('$serverUrl/api/status'));
      final response = await request.close().timeout(const Duration(seconds: 25));
      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body);
      final online = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data is Map &&
          data['status'] == 'active' &&
          data['server'] == 'Mi Tunnel';
      if (!mounted) return;
      setState(() {
        serverOnline = online;
        serverStatus = online ? 'Servidor Mi Tunnel conectado' : 'Servidor no disponible';
      });
      _addLog(online ? 'Servidor Render disponible.' : 'El servidor respondió, pero no confirmó estado activo.');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        serverOnline = false;
        serverStatus = 'Servidor no disponible';
      });
      _addLog('No se pudo comprobar Render: $e');
    } finally {
      client.close(force: true);
      if (mounted) setState(() => checkingServer = false);
    }
  }

  String _buildModeContent() {
    final host = hostController.text.trim();
    final port = portController.text.trim();
    switch (selectedMode) {
      case 'Direct Connection':
        return 'Mode: Direct Connection\nHost: $host\nPort: $port';
      case 'Custom Payload':
        return 'Mode: Custom Payload\nHost: $host\nPort: $port\nPayload: ${payloadController.text.trim()}';
      case 'Custom Host Header':
        return 'Mode: Custom Host Header\nHost: $host\nPort: $port\nHost Header: ${hostHeaderController.text.trim()}\nPayload: ${payloadController.text.trim()}';
      case 'Custom SNI':
        return 'Mode: Custom SNI\nHost: $host\nPort: $port\nSNI: ${sniController.text.trim()}\nServer Name: ${serverNameController.text.trim()}';
      case 'DNSTT Tunnel':
        return 'Mode: DNSTT Tunnel\nHost: $host\nPort: $port\nDNSTT Domain: ${dnsttController.text.trim()}';
      case 'Imported Config':
        if (selectedProtocol == 'SSH') {
          return 'Host: $host\nPort: $port\nUsername: ${usernameController.text.trim()}\nPassword: ${passwordController.text.isNotEmpty ? 'configured' : ''}\nPayload: ${payloadController.text.trim().isNotEmpty ? 'configured' : ''}';
        }
        return configController.text.trim();
      default:
        return configController.text.trim();
    }
  }

  Future<void> analyzeConfig() async {
    final host = hostController.text.trim();
    final portText = portController.text.trim();

    if (selectedMode != 'Imported Config' || selectedProtocol == 'SSH') {
      final port = int.tryParse(portText);
      if (host.isEmpty || port == null || port < 1 || port > 65535) {
        setState(() => result = 'Introduce un servidor y un puerto válido (1–65535).');
        _addLog('Análisis detenido: servidor o puerto inválido.');
        return;
      }
    }

    final content = _buildModeContent();
    if (content.trim().isEmpty) {
      setState(() => result = 'Pega o carga una configuración antes de analizar.');
      return;
    }

    setState(() {
      analyzing = true;
      result = 'Conectando con el servidor Mi Tunnel...';
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.postUrl(Uri.parse('$serverUrl/api/detect'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({
        'filename': '${selectedProtocol}_${selectedMode.replaceAll(' ', '_')}.txt',
        'content': content,
        'mode': selectedMode,
        'protocol': selectedProtocol,
      }));
      final response = await request.close().timeout(const Duration(seconds: 60));
      final responseText = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Error HTTP ${response.statusCode}: $responseText');
      }
      final decoded = jsonDecode(responseText);
      if (!mounted) return;
      setState(() => result = const JsonEncoder.withIndent('  ').convert(decoded));
      _addLog('Análisis completado: $selectedMode / $selectedProtocol.');
    } catch (e) {
      if (!mounted) return;
      setState(() => result = 'No se pudo analizar la configuración.\n\nComprueba Internet y el servidor Render.\n\nDetalle: $e');
      _addLog('Error durante el análisis: $e');
    } finally {
      client.close(force: true);
      if (mounted) setState(() => analyzing = false);
    }
  }

  Future<void> connectSsh() async {
    final host = hostController.text.trim();
    final port = int.tryParse(portController.text.trim());
    final username = usernameController.text.trim();
    final password = passwordController.text;

    if (host.isEmpty || username.isEmpty || password.isEmpty ||
        port == null || port < 1 || port > 65535) {
      setState(() => result = 'Completa servidor, puerto, usuario y contraseña.');
      return;
    }

    setState(() {
      connectingSsh = true;
      result = 'Conectando al servidor SSH...';
    });
    SSHClient? candidate;
    try {
      final socket = await SSHSocket.connect(host, port, timeout: const Duration(seconds: 15));
      final newClient = SSHClient(
        socket,
        username: username,
        onPasswordRequest: () => password,
        handshakeTimeout: const Duration(seconds: 15),
        authTimeout: const Duration(seconds: 20),
        onVerifyHostKey: (type, fingerprint) async {
          final fingerprintText = base64.encode(fingerprint);
          if (!mounted) return false;
          final accepted = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Verificar servidor SSH'),
              content: SelectableText(
                'Tipo de clave: $type\n\nHuella (base64):\n$fingerprintText\n\nCompara esta huella con la proporcionada por tu proveedor mediante un canal confiable. Si no puedes verificarla, rechaza la conexión.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Rechazar')),
                FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Huella verificada')),
              ],
            ),
          );
          return accepted ?? false;
        },
      );
      candidate = newClient;
      await newClient.authenticated.timeout(const Duration(seconds: 25));
      if (!mounted) {
        await newClient.close();
        return;
      }
      await sshClient?.close();
      setState(() {
        sshClient = newClient;
        result = '¡Conexión SSH autenticada correctamente!\nServidor: $host\nPuerto: $port\nUsuario: $username\nEstado: conectado';
      });
      _addLog('Autenticación SSH correcta en $host:$port.');
    } catch (e) {
      await candidate?.close();
      if (!mounted) return;
      setState(() => result = 'No se pudo establecer la conexión SSH.\n\nDetalle: $e');
      _addLog('Falló la conexión SSH: $e');
    } finally {
      if (mounted) setState(() => connectingSsh = false);
    }
  }

  Future<void> disconnectSsh() async {
    final client = sshClient;
    if (client == null) return;

    setState(() {
      sshClient = null;
      result = "Cerrando conexión SSH...";
    });

    try {
      await client.close();
      if (!mounted) return;
      setState(() => result = "Conexión SSH cerrada. Estado: desconectado");
      _addLog("Conexión SSH cerrada.");
    } catch (e) {
      if (!mounted) return;
      setState(() => result = "Error al cerrar SSH: $e");
      _addLog("Error al desconectar SSH: $e");
    }
  }

  Future<void> importConfig() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['conf', 'ovpn', 'txt', 'wg', 'json'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null) throw const FormatException('No se pudo leer el archivo seleccionado.');
      final text = utf8.decode(bytes, allowMalformed: true);
      setState(() {
        importedFileName = file.name;
        configController.text = text;
        selectedMode = 'Imported Config';
        if (file.extension == 'ovpn') selectedProtocol = 'OpenVPN';
        if (file.extension == 'wg') selectedProtocol = 'WireGuard';
        if (file.extension == 'json') selectedProtocol = 'Xray';
      });
      _addLog('Configuración importada: ${file.name}.');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Archivo cargado: ${file.name}')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo importar: $e')));
    }
  }

  Widget _field({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        minLines: maxLines == 1 ? 1 : maxLines,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, hintText: hint, suffixIcon: suffix),
      ),
    );
  }

  Widget _sectionTitle(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 11),
      child: Row(children: [
        if (icon != null) ...[Icon(icon, color: blue, size: 18), const SizedBox(width: 8)],
        Text(title, style: const TextStyle(color: blue, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
      ]),
    );
  }

  Widget _modeCard(String mode, IconData icon, String description) {
    final selected = selectedMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => setState(() => selectedMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF123D70) : panel,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: selected ? blue : Colors.white10, width: selected ? 1.4 : 1),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: selected ? blue.withValues(alpha: .14) : panelLight, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: selected ? blue : Colors.white70),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(mode, style: TextStyle(fontWeight: FontWeight.bold, color: selected ? Colors.white : Colors.white.withValues(alpha: .9))),
            const SizedBox(height: 3),
            Text(description, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ])),
          Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? blue : Colors.white30),
        ]),
      ),
    );
  }

  Widget _serverCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)),
      child: Row(children: [
        Icon(serverOnline ? Icons.cloud_done : Icons.cloud_off, color: serverOnline ? Colors.greenAccent : Colors.orangeAccent, size: 25),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(serverStatus, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          const Text('API de Mi Tunnel · Render', style: TextStyle(color: Colors.white54, fontSize: 12)),
        ])),
        IconButton(onPressed: checkingServer ? null : checkServer, icon: checkingServer ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh, color: blue), tooltip: 'Comprobar servidor'),
      ]),
    );
  }

  Widget _modeConfiguration() {
    switch (selectedMode) {
      case 'Direct Connection':
        return const _InfoPanel(text: 'Conexión directa a Internet. El motor de conexión todavía no está instalado. Esta opción no crea un túnel VPN por sí sola.');
      case 'Custom Payload':
        return _field(label: 'Payload', hint: 'Introduce tu payload', controller: payloadController, maxLines: 4);
      case 'Custom Host Header':
        return Column(children: [
          _field(label: 'Host Header', hint: 'www.ejemplo.com', controller: hostHeaderController),
          _field(label: 'Payload (opcional)', hint: 'Introduce tu payload', controller: payloadController, maxLines: 3),
        ]);
      case 'Custom SNI':
        return Column(children: [
          _field(label: 'SNI', hint: 'servidor.ejemplo.com', controller: sniController),
          _field(label: 'Nombre del servidor', hint: 'Nombre TLS del servidor', controller: serverNameController),
        ]);
      case 'DNSTT Tunnel':
        return _field(label: 'Dominio DNSTT', hint: 'tunel.ejemplo.com', controller: dnsttController);
      case 'Imported Config':
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DropdownButtonFormField<String>(
            value: selectedProtocol,
            decoration: const InputDecoration(labelText: 'Protocolo'),
            items: protocols.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (value) => setState(() => selectedProtocol = value ?? 'SSH'),
          ),
          const SizedBox(height: 13),
          if (selectedProtocol == 'SSH') ...[
            _field(label: 'Usuario SSH', hint: 'Tu usuario', controller: usernameController),
            _field(
              label: 'Contraseña SSH', hint: 'Tu contraseña', controller: passwordController,
              obscure: hidePassword,
              suffix: IconButton(icon: Icon(hidePassword ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => hidePassword = !hidePassword)),
            ),
            _field(label: 'Payload (opcional)', hint: 'Introduce tu payload', controller: payloadController, maxLines: 3),
          ],
          if (selectedProtocol != 'SSH') ...[
            OutlinedButton.icon(onPressed: importConfig, icon: const Icon(Icons.file_open), label: const Text('Seleccionar archivo de configuración')),
            if (importedFileName.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('Archivo: $importedFileName', style: const TextStyle(color: blue))),
            TextField(
              controller: configController,
              minLines: 6,
              maxLines: 10,
              decoration: const InputDecoration(labelText: 'Configuración importada', hintText: 'Pega aquí tu configuración...'),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(height: 48, child: FilledButton.icon(
            onPressed: analyzing ? null : analyzeConfig,
            icon: analyzing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.analytics_outlined),
            label: Text(analyzing ? 'Analizando...' : 'Analizar configuración'),
          )),
          if (selectedProtocol == 'SSH') ...[
            const SizedBox(height: 9),
            SizedBox(height: 48, child: OutlinedButton.icon(
              onPressed: connectingSsh ? null : connectSsh,
              icon: connectingSsh ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.vpn_key_outlined),
              label: Text(connectingSsh ? 'Conectando SSH...' : 'Probar acceso SSH'),
            )),
            const SizedBox(height: 9),
            SizedBox(height: 48, child: OutlinedButton.icon(onPressed: sshClient == null || connectingSsh ? null : disconnectSsh, icon: const Icon(Icons.link_off), label: const Text("Desconectar SSH"))),
          ],
        ]);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _homePage() {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 18, 16, 28), children: [
      Container(
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF123D70), Color(0xFF10243D)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: blue.withValues(alpha: .18)),
        ),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.shield_moon_rounded, size: 38, color: blue),
          SizedBox(height: 12),
          Text('Tu conexión segura', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
          SizedBox(height: 5),
          Text('Configura tu modo de conexión.', style: TextStyle(color: Colors.white70)),
        ]),
      ),
      const SizedBox(height: 15),
      _serverCard(),
      _sectionTitle('SERVIDOR', icon: Icons.dns_outlined),
      _field(label: 'Host / Servidor', hint: 'ejemplo.com', controller: hostController),
      _field(label: 'Puerto', hint: '22', controller: portController, keyboardType: TextInputType.number),
      Container(
        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(14)),
        child: SwitchListTile(
          value: customSetup,
          activeColor: blue,
          title: const Text('CUSTOM SETUP', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Mostrar opciones de configuración', style: TextStyle(color: Colors.white60, fontSize: 12)),
          onChanged: (value) => setState(() => customSetup = value),
        ),
      ),
      if (customSetup) ...[
        _sectionTitle('MODO DE CONEXIÓN', icon: Icons.tune),
        _modeCard('Direct Connection', Icons.public, 'Conexión directa a Internet'),
        const SizedBox(height: 9),
        _modeCard('Custom Payload', Icons.code, 'Configura una solicitud personalizada'),
        const SizedBox(height: 9),
        _modeCard('Custom Host Header', Icons.http, 'Personaliza el encabezado Host'),
        const SizedBox(height: 9),
        _modeCard('Custom SNI', Icons.security, 'Configura el nombre TLS del servidor'),
        const SizedBox(height: 9),
        _modeCard('DNSTT Tunnel', Icons.dns, 'Dominio para un motor DNSTT compatible'),
        const SizedBox(height: 9),
        _modeCard('Imported Config', Icons.file_open, 'Importa o pega una configuración'),
        _sectionTitle('CONFIGURACIÓN DEL MODO', icon: Icons.settings_outlined),
        _modeConfiguration(),
      ],
      const SizedBox(height: 18),
      const _InfoPanel(text: 'Tráfico: disponible cuando se instale un motor VPN compatible. Mi Tunnel todavía no establece un túnel VPN de tráfico.'),
      const SizedBox(height: 12),
      const Center(child: Text('Mi Tunnel • Motor VPN en desarrollo', style: TextStyle(color: Colors.white54, fontSize: 12))),
    ]);
  }

  Widget _logPage() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      _sectionTitle('REGISTRO DE ACTIVIDAD', icon: Icons.receipt_long),
      if (activityLog.isEmpty) const _InfoPanel(text: 'Todavía no hay actividad registrada.'),
      ...activityLog.map((entry) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(12)),
        child: Text(entry, style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.white70)),
      )),
      _sectionTitle('ÚLTIMO RESULTADO', icon: Icons.article_outlined),
      Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: panel, borderRadius: BorderRadius.circular(13)), child: SelectableText(result, style: const TextStyle(fontSize: 12, height: 1.5))),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: () => setState(() { activityLog.clear(); _addLog('Registro limpiado.'); }), icon: const Icon(Icons.delete_outline), label: const Text('Limpiar registro')),
    ]);
  }

  @override
  void dispose() {
    sshClient?.close();
    hostController.dispose();
    portController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    payloadController.dispose();
    configController.dispose();
    sniController.dispose();
    hostHeaderController.dispose();
    serverNameController.dispose();
    dnsttController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF101E32),
        centerTitle: true,
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.shield_rounded, color: blue),
          SizedBox(width: 9),
          Text('MI TUNNEL', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
        ]),
      ),
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(children: [
            Expanded(child: _tabButton('HOME', 0, Icons.home_outlined)),
            const SizedBox(width: 10),
            Expanded(child: _tabButton('LOG', 1, Icons.receipt_long_outlined)),
          ]),
        ),
        Expanded(child: selectedTabIndex == 0 ? _homePage() : _logPage()),
      ])),
    );
  }

  Widget _tabButton(String label, int index, IconData icon) {
    final selected = selectedTabIndex == index;
    return FilledButton.tonalIcon(
      onPressed: () => setState(() => selectedTabIndex = index),
      style: FilledButton.styleFrom(
        backgroundColor: selected ? const Color(0xFF123D70) : panel,
        foregroundColor: selected ? Colors.white : Colors.white70,
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFF142238), borderRadius: BorderRadius.circular(13), border: Border.all(color: Colors.white10)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, color: Color(0xFF38BDF8)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.white70, height: 1.4))),
      ]),
    );
  }
}
