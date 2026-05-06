import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class HistoricoPage extends StatefulWidget {
  const HistoricoPage({super.key});

  @override
  State<HistoricoPage> createState() => _HistoricoPageState();
}

class _HistoricoPageState extends State<HistoricoPage> {
  List<Map<String, dynamic>> historico = [];
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarHistorico();
  }

  Future<void> _carregarHistorico() async {
    setState(() => carregando = true);
    try {
      // 1) lê usuário
      final prefs = await SharedPreferences.getInstance();
      final usuarioId = prefs.getString('usuario_id') ?? '';
      if (usuarioId.isEmpty) {
        throw 'Usuário não identificado';
      }

      // 2) valida licença
      final licResp = await http.get(Uri.parse('https://barrest.tech/check_license.php'));
      if (licResp.statusCode != 200) throw 'Erro ao obter licença';
      final licJson = json.decode(licResp.body) as Map<String, dynamic>;
      if (licJson['licensed'] != true) throw 'Licença inativa';
      final licenseId = licJson['id'].toString();
      final authHeader = 'Basic ${base64Encode(utf8.encode(':$licenseId'))}';

      // 3) chama o endpoint de histórico
      final uri = Uri.parse('https://barrest.tech/get_historico.php');
      final resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': authHeader,
        },
        body: json.encode({'usuario_id': usuarioId}),
      );

      if (resp.statusCode != 200) {
        debugPrint('get_historico.php: ${resp.body}');
        throw 'Status ${resp.statusCode}';
      }

      final jsonRes = json.decode(resp.body) as Map<String, dynamic>;
      if (jsonRes['success'] != true || jsonRes['historico'] == null) {
        throw 'Nenhum histórico disponível';
      }

      final List<dynamic> raw = jsonRes['historico'];
      final List<Map<String, dynamic>> lista = raw.map((item) {
        final data = DateTime.parse(item['data_reserva'] as String);
        return {
          'nome': item['nome'] as String,
          'data': DateFormat('dd/MM/yy').format(data),
        };
      }).toList();

      if (mounted) {
        setState(() {
          historico = lista;
          carregando = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar histórico: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar histórico: $e')),
        );
        setState(() => carregando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2D24),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2D24),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFD4AF37)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Histórico',
          style: TextStyle(
            color: Color(0xFFD4AF37),
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
      body: SafeArea(
        child: carregando
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
              )
            : historico.isEmpty
                ? const Center(
                    child: Text(
                      'Nenhuma reserva usada encontrada.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    itemCount: historico.length,
                    separatorBuilder: (_, __) => const Divider(
                      color: Color(0xFFD4AF37),
                      thickness: 1,
                    ),
                    itemBuilder: (context, i) {
                      final item = historico[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: Text(
                          '${item['nome']} - ${item['data']}',
                          style:
                              const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
