import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EditarCardapioPage extends StatefulWidget {
  const EditarCardapioPage({super.key});

  @override
  State<EditarCardapioPage> createState() => _EditarCardapioPageState();
}

class _EditarCardapioPageState extends State<EditarCardapioPage> {
  final picker = ImagePicker();

  String licenseId = '';
  String usuarioId = '';
  String restauranteId = '';
  String nomeRestaurante = '';

  bool carregando = true;
  List<Map<String, dynamic>> pratos = [];
  Map<String, dynamic>? pratoSelecionado;

  final nomeEdicaoController = TextEditingController();
  final textoPromocaoController = TextEditingController();

  File? novaImagem;
  bool emPromocao = false;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  @override
  void dispose() {
    nomeEdicaoController.dispose();
    textoPromocaoController.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    final prefs = await SharedPreferences.getInstance();
    final uId = prefs.getString('usuario_id');
    if (uId == null) {
      _mostrarErro('Usuário não autenticado');
      return;
    }
    usuarioId = uId;

    final licResp = await http.get(
      Uri.parse('https://barrest.tech/check_license.php'),
    );
    if (licResp.statusCode != 200) {
      _mostrarErro('Erro ao validar licença');
      return;
    }

    final licJson = json.decode(licResp.body) as Map<String, dynamic>;
    if (licJson['licensed'] != true) {
      _mostrarErro('Licença inativa');
      return;
    }
    licenseId = licJson['id'].toString();

    final restUri = Uri.parse(
      'https://barrest.tech/get_restaurante_by_owner.php'
      '?license=$licenseId'
      '&usuario_id=$usuarioId',
    );

    final restResp = await http.get(restUri);
    if (restResp.statusCode != 200) {
      _mostrarErro('Falha ao carregar restaurante');
      return;
    }

    final restJson = json.decode(restResp.body) as Map<String, dynamic>;
    if (restJson['restaurante'] == null) {
      _mostrarErro('Restaurante não encontrado');
      return;
    }

    final rest = restJson['restaurante'] as Map<String, dynamic>;
    restauranteId = rest['id'].toString();
    nomeRestaurante = rest['nome']?.toString() ?? '';

    await _carregarPratos();
    setState(() => carregando = false);
  }

  Future<void> _carregarPratos() async {
    setState(() => carregando = true);

    final uri = Uri.parse(
      'https://barrest.tech/get_menu.php'
      '?license=$licenseId'
      '&restaurante_id=$restauranteId',
    );

    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      _mostrarErro('Erro ao buscar cardápio');
      return;
    }

    final List<dynamic> data = json.decode(resp.body);
    setState(() {
      pratos = data.map((e) => Map<String, dynamic>.from(e)).toList();
      carregando = false;
    });
  }

  Future<void> _atualizarPrato() async {
    if (pratoSelecionado == null) return;

    final id = pratoSelecionado!['id'];
    final novoNome = nomeEdicaoController.text.trim();

    if (novoNome.isEmpty) {
      _mostrarErro('Informe o nome do prato.');
      return;
    }

    String? novoArquivo = pratoSelecionado!['imagem']?.toString();

    if (novaImagem != null) {
      final ext = novaImagem!.path.split('.').last;
      final filename = '${DateTime.now().millisecondsSinceEpoch}.$ext';

      final uploadReq = http.MultipartRequest(
        'POST',
        Uri.parse('https://barrest.tech/upload_menu_image.php'),
      );

      uploadReq.fields['license'] = licenseId;
      uploadReq.fields['restaurante_id'] = restauranteId;
      uploadReq.fields['id'] = id.toString();

      uploadReq.files.add(
        await http.MultipartFile.fromPath(
          'file',
          novaImagem!.path,
          filename: filename,
        ),
      );

      try {
        final uploadResp = await uploadReq.send();
        final uploadBody = await uploadResp.stream.bytesToString();

        if (uploadResp.statusCode != 200) {
          _mostrarErro('Falha no upload de imagem: ${uploadResp.statusCode}');
          return;
        }

        final uploadJson = json.decode(uploadBody) as Map<String, dynamic>;
        if (uploadJson['success'] != true || uploadJson['filename'] == null) {
          _mostrarErro('Falha no upload de imagem: ${uploadJson['error'] ?? 'Resposta inválida'}');
          return;
        }

        novoArquivo = uploadJson['filename'].toString();
      } catch (e) {
        _mostrarErro('Erro no upload de imagem: $e');
        return;
      }
    }

    final updResp = await http.post(
      Uri.parse('https://barrest.tech/update_menu.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'license': licenseId,
        'restaurante_id': restauranteId,
        'id': id,
        'nome': novoNome,
        'imagem': novoArquivo,
        'em_promocao': emPromocao ? 1 : 0,
        'texto_promocao': emPromocao
            ? textoPromocaoController.text.trim()
            : '',
      }),
    );

    if (updResp.statusCode != 200) {
      _mostrarErro('Erro ao atualizar prato: ${updResp.statusCode} - ${updResp.body}');
      return;
    }

    try {
      final updJson = json.decode(updResp.body) as Map<String, dynamic>;
      if (updJson['success'] != true) {
        _mostrarErro('Erro ao atualizar prato: ${updJson['error'] ?? 'Resposta inválida'}');
        return;
      }
    } catch (_) {
      _mostrarErro('Erro ao atualizar prato: resposta inválida do servidor');
      return;
    }

    await _carregarPratos();

    setState(() {
      pratoSelecionado = null;
      novaImagem = null;
      emPromocao = false;
      textoPromocaoController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prato atualizado com sucesso!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _deletarPrato() async {
    if (pratoSelecionado == null) return;

    final id = pratoSelecionado!['id'];

    final resp = await http.get(
      Uri.parse(
        'https://barrest.tech/delete_menu.php'
        '?license=$licenseId'
        '&restaurante_id=$restauranteId'
        '&id=$id',
      ),
    );

    if (resp.statusCode != 200) {
      _mostrarErro('Erro ao deletar prato');
      return;
    }

    await _carregarPratos();

    setState(() {
      pratoSelecionado = null;
      emPromocao = false;
      textoPromocaoController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prato deletado.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _selecionarPrato(Map<String, dynamic> p) {
    setState(() {
      pratoSelecionado = p;
      nomeEdicaoController.text = p['nome']?.toString() ?? '';
      novaImagem = null;

      final promocaoValor = p['em_promocao'];
      emPromocao =
          promocaoValor == 1 || promocaoValor == '1' || promocaoValor == true;

      textoPromocaoController.text = p['texto_promocao']?.toString() ?? '';
    });
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
    setState(() => carregando = false);
  }

  String _urlImagem(String? img) {
    if (img == null || img.isEmpty) return '';
    return 'https://barrest.tech/uploads/cardapio/$img';
  }

  Widget _buildImagemPrato(Map<String, dynamic> p) {
    final url = _urlImagem(p['imagem']?.toString());
    final promocaoValor = p['em_promocao'];
    final pratoEmPromocao =
        promocaoValor == 1 || promocaoValor == '1' || promocaoValor == true;
    final textoPromo = p['texto_promocao']?.toString().trim() ?? '';

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            height: 100,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                const Icon(Icons.broken_image, color: Colors.white),
          ),
        ),
        if (pratoEmPromocao)
          Positioned(
            top: 6,
            left: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                textoPromo.isNotEmpty ? textoPromo : 'Em promoção',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
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
        title: Text(
          nomeRestaurante,
          style: const TextStyle(color: Color(0xFFD4AF37)),
        ),
      ),
      body: carregando
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
            )
          : Column(
              children: [
                Expanded(
                  child: pratos.isEmpty
                      ? const Center(
                          child: Text(
                            'Nenhum prato encontrado.',
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: pratos.length,
                          itemBuilder: (_, i) {
                            final p = pratos[i];
                            return GestureDetector(
                              onTap: () => _selecionarPrato(p),
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 100,
                                    width: double.infinity,
                                    child: _buildImagemPrato(p),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    p['nome'] ?? 'Sem nome',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFD4AF37),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                if (pratoSelecionado != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Editar Prato',
                          style: TextStyle(color: Colors.white, fontSize: 20),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: nomeEdicaoController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Novo nome',
                            labelStyle: TextStyle(color: Color(0xFFD4AF37)),
                            enabledBorder: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Color(0xFFD4AF37)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Color(0xFFD4AF37), width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () async {
                            if (_isPickingImage) return;

                            setState(() => _isPickingImage = true);
                            try {
                              final picked = await picker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (picked != null) {
                                setState(() => novaImagem = File(picked.path));
                              }
                            } finally {
                              setState(() => _isPickingImage = false);
                            }
                          },
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFD4AF37),
                              ),
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white10,
                            ),
                            alignment: Alignment.center,
                            child: novaImagem != null
                                ? Image.file(novaImagem!, fit: BoxFit.cover)
                                : Image.network(
                                    _urlImagem(
                                      pratoSelecionado!['imagem']?.toString(),
                                    ),
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(
                                      Icons.broken_image,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        CheckboxListTile(
                          value: emPromocao,
                          onChanged: (valor) {
                            setState(() {
                              emPromocao = valor ?? false;
                              if (!emPromocao) {
                                textoPromocaoController.clear();
                              }
                            });
                          },
                          activeColor: const Color(0xFFD4AF37),
                          checkColor: Colors.black,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Ativar promoção',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        if (emPromocao) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: textoPromocaoController,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(
                              labelText: 'Texto da promoção',
                              hintText: 'Ex: 10% OFF hoje',
                              hintStyle: TextStyle(color: Colors.white54),
                              labelStyle:
                                  TextStyle(color: Color(0xFFD4AF37)),
                              enabledBorder: OutlineInputBorder(
                                borderSide:
                                    BorderSide(color: Color(0xFFD4AF37)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Color(0xFFD4AF37),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _atualizarPrato,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD4AF37),
                                ),
                                child: const Text(
                                  'Atualizar',
                                  style: TextStyle(color: Colors.black),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _deletarPrato,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text(
                                  'Deletar',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}