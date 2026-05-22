import 'dart:convert';
import 'package:barrestapp/ReservaVisualizacaoPage.dart';
import 'package:barrestapp/restaurantes/HistoricoReservasPage.dart';
import 'package:barrestapp/restaurantes/saldo.dart';
import 'package:barrestapp/visualizacaoPage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String kCheckLicenseUrl = 'https://barrest.tech/check_license.php';
const String kGetRestaurantsUrl = 'https://barrest.tech/get_restaurantes.php';
const String kGetLastReservaUrl = 'https://barrest.tech/get_last_reserva.php';

class RestaurantesPage extends StatefulWidget {
  final String cidade;
  final String idCategoria;

  const RestaurantesPage({
    super.key,
    required this.cidade,
    required this.idCategoria,
  });

  @override
  State<RestaurantesPage> createState() => _RestaurantesPageState();
}

class _RestaurantesPageState extends State<RestaurantesPage> {
  List<Map<String, dynamic>> restaurantes = [];
  bool carregando = true;
  String textoBusca = '';

  @override
  void initState() {
    super.initState();
    carregarRestaurantes();
  }

  int _diaAtual() {
    return DateTime.now().weekday;
  }

  bool _restauranteEstaAbertoHoje(Map<String, dynamic> restaurante) {
    final diasTexto =
        restaurante['dias_funcionamento']?.toString().trim() ?? '';

    if (diasTexto.isEmpty) {
      return false;
    }

    final hoje = _diaAtual();

    final dias =
        diasTexto
            .split(',')
            .map((e) => int.tryParse(e.trim()))
            .whereType<int>()
            .toList();

    return dias.contains(hoje);
  }

  String _nomeDiaAtual() {
    switch (_diaAtual()) {
      case 1:
        return 'segunda-feira';
      case 2:
        return 'terça-feira';
      case 3:
        return 'quarta-feira';
      case 4:
        return 'quinta-feira';
      case 5:
        return 'sexta-feira';
      case 6:
        return 'sábado';
      case 7:
        return 'domingo';
      default:
        return 'hoje';
    }
  }

  Future<void> carregarRestaurantes() async {
    setState(() => carregando = true);

    try {
      final licResp = await http.get(Uri.parse(kCheckLicenseUrl));
      if (licResp.statusCode != 200) {
        throw 'Erro ao verificar licença: ${licResp.statusCode}';
      }

      final licJson = json.decode(licResp.body) as Map<String, dynamic>;
      if (licJson['licensed'] != true) {
        throw 'Nenhuma licença ativa';
      }

      final String licenseId = licJson['id'].toString();

      final uri = Uri.parse(
        '$kGetRestaurantsUrl'
        '?license=${Uri.encodeComponent(licenseId)}'
        '&categoria=${Uri.encodeComponent(widget.idCategoria)}'
        '&cidade=${Uri.encodeComponent(widget.cidade)}',
      );

      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        throw 'Erro ao carregar restaurantes: ${resp.statusCode}';
      }

      final List<dynamic> data = json.decode(resp.body);
      final lista =
          data.map<Map<String, dynamic>>((item) {
            return Map<String, dynamic>.from(item as Map);
          }).toList();

      setState(() {
        restaurantes = lista;
        carregando = false;
      });
    } catch (e) {
      setState(() => carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar restaurantes: $e')),
      );
    }
  }

  Future<void> buscarERedirecionarReservaAtiva() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioId = prefs.getString('usuario_id');

    if (usuarioId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não identificado.')),
      );
      return;
    }

    try {
      final licResp = await http.get(Uri.parse(kCheckLicenseUrl));
      if (licResp.statusCode != 200) throw 'Erro ao obter licença';

      final licJson = json.decode(licResp.body) as Map<String, dynamic>;
      if (licJson['licensed'] != true) throw 'Licença inativa';

      final licenseId = licJson['id'].toString();
      final credentials = utf8.encode(':$licenseId');
      final authHeader = 'Basic ${base64Encode(credentials)}';

      final uri = Uri.parse(kGetLastReservaUrl);
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': authHeader,
      };
      final body = json.encode({'usuario_id': usuarioId});

      debugPrint('→ POST $uri');
      debugPrint('   headers: $headers');
      debugPrint('   body: $body');

      final response = await http.post(uri, headers: headers, body: body);

      debugPrint('← status: ${response.statusCode}');
      debugPrint('   body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonRes = json.decode(response.body) as Map<String, dynamic>;
        if (jsonRes['success'] == true && jsonRes['reserva'] != null) {
          final reserva = jsonRes['reserva'] as Map<String, dynamic>;
          final dataReserva = DateTime.parse(reserva['data_reserva']);
          final horaReserva = TimeOfDay(
            hour: dataReserva.hour,
            minute: dataReserva.minute,
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => ReservaVisualizacaoPage(
                    reservaId: reserva['id'],
                    data: dataReserva,
                    hora: horaReserva,
                    pessoas: reserva['quantidade_pessoas'],
                    idRestaurante: reserva['restaurante_id'],
                  ),
            ),
          );
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma reserva ativa encontrada.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao buscar reserva: $e')));
    }
  }

  void _abrirMenuLateral() async {
    final prefs = await SharedPreferences.getInstance();
    final nomeUsuario = prefs.getString('usuario_nome') ?? 'Usuário';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) {
        return Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: const Color(0xFF1E2D24),
            child: SizedBox(
              width: 250,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFFD4AF37)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  ListTile(
                    leading: const Icon(Icons.person, color: Color(0xFFD4AF37)),
                    title: Text(
                      nomeUsuario,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.account_balance_wallet,
                      color: Color(0xFFD4AF37),
                    ),
                    title: const Text(
                      'Saldo',
                      style: TextStyle(color: Color(0xFFD4AF37)),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SaldoPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.room_service,
                      color: Color(0xFFD4AF37),
                    ),
                    title: const Text(
                      'Reservas',
                      style: TextStyle(color: Color(0xFFD4AF37)),
                    ),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await buscarERedirecionarReservaAtiva();
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.bookmark,
                      color: Color(0xFFD4AF37),
                    ),
                    title: const Text(
                      'Histórico',
                      style: TextStyle(color: Color(0xFFD4AF37)),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.pushNamed(context, '/historico');
                    },
                  ),
                  ListTile(
                      leading: const Icon(
                        Icons.delete_forever,
                        color: Color(0xFFD4AF37),
                      ),
                      title: const Text(
                        'Deletar conta',
                        style: TextStyle(color: Color(0xFFD4AF37)),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.pushNamed(context, '/deletarConta');
                      },
                    ),
                  const Spacer(),
                  const Divider(color: Color(0xFFD4AF37)),
                  ListTile(
                    title: const Text(
                      'Sair',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () async {
                      await prefs.remove('usuario_id');
                      await prefs.remove('usuario_nome');
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/login', (route) => false);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final v = Curves.easeInOut.transform(animation.value) - 1.0;
        return Transform.translate(offset: Offset(-250 * v, 0), child: child);
      },
    );
  }

  Widget buildEstrelas(double nota) {
    final estrelas = <Widget>[];
    final cheias = nota.floor();
    final meia = (nota - cheias) >= 0.5;

    for (var i = 0; i < cheias; i++) {
      estrelas.add(const Icon(Icons.star, color: Color(0xFFD4AF37), size: 18));
    }

    if (meia) {
      estrelas.add(
        const Icon(Icons.star_half, color: Color(0xFFD4AF37), size: 18),
      );
    }

    while (estrelas.length < 5) {
      estrelas.add(
        const Icon(Icons.star_border, color: Color(0xFFD4AF37), size: 18),
      );
    }

    return Row(children: estrelas);
  }

  @override
  Widget build(BuildContext context) {
    final restaurantesFiltrados =
        restaurantes.where((r) {
          final nome = r['nome']?.toString().toLowerCase() ?? '';
          return nome.contains(textoBusca.toLowerCase());
        }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF1E2D24),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2D24),
        elevation: 0,
        toolbarHeight: 140,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFFD4AF37)),
          onPressed: _abrirMenuLateral,
        ),
        centerTitle: true,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: 110,
              width: 110,
              child: Image.asset(
                'assets/logo-Transparente.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.location_on, color: Color(0xFFD4AF37)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                widget.cidade,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            carregando
                ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      onChanged: (v) => setState(() => textoBusca = v.trim()),
                      decoration: InputDecoration(
                        hintText: 'Buscar restaurante...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFFD4AF37),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xFFD4AF37),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: Color(0xFFD4AF37),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintStyle: const TextStyle(color: Colors.white70),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFD4AF37)),
                    const SizedBox(height: 16),
                    const Text(
                      'Restaurantes',
                      style: TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),
                    Expanded(
                      child:
                          restaurantesFiltrados.isEmpty
                              ? Center(
                                child: Text(
                                  'Nenhum restaurante aberto encontrado para ${_nomeDiaAtual()}.',
                                  style: const TextStyle(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              )
                              : ListView.builder(
                                itemCount: restaurantesFiltrados.length,
                                itemBuilder: (_, i) {
                                  final r = restaurantesFiltrados[i];
                                  final nome =
                                      r['nome']?.toString() ?? 'Sem Nome';
                                  final nota =
                                      double.tryParse(
                                        r['avaliacao'].toString(),
                                      ) ??
                                      0.0;
                                  final logo = r['logo']?.toString() ?? '';
                                  final imageUrl =
                                      logo.isNotEmpty
                                          ? 'https://barrest.tech/uploads/restaurantes/$logo'
                                          : '';
                                  final abertoHoje = _restauranteEstaAbertoHoje(
                                    r,
                                  );

                                  return GestureDetector(
                                    onTap: () {
                                      if (!abertoHoje) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Este restaurante está fechado hoje.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (_) => VisualizacaoPage(
                                                nomeRestaurante: nome,
                                                logo: imageUrl,
                                                idRestaurante:
                                                    r['id'].toString(),
                                              ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2E3D34),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  const BorderRadius.only(
                                                    topLeft: Radius.circular(
                                                      12,
                                                    ),
                                                    bottomLeft: Radius.circular(
                                                      12,
                                                    ),
                                                  ),
                                              child:
                                                  imageUrl.isNotEmpty
                                                      ? Image.network(
                                                        imageUrl,
                                                        width: 140,
                                                        height: 140,
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (
                                                              _,
                                                              __,
                                                              ___,
                                                            ) => Container(
                                                              width: 140,
                                                              height: 140,
                                                              color:
                                                                  Colors.grey,
                                                              child: const Icon(
                                                                Icons
                                                                    .image_not_supported,
                                                                color:
                                                                    Colors
                                                                        .white,
                                                                size: 50,
                                                              ),
                                                            ),
                                                      )
                                                      : Container(
                                                        width: 140,
                                                        height: 140,
                                                        color: Colors.grey,
                                                        child: const Icon(
                                                          Icons
                                                              .image_not_supported,
                                                          color: Colors.white,
                                                          size: 50,
                                                        ),
                                                      ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 16.0,
                                                      horizontal: 8,
                                                    ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      nome,
                                                      style: const TextStyle(
                                                        color: Color(
                                                          0xFFD4AF37,
                                                        ),
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    buildEstrelas(nota),
                                                    const SizedBox(height: 10),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            abertoHoje
                                                                ? Colors.green
                                                                    .withOpacity(
                                                                      0.18,
                                                                    )
                                                                : Colors.red
                                                                    .withOpacity(
                                                                      0.18,
                                                                    ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                        border: Border.all(
                                                          color:
                                                              abertoHoje
                                                                  ? Colors
                                                                      .greenAccent
                                                                  : Colors
                                                                      .redAccent,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        abertoHoje
                                                            ? 'Aberto hoje'
                                                            : 'Fechado hoje',
                                                        style: TextStyle(
                                                          color:
                                                              abertoHoje
                                                                  ? Colors
                                                                      .greenAccent
                                                                  : Colors
                                                                      .redAccent,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
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
