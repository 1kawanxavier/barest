import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class SaquesPage extends StatefulWidget {
  const SaquesPage({Key? key}) : super(key: key);

  @override
  State<SaquesPage> createState() => _SaquesPageState();
}

class _SaquesPageState extends State<SaquesPage> {
  static const _checkLicenseUrl  = 'https://barrest.tech/check_license.php';
  static const _getSaquesBaseUrl = 'https://barrest.tech/admin/get_saques.php';

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _saques = [];
  String? _licenseId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _fetchLicense();
      await _fetchSaques();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _fetchLicense() async {
    final resp = await http.get(Uri.parse(_checkLicenseUrl)).timeout(
      const Duration(seconds: 5),
    );
    if (resp.statusCode != 200) throw 'Erro ao validar licença';
    final map = json.decode(resp.body) as Map<String, dynamic>;
    if (map['licensed'] != true) throw 'Licença inativa';
    _licenseId = map['id'].toString();
  }

  Future<void> _fetchSaques() async {
    if (_licenseId == null) throw 'Licença não obtida';
    setState(() {
      _loading = true;
      _error = null;
    });

    final uri = Uri.parse(
      '$_getSaquesBaseUrl?license=${Uri.encodeComponent(_licenseId!)}'
    );
    final resp = await http.get(uri).timeout(
      const Duration(seconds: 10),
    );
    if (resp.statusCode != 200) throw 'Erro ${resp.statusCode} ao buscar saques';
    final body = json.decode(resp.body) as Map<String, dynamic>;
    if (body['success'] != true) throw body['error'] ?? 'Resposta inesperada';

    setState(() {
      _saques = List<Map<String, dynamic>>.from(body['saques'] as List);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF1E2D24);
    const gold   = Color(0xFFD4AF37);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        iconTheme: const IconThemeData(color: gold),
        title: const Text('Saques', style: TextStyle(color: gold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: gold))
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                )
              : _saques.isEmpty
                  ? const Center(
                      child: Text(
                        'Nenhuma solicitação de saque.',
                        style: TextStyle(color: Colors.white60, fontSize: 16),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _saques.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Colors.white24),
                      itemBuilder: (context, i) {
                        final t               = _saques[i];
                        final valor           = double.tryParse(t['valor'].toString()) ?? 0.0;
                        final nomeRestaurante = t['restaurante_nome'] as String? ?? '—';

                        return ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SaqueDetalhesPage(
                                  saque: t,
                                  licenseId: _licenseId!,
                                ),
                              ),
                            );
                          },
                          tileColor: const Color(0xFF2E3D34),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                          title: const Text(
                            'PIX Saque',
                            style: TextStyle(
                              color: gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Restaurante: $nomeRestaurante',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: Text(
                            'R\$${valor.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: gold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class SaqueDetalhesPage extends StatefulWidget {
  final Map<String, dynamic> saque;
  final String licenseId;
  const SaqueDetalhesPage({
    required this.saque,
    required this.licenseId,
    Key? key,
  }) : super(key: key);

  @override
  _SaqueDetalhesPageState createState() => _SaqueDetalhesPageState();
}

class _SaqueDetalhesPageState extends State<SaqueDetalhesPage> {
  File? _image;
  bool _uploading = false;

  Future<void> _copyKey() async {
    final desc = widget.saque['descricao'] as String;
    final match = RegExp(r'chave:\s*(.+)$', caseSensitive: false)
        .firstMatch(desc);
    final chave = match?.group(1)?.trim() ?? '';
    await Clipboard.setData(ClipboardData(text: chave));
    // manter o snack, mas complementar com a página de confirmação depois do upload
    ScaffoldMessenger.of(context)
      .showSnackBar(const SnackBar(content: Text('Chave PIX copiada!')));
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;
    setState(() => _image = File(xfile.path));
    await _uploadComprovante();
  }

  Future<void> _uploadComprovante() async {
    if (_image == null) return;
    setState(() => _uploading = true);

    final uri = Uri.parse('https://barrest.tech/admin/upload_comprovante.php');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Basic ${base64Encode(utf8.encode(':' + widget.licenseId))}'
      ..fields['transacao_id'] = widget.saque['id'] as String
      ..files.add(await http.MultipartFile.fromPath(
        'comprovante', _image!.path,
      ));

    final resp = await req.send();
    setState(() => _uploading = false);

    if (resp.statusCode == 200) {
      // navega para página de confirmação
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ConfirmacaoPage()),
      );
    } else {
      // em caso de erro, ainda exibimos Modal de erro
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF2E3D34),
          title: const Text('Erro', style: TextStyle(color: Colors.redAccent)),
          content: const Text('Falha ao enviar comprovante.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final desc     = widget.saque['descricao'] as String;
    final data     = widget.saque['data'] as String;
    final valor    = double.tryParse(widget.saque['valor'].toString()) ?? 0.0;
    final nomeRest = widget.saque['restaurante_nome'] as String;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Saque'),
        backgroundColor: const Color(0xFF1E2D24),
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
      ),
      backgroundColor: const Color(0xFF1E2D24),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Restaurante: $nomeRest',
                style: const TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 8),
            Text('Valor: R\$${valor.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 8),
            Text('Data: $data',
                style: const TextStyle(color: Colors.white70, fontSize: 16)),
            const Divider(color: Colors.white54, height: 32),
            GestureDetector(
              onTap: _copyKey,
              child: Container(
                padding: const EdgeInsets.all(12),
                color: const Color(0xFF2E3D34),
                child: Text(
                  desc,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _uploading ? null : _pickAndUpload,
              icon: const Icon(Icons.upload_file, color: Colors.black),
              label: Text(_uploading
                  ? 'Enviando...'
                  : 'Enviar Comprovante',
                  style: const TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Página de confirmação que aparece após o upload
class ConfirmacaoPage extends StatelessWidget {
  const ConfirmacaoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF1E2D24);
    const gold   = Color(0xFFD4AF37);

    return Scaffold(
      backgroundColor: bgDark,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 120, color: gold),
            const SizedBox(height: 24),
            const Text(
              'Comprovante enviado\ncom sucesso!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              onPressed: () {
                // volta para a lista de saques (removendo esta página)
                Navigator.popUntil(context, (r) => r.isFirst);
              },
              child: const Text(
                'Voltar',
                style: TextStyle(color: Colors.black, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
