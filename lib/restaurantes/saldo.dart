import 'dart:convert';
import 'package:barrestapp/restaurantes/qr_pay.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SaldoPage extends StatefulWidget {
  const SaldoPage({super.key});

  @override
  State<SaldoPage> createState() => _SaldoPageState();
}

class _SaldoPageState extends State<SaldoPage> with WidgetsBindingObserver {
  String? usuarioId;
  String? licenseId;
  double saldoAtual = 0.00;
  final TextEditingController _valorCtrl = TextEditingController();
  List<Map<String, dynamic>> transacoes = [];

  static const _mpAccessToken =
      'APP_USR-5744811975964717-071418-72170660d6e61b882065d130f878728d-180818825';

  static const _kCheckLicenseUrl = 'https://barrest.tech/check_license.php';
  static const _kGetSaldoUrl    = 'https://barrest.tech/get_saldo.php';
  static const _kUpsertSaldoUrl = 'https://barrest.tech/upsert_saldo.php';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inicializarDados();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _valorCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && usuarioId != null) {
      _buscarOuCriarSaldo(usuarioId!);
      _carregarTransacoes();
    }
  }

  Future<void> _inicializarDados() async {
    try {
      await _fetchAndSetLicenseId();
      await carregarUsuarioId();
    } catch (e) {
      debugPrint('Erro ao inicializar: $e');
    }
  }

  Future<void> _fetchAndSetLicenseId() async {
    final resp = await http.get(Uri.parse(_kCheckLicenseUrl));
    if (resp.statusCode != 200) throw 'Erro ao verificar licença';
    final jsonMap = json.decode(resp.body) as Map<String, dynamic>;
    if (jsonMap['licensed'] != true) throw 'Licença inativa';
    licenseId = jsonMap['id'].toString();
  }

  Future<void> carregarUsuarioId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('usuario_id');
    if (id != null && id.isNotEmpty) {
      usuarioId = id;
      await _buscarOuCriarSaldo(id);
      await _carregarTransacoes();
    }
  }

  Future<void> _buscarOuCriarSaldo(String idUsuario) async {
    if (licenseId == null) return;
    try {
      final basicAuth = 'Basic ${base64Encode(utf8.encode(':$licenseId'))}';
      final uri = Uri.parse(
        '$_kGetSaldoUrl?usuario_id=${Uri.encodeComponent(idUsuario)}'
      );
      final resp = await http.get(uri, headers: {
        'Authorization': basicAuth,
      });
      if (resp.statusCode != 200) throw 'Status ${resp.statusCode}';
      final jsonMap = json.decode(resp.body) as Map<String, dynamic>;

      if (jsonMap['valor'] != null) {
        setState(() => saldoAtual = double.parse(jsonMap['valor'].toString()));
      } else {
        final upsert = await http.post(
          Uri.parse(_kUpsertSaldoUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': basicAuth,
          },
          body: json.encode({
            'usuario_id': idUsuario,
            'valor': 0.00,
          }),
        );
        if (upsert.statusCode == 200) {
          setState(() => saldoAtual = 0.00);
        } else {
          throw 'Erro ao criar saldo: ${upsert.statusCode}';
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar/criar saldo: $e');
    }
  }

  Future<void> _carregarTransacoes() async {
    if (usuarioId == null || licenseId == null) return;
    try {
      final basicAuth = 'Basic ${base64Encode(utf8.encode(':$licenseId'))}';
      final uri = Uri.parse(
        'https://barrest.tech/get_transacoes.php?usuario_id=${Uri.encodeComponent(usuarioId!)}'
      );
      final resp = await http.get(uri, headers: {'Authorization': basicAuth});
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List;
        setState(() {
          transacoes = List<Map<String, dynamic>>.from(data);
        });
      } else {
        debugPrint('Erro ao buscar transações: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('Erro ao buscar transações: $e');
    }
  }
Widget _botaoValorSugerido(double valor) {
  return OutlinedButton(
    style: OutlinedButton.styleFrom(
      side: const BorderSide(color: Color(0xFFD4AF37)),
      foregroundColor: const Color(0xFFD4AF37),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    ),
    onPressed: () => _adicionarValorSugerido(valor),
    child: Text(
      'R\$ ${valor.toStringAsFixed(0)}',
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
  );
}
void _adicionarValorSugerido(double valor) {
  final textoAtual = _valorCtrl.text.replaceAll(',', '.').trim();
  final valorAtual = double.tryParse(textoAtual) ?? 0.0;

  final novoValor = valorAtual + valor;

  _valorCtrl.text = novoValor.toStringAsFixed(2);
  _valorCtrl.selection = TextSelection.fromPosition(
    TextPosition(offset: _valorCtrl.text.length),
  );
}
  Future<void> _showAdicionarSaldoDialog() async {
    if (usuarioId == null) return;
    _valorCtrl.clear();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF2E3D34),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 2),
        ),
        title: const Text(
          'Adicionar Saldo',
          style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Escolha um valor rápido ou digite manualmente:',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 14),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _botaoValorSugerido(10),
                _botaoValorSugerido(15),
                _botaoValorSugerido(30),
              ],
            ),

            const SizedBox(height: 18),

            TextField(
              controller: _valorCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: const TextStyle(color: Colors.white, fontSize: 20),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                prefixText: 'R\$ ',
                prefixStyle: TextStyle(color: Color(0xFFD4AF37)),
                hintText: '0.00',
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFD4AF37)),
                ),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final text = _valorCtrl.text.replaceAll(',', '.');
              final valor = double.tryParse(text);
              if (valor == null || valor <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Informe um valor válido')),
                );
                return;
              }
              Navigator.of(context).pop();
              await _criarTransacaoEGerarLink(valor);
            },
            child: const Text('Adicionar', style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  Future<void> _criarTransacaoEGerarLink(double valor) async {
    if (licenseId == null) return;
    final uri = Uri.parse('https://api.mercadopago.com/checkout/preferences');
    final body = jsonEncode({
      'items': [
        {'title': 'Adicionar Saldo', 'quantity': 1, 'unit_price': valor}
      ],
      'metadata': {
        'usuario_id': usuarioId,
        'license_id': licenseId,
      },
      'back_urls': {
        'success': 'https://yourapp.com/success',
        'failure': 'https://yourapp.com/failure',
        'pending': 'https://yourapp.com/pending'
      }
    });
    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $_mpAccessToken',
        'Content-Type': 'application/json'
      },
      body: body,
    );
    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final link = data['init_point'] as String;
      await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    } else {
      String errorMsg;
      try {
        final err = jsonDecode(response.body);
        errorMsg = err['message'] ?? 'Erro desconhecido';
      } catch (_) {
        errorMsg = 'Status ${response.statusCode}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar link MP: $errorMsg')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2D24),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2D24),
        elevation: 0,
        title: const Text('Saldo', style: TextStyle(color: Color(0xFFD4AF37))),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Card(
                color: const Color(0xFF2E3D34),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text('Saldo Disponível',
                          style: TextStyle(color: Colors.white70, fontSize: 16)),
                      const SizedBox(height: 12),
                      Text(
                        'R\$ ${saldoAtual.toStringAsFixed(2)}',
                        style: const TextStyle(
                            color: Color(0xFFD4AF37),
                            fontSize: 28,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _formaPagamentoCard(
                  icon: Icons.pix,
                  label: 'Adicionar Saldo',
                  onTap: _showAdicionarSaldoDialog,
                ),
                const SizedBox(width: 12),
                _formaPagamentoCard(
                  icon: Icons.credit_card,
                  label: 'Pagar',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const QrPayPage()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Histórico de Transações',
                style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: transacoes.isEmpty
                  ? Center(
                      child: Text(
                        'Nenhuma transação encontrada.',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
                      ),
                    )
                  : ListView.separated(
                      itemCount: transacoes.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white24),
                      itemBuilder: (context, index) {
                        final trans = transacoes[index];
                        final tipo = trans['tipo'] as String? ?? '';
                        final valor = double.tryParse(trans['valor'].toString()) ?? 0.0;
                        final data = DateTime.tryParse(trans['data'] ?? '') ?? DateTime.now();
                        final destinoNome = trans['destino_nome'] as String?;

                        final isAdicao = tipo.toLowerCase().contains('adição');
                        final cor = isAdicao ? Colors.green : Colors.red;

                        final texto = isAdicao
                            ? 'Adição de saldo'
                            : (destinoNome != null && destinoNome.isNotEmpty)
                                ? 'Pagou ao $destinoNome'
                                : 'Pagamento';

                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            texto,
                            style: TextStyle(color: cor, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${data.day.toString().padLeft(2,'0')}/'
                            '${data.month.toString().padLeft(2,'0')}/'
                            '${data.year}',
                            style: const TextStyle(color: Colors.white54),
                          ),
                          trailing: Text(
                            'R\$ ${valor.toStringAsFixed(2)}',
                            style: TextStyle(color: cor, fontWeight: FontWeight.bold),
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

  Widget _formaPagamentoCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Card(
        color: const Color(0xFF2E3D34),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 30, color: const Color(0xFFD4AF37)),
                const SizedBox(height: 8),
                Text(label, style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}