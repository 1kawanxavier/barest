import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

const _checkLicenseUrl = 'https://barrest.tech/check_license.php';
const _getEmpresaConfigUrl = 'https://barrest.tech/get_empresa_config.php';
const _updateEmpresaConfigUrl = 'https://barrest.tech/update_empresa_config.php';

class ConfiguracoesRestaurantePage extends StatefulWidget {
  const ConfiguracoesRestaurantePage({super.key});

  @override
  State<ConfiguracoesRestaurantePage> createState() =>
      _ConfiguracoesRestaurantePageState();
}

class _ConfiguracoesRestaurantePageState
    extends State<ConfiguracoesRestaurantePage> {
  final ImagePicker _picker = ImagePicker();

  final nomeController = TextEditingController();
  final enderecoController = TextEditingController();
  final cidadeController = TextEditingController();
  final cnpjController = TextEditingController();
  final categoriasController = TextEditingController();
  final emailController = TextEditingController();

  String licenseId = '';
  String? restauranteId;
  String? logoUrl;
  File? novaLogoFile;

  bool carregando = true;
  bool salvando = false;

  final Map<int, bool> diasFuncionamento = {
    1: false, // segunda
    2: false, // terça
    3: false, // quarta
    4: false, // quinta
    5: false, // sexta
    6: false, // sábado
    7: false, // domingo
  };

  @override
  void initState() {
    super.initState();
    _carregarDadosEmpresa();
  }

  @override
  void dispose() {
    nomeController.dispose();
    enderecoController.dispose();
    cidadeController.dispose();
    cnpjController.dispose();
    categoriasController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> _carregarDadosEmpresa() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ownerId = prefs.getString('usuario_id') ?? '';

      if (ownerId.isEmpty) {
        throw 'Usuário não autenticado.';
      }

      final licResp = await http.get(Uri.parse(_checkLicenseUrl));
      if (licResp.statusCode != 200) {
        throw 'Falha ao validar licença.';
      }

      final licJson = json.decode(licResp.body) as Map<String, dynamic>;
      if (licJson['licensed'] != true) {
        throw 'Licença inativa.';
      }

      licenseId = licJson['id'].toString();

      final uri = Uri.parse(
        '$_getEmpresaConfigUrl'
        '?license=${Uri.encodeComponent(licenseId)}'
        '&owner_id=${Uri.encodeComponent(ownerId)}',
      );

      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        throw 'Erro ao buscar empresa: ${resp.statusCode}';
      }

      final jsonRes = json.decode(resp.body) as Map<String, dynamic>;

      if (jsonRes['success'] != true || jsonRes['empresa'] == null) {
        throw jsonRes['message']?.toString() ?? 'Empresa não encontrada.';
      }

      final empresa = jsonRes['empresa'] as Map<String, dynamic>;

      restauranteId = empresa['id']?.toString();
      logoUrl = empresa['logo_url']?.toString();

      nomeController.text = empresa['nome']?.toString() ?? '';
      enderecoController.text = empresa['endereco']?.toString() ?? '';
      cidadeController.text = empresa['cidade']?.toString() ?? '';
      cnpjController.text = empresa['cnpj']?.toString() ?? '';
      categoriasController.text = empresa['idcategorias']?.toString() ?? '';
      emailController.text = empresa['email']?.toString() ?? '';

      _carregarDiasFuncionamento(
        empresa['dias_funcionamento']?.toString() ?? '',
      );

      if (!mounted) return;
      setState(() {
        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      _mostrarErro(e.toString());
      setState(() {
        carregando = false;
      });
    }
  }

  void _carregarDiasFuncionamento(String diasTexto) {
    for (final key in diasFuncionamento.keys) {
      diasFuncionamento[key] = false;
    }

    if (diasTexto.trim().isEmpty) return;

    final dias = diasTexto
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);

    for (final dia in dias) {
      final numero = int.tryParse(dia);
      if (numero != null && diasFuncionamento.containsKey(numero)) {
        diasFuncionamento[numero] = true;
      }
    }
  }

  String _montarDiasFuncionamentoTexto() {
    final diasSelecionados = diasFuncionamento.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key.toString())
        .toList();

    return diasSelecionados.join(',');
  }

  Future<void> _selecionarNovaLogo() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (picked == null) return;

      final file = File(picked.path);
      final existe = await file.exists();

      if (!existe) {
        _mostrarErro('Não foi possível acessar a imagem selecionada.');
        return;
      }

      setState(() {
        novaLogoFile = file;
      });
    } catch (e) {
      _mostrarErro('Erro ao selecionar imagem: $e');
    }
  }

  Future<void> _salvarAlteracoes() async {
    if (restauranteId == null || restauranteId!.isEmpty) {
      _mostrarErro('Restaurante não identificado.');
      return;
    }

    if (nomeController.text.trim().isEmpty) {
      _mostrarErro('Informe o nome do restaurante.');
      return;
    }

    setState(() => salvando = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(_updateEmpresaConfigUrl),
      );

      request.fields['license'] = licenseId;
      request.fields['id'] = restauranteId!;
      request.fields['nome'] = nomeController.text.trim();
      request.fields['endereco'] = enderecoController.text.trim();
      request.fields['cidade'] = cidadeController.text.trim();
      request.fields['cnpj'] = cnpjController.text.trim();
      request.fields['idcategorias'] = categoriasController.text.trim();
      request.fields['email'] = emailController.text.trim();
      request.fields['dias_funcionamento'] = _montarDiasFuncionamentoTexto();

      if (novaLogoFile != null) {
        final existe = await novaLogoFile!.exists();

        if (!existe) {
          _mostrarErro(
            'A imagem selecionada não foi encontrada. Escolha a logo novamente.',
          );
          if (mounted) {
            setState(() => salvando = false);
          }
          return;
        }

        request.files.add(
          await http.MultipartFile.fromPath('logo', novaLogoFile!.path),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw 'Erro HTTP ${response.statusCode}';
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      debugPrint('RESPOSTA UPDATE: ${response.body}');

      final debugData = data['debug'] as Map<String, dynamic>?;

      if (debugData != null) {
        debugPrint('ID PROPRIETARIO: ${debugData['idproprietario']}');
        debugPrint('EMAIL ANTES: ${debugData['email_antes']}');
        debugPrint('EMAIL RECEBIDO: ${debugData['email_recebido']}');
        debugPrint('EMAIL DEPOIS: ${debugData['email_depois']}');
        debugPrint('USUARIO ROWS: ${debugData['usuario_rows']}');
        debugPrint('RESTAURANTE ROWS: ${debugData['restaurante_rows']}');
      }

      if (data['success'] != true) {
        throw data['message']?.toString() ?? 'Erro ao salvar alterações.';
      }

      if (data['logo_url'] != null && data['logo_url'].toString().isNotEmpty) {
        logoUrl = data['logo_url'].toString();
      }

      if (!mounted) return;

      setState(() {
        novaLogoFile = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados atualizados com sucesso.'),
        ),
      );
    } catch (e) {
      _mostrarErro('Erro ao salvar: $e');
    } finally {
      if (mounted) {
        setState(() => salvando = false);
      }
    }
  }

  void _mostrarErro(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  Widget _campo({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    String? hint,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFFD4AF37)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
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
        ),
      ),
    );
  }

  Widget _buildDiasFuncionamento() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD4AF37)),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withOpacity(0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dias de funcionamento',
            style: TextStyle(
              color: Color(0xFFD4AF37),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _checkboxDia(1, 'Segunda-feira'),
          _checkboxDia(2, 'Terça-feira'),
          _checkboxDia(3, 'Quarta-feira'),
          _checkboxDia(4, 'Quinta-feira'),
          _checkboxDia(5, 'Sexta-feira'),
          _checkboxDia(6, 'Sábado'),
          _checkboxDia(7, 'Domingo'),
        ],
      ),
    );
  }

  Widget _checkboxDia(int dia, String titulo) {
    return CheckboxListTile(
      value: diasFuncionamento[dia] ?? false,
      onChanged: (valor) {
        setState(() {
          diasFuncionamento[dia] = valor ?? false;
        });
      },
      activeColor: const Color(0xFFD4AF37),
      checkColor: const Color(0xFF1E2D24),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: Text(
        titulo,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildLogo() {
    if (novaLogoFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          novaLogoFile!,
          width: 150,
          height: 150,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _logoPlaceholder(),
        ),
      );
    }

    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          logoUrl!,
          width: 150,
          height: 150,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _logoPlaceholder(),
        ),
      );
    }

    return _logoPlaceholder();
  }

  Widget _logoPlaceholder() {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFD4AF37)),
        borderRadius: BorderRadius.circular(16),
        color: Colors.white10,
      ),
      child: const Icon(
        Icons.store,
        color: Color(0xFFD4AF37),
        size: 60,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2D24),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2D24),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Configurações',
          style: TextStyle(
            color: Color(0xFFD4AF37),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
      ),
      body: carregando
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFD4AF37),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _buildLogo()),
                    const SizedBox(height: 12),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: _selecionarNovaLogo,
                        icon: const Icon(
                          Icons.image,
                          color: Color(0xFFD4AF37),
                        ),
                        label: const Text(
                          'Alterar logotipo',
                          style: TextStyle(color: Color(0xFFD4AF37)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFD4AF37)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _campo(
                      label: 'Nome do restaurante',
                      controller: nomeController,
                    ),
                    _campo(
                      label: 'Email',
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    _campo(
                      label: 'Endereço',
                      controller: enderecoController,
                      maxLines: 2,
                    ),
                    _campo(
                      label: 'Cidade',
                      controller: cidadeController,
                    ),
                    _campo(
                      label: 'CNPJ',
                      controller: cnpjController,
                      keyboardType: TextInputType.number,
                    ),
                    _campo(
                      label: 'Categoria',
                      controller: categoriasController,
                      hint: 'Ex: alacarte',
                    ),
                    _buildDiasFuncionamento(),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: salvando ? null : _salvarAlteracoes,
                        icon: salvando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF1E2D24),
                                ),
                              )
                            : const Icon(
                                Icons.save,
                                color: Color(0xFF1E2D24),
                              ),
                        label: Text(
                          salvando ? 'Salvando...' : 'Salvar alterações',
                          style: const TextStyle(
                            color: Color(0xFF1E2D24),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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