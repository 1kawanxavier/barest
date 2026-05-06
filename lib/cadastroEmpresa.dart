import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'package:barrestapp/text/politica_texto.dart';

const String kCheckLicenseUrl    = 'https://barrest.tech/check_license.php';
const String kGetCategoriesUrl   = 'https://barrest.tech/get_categories.php';
const String kRegisterCompanyUrl = 'https://barrest.tech/register_company.php';

class CadastroEmpresaPage extends StatefulWidget {
  const CadastroEmpresaPage({super.key});

  @override
  State<CadastroEmpresaPage> createState() => _CadastroEmpresaPageState();
}

class _CadastroEmpresaPageState extends State<CadastroEmpresaPage> {
  final ImagePicker _picker = ImagePicker();
  File? _logoFile;

  final nomeController      = TextEditingController();
  final nomeEstabController = TextEditingController();
  final emailController     = TextEditingController();
  final senhaController     = TextEditingController();
  final cnpjController      = TextEditingController();
  final enderecoController  = TextEditingController();

  List<String> categorias   = [];
  List<String> selecionadas = [];
  bool isLoadingCats        = true;

  bool aceitouTermos        = false;
  String cidadeDetectada    = 'Localizando...';

  @override
  void initState() {
    super.initState();
    _obterCidadeAtual();
    _carregarCategorias();
  }

  Future<void> _carregarCategorias() async {
    setState(() {
      isLoadingCats = true;
      categorias = [];
    });
    try {
      // Verifica licença ativa
      final licResp = await http.get(Uri.parse(kCheckLicenseUrl));
      if (licResp.statusCode != 200) throw 'Erro ao verificar licença';
      final licJson = json.decode(licResp.body) as Map<String, dynamic>;
      if (licJson['licensed'] != true) throw 'Licença inválida';
      final String licenseId = licJson['id'].toString();

      // Monta header Basic Auth
      final credentials = utf8.encode(':$licenseId');
      final authHeader  = 'Basic ${base64Encode(credentials)}';

      // Busca categorias
      final resp = await http.get(
        Uri.parse(kGetCategoriesUrl),
        headers: {
          'Authorization': authHeader,
          'Accept':        'application/json',
        },
      );
      if (resp.statusCode != 200) throw 'Status ${resp.statusCode}';

      final list = json.decode(resp.body) as List<dynamic>;
      setState(() {
        categorias = list.map((e) => e['nome'] as String).toList();
      });
    } on SocketException {
      // Sem conexão com a internet
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sem conexão com a internet')),
        );
      }
    } catch (e) {
      debugPrint('Erro ao carregar categorias: $e');
      setState(() {
        categorias = [];
      });
    } finally {
      setState(() {
        isLoadingCats = false;
      });
    }
  }

  Future<void> _obterCidadeAtual() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => cidadeDetectada = 'GPS desativado');
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => cidadeDetectada = 'Permissão negada');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => cidadeDetectada = 'Permissão negada permanentemente');
      return;
    }
    try {
      final posicao = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final placemarks = await placemarkFromCoordinates(posicao.latitude, posicao.longitude);
      String cidadeAtual = '';
      for (final pm in placemarks) {
        if ((pm.locality ?? '').isNotEmpty) {
          cidadeAtual = pm.locality!;
          break;
        } else if ((pm.subAdministrativeArea ?? '').isNotEmpty) {
          cidadeAtual = pm.subAdministrativeArea!;
          break;
        } else if ((pm.administrativeArea ?? '').isNotEmpty) {
          cidadeAtual = pm.administrativeArea!;
        }
      }
      setState(() => cidadeDetectada = cidadeAtual.isEmpty ? 'Cidade não encontrada' : cidadeAtual);
    } catch (e) {
      setState(() => cidadeDetectada = 'Erro ao buscar cidade');
    }
  }

  Future<void> _escolherLogo() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _logoFile = File(picked.path));
  }

  Future<void> _cadastrarEmpresa() async {
    final nome      = nomeController.text.trim();
    final nomeEstab = nomeEstabController.text.trim();
    final email     = emailController.text.trim();
    final senha     = senhaController.text.trim();
    final cnpj      = cnpjController.text.trim();
    final endereco  = _padronizarEndereco(enderecoController.text.trim());
    final cidade    = cidadeDetectada;

    if (!aceitouTermos ||
        nome.isEmpty ||
        nomeEstab.isEmpty ||
        !_validarEmail(email) ||
        senha.length < 6 ||
        cnpj.isEmpty ||
        endereco.isEmpty ||
        cidade.isEmpty ||
        selecionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos corretamente')),
      );
      return;
    }

    final senhaHash = sha256.convert(utf8.encode(senha)).toString();
    final uri = Uri.parse(kRegisterCompanyUrl);
    final req = http.MultipartRequest('POST', uri)
      ..fields['nome_responsavel']     = nome
      ..fields['nome_estabelecimento'] = nomeEstab
      ..fields['email']                = email
      ..fields['senha_hash']           = senhaHash
      ..fields['cnpj']                 = cnpj
      ..fields['endereco']             = endereco
      ..fields['cidade']               = cidade
      ..fields['categorias']           = selecionadas.join(',');
    if (_logoFile != null) {
      req.files.add(await http.MultipartFile.fromPath('logo', _logoFile!.path));
    }
    try {
      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      final data = json.decode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Empresa cadastrada com sucesso!')),
        );
        Navigator.pushReplacementNamed(context, '/categoria');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Erro ao cadastrar.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao cadastrar. Tente novamente.')),
      );
    }
  }

  bool _validarEmail(String email) =>
      RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);

  String _padronizarEndereco(String input) {
    final mapa = {'av': 'avenida', 'r': 'rua', 'rod': 'rodovia', 'estr': 'estrada'};
    final parts = input.toLowerCase().split(' ');
    if (parts.isEmpty) return input;
    final first = mapa[parts[0]] ?? parts[0];
    return ([first, ...parts.sublist(1)]).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final alturaTela = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: const Color(0xFF1E2D24),
      body: SafeArea(
        child: Row(
          children: [  
            Expanded(
              child: Container(
                constraints: BoxConstraints(minHeight: alturaTela),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E2D24),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(60),
                    bottomLeft: Radius.circular(60),
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      const Text(
                        'Cadastro de Estabelecimento',
                        style: TextStyle(fontSize: 24, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      _campoTexto('Nome responsável', nomeController),
                      _campoTexto('Nome do estabelecimento', nomeEstabController),
                      _campoTexto('E-mail', emailController, keyboard: TextInputType.emailAddress),
                      _campoTexto('Senha', senhaController, senha: true),
                      _campoTexto(
                        'CNPJ',
                        cnpjController,
                        keyboard: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, CnpjInputFormatter()],
                      ),
                      _campoTexto('Endereço', enderecoController),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Color(0xFFD4AF37)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.location_city, color: Color(0xffD4AF37)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(cidadeDetectada, style: const TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _escolherLogo,
                        child: Container(
                          height: 100,
                          color: Colors.white10,
                          alignment: Alignment.center,
                          child: _logoFile != null
                              ? Image.file(_logoFile!)
                              : const Text('Selecionar Logo', style: TextStyle(color: Colors.white70)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Categorias:', style: TextStyle(color: Colors.white)),
                      const SizedBox(height: 8),
                      if (isLoadingCats)
                        const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
                      if (!isLoadingCats && categorias.isEmpty)
                        const Center(child: Text('Nenhuma categoria disponível', style: TextStyle(color: Colors.white))),
                      if (!isLoadingCats)
                        Column(
                          children: categorias.map((cat) {
                            return CheckboxListTile(
                              value: selecionadas.contains(cat),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) selecionadas.add(cat);
                                  else selecionadas.remove(cat);
                                });
                              },
                              activeColor: const Color(0xFFD4AF37),
                              checkColor: Colors.black,
                              title: Text(cat, style: const TextStyle(color: Colors.white)),
                            );
                          }).toList(),
                        ),
                      Row(
                        children: [
                          Checkbox(
                            value: aceitouTermos,
                            activeColor: const Color(0xFFD4AF37),
                            onChanged: (val) => setState(() => aceitouTermos = val ?? false),
                          ),
                          const Expanded(
                            child: Text(
                              'Aceito os Termos e Condições',
                              style: TextStyle(color: Colors.white, decoration: TextDecoration.underline),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: aceitouTermos ? _cadastrarEmpresa : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: aceitouTermos ? const Color(0xFFD4AF37) : Colors.grey,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text(
                            'CRIAR CONTA',
                            style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Campo de texto reutilizável
Widget _campoTexto(
  String label,
  TextEditingController controller, {
  bool senha = false,
  TextInputType keyboard = TextInputType.text,
  List<TextInputFormatter>? inputFormatters,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: controller,
      obscureText: senha,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: const TextStyle(color: Colors.white70),
        prefixIcon: const Icon(Icons.edit, color: Color(0xFFD4AF37)),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFD4AF37)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFD4AF37), width: 2),
        ),
      ),
    ),
  );
}

// Formatter para CNPJ
class CnpjInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();
    for (var i = 0; i < digitsOnly.length && i < 14; i++) {
      if (i == 2 || i == 5) buffer.write('.');
      if (i == 8) buffer.write('/');
      if (i == 12) buffer.write('-');
      buffer.write(digitsOnly[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}
