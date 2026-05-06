import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class ReservaVisualizacaoPage extends StatefulWidget {
  final String reservaId;
  final DateTime data;
  final TimeOfDay hora;
  final int pessoas;
  final String idRestaurante;

  const ReservaVisualizacaoPage({
    super.key,
    required this.reservaId,
    required this.data,
    required this.hora,
    required this.pessoas,
    required this.idRestaurante,
  });

  @override
  State<ReservaVisualizacaoPage> createState() =>
      _ReservaVisualizacaoPageState();
}

class _ReservaVisualizacaoPageState extends State<ReservaVisualizacaoPage> {
  String endereco = 'Carregando endereço...';

  @override
  void initState() {
    super.initState();
    _carregarEndereco();
  }

  Future<void> _carregarEndereco() async {
  try {
    // 1) Valida a licença
    final licResp = await http.get(
      Uri.parse('https://barrest.tech/check_license.php'),
    );
    if (licResp.statusCode != 200) throw 'Erro ao obter licença';
    final licJson = json.decode(licResp.body) as Map<String, dynamic>;
    if (licJson['licensed'] != true) throw 'Licença inativa';
    final licenseId = licJson['id'].toString();

    // 2) Busca o restaurante pelo ID, passando a license como GET
    final uri = Uri.parse(
      'https://barrest.tech/get_restaurante.php'
      '?id=${widget.idRestaurante}'
      '&license=$licenseId',
    );
    final resp = await http.get(uri);

    if (resp.statusCode != 200) {
      debugPrint('get_restaurante.php respondeu: ${resp.body}');
      throw 'Status ${resp.statusCode}';
    }

    // 3) Parser do JSON plano { id, nome, endereco, logo, logo_url }
    final jsonRes = json.decode(resp.body) as Map<String, dynamic>;

    // 4) Extrai o endereço (ou texto padrão)
    final e = (jsonRes['endereco'] as String?)?.trim();
    setState(() => endereco = e != null && e.isNotEmpty
        ? e
        : 'Endereço não disponível');
  } catch (e) {
    setState(() => endereco = 'Endereço não disponível');
    debugPrint('Erro ao carregar endereço: $e');
  }
}

  Future<void> _abrirNoMaps() async {
    if (endereco.isEmpty || endereco.contains('disponível')) return;
    final query = Uri.encodeComponent(endereco);
    final mapsUrl =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    try {
      final launched = await launchUrl(
        mapsUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(mapsUrl, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o endereço.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataFmt =
        '${widget.data.day.toString().padLeft(2, '0')}/${widget.data.month.toString().padLeft(2, '0')}/${widget.data.year}';
    final horaFmt =
        '${widget.hora.hour.toString().padLeft(2, '0')}:${widget.hora.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFF1E2D24),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2D24),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        title:
            const Text('Minha Reserva', style: TextStyle(color: Color(0xFFD4AF37))),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              const Icon(Icons.event_available,
                  color: Color(0xFFD4AF37), size: 50),
              const SizedBox(height: 10),
              const Text('Detalhes da Reserva',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFFD4AF37), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.calendar_today,
                          color: Color(0xFFD4AF37)),
                      const SizedBox(width: 8),
                      Text('$dataFmt   $horaFmt',
                          style: const TextStyle(color: Colors.white)),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.people, color: Color(0xFFD4AF37)),
                      const SizedBox(width: 8),
                      Text(
                          '${widget.pessoas} Pessoa${widget.pessoas > 1 ? 's' : ''}',
                          style: const TextStyle(color: Colors.white)),
                    ]),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _abrirNoMaps,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on,
                              color: Color(0xFFD4AF37)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(endereco,
                                style: const TextStyle(
                                    color: Colors.white,
                                    decoration: TextDecoration.underline)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Semantics(
                label:
                    'QR Code da reserva. Use este código para confirmar sua presença no restaurante.',
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFFD4AF37), width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: widget.reservaId,
                    version: QrVersions.auto,
                    size: 180,
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
