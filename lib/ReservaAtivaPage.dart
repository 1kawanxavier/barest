import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ReservaAtivaPage extends StatefulWidget {
  final String reservaId;
  final DateTime data;
  final TimeOfDay hora;
  final int pessoas;
  final String idRestaurante;

  const ReservaAtivaPage({
    super.key,
    required this.reservaId,
    required this.data,
    required this.hora,
    required this.pessoas,
    required this.idRestaurante,
  });

  @override
  State<ReservaAtivaPage> createState() => _ReservaAtivaPageState();
}

class _ReservaAtivaPageState extends State<ReservaAtivaPage> {
  String endereco = '';
  bool _isLoadingEndereco = true;

  @override
  void initState() {
    super.initState();
    carregarEndereco();
  }

  Future<void> carregarEndereco() async {
    try {
      // 1) Verifica licença ativa
      final licResp = await http.get(
        Uri.parse('https://barrest.tech/check_license.php'),
      );
      if (licResp.statusCode != 200) {
        throw 'Erro ao obter licença: ${licResp.statusCode}';
      }
      final licJson = json.decode(licResp.body) as Map<String, dynamic>;
      if (licJson['licensed'] != true) {
        throw 'Nenhuma licença ativa';
      }
      final String licenseId = licJson['id'].toString();

      // 2) Monta URI para get_restaurante.php
      final uri = Uri.https(
        'barrest.tech',
        '/get_restaurante.php',
        {
          'license': licenseId,
          'id': widget.idRestaurante,
        },
      );

      // Mostra no console a URL completa que será chamada
      debugPrint('Chamando URL: ${uri.toString()}');

      // 3) Faz a requisição
      final resp = await http.get(uri);
      debugPrint('get_restaurante.php respondeu: ${resp.statusCode} ${resp.body}');

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        setState(() {
          endereco = (data['endereco'] ?? '').toString().trim();
          _isLoadingEndereco = false;
        });
      } else {
        throw 'Status ${resp.statusCode}';
      }
    } catch (e) {
      setState(() {
        endereco = 'Endereço não disponível';
        _isLoadingEndereco = false;
      });
      debugPrint('Erro ao carregar endereço: $e');
    }
  }

  Future<void> abrirNoMaps() async {
    if (_isLoadingEndereco || endereco.isEmpty) return;

    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(endereco)}',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o Google Maps.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataFormatada =
        '${widget.data.day.toString().padLeft(2, '0')}/${widget.data.month.toString().padLeft(2, '0')}/${widget.data.year}';
    final horaFormatada =
        '${widget.hora.hour.toString().padLeft(2, '0')}:${widget.hora.minute.toString().padLeft(2, '0')}';

    final enderecoTexto = _isLoadingEndereco
        ? 'Carregando endereço...'
        : (endereco.isNotEmpty ? endereco : 'Endereço não disponível');

    return Scaffold(
      backgroundColor: const Color(0xFF1E2D24),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: Color(0xFFD4AF37)),
                    tooltip: 'Menu do aplicativo',
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Semantics(
                label:
                    'Logo da Barrest: um garfo à esquerda e uma faca à direita formando uma moldura que envolve uma casa estilizada com dois telhados. Abaixo, a palavra BARREST em letras maiúsculas.',
                child: Image.asset(
                  'assets/logo-Transparente.png',
                  height: 100,
                ),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.check_circle, color: Color(0xFFD4AF37), size: 50),
              const SizedBox(height: 10),
              
              const Text(
                'Reserva Confirmada',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Mostre o QR code da sua confirmação\n ao chegar no estabelecimento.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFD4AF37), fontSize: 14),
              ),
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
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Color(0xFFD4AF37)),
                        const SizedBox(width: 8),
                        Text(
                          '$dataFormatada   $horaFormatada',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.people, color: Color(0xFFD4AF37)),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.pessoas} Pessoa${widget.pessoas > 1 ? 's' : ''}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: abrirNoMaps,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, color: Color(0xFFD4AF37)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              enderecoTexto,
                              style: const TextStyle(
                                color: Colors.white,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Semantics(
                label: 'QR Code da reserva. Use este código para confirmar sua presença.',
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
