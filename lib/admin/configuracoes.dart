// lib/restaurantes/configuracoes.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

const String kCheckLicenseUrl = 'https://barrest.tech/check_license.php';
const String kGetTaxaUrl       = 'https://barrest.tech/admin/get_taxa.php';
const String kSaveTaxaUrl      = 'https://barrest.tech/admin/save_taxa.php';

class Configuracoes extends StatefulWidget {
  const Configuracoes({Key? key}) : super(key: key);

  @override
  State<Configuracoes> createState() => _ConfiguracoesState();
}

class _ConfiguracoesState extends State<Configuracoes> {
  bool carregando = true;
  bool salvando = false;

  String? _licenseId;
  int _destinatarioOption = 0; // 0 = Cliente, 1 = Restaurante
  int _tipoOption        = 0;  // 0 = Porcentagem, 1 = Valor fixo
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _verificarSessaoEIniciar();
  }

  Future<void> _verificarSessaoEIniciar() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('usuario_id');
    final nivel  = prefs.getInt('usuario_nivel');

    if (userId == null || nivel != 3) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      return;
    }

    try {
      // validar licença
      final licResp = await http
          .get(Uri.parse(kCheckLicenseUrl))
          .timeout(const Duration(seconds: 5));
      if (licResp.statusCode != 200) throw 'Falha ao validar licença';
      final licJson = json.decode(licResp.body) as Map<String, dynamic>;
      if (licJson['licensed'] != true) throw 'Licença inativa';
      _licenseId = licJson['id'].toString();

      // carregar configurações
      await _carregarConfiguracoes();
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
      setState(() => carregando = false);
    }
  }

  Future<void> _carregarConfiguracoes() async {
    try {
      final uri = Uri.parse(
        '$kGetTaxaUrl?license=${Uri.encodeComponent(_licenseId!)}',
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) throw 'Erro ao carregar configurações';
      final data = json.decode(resp.body) as Map<String, dynamic>;

      setState(() {
        _destinatarioOption = (data['destinatario'] as int? ?? 1) - 1;
        _tipoOption         = (data['tipo'] as int? ?? 1) - 1;
        _controller.text    = data['valor']?.toString() ?? '';
        carregando          = false;
      });
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
      setState(() => carregando = false);
    }
  }

  Future<void> _salvarConfiguracoes() async {
    final valor = _controller.text.trim();
    if (valor.isEmpty) {
      _showError('Informe um valor para a taxa');
      return;
    }

    setState(() => salvando = true);
    try {
      final resp = await http.post(
        Uri.parse(kSaveTaxaUrl),
        body: {
          'license': _licenseId!,
          'destinatario': (_destinatarioOption + 1).toString(),
          'tipo': (_tipoOption + 1).toString(),
          'valor': valor,
        },
      ).timeout(const Duration(seconds: 5));

      if (resp.statusCode != 200) throw 'Erro ao salvar configurações';
      final jsonRes = json.decode(resp.body) as Map<String, dynamic>;
      if (jsonRes['success'] != true) throw jsonRes['error'] ?? 'Falha desconhecida';

      if (!mounted) return;
      _showSuccessMessage();
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  /// Exibe mensagem de sucesso de forma destacada
  void _showSuccessMessage() {
    final snack = SnackBar(
      content: Row(
        children: const [
          Icon(Icons.check_circle_outline, color: Colors.white),
          SizedBox(width: 12),
          Expanded(child: Text('Configurações salvas com sucesso!')),
        ],
      ),
      backgroundColor: const Color(0xFFD4AF37),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      duration: const Duration(seconds: 3),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snack);
  }

    /// Exibe mensagem de erro
  void _showError(String message) {
    final snack = SnackBar(
      content: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      duration: const Duration(seconds: 3),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snack);
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF1E2D24);
    const gold   = Color(0xFFD4AF37);

    final label  = _tipoOption == 0 ? 'Porcentagem (%)' : 'Valor fixo (R\$)';
    final hint   = _tipoOption == 0 ? 'Ex: 5' : 'Ex: 2.50';
    final suffix = _tipoOption == 0 ? '%' : 'R\$';

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: true,
        title: const Text('Configurações', style: TextStyle(color: Color(0xFFD4AF37))),
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator(color: gold))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // destinatário
                    Text('Taxa aplicada a:', style: TextStyle(color: gold, fontSize: 18)),
                    const SizedBox(height: 12),
                    ToggleButtons(
                      borderRadius: BorderRadius.circular(12),
                      borderColor: gold,
                      selectedBorderColor: gold,
                      color: gold,
                      selectedColor: Colors.white,
                      fillColor: gold.withOpacity(0.2),
                      isSelected: [
                        _destinatarioOption == 0,
                        _destinatarioOption == 1,
                      ],
                      onPressed: (i) => setState(() => _destinatarioOption = i),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text('Cliente', style: TextStyle(fontSize: 16)),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text('Restaurante', style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // tipo de cobrança
                    Text('Tipo de cobrança:', style: TextStyle(color: gold, fontSize: 18)),
                    const SizedBox(height: 12),
                    ToggleButtons(
                      borderRadius: BorderRadius.circular(12),
                      borderColor: gold,
                      selectedBorderColor: gold,
                      color: gold,
                      selectedColor: Colors.white,
                      fillColor: gold.withOpacity(0.2),
                      isSelected: [
                        _tipoOption == 0,
                        _tipoOption == 1,
                      ],
                      onPressed: (i) => setState(() => _tipoOption = i),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text('Porcentagem', style: TextStyle(fontSize: 16)),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text('Valor fixo', style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // input
                    Text(label, style: TextStyle(color: gold, fontSize: 18)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _controller,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: hint,
                        suffixText: suffix,
                        suffixStyle: TextStyle(color: gold),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: gold),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: gold, width: 2),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 32),
                    // salvar
                    ElevatedButton(
                      onPressed: salvando ? null : _salvarConfiguracoes,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: bgDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: salvando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: bgDark),
                            )
                          : const Text('Salvar', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
