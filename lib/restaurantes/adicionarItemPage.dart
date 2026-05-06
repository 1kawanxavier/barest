import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

const _checkLicenseUrl    = 'https://barrest.tech/check_license.php';
const _getEmpresaUrl      = 'https://barrest.tech/get_empresa.php';
const _novaItemCardapioUrl = 'https://barrest.tech/nova_item_cardapio.php';

class AdicionarItemPage extends StatefulWidget {
  const AdicionarItemPage({super.key});
  @override
  State<AdicionarItemPage> createState() => _AdicionarItemPageState();
}

class _AdicionarItemPageState extends State<AdicionarItemPage> {
  final _picker = ImagePicker();
  final nomeCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  File? _imagemFile;
  String? restauranteId;
  bool carregando = false;

  @override
  void initState() {
    super.initState();
    _carregarRestauranteId();
  }

  Future<void> _carregarRestauranteId() async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final ownerId = prefs.getString('usuario_id') ?? '';
      if (ownerId.isEmpty) throw 'Usuário não autenticado';

      // valida licença
      final licResp = await http.get(Uri.parse(_checkLicenseUrl));
      if (licResp.statusCode != 200) throw 'Erro licença';
      final licJson = json.decode(licResp.body);
      if (licJson['licensed'] != true) throw 'Licença inativa';
      final licenseId = licJson['id'].toString();

      // busca empresa (para obter restaurante_id)
      final uri = Uri.parse('$_getEmpresaUrl'
          '?license=${Uri.encodeComponent(licenseId)}'
          '&owner_id=${Uri.encodeComponent(ownerId)}');
      final resp = await http.get(uri);
      if (resp.statusCode != 200) throw 'Erro get_empresa';
      final jsonRes = json.decode(resp.body);
      if (jsonRes['success'] != true || jsonRes['empresa'] == null) {
        throw 'Empresa não encontrada';
      }
      setState(() => restauranteId = jsonRes['empresa']['id'] as String);
    } catch (e) {
      _mostrarErro(e.toString());
    }
  }

  Future<void> _escolherImagem() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imagemFile = File(picked.path));
    }
  }

  Future<void> _salvarItem() async {
    final nome = nomeCtrl.text.trim();
    final desc = descCtrl.text.trim();
    if (nome.isEmpty || _imagemFile == null || restauranteId == null) {
      _mostrarErro('Preencha todos os campos obrigatórios.');
      return;
    }

    setState(() => carregando = true);
    try {
      final prefs   = await SharedPreferences.getInstance();
      final ownerId = prefs.getString('usuario_id')!;

      // valida licença de novo
      final licResp = await http.get(Uri.parse(_checkLicenseUrl));
      final licJson = json.decode(licResp.body);
      final licenseId = licJson['id'].toString();

      // monta multipart request
      final uri = Uri.parse(_novaItemCardapioUrl);
      final req = http.MultipartRequest('POST', uri)
        ..fields['license']       = licenseId
        ..fields['owner_id']      = ownerId
        ..fields['restaurante_id']= restauranteId!
        ..fields['nome']          = nome
        ..fields['descricao']     = desc
        ..files.add(await http.MultipartFile.fromPath(
            'imagem', _imagemFile!.path));

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);

      if (resp.statusCode != 200) {
        throw 'Status ${resp.statusCode}';
      }
      final body = json.decode(resp.body);
      if (body['success'] != true) {
        throw body['error'] ?? 'Erro desconhecido';
      }

      // sucesso
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Sucesso'),
          content: const Text('Item adicionado com sucesso!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('OK'),
            )
          ],
        ),
      );
    } catch (e) {
      _mostrarErro('Erro ao salvar o item: $e');
    } finally {
      setState(() => carregando = false);
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ... sua UI permanece exatamente igual, apenas _salvarItem e _carregarRestauranteId foram atualizados ...
    return Scaffold(
      backgroundColor: const Color(0xFF1E2D24),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2D24),
        title: const Text('Adicionar Item ao Cardápio',
            style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: carregando
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
            : Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: nomeCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: _decoration('Nome do prato'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: descCtrl,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 2,
                        decoration: _decoration('Descrição (opcional)'),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _escolherImagem,
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            border: Border.all(color: const Color(0xFFD4AF37)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: _imagemFile != null
                              ? Image.file(_imagemFile!, fit: BoxFit.cover)
                              : const Text('Selecionar imagem',
                                  style: TextStyle(color: Colors.white70)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _salvarItem,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              'Salvar',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E2D24)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFFD4AF37)),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFD4AF37)),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
