// lib/restaurantes/admin.dart

import 'dart:async';
import 'dart:convert';

import 'package:barrestapp/admin/configuracoes.dart';
import 'package:barrestapp/admin/relatorios_page.dart';
import 'package:barrestapp/admin/saques.dart';
import 'package:barrestapp/admin/usuarios_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'restaurantes_page.dart';

const String kCheckLicenseUrl = 'https://barrest.tech/check_license.php';
const String kGetAdminStatsUrl = 'https://barrest.tech/get_admin_stats.php';

class AdminPage extends StatefulWidget {
  const AdminPage({Key? key}) : super(key: key);

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  bool carregando = true;
  int totalRestaurantes = 0;
  int totalUsuarios = 0;

  @override
  void initState() {
    super.initState();
    _verificarSessaoEIniciar();
  }

  Future<void> _verificarSessaoEIniciar() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('usuario_id');
    final nivel = prefs.getInt('usuario_nivel');

    if (userId == null || nivel != 3) {
      // não autorizado, volta ao login
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      return;
    }

    await _carregarDadosAdmin();
  }

  Future<void> _carregarDadosAdmin() async {
    try {
      // 1) validar licença e obter ID
      final licResp = await http
          .get(Uri.parse(kCheckLicenseUrl))
          .timeout(const Duration(seconds: 5));
      if (licResp.statusCode != 200) throw 'Falha ao validar licença';
      final licJson = json.decode(licResp.body) as Map<String, dynamic>;
      if (licJson['licensed'] != true) throw 'Licença inativa';
      final licenseId = licJson['id'].toString();

      // 2) buscar estatísticas de admin
      final uriStats = Uri.parse(
        '$kGetAdminStatsUrl?license=${Uri.encodeComponent(licenseId)}',
      );
      final resp = await http.get(uriStats).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) throw 'Erro ao buscar estatísticas';
      final jsonRes = json.decode(resp.body) as Map<String, dynamic>;

      setState(() {
        totalRestaurantes = (jsonRes['total_restaurantes'] as int?) ?? 0;
        totalUsuarios = (jsonRes['total_usuarios'] as int?) ?? 0;
        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      setState(() => carregando = false);
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
        toolbarHeight: 100,
        centerTitle: true,
        title: SizedBox(
          height: 80,
          child: Image.asset(
            'assets/logo-Transparente.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
      body:
          carregando
              ? const Center(child: CircularProgressIndicator(color: gold))
              : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Título
                      Center(
                        child: Text(
                          'Admin Dashboard',
                          style: const TextStyle(
                            color: gold,
                            fontSize: 28,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Menu de opções
                      _botaoMenu(
                        icon: Icons.store,
                        texto: 'Total Restaurantes\n$totalRestaurantes',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RestaurantesPage(),
                            ),
                          );
                        },
                      ),
                      _botaoMenu(
                        icon: Icons.people,
                        texto: 'Total Usuários\n$totalUsuarios',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const UsuariosPage(),
                            ),
                          );
                        },
                      ),
                      _botaoMenu(
                        icon: Icons.bar_chart,
                        texto: 'Relatórios',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RelatoriosPage(),
                            ),
                          );
                        },
                      ),
                      _botaoMenu(
                        icon: Icons.settings,
                        texto: 'Configurações',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const Configuracoes(),
                            ),
                          );
                        },
                      ),
                      _botaoMenu(
                        icon: Icons.account_balance_wallet,
                        texto: 'Saques',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SaquesPage(),
                            ),
                          );
                        },
                      ),
                      _botaoMenu(
                        icon: Icons.exit_to_app,
                        texto: 'Sair',
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('usuario_id');
                          await prefs.remove('usuario_nivel');
                          if (!mounted) return;
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/login',
                            (_) => false,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _botaoMenu({
    required IconData icon,
    required String texto,
    required VoidCallback onTap,
  }) {
    const gold = Color(0xFFD4AF37);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: gold),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: gold, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  texto,
                  style: const TextStyle(color: gold, fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
