import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';

class EsqueceuSenhaPage extends StatefulWidget {
  const EsqueceuSenhaPage({super.key});

  @override
  State<EsqueceuSenhaPage> createState() => _EsqueceuSenhaPageState();
}

class _EsqueceuSenhaPageState extends State<EsqueceuSenhaPage> {
  final TextEditingController emailController = TextEditingController();
  final List<TextEditingController> codigoControllers =
      List.generate(6, (_) => TextEditingController());
  final TextEditingController novaSenhaController = TextEditingController();

  final List<FocusNode> focusNodes = List.generate(6, (_) => FocusNode());

  bool mostrarCampoCodigo = false;
  bool mostrarCampoNovaSenha = false;
  String usuarioId = '';

  bool validarEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  String gerarCodigo() {
    final random = Random();
    return List.generate(6, (_) => random.nextInt(10)).join();
  }

  String gerarHash(String senha) {
    final bytes = utf8.encode(senha);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> enviarCodigoPorEmail({
    required String email,
    required String codigo,
    required String tempoLimite,
  }) async {
    const serviceId = 'service_d7qx9sh';
    const templateId = 'template_wy4pwyk';
    const publicKey = 'PKkBB5MXJtwL6ka_Q';

    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    final response = await http.post(
      url,
      headers: {
        'origin': 'http://localhost',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': publicKey,
        'template_params': {
          'email': email,
          'passcode': codigo,
          'time': tempoLimite,
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Erro ao enviar e-mail: ${response.body}');
    }
  }

  Future<void> enviarEmailRecuperacao() async {
    final email = emailController.text.trim();

    if (!validarEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite um e-mail válido')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recuperação de senha não está disponível sem backend.'),
      ),
    );
  }

  Future<void> verificarCodigo() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('A verificação de código não está disponível.'),
      ),
    );
  }

  Future<void> redefinirSenha() async {
    final novaSenha = novaSenhaController.text.trim();

    if (novaSenha.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Senha deve ter pelo menos 6 caracteres.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Redefinição de senha não está implementada.'),
      ),
    );
  }

  Widget buildCodigoInputs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (i) {
        return SizedBox(
          width: 40,
          child: TextField(
            controller: codigoControllers[i],
            focusNode: focusNodes[i],
            maxLength: 1,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 20),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              counterText: '',
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFD4AF37)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFD4AF37), width: 2),
              ),
            ),
            onChanged: (value) {
              if (value.isNotEmpty && i < 5) {
                focusNodes[i + 1].requestFocus();
              }
            },
          ),
        );
      }),
    );
  }

  ButtonStyle botaoDourado() {
    return ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFFD4AF37),
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alturaTela = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFD4AF37),
      body: SafeArea(
        child: Row(
          children: [
            Container(
              width: 50,
              color: const Color(0xFFD4AF37),
              child: const Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: Text(
                      'Barrest - Sua reserva perfeita',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.black,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Container(
                  constraints: BoxConstraints(minHeight: alturaTela),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E2D24),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(60),
                      bottomLeft: Radius.circular(60),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        Image.asset('assets/logo-Transparente.png', width: 200, height: 200),
                        const SizedBox(height: 32),
                        const Text('Recuperar Senha', style: TextStyle(fontSize: 24, color: Colors.white)),
                        const SizedBox(height: 24),
                        if (!mostrarCampoCodigo) ...[
                          TextField(
                            controller: emailController,
                            decoration: const InputDecoration(
                              hintText: 'Digite seu e-mail',
                              prefixIcon: Icon(Icons.email, color: Color(0xFFD4AF37)),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFFD4AF37)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFFD4AF37), width: 2),
                              ),
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: enviarEmailRecuperacao,
                            style: botaoDourado(),
                            child: const Text('Enviar código'),
                          ),
                        ] else if (!mostrarCampoNovaSenha) ...[
                          buildCodigoInputs(),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: verificarCodigo,
                            style: botaoDourado(),
                            child: const Text('Verificar código'),
                          ),
                        ] else ...[
                          TextField(
                            controller: novaSenhaController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: 'Nova senha',
                              prefixIcon: Icon(Icons.lock, color: Color(0xFFD4AF37)),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFFD4AF37)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFFD4AF37), width: 2),
                              ),
                            ),
                            style: const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: redefinirSenha,
                            style: botaoDourado(),
                            child: const Text('Redefinir senha'),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Voltar para login', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 16)),
                        ),
                      ],
                    ),
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
