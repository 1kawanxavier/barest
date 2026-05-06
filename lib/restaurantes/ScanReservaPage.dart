import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;

class ScanReservaPage extends StatefulWidget {
  const ScanReservaPage({super.key});

  @override
  State<ScanReservaPage> createState() => _ScanReservaPageState();
}

class _ScanReservaPageState extends State<ScanReservaPage> {
  final MobileScannerController scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  Map<String, dynamic>? reservaInfo;
  bool carregando = false;
  bool escaneado = false;
  String licenseId = '';

  @override
  void initState() {
    super.initState();
    _loadLicense();
  }

  Future<void> _loadLicense() async {
    final licResp = await http.get(
      Uri.parse('https://barrest.tech/check_license.php'),
    );

    if (licResp.statusCode == 200) {
      final licJson = json.decode(licResp.body);
      if (licJson['licensed'] == true) {
        setState(() => licenseId = licJson['id'].toString());
        return;
      }
    }

    _mostrarErro('Licença inválida.');
  }

  Future<void> _buscarReserva(String idReserva) async {
    if (idReserva.isEmpty || idReserva.length > 64) {
      _mostrarErro('Código inválido.');
      setState(() => escaneado = false);
      scannerController.start();
      return;
    }

    setState(() => carregando = true);

    final uri = Uri.parse(
      'https://barrest.tech/get_reserva_min.php'
      '?license=$licenseId'
      '&id=$idReserva',
    );

    try {
      final resp = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Tempo de requisição excedido');
        },
      );

      final body = json.decode(resp.body) as Map<String, dynamic>;

      if (resp.statusCode == 200) {
        setState(() => reservaInfo = body);
      } else {
        final msg = body['error'] as String? ?? 'Erro desconhecido';
        _mostrarErro(msg);
        setState(() => escaneado = false);
        scannerController.start();
      }
    } on TimeoutException catch (_) {
      _mostrarErro('Tempo de resposta do servidor excedido.');
      setState(() => escaneado = false);
      scannerController.start();
    } catch (e) {
      _mostrarErro('Falha ao buscar reserva: $e');
      setState(() => escaneado = false);
      scannerController.start();
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  Future<void> _confirmarReserva() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar Reserva'),
        content: const Text('Deseja confirmar esta reserva?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Não'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sim'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => carregando = true);

    final uri = Uri.parse('https://barrest.tech/update_reserva_restaurante.php');

    final resp = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'license': licenseId,
        'id': reservaInfo!['id'],
      }),
    );

    setState(() => carregando = false);

    if (resp.statusCode == 200) {
      final j = json.decode(resp.body);
      if (j['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reserva confirmada com sucesso!')),
        );
        Navigator.pop(context);
        return;
      }
    }

    _mostrarErro('Falha ao confirmar reserva.');
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  void dispose() {
    scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2D24),
      body: SafeArea(
        child: Stack(
          children: [
            if (!escaneado && !carregando)
              MobileScanner(
                controller: scannerController,
                onDetect: (capture) {
                  final barcode = capture.barcodes.firstOrNull;
                  final idReserva = barcode?.rawValue;

                  if (idReserva != null && !escaneado && licenseId.isNotEmpty) {
                    setState(() => escaneado = true);

                    scannerController.stop();
                    debugPrint('QR code lido: $idReserva');
                    _buscarReserva(idReserva);
                  }
                },
              )
            else if (carregando)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
              )
            else
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: _buildInfoReserva(),
                ),
              ),

            Positioned(
              top: 16,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFFD4AF37)),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Image.asset('assets/logo-Transparente.png', height: 60),
                  const SizedBox(height: 8),
                  const Text(
                    'Scan Reserva',
                    style: TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoReserva() {
    final nome = reservaInfo?['usuario_nome'] ?? 'Usuário';
    final pessoas = reservaInfo?['quantidade_pessoas']?.toString() ?? '0';
    final dataHora = reservaInfo?['data_reserva'] ?? '';
    final hora = dataHora.length >= 16 ? dataHora.substring(11, 16) : '00:00';

    final List pratos =
        reservaInfo?['pratos'] is List ? reservaInfo!['pratos'] : [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(
          Icons.event_available,
          size: 100,
          color: Color(0xFFD4AF37),
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD4AF37)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow(Icons.person, nome),
              const SizedBox(height: 8),
              _infoRow(Icons.people, '$pessoas pessoa(s)'),
              const SizedBox(height: 8),
              _infoRow(Icons.access_time, hora),

              if (pratos.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Divider(color: Color(0xFFD4AF37)),
                const SizedBox(height: 8),

                const Row(
                  children: [
                    Icon(Icons.restaurant_menu, color: Color(0xFFD4AF37)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pratos reservados',
                        style: TextStyle(
                          color: Color(0xFFD4AF37),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                ...pratos.map((p) {
                  final nomePrato = p['nome_prato']?.toString() ?? 'Prato';
                  final quantidade = p['quantidade']?.toString() ?? '1';

                  return Padding(
                    padding: const EdgeInsets.only(left: 36, bottom: 6),
                    child: Text(
                      '${quantidade}x $nomePrato',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                }).toList(),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _confirmarReserva,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          ),
          child: const Text(
            'CONFIRMAR',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFD4AF37)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}