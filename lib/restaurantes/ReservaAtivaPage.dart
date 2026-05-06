import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class ReservaAtivaPage extends StatefulWidget {
  const ReservaAtivaPage({super.key});

  @override
  State<ReservaAtivaPage> createState() => _ReservaAtivaPageState();
}

class _ReservaAtivaPageState extends State<ReservaAtivaPage> {
  bool carregando = true;
  String licenseId = '';
  String usuarioId = '';
  String restauranteId = '';
  List<Map<String, dynamic>> reservas = [];

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    final prefs = await SharedPreferences.getInstance();
    final uId = prefs.getString('usuario_id');
    if (uId == null) {
      _mostrarErro('Usuário não autenticado.');
      return;
    }
    usuarioId = uId;

    // 1) validar licença
    final licResp = await http.get(Uri.parse('https://barrest.tech/check_license.php'));
    if (licResp.statusCode != 200) {
      _mostrarErro('Erro ao validar licença.');
      return;
    }
    final licJson = json.decode(licResp.body) as Map<String, dynamic>;
    if (licJson['licensed'] != true) {
      _mostrarErro('Licença inativa.');
      return;
    }
    licenseId = licJson['id'].toString();

    // 2) buscar id do restaurante
    final restUri = Uri.parse(
      'https://barrest.tech/get_restaurante_by_owner.php'
      '?license=$licenseId'
      '&usuario_id=$usuarioId',
    );
    final restResp = await http.get(restUri);
    if (restResp.statusCode != 200) {
      _mostrarErro('Falha ao carregar restaurante.');
      return;
    }
    final restJson = json.decode(restResp.body) as Map<String, dynamic>;
    if (restJson['restaurante'] == null) {
      _mostrarErro('Restaurante não encontrado.');
      return;
    }
    restauranteId = restJson['restaurante']['id'].toString();

    // 3) carregar reservas
    await _carregarReservasAtivas();
  }

  Future<void> _carregarReservasAtivas() async {
    setState(() => carregando = true);
    final uri = Uri.parse(
      'https://barrest.tech/get_reservas_ativas.php'
      '?license=$licenseId'
      '&restaurante_id=$restauranteId',
    );
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      _mostrarErro('Erro ao buscar reservas.');
      return;
    }
    final List<dynamic> data = json.decode(resp.body);
    setState(() {
      reservas = data.map((e) => Map<String, dynamic>.from(e)).toList();
      carregando = false;
    });
  }

  Future<void> _confirmarCancelamentoReserva(String reservaId) async {
    final confirmacao = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: const Text('Tem certeza que deseja cancelar esta reserva?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Fechar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar reserva', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmacao != true) return;

    final uri = Uri.parse(
      'https://barrest.tech/delete_reserva.php'
      '?license=$licenseId'
      '&restaurante_id=$restauranteId'
      '&id=$reservaId',
    );
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      _mostrarErro('Erro ao cancelar reserva.');
      return;
    }
    final j = json.decode(resp.body) as Map<String, dynamic>;
    if (j['success'] != true) {
      _mostrarErro(j['error'] ?? 'Falha desconhecida.');
      return;
    }
    await _carregarReservasAtivas();
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
    );
    setState(() => carregando = false);
  }

  String _formatarHorario(String isoString) {
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat.Hm().format(dt);
    } catch (_) {
      return '00:00';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2D24),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2D24),
        elevation: 0,
        leading: const BackButton(color: Color(0xFFD4AF37)),
        title: const Text(
          'Reservas Ativas',
          style: TextStyle(
            color: Color(0xFFD4AF37),
            fontSize: 22,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : reservas.isEmpty
              ? const Center(child: Text('Nenhuma reserva ativa.', style: TextStyle(color: Colors.white)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Semantics(
                      label: 'Logo da Barrest',
                      child: Center(
                        child: Image.asset('assets/logo-Transparente.png', height: 80),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...reservas.map((reserva) {
                        final nomeUsuario = reserva['usuario_nome']?.toString().trim() ?? 'Cliente';
                        final quantidade = reserva['quantidade_pessoas'] ?? 0;
                        final horario = _formatarHorario(reserva['data_reserva'] ?? '');

                        final List pratos = reserva['pratos'] is List ? reserva['pratos'] : [];

                        return Semantics(
                          label: 'Reserva para $quantidade pessoas às $horario de $nomeUsuario',
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: InkWell(
                              onTap: () => _confirmarCancelamentoReserva(reserva['id'].toString()),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFD4AF37)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      const Icon(Icons.calendar_today, color: Color(0xFFD4AF37)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          nomeUsuario,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ]),
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      const Icon(Icons.people, color: Color(0xFFD4AF37)),
                                      const SizedBox(width: 8),
                                      Text(
                                        '$quantidade Pessoas',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ]),
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      const Icon(Icons.access_time, color: Color(0xFFD4AF37)),
                                      const SizedBox(width: 8),
                                      Text(
                                        horario,
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ]),

                                    if (pratos.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      const Divider(color: Color(0xFFD4AF37)),
                                      const SizedBox(height: 6),
                                      const Row(
                                        children: [
                                          Icon(Icons.restaurant_menu, color: Color(0xFFD4AF37)),
                                          SizedBox(width: 8),
                                          Text(
                                            'Pratos reservados',
                                            style: TextStyle(
                                              color: Color(0xFFD4AF37),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      ...pratos.map((p) {
                                        final nomePrato = p['nome_prato']?.toString() ?? 'Prato';
                                        final qtd = p['quantidade']?.toString() ?? '1';

                                        return Padding(
                                          padding: const EdgeInsets.only(left: 32, bottom: 4),
                                          child: Text(
                                            '${qtd}x $nomePrato',
                                            style: const TextStyle(color: Colors.white70),
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                  ],
                ),
    );
  }
}
