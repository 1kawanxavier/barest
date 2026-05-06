import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kCheckLicenseUrl = 'https://barrest.tech/check_license.php';
const String kGetRestaurantesUrl =
    'https://barrest.tech/admin/get_restaurantes.php';

class RestaurantesPage extends StatefulWidget {
  const RestaurantesPage({Key? key}) : super(key: key);

  @override
  State<RestaurantesPage> createState() => _RestaurantesPageState();
}

class _RestaurantesPageState extends State<RestaurantesPage> {
  bool carregando = true;
  String? erro;
  List<Restaurant> lista = [];

  @override
  void initState() {
    super.initState();
    _fetchRestaurantes();
  }

  Future<void> _fetchRestaurantes() async {
    setState(() {
      carregando = true;
      erro = null;
    });

    try {
      // 1) valida licença e obtém ID
      final licResp = await http
          .get(Uri.parse(kCheckLicenseUrl))
          .timeout(const Duration(seconds: 5));
      if (licResp.statusCode != 200) throw 'Falha ao validar licença';
      final licJson = json.decode(licResp.body) as Map<String, dynamic>;
      if (licJson['licensed'] != true) throw 'Licença inativa';
      final licenseId = licJson['id'].toString();

      // 2) busca restaurantes
      final uri = Uri.parse(
        '$kGetRestaurantesUrl?license=${Uri.encodeComponent(licenseId)}',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) throw 'Erro ao buscar restaurantes';

      final data = json.decode(resp.body) as Map<String, dynamic>;
      if (data['success'] != true || data['restaurantes'] == null) {
        throw data['error'] ?? 'Resposta inesperada do servidor';
      }

      final raw = data['restaurantes'] as List<dynamic>;
      lista = raw.map((e) => Restaurant.fromJson(e)).toList();

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

  Future<bool> _confirmarExclusao(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C3D33),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Excluir restaurante',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Deseja realmente excluir este restaurante?',
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF3E5A4A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Não'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFB72B2B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sim'),
            ),
          ],
        );
      },
    );

    return confirm == true;
  }

  Future<void> _deletarRestaurante(String id) async {
    try {
      final licResp = await http
          .get(Uri.parse(kCheckLicenseUrl))
          .timeout(const Duration(seconds: 5));
      if (licResp.statusCode != 200) throw 'Falha ao validar licença';

      final licJson = json.decode(licResp.body) as Map<String, dynamic>;
      if (licJson['licensed'] != true) throw 'Licença inativa';
      final licenseId = licJson['id'].toString();

      final deleteUri = Uri.parse(
        'https://barrest.tech/admin/delete_restaurante.php?license=${Uri.encodeComponent(licenseId)}&restaurante_id=${Uri.encodeComponent(id)}',
      );
      final resp = await http
          .get(deleteUri)
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) {
        throw 'Erro ao excluir restaurante: ${resp.statusCode}';
      }

      final data = json.decode(resp.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        throw data['message'] ?? 'Falha ao excluir restaurante';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restaurante excluído com sucesso.')),
      );
      await _fetchRestaurantes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível excluir restaurante: $e')),
      );
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
                'Restaurantes',
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
                      ? Center(
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
                          final r = lista[idx];
                          return _RestaurantCard(
                            restaurant: r,
                            onDelete: () async {
                              final confirme = await _confirmarExclusao(
                                context,
                              );
                              if (!confirme) return;
                              await _deletarRestaurante(r.id);
                            },
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

class Restaurant {
  final String id;
  final String nome;
  final String cidade;
  final List<String> categorias;
  final String logoUrl;
  final String proprietarioNome;
  final int totalReservas;

  Restaurant({
    required this.id,
    required this.nome,
    required this.cidade,
    required this.categorias,
    required this.logoUrl,
    required this.proprietarioNome,
    required this.totalReservas,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    // categorias vêm como string CSV
    final catsRaw = json['categorias'] ?? '';
    final cats =
        (catsRaw as String)
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();

    return Restaurant(
      id: json['id']?.toString() ?? '',
      nome: json['nome'] ?? '',
      cidade: json['cidade'] ?? '',
      categorias: cats,
      logoUrl: json['logo_url'] ?? '',
      proprietarioNome: json['proprietario_nome'] ?? '',
      totalReservas: (json['total_reservas'] as int?) ?? 0,
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onDelete;

  const _RestaurantCard({required this.restaurant, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    const bgCard = Color(0xFF273A31);
    const gold = Color(0xFFD4AF37);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  child: Image.network(
                    restaurant.logoUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => Container(
                          width: 100,
                          height: 100,
                          color: const Color(0xFF1B2A24),
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.white54,
                            size: 36,
                          ),
                        ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurant.nome,
                        style: const TextStyle(
                          color: gold,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        restaurant.cidade,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        restaurant.categorias.join(', '),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Proprietário: ${restaurant.proprietarioNome}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Reservas: ${restaurant.totalReservas}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: onDelete,
                      tooltip: 'Excluir restaurante',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Excluir',
                      style: TextStyle(
                        color: Colors.redAccent.shade100,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
