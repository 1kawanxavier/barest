import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class HistoricoReservasPage extends StatefulWidget {
  const HistoricoReservasPage({super.key});

  @override
  State<HistoricoReservasPage> createState() => _HistoricoReservasPageState();
}

class _HistoricoReservasPageState extends State<HistoricoReservasPage> {
  bool carregando = true;
  String licenseId = '';
  String usuarioId = '';
  String restauranteId = '';
  List<Map<String, dynamic>> reservas = [];
  String? filtroSelecionado;
  DateTime? dataSelecionada;

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

    // 1) valida licença
    final licResp = await http.get(
      Uri.parse('https://barrest.tech/check_license.php'),
    );
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

    // 2) busca restaurante do proprietário
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

    // 3) carrega histórico
    await _carregarReservas();
  }

  Future<void> _carregarReservas() async {
    setState(() => carregando = true);
    final uri = Uri.parse(
      'https://barrest.tech/get_historico_reservas.php'
      '?license=$licenseId'
      '&restaurante_id=$restauranteId',
    );
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      _mostrarErro('Erro ao carregar histórico.');
      return;
    }
    final List<dynamic> data = json.decode(resp.body);
    setState(() {
      reservas = data.map((e) => Map<String, dynamic>.from(e)).toList();
      carregando = false;
    });
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
    );
    setState(() => carregando = false);
  }

  String formatarHorario(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat.Hm().format(dt);
    } catch (_) {
      return '00:00';
    }
  }

  String formatarData(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd/MM/yyyy').format(dt);
    } catch (_) {
      return 'Data inválida';
    }
  }

  Future<void> _cancelarReserva(String idReserva) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancelar Reserva'),
        content: const Text('Tem certeza que deseja cancelar esta reserva?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Não')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sim')),
        ],
      ),
    );
    if (confirmar != true) return;

    final uri = Uri.parse(
      'https://barrest.tech/delete_reserva.php'
      '?license=$licenseId'
      '&restaurante_id=$restauranteId'
      '&id=$idReserva',
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
    await _carregarReservas();
  }

  void _mostrarFiltroDialog() async {
    final res = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E2D24),
        title: const Text('Filtrar reservas', style: TextStyle(color: Color(0xFFD4AF37))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Todas', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, null),
            ),
            ListTile(
              title: const Text('Apenas utilizadas', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'usado'),
            ),
            ListTile(
              title: const Text('Apenas ativas', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'nao_usado'),
            ),
          ],
        ),
      ),
    );
    if (mounted) setState(() => filtroSelecionado = res);
  }

  void _selecionarDataFiltro() async {
    final data = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (data != null && mounted) setState(() => dataSelecionada = data);
  }

  @override
  Widget build(BuildContext context) {
    var lista = reservas;
    if (filtroSelecionado == 'usado') {
      lista = lista.where((r) => r['usado'] == 1 || r['usado'] == true).toList();
    } else if (filtroSelecionado == 'nao_usado') {
      lista = lista.where((r) => r['usado'] == 0 || r['usado'] == null).toList();
    }
    if (dataSelecionada != null) {
      lista = lista.where((r) {
        final dt = DateTime.tryParse(r['data_reserva'] ?? '') ?? DateTime(0);
        return dt.year == dataSelecionada!.year &&
               dt.month == dataSelecionada!.month &&
               dt.day == dataSelecionada!.day;
      }).toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E2D24),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2D24),
        elevation: 0,
        leading: const BackButton(color: Color(0xFFD4AF37)),
        title: const Text(
          'Histórico de Reservas',
          style: TextStyle(
            color: Color(0xFFD4AF37),
            fontSize: 22,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Color(0xFFD4AF37)),
            onPressed: _mostrarFiltroDialog,
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Color(0xFFD4AF37)),
            onPressed: _selecionarDataFiltro,
          ),
        ],
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : lista.isEmpty
              ? const Center(
                  child: Text('Nenhuma reserva encontrada.', style: TextStyle(color: Colors.white)),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: Image.asset('assets/logo-Transparente.png', height: 80),
                    ),
                    if (filtroSelecionado != null || dataSelecionada != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            filtroSelecionado = null;
                            dataSelecionada = null;
                          });
                        },
                        child: const Text('Limpar filtro', style: TextStyle(color: Color(0xFFD4AF37))),
                      ),
                    const SizedBox(height: 16),
                    ...lista.map((reserva) {
                      final nome = reserva['usuario_nome']?.toString().trim() ?? 'Cliente';
                      final qtd = reserva['quantidade_pessoas'] ?? 0;
                      final dtIso = reserva['data_reserva'] ?? '';
                      final data = formatarData(dtIso);
                      final hora = formatarHorario(dtIso);
                      final usado = reserva['usado'] == 1 || reserva['usado'] == true;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Material(
                          color: usado ? Colors.white10 : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: usado ? null : () => _cancelarReserva(reserva['id'].toString()),
                            borderRadius: BorderRadius.circular(12),
                            splashColor: const Color(0x33D4AF37),
                            highlightColor: const Color(0x22D4AF37),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: usado ? Colors.grey : const Color(0xFFD4AF37)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.calendar_today, color: Color(0xFFD4AF37)),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(nome, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                  ]),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    const Icon(Icons.people, color: Color(0xFFD4AF37)),
                                    const SizedBox(width: 8),
                                    Text('$qtd Pessoas', style: const TextStyle(color: Colors.white)),
                                  ]),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    const Icon(Icons.calendar_month, color: Color(0xFFD4AF37)),
                                    const SizedBox(width: 8),
                                    Text('$data às $hora', style: const TextStyle(color: Colors.white)),
                                  ]),
                                  if (usado)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text('Reserva já utilizada', style: TextStyle(color: Colors.grey)),
                                    ),
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
