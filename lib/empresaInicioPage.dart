import 'dart:async';
import 'dart:convert';
import 'package:barrestapp/restaurantes/configuracao.dart';
import 'package:barrestapp/restaurantes/saldoRestaurante.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:barrestapp/restaurantes/HistoricoReservasPage.dart';
import 'package:barrestapp/restaurantes/ScanReservaPage.dart';
import 'package:barrestapp/restaurantes/ReservaAtivaPage.dart';

const _checkLicenseUrl = 'https://barrest.tech/check_license.php';
const _getEmpresaUrl = 'https://barrest.tech/get_empresa.php';
const _getReservasCountsUrl = 'https://barrest.tech/get_reservas_counts.php';

class EmpresaInicioPage extends StatefulWidget {
  const EmpresaInicioPage({super.key});
  @override
  State<EmpresaInicioPage> createState() => _EmpresaInicioPageState();
}

class _EmpresaInicioPageState extends State<EmpresaInicioPage> {
  int reservasAtivas = 0;
  int totalReservas = 0;

  String nomeRestaurante = '';
  String? logoUrl;
  String? restauranteId;
  String licenseId = '';
  bool carregando = true;
  late Timer _refreshTimer;
  @override
  void initState() {
    super.initState();
    carregarDadosEmpresa();
    // A cada 30 segundos, apenas atualiza os contadores de reserva
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (restauranteId != null) {
        _carregarReservasCounts();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  Future<void> carregarDadosEmpresa() async {
    try {
      // 1) usuário
      final prefs = await SharedPreferences.getInstance();
      final ownerId = prefs.getString('usuario_id') ?? '';
      if (ownerId.isEmpty) {
        throw 'Usuário não autenticado.';
      }

      // 2) validar licença
      final licResp = await http.get(Uri.parse(_checkLicenseUrl));
      if (licResp.statusCode != 200) throw 'Falha ao validar licença';
      final licJson = json.decode(licResp.body) as Map<String, dynamic>;
      if (licJson['licensed'] != true) throw 'Licença inativa';
      licenseId = licJson['id'].toString();

      // 3) buscar dados da empresa
      final uri = Uri.parse(
        '$_getEmpresaUrl'
        '?license=${Uri.encodeComponent(licenseId)}'
        '&owner_id=${Uri.encodeComponent(ownerId)}',
      );
      final resp = await http.get(uri);
      if (resp.statusCode != 200) throw 'Erro get_empresa: ${resp.statusCode}';
      final jsonRes = json.decode(resp.body) as Map<String, dynamic>;
      if (jsonRes['success'] != true || jsonRes['empresa'] == null) {
        throw 'Empresa não encontrada';
      }
      final empresa = jsonRes['empresa'] as Map<String, dynamic>;

      // 4) atualiza estado da empresa
      restauranteId = empresa['id'] as String?;
      nomeRestaurante = empresa['nome'] as String? ?? '(Sem nome)';
      logoUrl = empresa['logo_url'] as String?;
      carregando = false;

      setState(() {});

      // 5) buscar contadores de reservas
      if (restauranteId != null) {
        await _carregarReservasCounts();
      }
    } catch (e) {
      _mostrarErro(e.toString());
    }
  }

  Future<void> _carregarReservasCounts() async {
    try {
      final uri = Uri.parse(
        '$_getReservasCountsUrl'
        '?license=${Uri.encodeComponent(licenseId)}'
        '&restaurante_id=${Uri.encodeComponent(restauranteId!)}',
      );
      final resp = await http.get(uri);
      if (resp.statusCode != 200) throw 'Erro ao buscar contadores';
      final jsonC = json.decode(resp.body) as Map<String, dynamic>;
      setState(() {
        reservasAtivas = jsonC['ativas'] as int? ?? 0;
        totalReservas = jsonC['total'] as int? ?? 0;
      });
    } catch (e) {
      // deixa 0 sem interromper
      debugPrint('Erro contadores: $e');
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(mensagem)));
    setState(() {
      carregando = false;
      nomeRestaurante = '(Erro)';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2D24),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2D24),
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
              ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
              )
              : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (logoUrl != null)
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              logoUrl!,
                              width: 160,
                              height: 160,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) => const Icon(
                                    Icons.image_not_supported,
                                    color: Colors.white,
                                    size: 80,
                                  ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          nomeRestaurante,
                          style: const TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 28,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 24),

                      _botaoMenu(
                        icon: Icons.add,
                        texto: 'Adicionar Item ao Cardápio',
                        onTap:
                            () =>
                                Navigator.pushNamed(context, '/adicionarItem'),
                      ),
                      _botaoMenu(
                        icon: Icons.edit,
                        texto: 'Alterar Cardápio',
                        onTap:
                            () =>
                                Navigator.pushNamed(context, '/editarCardapio'),
                      ),
                      _botaoMenu(
                        icon: Icons.calendar_today,
                        texto: 'Reservas Ativas\n$reservasAtivas reservas',
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ReservaAtivaPage(),
                              ),
                            ),
                      ),
                      _botaoMenu(
                        icon: Icons.history,
                        texto: 'Total de Reservas\n$totalReservas reservas',
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HistoricoReservasPage(),
                              ),
                            ),
                      ),
                      _botaoMenu(
                        icon: Icons.qr_code_scanner,
                        texto: 'Scanner para QR Code',
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ScanReservaPage(),
                              ),
                            ),
                      ),
                      _botaoMenu(
                        icon: Icons.account_balance_wallet,
                        texto: 'Saldo • R\$',
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SaldoPage(),
                              ),
                            ),
                      ),

                      _botaoMenu(
                        icon: Icons.settings,
                        texto: 'Configurações',
                        onTap:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => const ConfiguracoesRestaurantePage(),
                              ),
                            ),
                      ),
                      _botaoMenu(
                        icon: Icons.exit_to_app,
                        texto: 'Sair',
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('usuario_id');
                          if (!context.mounted) return;
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD4AF37)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFFD4AF37), size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  texto,
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 18,
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
