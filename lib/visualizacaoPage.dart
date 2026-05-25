import 'dart:convert';

import 'package:barrestapp/ReservaAtivaPage.dart';
import 'package:barrestapp/restaurantes/saldo.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:barrestapp/ReservaVisualizacaoPage.dart';

class VisualizacaoPage extends StatefulWidget {
  final String nomeRestaurante;
  final String logo;
  final String idRestaurante;

  const VisualizacaoPage({
    super.key,
    required this.nomeRestaurante,
    required this.logo,
    required this.idRestaurante,
  });

  @override
  State<VisualizacaoPage> createState() => _VisualizacaoPageState();
}

class _VisualizacaoPageState extends State<VisualizacaoPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> pratos = [];
  bool carregandoMenu = true;

  String endereco = '';
  String? usuarioId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    carregarUsuarioId();
    carregarMenu();
    carregarEndereco();
  }

  Future<void> carregarUsuarioId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('usuario_id');
    if (id != null && id.isNotEmpty) {
      setState(() => usuarioId = id);
    }
  }

  bool _pratoEmPromocao(Map<String, dynamic> prato) {
    final valor = prato['em_promocao'];
    return valor == 1 || valor == '1' || valor == true;
  }

  String _textoPromocao(Map<String, dynamic> prato) {
    final texto = prato['texto_promocao']?.toString().trim() ?? '';
    if (texto.isNotEmpty) return texto;
    return 'Em promoção';
  }

  Future<void> buscarERedirecionarReservaAtiva() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioIdLocal = prefs.getString('usuario_id');
    if (usuarioIdLocal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não identificado.')),
      );
      return;
    }

    try {
      print('➡️ GET check_license.php');
      final licResp = await http
          .get(Uri.parse('https://barrest.tech/check_license.php'))
          .timeout(const Duration(seconds: 5));
      print('⬅️ Status: ${licResp.statusCode}, body: ${licResp.body}');
      if (licResp.statusCode != 200) throw 'Erro ao obter licença';
      final licJson = json.decode(licResp.body);
      if (licJson['licensed'] != true) throw 'Licença inativa';
      final licenseId = licJson['id'].toString();
      final authHeader = 'Basic ${base64Encode(utf8.encode(':$licenseId'))}';

      final uri = Uri.parse('https://barrest.tech/get_last_reserva.php');
      final body = json.encode({'usuario_id': usuarioIdLocal});
      print('➡️ POST get_last_reserva.php, body: $body');
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': authHeader,
        },
        body: body,
      );
      print('⬅️ Status: ${response.statusCode}, body: ${response.body}');

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhuma reserva ativa encontrada.')),
        );
      } else {
        throw 'Status ${response.statusCode}';
      }
    } catch (e) {
      print('❌ buscarERedirecionarReservaAtiva erro: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao buscar reserva: $e')));
    }
  }

  void _mostrarImagemAmpliada(String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            color: Colors.black.withOpacity(0.85),
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {},
              child: InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(imageUrl, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _abrirMenuLateral() async {
    final prefs = await SharedPreferences.getInstance();
    final nomeUsuario = prefs.getString('usuario_nome') ?? 'Usuário';
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder:
          (context, a1, a2) => Align(
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
                      leading: const Icon(
                        Icons.person,
                        color: Color(0xFFD4AF37),
                      ),
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
                        if (context.mounted) {
                          Navigator.of(
                            context,
                          ).pushNamedAndRemoveUntil('/categoria', (_) => false);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
      transitionBuilder: (context, anim, sec, child) {
        final v = Curves.easeInOut.transform(anim.value) - 1.0;
        return Transform.translate(offset: Offset(-250 * v, 0.0), child: child);
      },
    );
  }

  Future<void> carregarMenu() async {
    setState(() => carregandoMenu = true);
    try {
      print('➡️ GET check_license.php');
      final licResp = await http.get(
        Uri.parse('https://barrest.tech/check_license.php'),
      );
      print('⬅️ Status: ${licResp.statusCode}, body: ${licResp.body}');
      if (licResp.statusCode != 200) throw 'Erro na licença';
      final licenseId = json.decode(licResp.body)['id'].toString();

      final url = Uri.parse(
        'https://barrest.tech/get_menu.php'
        '?license=$licenseId'
        '&restaurante_id=${widget.idRestaurante}',
      );
      print('➡️ GET get_menu.php');
      final resp = await http.get(url);
      print('⬅️ Status: ${resp.statusCode}, body length: ${resp.body.length}');
      if (resp.statusCode != 200) throw 'Erro HTTP: ${resp.statusCode}';

      final data = json.decode(resp.body) as List;
      setState(() {
        pratos = List<Map<String, dynamic>>.from(data);
        carregandoMenu = false;
      });
    } catch (e) {
      print('❌ carregarMenu erro: $e');
      if (mounted) {
        setState(() => carregandoMenu = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar menu: $e')));
      }
    }
  }

  Future<void> carregarEndereco() async {
    try {
      print('➡️ GET check_license.php (endereço)');
      final licResp = await http.get(
        Uri.parse('https://barrest.tech/check_license.php'),
      );
      print('⬅️ Status: ${licResp.statusCode}, body: ${licResp.body}');
      if (licResp.statusCode != 200) throw 'Erro ao obter licença';
      final licenseId = json.decode(licResp.body)['id'].toString();

      final url = Uri.parse(
        'https://barrest.tech/info_restaurante.php'
        '?license=$licenseId'
        '&id=${widget.idRestaurante}',
      );
      print('➡️ GET info_restaurante.php');
      final resp = await http.get(url);
      print('⬅️ Status: ${resp.statusCode}, body: ${resp.body}');
      if (resp.statusCode != 200) throw 'Erro ao buscar restaurante';

      final enderecoStr = json.decode(resp.body)['endereco'] ?? '';
      if (mounted) setState(() => endereco = enderecoStr.trim());
    } catch (e) {
      print('❌ carregarEndereco erro: $e');
      setState(() => endereco = '');
    }
  }

  Future<void> abrirNoMaps() async {
    if (endereco.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Endereço não disponível.')));
      return;
    }
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(endereco)}',
    );
    print('➡️ Abrindo Maps: $url');
    if (!await launchUrl(url, mode: LaunchMode.platformDefault)) {
      print('❌ Não foi possível abrir o mapa');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir o mapa no navegador.'),
        ),
      );
    }
  }

  Widget _buildImagemPrato(Map<String, dynamic> prato) {
    final imagem = prato['imagem']?.toString() ?? '';
    final imageUrl = 'https://barrest.tech/uploads/cardapio/$imagem';
    final emPromocao = _pratoEmPromocao(prato);
    final textoPromocao = _textoPromocao(prato);

    final imagemWidget =
        (imagem.endsWith('.jpg') ||
                imagem.endsWith('.jpeg') ||
                imagem.endsWith('.png') ||
                imagem.endsWith('.webp'))
            ? GestureDetector(
              onTap: () => _mostrarImagemAmpliada(imageUrl),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder:
                    (_, __, ___) => Container(
                      color: const Color(0xFF2E3D34),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
              ),
            )
            : Container(
              color: const Color(0xFF2E3D34),
              alignment: Alignment.center,
              child: const Icon(
                Icons.image_not_supported,
                size: 50,
                color: Colors.white,
              ),
            );

    return Stack(
      children: [
        Positioned.fill(child: imagemWidget),
        if (emPromocao)
          Positioned(
            top: 12,
            right: -30,
            child: Transform.rotate(
              angle: 0.55,
              child: Container(
                width: 115,
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 10,
                ),
                decoration: const BoxDecoration(color: Colors.redAccent),
                child: Text(
                  textoPromocao,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCardPrato(Map<String, dynamic> prato) {
    final nomePrato = prato['nome']?.toString() ?? 'Sem Nome';
    final descricao = prato['descricao']?.toString().trim() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2E3D34),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: _buildImagemPrato(prato),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nomePrato,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (descricao.isNotEmpty)
                  Text(
                    descricao,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2D24),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2D24),
        elevation: 0,
        toolbarHeight: 140,
        leading: usuarioId != null
        ? IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFFD4AF37)),
            onPressed: _abrirMenuLateral,
          )
        : IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFFD4AF37)),
            onPressed: () => Navigator.pop(context),
          ),
        centerTitle: true,
        title: SizedBox(
          height: 110,
          width: 110,
          child: Image.asset(
            'assets/logo-Transparente.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.logo,
                width: 220,
                height: 140,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => const Icon(
                      Icons.image_not_supported,
                      color: Colors.white,
                    ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    widget.nomeRestaurante,
                    style: const TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 26,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.location_on,
                    color: Color(0xFFD4AF37),
                    size: 30,
                  ),
                  onPressed: abrirNoMaps,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFD4AF37),
            labelColor: const Color(0xFFD4AF37),
            unselectedLabelColor: Colors.white70,
            tabs: const [Tab(text: 'Cardápio'), Tab(text: 'Reservar mesa')],
          ),
          const Divider(color: Color(0xFFD4AF37)),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                carregandoMenu
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFD4AF37),
                      ),
                    )
                    : pratos.isEmpty
                    ? const Center(
                      child: Text(
                        'Nenhum prato cadastrado.',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    )
                    : Padding(
                      padding: const EdgeInsets.all(8),
                      child: GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.8,
                        children: pratos.map(_buildCardPrato).toList(),
                      ),
                    ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: ReservaMesaForm(
                      restauranteId: widget.idRestaurante,
                      endereco: endereco,
                      pratos: pratos,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReservaMesaForm extends StatefulWidget {
  final String restauranteId;
  final String endereco;
  final List<Map<String, dynamic>> pratos;

  const ReservaMesaForm({
    super.key,
    required this.restauranteId,
    required this.endereco,
    required this.pratos,
  });

  @override
  State<ReservaMesaForm> createState() => _ReservaMesaFormState();
}

class _ReservaMesaFormState extends State<ReservaMesaForm> {
  Future<void> _mostrarAvisoLoginNecessario() async {
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1E2D24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
      ),
      title: const Column(
        children: [
          Icon(
            Icons.lock_outline,
            color: Color(0xFFD4AF37),
            size: 48,
          ),
          SizedBox(height: 12),
          Text(
            'Entre para reservar',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFD4AF37),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: const Text(
        'Para reservar uma mesa, você precisa entrar na sua conta ou criar um cadastro gratuito no aplicativo.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, fontSize: 15),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Agora não',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/login');
          },
          child: const Text(
            'Entrar ou criar conta',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}
  DateTime data = DateTime.now();
  TimeOfDay hora = TimeOfDay.fromDateTime(
    DateTime.now().add(const Duration(hours: 1)),
  );
  int pessoas = 2;
  final List<Map<String, dynamic>> carrinhoPratos = [];

  void _selecionarData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: data,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (escolhida != null) setState(() => data = escolhida);
  }

  void _selecionarHora() async {
    final escolhida = await showTimePicker(context: context, initialTime: hora);
    if (escolhida != null) setState(() => hora = escolhida);
  }

  Future<double> _getSaldo({
    required String usuarioId,
    required String licenseId,
  }) async {
    final authHeader = 'Basic ${base64Encode(utf8.encode(':$licenseId'))}';
    final uri = Uri.parse(
      'https://barrest.tech/get_saldo.php?usuario_id=${Uri.encodeComponent(usuarioId)}',
    );

    final resp = await http
        .get(uri, headers: {'Authorization': authHeader})
        .timeout(const Duration(seconds: 8));

    if (resp.statusCode != 200) {
      throw 'Erro ao consultar saldo (HTTP ${resp.statusCode})';
    }

    final j = json.decode(resp.body) as Map<String, dynamic>;
    if (j['success'] != true) {
      throw (j['error'] ?? 'Falha ao consultar saldo');
    }

    final v = j['valor'];
    return v == null ? 0.0 : (double.tryParse(v.toString()) ?? 0.0);
  }

  Future<bool> _debitarSaldo({
    required String usuarioId,
    required double valor,
    required String licenseId,
  }) async {
    final authHeader = 'Basic ${base64Encode(utf8.encode(':$licenseId'))}';
    final valorStr = valor.toStringAsFixed(2);
    final mpPaymentId = 'saldo-${DateTime.now().millisecondsSinceEpoch}';

    final uri = Uri.https('barrest.tech', '/debitar_saldo.php', {
      'license': licenseId,
    });

    final body = jsonEncode({
      'usuario_id': usuarioId,
      'valor': valorStr,
      'mp_payment_id': mpPaymentId,
      'metodo': 'saldo',
    });

    final resp = await http
        .post(
          uri,
          headers: {
            'Authorization': authHeader,
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 10));

    debugPrint('debitar_saldo => ${resp.statusCode} ${resp.reasonPhrase}');
    debugPrint('resp: ${resp.body}');
    if (resp.statusCode != 200) {
      throw 'Erro ao debitar saldo (HTTP ${resp.statusCode})\n${resp.body}';
    }

    final j = json.decode(resp.body) as Map<String, dynamic>;
    if (j['success'] == true) return true;
    final msg = j['error']?.toString() ?? 'Falha ao debitar saldo';
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
    return false;
  }

  Future<Map<String, dynamic>?> aguardarTaxaReserva({
    required String usuarioId,
    int tentativasMax = 30,
    Duration intervalo = const Duration(seconds: 5),
  }) async {
    final uri = Uri.parse('https://barrest.tech/get_last_transaction.php');
    for (var i = 1; i <= tentativasMax; i++) {
      final payload = {'usuario_id': usuarioId};
      print('🔄 Polling #$i - POST $uri body: $payload');
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      print('📥 Polling #$i - status: ${resp.statusCode}, body: ${resp.body}');
      if (resp.statusCode == 200) {
        final jsonBody = json.decode(resp.body) as Map<String, dynamic>;
        if (jsonBody['success'] == true) {
          print('✅ Polling encontrou transacao: ${jsonBody['transacao']}');
          return jsonBody['transacao'] as Map<String, dynamic>;
        }
      }
      await Future.delayed(intervalo);
    }
    print('⚠️ Polling esgotou tentativas');
    return null;
  }

  Future<void> _criarTransacaoEGerarLink(double valor) async {
    const accessToken =
        'APP_USR-5744811975964717-071418-72170660d6e61b882065d130f878728d-180818825';
    final prefs = await SharedPreferences.getInstance();
    final usuarioIdLocal = prefs.getString('usuario_id');
    if (usuarioIdLocal == null) return;

    final body = jsonEncode({
      'items': [
        {'title': 'Taxa de Reserva', 'quantity': 1, 'unit_price': valor},
      ],
      'metadata': {'usuario_id': usuarioIdLocal},
      'back_urls': {
        'success': 'https://yourapp.com/success',
        'failure': 'https://yourapp.com/failure',
        'pending': 'https://yourapp.com/pending',
      },
    });

    print(
      '➡️ MP Preference POST https://api.mercadopago.com/checkout/preferences',
    );
    print('   body: $body');
    final response = await http.post(
      Uri.parse('https://api.mercadopago.com/checkout/preferences'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: body,
    );
    print(
      '⬅️ MP Preference status: ${response.statusCode}, body: ${response.body}',
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final link = data['init_point'] as String;
      print('🔗 MP init_point: $link');
      await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    } else {
      print('❌ MP Preference erro: ${response.body}');
      final err = jsonDecode(response.body);
      final msg = err['message'] ?? 'Erro ao gerar link MP';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<bool?> _perguntarSeQuerPratos() {
    return showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            backgroundColor: const Color(0xFF1E2D24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text(
              'Deseja reservar pratos?',
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'Você pode escolher pratos do cardápio para deixar reservado junto com a mesa.',
              style: TextStyle(color: Colors.white),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Não',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Escolher pratos',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            ],
          ),
    );
  }

  int _quantidadeNoCarrinho(String menuId) {
    final index = carrinhoPratos.indexWhere((item) => item['menu_id'] == menuId);
    if (index < 0) return 0;
    return (carrinhoPratos[index]['quantidade'] as int?) ?? 0;
  }

  int _totalItensCarrinho() {
    var total = 0;
    for (final item in carrinhoPratos) {
      total += (item['quantidade'] as int?) ?? 0;
    }
    return total;
  }

  void _adicionarPratoCarrinho(Map<String, dynamic> prato, void Function(void Function()) setModalState) {
    final menuId = prato['id']?.toString() ?? '';
    if (menuId.isEmpty) return;

    final nome = prato['nome']?.toString() ?? 'Sem nome';
    final index = carrinhoPratos.indexWhere((item) => item['menu_id'] == menuId);

    if (index >= 0) {
      carrinhoPratos[index]['quantidade'] =
          ((carrinhoPratos[index]['quantidade'] as int?) ?? 0) + 1;
    } else {
      carrinhoPratos.add({
        'menu_id': menuId,
        'nome_prato': nome,
        'quantidade': 1,
      });
    }

    setModalState(() {});
    setState(() {});
  }

  void _removerPratoCarrinho(String menuId, void Function(void Function()) setModalState) {
    final index = carrinhoPratos.indexWhere((item) => item['menu_id'] == menuId);
    if (index < 0) return;

    final quantidade = (carrinhoPratos[index]['quantidade'] as int?) ?? 0;
    if (quantidade <= 1) {
      carrinhoPratos.removeAt(index);
    } else {
      carrinhoPratos[index]['quantidade'] = quantidade - 1;
    }

    setModalState(() {});
    setState(() {});
  }

  Future<void> _abrirCardapioParaReserva() async {
    if (widget.pratos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum prato disponível no cardápio.')),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2D24),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.88,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Escolha os pratos',
                    style: TextStyle(
                      color: Color(0xFFD4AF37),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Adicione pratos ao pedido da reserva',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const Divider(color: Color(0xFFD4AF37)),
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.pratos.length,
                      itemBuilder: (_, index) {
                        final prato = widget.pratos[index];
                        final menuId = prato['id']?.toString() ?? '';
                        final nome = prato['nome']?.toString() ?? 'Sem nome';
                        final descricao = prato['descricao']?.toString().trim() ?? '';
                        final imagem = prato['imagem']?.toString() ?? '';
                        final imageUrl = 'https://barrest.tech/uploads/cardapio/$imagem';
                        final quantidade = _quantidadeNoCarrinho(menuId);

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E3D34),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: quantidade > 0
                                  ? const Color(0xFFD4AF37)
                                  : Colors.transparent,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(8),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 58,
                                height: 58,
                                child: (imagem.endsWith('.jpg') ||
                                        imagem.endsWith('.jpeg') ||
                                        imagem.endsWith('.png') ||
                                        imagem.endsWith('.webp'))
                                    ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.image_not_supported,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.restaurant_menu,
                                        color: Color(0xFFD4AF37),
                                      ),
                              ),
                            ),
                            title: Text(
                              nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: descricao.isEmpty
                                ? null
                                : Text(
                                    descricao,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                            trailing: quantidade == 0
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.add_shopping_cart,
                                      color: Color(0xFFD4AF37),
                                    ),
                                    onPressed: () => _adicionarPratoCarrinho(prato, setModalState),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: Color(0xFFD4AF37),
                                        ),
                                        onPressed: () => _removerPratoCarrinho(menuId, setModalState),
                                      ),
                                      Text(
                                        '$quantidade',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                          color: Color(0xFFD4AF37),
                                        ),
                                        onPressed: () => _adicionarPratoCarrinho(prato, setModalState),
                                      ),
                                    ],
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E2D24),
                      border: Border(top: BorderSide(color: Color(0xFFD4AF37))),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_totalItensCarrinho()} item(ns) no pedido',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Continuar',
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Map<String, dynamic> _montarReservaBody({
    required String usuarioIdLocal,
    required DateTime dataHoraReserva,
  }) {
    return {
      'usuario_id': usuarioIdLocal,
      'restaurante_id': widget.restauranteId,
      'data_reserva': dataHoraReserva.toIso8601String(),
      'quantidade_pessoas': pessoas,
      'pratos': carrinhoPratos,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Reservar Mesa',
          style: TextStyle(
            color: Color(0xFFD4AF37),
            fontSize: 24,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _campoSelecionavel(
          label: 'Data',
          valor:
              '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}',
          icone: Icons.calendar_today,
          onTap: _selecionarData,
        ),
        const SizedBox(height: 12),
        _campoSelecionavel(
          label: 'Horário',
          valor:
              '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}',
          icone: Icons.access_time,
          onTap: _selecionarHora,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD4AF37)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nº de pessoas',
                style: TextStyle(color: Color(0xFFD4AF37), fontSize: 16),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, color: Color(0xFFD4AF37)),
                    onPressed:
                        pessoas > 1 ? () => setState(() => pessoas--) : null,
                  ),
                  Text(
                    '$pessoas',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(width: 8),

                  if (pessoas >= 4)
                    const Text(
                      'Máx. 4',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Color(0xFFD4AF37)),
                    onPressed: pessoas < 4
                    ? () => setState(() => pessoas++)
                    : null,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4AF37),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            final usuarioIdLocal = prefs.getString('usuario_id');


            if (usuarioIdLocal == null || usuarioIdLocal.isEmpty) {
              await _mostrarAvisoLoginNecessario();
              return;
            }

            if (carrinhoPratos.isEmpty) {
              final querPratos = await _perguntarSeQuerPratos();
              if (querPratos == true) {
                await _abrirCardapioParaReserva();
              }
            }

            try {
              print('➡️ GET check_license.php');
              final licResp = await http
                  .get(Uri.parse('https://barrest.tech/check_license.php'))
                  .timeout(const Duration(seconds: 5));
              print('⬅️ Status: ${licResp.statusCode}, body: ${licResp.body}');
              if (licResp.statusCode != 200) throw 'Licença inválida';
              final licJson = json.decode(licResp.body);
              if (licJson['licensed'] != true) throw 'Licença inativa';
              final licenseId = licJson['id'].toString();

              print('➡️ GET get_taxa.php');
              final taxaResp = await http
                  .get(
                    Uri.parse(
                      'https://barrest.tech/admin/get_taxa.php?license=${Uri.encodeComponent(licenseId)}',
                    ),
                  )
                  .timeout(const Duration(seconds: 5));
              print(
                '⬅️ Status: ${taxaResp.statusCode}, body: ${taxaResp.body}',
              );
              if (taxaResp.statusCode != 200) throw 'Erro ao buscar taxa';
              final taxaJson =
                  json.decode(taxaResp.body) as Map<String, dynamic>;
              final destinatarioTaxa = (taxaJson['destinatario'] as int?) ?? 1;
              final tipoTaxa = (taxaJson['tipo'] as int?) ?? 1;
              final valorTaxaStr = taxaJson['valor']?.toString() ?? '0';
              final valorTaxa = double.parse(valorTaxaStr);

              if (destinatarioTaxa == 1) {
                final double valorCobrar = valorTaxa;
                final saldo = await _getSaldo(
                  usuarioId: usuarioIdLocal,
                  licenseId: licenseId,
                );

                if (saldo >= valorCobrar) {
                  final debitoOk = await _debitarSaldo(
                    usuarioId: usuarioIdLocal,
                    valor: valorCobrar,
                    licenseId: licenseId,
                  );
                  if (!debitoOk) throw 'Não foi possível debitar o saldo.';

                  final dataHoraReserva = DateTime(
                    data.year,
                    data.month,
                    data.day,
                    hora.hour,
                    hora.minute,
                  );
                  final reservaBody = _montarReservaBody(
                    usuarioIdLocal: usuarioIdLocal,
                    dataHoraReserva: dataHoraReserva,
                  );

                  final response = await http
                      .post(
                        Uri.parse('https://barrest.tech/nova_reserva.php'),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode(reservaBody),
                      )
                      .timeout(const Duration(seconds: 5));

                  if (response.statusCode == 200) {
                    final jsonBody =
                        json.decode(response.body) as Map<String, dynamic>;
                    if (jsonBody['success'] == true) {
                      final reservaId = jsonBody['reserva_id'];
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => ReservaAtivaPage(
                                reservaId: reservaId,
                                data: data,
                                hora: hora,
                                pessoas: pessoas,
                                idRestaurante: widget.restauranteId,
                              ),
                        ),
                      );
                      return;
                    } else {
                      throw 'Erro no servidor: ${jsonBody['error'] ?? 'Resposta inesperada'}';
                    }
                  } else {
                    throw 'Status ${response.statusCode}';
                  }
                } else {
                  await showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (_) => AlertDialog(
                          backgroundColor: const Color(0xFFD4AF37),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.white,
                                size: 40,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Saldo insuficiente para a taxa de '
                                '${tipoTaxa == 1 ? '$valorTaxaStr%' : 'R\$ $valorTaxaStr'}.\n',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text(
                                'Pagar reserva',
                                style: TextStyle(color: Color(0xFFD4AF37)),
                              ),
                            ),
                          ],
                        ),
                  );

                  await _criarTransacaoEGerarLink(valorCobrar);

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (_) => const AlertDialog(
                          content: SizedBox(
                            height: 80,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                  );

                  final transacao = await aguardarTaxaReserva(
                    usuarioId: usuarioIdLocal,
                  );
                  if (context.mounted) Navigator.of(context).pop();

                  if (transacao == null) {
                    print('⚠️ Nenhuma transação, abortando reserva');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Pagamento não identificado a tempo.'),
                      ),
                    );
                    return;
                  }

                  final dataHoraReserva = DateTime(
                    data.year,
                    data.month,
                    data.day,
                    hora.hour,
                    hora.minute,
                  );
                  final reservaBody = _montarReservaBody(
                    usuarioIdLocal: usuarioIdLocal,
                    dataHoraReserva: dataHoraReserva,
                  );
                  print('➡️ POST nova_reserva.php, body: $reservaBody');

                  final response = await http
                      .post(
                        Uri.parse('https://barrest.tech/nova_reserva.php'),
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode(reservaBody),
                      )
                      .timeout(const Duration(seconds: 5));

                  print(
                    '⬅️ Status: ${response.statusCode}, body: ${response.body}',
                  );
                  if (response.statusCode == 200) {
                    final jsonBody =
                        json.decode(response.body) as Map<String, dynamic>;
                    if (jsonBody['success'] == true) {
                      final reservaId = jsonBody['reserva_id'];
                      print('✅ Reserva criada: $reservaId');
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => ReservaAtivaPage(
                                reservaId: reservaId,
                                data: data,
                                hora: hora,
                                pessoas: pessoas,
                                idRestaurante: widget.restauranteId,
                              ),
                        ),
                      );
                      return;
                    } else {
                      throw 'Erro no servidor: ${jsonBody['error'] ?? 'Resposta inesperada'}';
                    }
                  } else {
                    throw 'Status ${response.statusCode}';
                  }
                }
              } else if (destinatarioTaxa == 2 && tipoTaxa == 2) {
                final prefs = await SharedPreferences.getInstance();
                final usuarioIdLocal = prefs.getString('usuario_id')!;

                final transferResp = await http
                    .post(
                      Uri.parse(
                        'https://barrest.tech/admin/transferir_taxa.php?license=$licenseId',
                      ),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({
                        'restaurante_id': widget.restauranteId,
                        'valor': valorTaxa,
                      }),
                    )
                    .timeout(const Duration(seconds: 5));

                final transferJson =
                    json.decode(transferResp.body) as Map<String, dynamic>;
                if (transferResp.statusCode != 200 ||
                    transferJson['success'] != true) {
                  throw transferJson['error'] ??
                      'Erro na transferência interna';
                }

                final dataHoraReserva = DateTime(
                  data.year,
                  data.month,
                  data.day,
                  hora.hour,
                  hora.minute,
                );
                final reservaBody = {
                  'usuario_id': usuarioIdLocal,
                  'restaurante_id': widget.restauranteId,
                  'data_reserva': dataHoraReserva.toIso8601String(),
                  'quantidade_pessoas': pessoas,
                };
                final reservaResp = await http
                    .post(
                      Uri.parse('https://barrest.tech/nova_reserva.php'),
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode(reservaBody),
                    )
                    .timeout(const Duration(seconds: 5));
                final reservaJson =
                    json.decode(reservaResp.body) as Map<String, dynamic>;
                if (reservaResp.statusCode == 200 &&
                    reservaJson['success'] == true) {
                  final reservaId = reservaJson['reserva_id'];
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => ReservaAtivaPage(
                            reservaId: reservaId,
                            data: data,
                            hora: hora,
                            pessoas: pessoas,
                            idRestaurante: widget.restauranteId,
                          ),
                    ),
                  );
                  return;
                }
                throw reservaJson['error'] ?? 'Erro ao criar reserva';
              } else {
                final dataHoraReserva = DateTime(
                  data.year,
                  data.month,
                  data.day,
                  hora.hour,
                  hora.minute,
                );
                final reservaBody = {
                  'usuario_id': usuarioIdLocal,
                  'restaurante_id': widget.restauranteId,
                  'data_reserva': dataHoraReserva.toIso8601String(),
                  'quantidade_pessoas': pessoas,
                };

                print('➡️ POST nova_reserva.php (padrão), body: $reservaBody');
                final reservaResp = await http
                    .post(
                      Uri.parse('https://barrest.tech/nova_reserva.php'),
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode(reservaBody),
                    )
                    .timeout(const Duration(seconds: 5));

                print(
                  '⬅️ Status: ${reservaResp.statusCode}, body: ${reservaResp.body}',
                );
                final reservaJson =
                    json.decode(reservaResp.body) as Map<String, dynamic>;

                if (reservaResp.statusCode == 200 &&
                    reservaJson['success'] == true) {
                  final reservaId = reservaJson['reserva_id'];
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => ReservaAtivaPage(
                            reservaId: reservaId,
                            data: data,
                            hora: hora,
                            pessoas: pessoas,
                            idRestaurante: widget.restauranteId,
                          ),
                    ),
                  );
                } else {
                  throw reservaJson['error'] ?? 'Erro ao criar reserva';
                }
              }
            } catch (e) {
              print('❌ onPressed erro: $e');
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Erro: $e')));
            }
          },
          child: const Text(
            'RESERVAR',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _campoSelecionavel({
    required String label,
    required String valor,
    required IconData icone,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD4AF37)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 16),
            ),
            Text(valor, style: const TextStyle(color: Colors.white)),
            Icon(icone, color: const Color(0xFFD4AF37)),
          ],
        ),
      ),
    );
  }
}
