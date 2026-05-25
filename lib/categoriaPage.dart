import 'package:barrestapp/ReservaVisualizacaoPage.dart';
import 'package:barrestapp/restaurantes/saldo.dart';
import 'package:barrestapp/visualizacaoPage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CategoriasPage extends StatefulWidget {
  const CategoriasPage({super.key});

  @override
  State<CategoriasPage> createState() => _CategoriasPageState();
}

class _CategoriasPageState extends State<CategoriasPage> {
  List<Map<String, dynamic>> categorias = [];
  List<Map<String, dynamic>> restaurantes = [];
  bool carregando = true;

  String cidade = 'Localizando...';
  String textoBusca = '';
  String usuarioNome = '';
  bool usuarioLogado = false;
  bool _modalAberto = false;

  static const String promoId = '0f4aacce-7463-11f0-99b4-d23bafbfaf2f';

  @override
  void initState() {
    super.initState();
    carregarUsuarioNome();
    obterCidadeAtual();
  }

  Future<void> carregarUsuarioNome() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('usuario_id');
    final nome = prefs.getString('usuario_nome');

    setState(() {
      usuarioLogado = id != null && id.isNotEmpty;
      usuarioNome = nome ?? '';
    });
  }

  int _diaAtual() {
    return DateTime.now().weekday;
  }

  bool _restauranteEstaAbertoHoje(Map<String, dynamic> restaurante) {
    final diasTexto =
        restaurante['dias_funcionamento']?.toString().trim() ?? '';

    if (diasTexto.isEmpty) return false;

    final hoje = _diaAtual();

    final dias =
        diasTexto
            .split(',')
            .map((e) => int.tryParse(e.trim()))
            .whereType<int>()
            .toList();

    return dias.contains(hoje);
  }

  Future<String> _obterLicenseId() async {
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

    return licJson['id'].toString();
  }

  Future<List<Map<String, dynamic>>> _buscarCategorias(String licenseId) async {
    final credentials = utf8.encode(':$licenseId');
    final authHeader = 'Basic ${base64Encode(credentials)}';

    final resp = await http.get(
      Uri.parse('https://barrest.tech/get_categories.php'),
      headers: {'Authorization': authHeader},
    );

    if (resp.statusCode != 200) {
      throw 'Erro ao carregar categorias: ${resp.statusCode}';
    }

    final data = json.decode(resp.body) as List<dynamic>;

    return data
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
        .where((c) => c['id'] != promoId)
        .toList();
  }

  Future<List<Map<String, dynamic>>> _buscarRestaurantesDaCategoria({
    required String licenseId,
    required String nomeCategoria,
  }) async {
    final uri = Uri.parse(
      'https://barrest.tech/get_restaurantes.php'
      '?license=${Uri.encodeComponent(licenseId)}'
      '&categoria=${Uri.encodeComponent(nomeCategoria)}'
      '&cidade=${Uri.encodeComponent(cidade)}',
    );

    final resp = await http.get(uri);

    if (resp.statusCode != 200) {
      return [];
    }

    final data = json.decode(resp.body) as List<dynamic>;

    return data.map<Map<String, dynamic>>((item) {
      final map = Map<String, dynamic>.from(item as Map);
      map['categoria_exibicao'] = nomeCategoria;
      return map;
    }).toList();
  }

  Future<void> carregarDadosTela() async {
    if (cidade.isEmpty || cidade == 'Localizando...') return;

    setState(() => carregando = true);

    try {
      final licenseId = await _obterLicenseId();
      final listaCategorias = await _buscarCategorias(licenseId);

      final List<Map<String, dynamic>> todosRestaurantes = [];

      for (final categoria in listaCategorias) {
        final nomeCategoria = (categoria['nome'] ?? '').toString().trim();
        if (nomeCategoria.isEmpty) continue;

        final lista = await _buscarRestaurantesDaCategoria(
          licenseId: licenseId,
          nomeCategoria: nomeCategoria,
        );

        todosRestaurantes.addAll(lista);
      }

      final Map<String, Map<String, dynamic>> unicos = {};
      for (final r in todosRestaurantes) {
        final id = r['id']?.toString() ?? '';
        if (id.isEmpty) continue;

        unicos[id] = {
          ...r,
          'categoria_exibicao':
              r['categoria_exibicao'] ?? r['categoria'] ?? 'Restaurante',
        };
      }

      setState(() {
        categorias = listaCategorias;
        restaurantes = unicos.values.toList();
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
      final licResp = await http.get(
        Uri.parse('https://barrest.tech/check_license.php'),
      );
      if (licResp.statusCode != 200) throw 'Erro ao obter licença';

      final licJson = json.decode(licResp.body);
      if (licJson['licensed'] != true) throw 'Licença inativa';

      final licenseId = licJson['id'].toString();
      final credentials = utf8.encode(':$licenseId');
      final authHeader = 'Basic ${base64Encode(credentials)}';

      final uri = Uri.parse('https://barrest.tech/get_last_reserva.php');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': authHeader,
      };
      final bodyMap = {'usuario_id': usuarioId};
      final bodyJson = json.encode(bodyMap);

      final response = await http.post(uri, headers: headers, body: bodyJson);

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
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhuma reserva ativa encontrada.')),
          );
        }
      } else {
        throw 'Status ${response.statusCode}';
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao buscar reserva: $e')));
    }
  }

  void _abrirMenuLateral() {
        if (!usuarioLogado) {
      Navigator.pushNamed(context, '/login');
      return;
    }
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
                      usuarioNome.isNotEmpty ? usuarioNome : 'Usuário',
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
                      final prefs = await SharedPreferences.getInstance();
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
        final curvedValue = Curves.easeInOut.transform(animation.value) - 1.0;
        return Transform.translate(
          offset: Offset(-250 * curvedValue, 0.0),
          child: child,
        );
      },
    );
  }

  Future<void> obterCidadeAtual() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        cidade = 'GPS desativado';
        carregando = false;
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          cidade = 'Permissão negada';
          carregando = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        cidade = 'Permissão negada permanentemente';
        carregando = false;
      });
      return;
    }

    try {
      final posicao = await Geolocator.getCurrentPosition();
      final placemarks = await placemarkFromCoordinates(
        posicao.latitude,
        posicao.longitude,
      );

      String cidadeAtual = '';
      for (final pm in placemarks) {
        if (pm.locality != null && pm.locality!.isNotEmpty) {
          cidadeAtual = pm.locality!;
          break;
        } else if (pm.subAdministrativeArea != null &&
            pm.subAdministrativeArea!.isNotEmpty) {
          cidadeAtual = pm.subAdministrativeArea!;
          break;
        } else if (pm.administrativeArea != null &&
            pm.administrativeArea!.isNotEmpty) {
          cidadeAtual = pm.administrativeArea!;
        }
      }

      if (cidadeAtual.isEmpty) cidadeAtual = 'Cidade não encontrada';

      setState(() => cidade = cidadeAtual);
      await carregarDadosTela();
    } catch (e) {
      setState(() {
        cidade = 'Erro ao buscar cidade';
        carregando = false;
      });
    }
  }

  Future<void> _mostrarSelecaoDeCidade() async {
    if (_modalAberto) return;
    setState(() => _modalAberto = true);

    try {
      final posicao = await Geolocator.getCurrentPosition();
      final placemarks = await placemarkFromCoordinates(
        posicao.latitude,
        posicao.longitude,
      );

      String estadoNome = '';
      for (final pm in placemarks) {
        if (pm.administrativeArea != null &&
            pm.administrativeArea!.isNotEmpty) {
          estadoNome = pm.administrativeArea!;
          break;
        }
      }

      if (estadoNome.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível determinar o estado.'),
          ),
        );
        return;
      }

      final Map<String, String> estados = {
        'Acre': 'AC',
        'Alagoas': 'AL',
        'Amapá': 'AP',
        'Amazonas': 'AM',
        'Bahia': 'BA',
        'Ceará': 'CE',
        'Distrito Federal': 'DF',
        'Espírito Santo': 'ES',
        'Goiás': 'GO',
        'Maranhão': 'MA',
        'Mato Grosso': 'MT',
        'Mato Grosso do Sul': 'MS',
        'Minas Gerais': 'MG',
        'Pará': 'PA',
        'Paraíba': 'PB',
        'Paraná': 'PR',
        'Pernambuco': 'PE',
        'Piauí': 'PI',
        'Rio de Janeiro': 'RJ',
        'Rio Grande do Norte': 'RN',
        'Rio Grande do Sul': 'RS',
        'Rondônia': 'RO',
        'Roraima': 'RR',
        'Santa Catarina': 'SC',
        'São Paulo': 'SP',
        'Sergipe': 'SE',
        'Tocantins': 'TO',
      };

      final siglaEstado = estados[estadoNome];
      if (siglaEstado == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estado $estadoNome não encontrado.')),
        );
        return;
      }

      final url = Uri.parse(
        'https://servicodados.ibge.gov.br/api/v1/localidades/estados/$siglaEstado/municipios',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        final cidadesEncontradas =
            data.map<String>((m) => m['nome'] as String).toList()..sort();

        await showModalBottomSheet(
          context: context,
          builder:
              (_) => ListView.builder(
                itemCount: cidadesEncontradas.length,
                itemBuilder: (_, i) {
                  return ListTile(
                    title: Text(cidadesEncontradas[i]),
                    onTap: () async {
                      final cidadeSelecionada = cidadesEncontradas[i];
                      Navigator.pop(context);
                      setState(() => cidade = cidadeSelecionada);
                      await carregarDadosTela();
                    },
                  );
                },
              ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao buscar cidades no IBGE.')),
        );
      }
    } catch (e) {
      debugPrint('Erro ao buscar cidade: $e');
    } finally {
      setState(() => _modalAberto = false);
    }
  }

  double _notaDoRestaurante(Map<String, dynamic> restaurante) {
    final valor = double.tryParse(restaurante['avaliacao']?.toString() ?? '');
    return valor ?? 0.0;
  }

  String _categoriaDoRestaurante(Map<String, dynamic> restaurante) {
    final categoria =
        restaurante['categoria_exibicao']?.toString().trim() ?? '';
    if (categoria.isNotEmpty) return categoria;

    final fallback = restaurante['categoria']?.toString().trim() ?? '';
    if (fallback.isNotEmpty) return fallback;

    return 'Restaurante';
  }

  String _logoDoRestaurante(Map<String, dynamic> restaurante) {
    final logo = restaurante['logo']?.toString() ?? '';
    if (logo.isEmpty) return '';

    if (logo.startsWith('http://') || logo.startsWith('https://')) {
      return logo;
    }

    return 'https://barrest.tech/uploads/restaurantes/$logo';
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

  Widget _buildTag({
    required String texto,
    required Color corTexto,
    required Color corBorda,
    required Color corFundo,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: corBorda),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: corTexto,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _restauranteItem(Map<String, dynamic> restaurante) {
    final nome = restaurante['nome']?.toString() ?? 'Sem Nome';
    final categoria = _categoriaDoRestaurante(restaurante);
    final nota = _notaDoRestaurante(restaurante);
    final imageUrl = _logoDoRestaurante(restaurante);
    final abertoHoje = _restauranteEstaAbertoHoje(restaurante);

    return GestureDetector(
      onTap: () {
        if (cidade == 'Localizando...') return;

        if (!abertoHoje) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Este restaurante está fechado hoje.'),
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
                  idRestaurante: restaurante['id'].toString(),
                ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2E3D34),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child:
                    imageUrl.isNotEmpty
                        ? Image.network(
                          imageUrl,
                          width: 130,
                          height: 140,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => Container(
                                width: 130,
                                height: 140,
                                color: Colors.grey,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white,
                                  size: 50,
                                ),
                              ),
                        )
                        : Container(
                          width: 130,
                          height: 140,
                          color: Colors.grey,
                          child: const Icon(
                            Icons.image_not_supported,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nome,
                        style: const TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      buildEstrelas(nota),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildTag(
                            texto: categoria,
                            corTexto: const Color(0xFFD4AF37),
                            corBorda: const Color(0xFFD4AF37),
                            corFundo: const Color(0x33D4AF37),
                          ),
                          _buildTag(
                            texto: abertoHoje ? 'Aberto hoje' : 'Fechado hoje',
                            corTexto:
                                abertoHoje
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                            corBorda:
                                abertoHoje
                                    ? Colors.greenAccent
                                    : Colors.redAccent,
                            corFundo:
                                abertoHoje
                                    ? Colors.green.withOpacity(0.18)
                                    : Colors.red.withOpacity(0.18),
                          ),
                        ],
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
  }

  @override
  Widget build(BuildContext context) {
    final restaurantesFiltrados =
        restaurantes.where((restaurante) {
          final nome = (restaurante['nome'] ?? '').toString().toLowerCase();
          final categoria = _categoriaDoRestaurante(restaurante).toLowerCase();
          final busca = textoBusca.toLowerCase();

          return nome.contains(busca) || categoria.contains(busca);
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
        title: SizedBox(
          height: 110,
          width: 110,
          child: Image.asset(
            'assets/logo-Transparente.png',
            fit: BoxFit.contain,
          ),
        ),
        actions: [
          const Icon(Icons.location_on, color: Color(0xFFD4AF37)),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _mostrarSelecaoDeCidade,
              child: Text(
                cidade.isEmpty ? 'Cidade não identificada' : cidade,
                style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 16,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              onChanged: (valor) {
                setState(() => textoBusca = valor);
              },
              decoration: InputDecoration(
                hintText: 'Buscar restaurante...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37)),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFFD4AF37)),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                    color: Color(0xFFD4AF37),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                hintStyle: const TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFFD4AF37)),
            const SizedBox(height: 16),
            const Text(
              'ESCOLHA SEU RESTAURANTE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            carregando
                ? const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                  ),
                )
                : Expanded(
                  child:
                      restaurantesFiltrados.isEmpty
                          ? const Center(
                            child: Text(
                              'Nenhum restaurante encontrado.',
                              style: TextStyle(color: Colors.white),
                            ),
                          )
                          : ListView.builder(
                            itemCount: restaurantesFiltrados.length,
                            itemBuilder:
                                (_, i) =>
                                    _restauranteItem(restaurantesFiltrados[i]),
                          ),
                ),
          ],
        ),
      ),
    );
  }
}
