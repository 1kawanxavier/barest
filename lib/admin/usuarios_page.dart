// lib/restaurantes/usuarios_page.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kCheckLicenseUrl = 'https://barrest.tech/check_license.php';
const String kGetUsersUrl = 'https://barrest.tech/admin/get_users.php';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({Key? key}) : super(key: key);

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  bool carregando = true;
  String? erro;
  List<Usuario> lista = [];

  @override
  void initState() {
    super.initState();
    _fetchUsuarios();
  }

  String _formatarData(DateTime dt) {
    final d = dt.toLocal();
    final dia = d.day.toString().padLeft(2, '0');
    final mes = d.month.toString().padLeft(2, '0');
    final ano = d.year.toString();
    final hora = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$ano $hora:$min';
  }

  Future<void> _fetchUsuarios() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      // 1) valida licença
      final licResp = await http
          .get(Uri.parse(kCheckLicenseUrl))
          .timeout(const Duration(seconds: 5));
      if (licResp.statusCode != 200) {
        throw 'Status ${licResp.statusCode} na validação de licença';
      }
      final licJson = json.decode(licResp.body) as Map<String, dynamic>;
      if (licJson['licensed'] != true) throw 'Licença inativa';
      final licenseId = licJson['id']?.toString() ?? '';
      if (licenseId.isEmpty) throw 'ID da licença não retornado';

      // 2) busca usuários + saldo
      final uri = Uri.parse(
        '$kGetUsersUrl?license=${Uri.encodeComponent(licenseId)}',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) {
        throw 'Status ${resp.statusCode} ao buscar usuários';
      }

      final data = json.decode(resp.body) as Map<String, dynamic>;
      if (data['success'] != true || data['usuarios'] == null) {
        throw data['error'] ?? 'Resposta inesperada do servidor';
      }

      final raw = data['usuarios'] as List<dynamic>;
      lista = raw.map((e) => Usuario.fromJson(e)).toList();

      setState(() {
        carregando = false;
      });
    } catch (e) {
      setState(() {
        erro = e.toString();
        carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF1E2D24);
    const gold = Color(0xFFD4AF37);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        toolbarHeight: 70,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: gold),
          onPressed: () => Navigator.pop(context),
        ),
        title: SizedBox(
          height: 50,
          child: Image.asset(
            'assets/logo-Transparente.png',
            fit: BoxFit.contain,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(color: gold, thickness: 1),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'Usuários',
                style: TextStyle(
                  color: gold,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child:
                  carregando
                      ? const Center(
                        child: CircularProgressIndicator(color: gold),
                      )
                      : erro != null
                      ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          erro!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      )
                      : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: lista.length,
                        separatorBuilder: (_, __) => const Divider(color: gold),
                        itemBuilder: (_, idx) {
                          final u = lista[idx];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF27412F),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    u.nome,
                                    style: const TextStyle(
                                      color: gold,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Cadastrado em: ${_formatarData(u.dataCadastro)}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Saldo: R\$ ${u.saldo.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class Usuario {
  final String id;
  final String nome;
  final DateTime dataCadastro;
  final double saldo;

  Usuario({
    required this.id,
    required this.nome,
    required this.dataCadastro,
    required this.saldo,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id']?.toString() ?? '',
      nome: json['nome'] ?? '',
      dataCadastro: DateTime.parse(
        json['datacadastro'] ?? DateTime.now().toIso8601String(),
      ),
      saldo: double.tryParse(json['saldo']?.toString() ?? '') ?? 0.0,
    );
  }
}
