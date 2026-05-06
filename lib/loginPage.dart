import 'dart:convert';
import 'dart:io';  // Para capturar SocketException
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

const String kCheckLicenseUrl = 'https://barrest.tech/check_license.php';
const String kLoginUrl        = 'https://barrest.tech/login_user.php';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();

  bool licencaValida = true;
  int tentativas = 0;

  @override
  void initState() {
    super.initState();
    _verificarLicenca();
  }

  Future<void> _verificarLicenca() async {
    try {
      final ok = await verificarLicenca();
      if (!ok) {
        setState(() => licencaValida = false);
      } else {
        _verificarSessao();
      }
    } on SocketException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sem conexão com a internet')),
      );
    } catch (_) {
      setState(() => licencaValida = false);
    }
  }

  Future<bool> verificarLicenca() async {
    final resp = await http
        .get(Uri.parse(kCheckLicenseUrl))
        .timeout(const Duration(seconds: 5));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return data['licensed'] == true;
    }
    return false;
  }

  Future<void> _verificarSessao() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('usuario_id');
    final nivel  = prefs.getInt('usuario_nivel');
    if (userId != null && nivel != null) {
      if (!mounted) return;
        if (nivel == 1) {
            Navigator.pushReplacementNamed(context, '/categoria');
          } else if (nivel == 3) {
            Navigator.pushReplacementNamed(context, '/adminPage');
          } else {
            Navigator.pushReplacementNamed(context, '/empresaInicioPage');
          }
    }
  }

  String _hashSenha(String senha) =>
      sha256.convert(utf8.encode(senha)).toString();

  bool _validarEmail(String email) =>
      RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);

  Future<void> realizarLogin() async {
    final email = emailController.text.trim();
    final senha = senhaController.text.trim();

    if (tentativas >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Muitas tentativas. Tente novamente mais tarde.')),
      );
      return;
    }
    if (!_validarEmail(email) || senha.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail ou senha inválidos')),
      );
      tentativas++;
      return;
    }

    final senhaHash = _hashSenha(senha);
    final payload = jsonEncode({
      'email':      email,
      'senha_hash': senhaHash,
    });

    try {
      final resp = await http.post(
        Uri.parse(kLoginUrl),
        headers: {'Content-Type': 'application/json'},
        body: payload,
      );
      final data = jsonDecode(resp.body);

      if (resp.statusCode == 200 && data['success'] == true) {
        final user = data['user'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('usuario_id', user['id'].toString());
        await prefs.setInt('usuario_nivel', user['nivel']);
        await prefs.setString('usuario_nome', user['nome']);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bem-vindo(a), ${user['nome']}!')),
        );
        tentativas = 0;

       if (user['nivel'] == 1) {
          Navigator.pushReplacementNamed(context, '/categoria');
        } else if (user['nivel'] == 3) {
          Navigator.pushReplacementNamed(context, '/adminPage');
        } else {
          Navigator.pushReplacementNamed(context, '/empresaInicioPage');
        }
      } else {
        final msg = data['message'] ?? 'Falha no login.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        tentativas++;
      }
    } catch (e) {
      debugPrint('Erro HTTP login: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao conectar. Tente novamente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final alturaTela = MediaQuery.of(context).size.height;

    if (!licencaValida) {
      return Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.lock, size: 100, color: Colors.redAccent),
                SizedBox(height: 20),
                Text('Licença Inválida',
                    style: TextStyle(fontSize: 24, color: Colors.white)),
                SizedBox(height: 12),
                Text(
                  'Este aplicativo não possui uma licença ativa.\nEntre em contato com o suporte.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1E2D24),
      body: SafeArea(
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Image.asset('assets/logo-Transparente.png',
                      width: 200, height: 200),
                  const SizedBox(height: 16),
                  // Aqui a frase foi movida para abaixo do logo:
                  const Text(
                    'Sua reserva perfeita',
                    style: TextStyle(
                      fontSize: 20,
                      color: Color(0xFFD4AF37),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Entrar na conta',
                      style: TextStyle(fontSize: 24, color: Colors.white)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'E-mail',
                      prefixIcon:
                          const Icon(Icons.email, color: Color(0xFFD4AF37)),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFD4AF37)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Color(0xFFD4AF37), width: 2),
                      ),
                      hintStyle: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: senhaController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Senha',
                      prefixIcon:
                          const Icon(Icons.lock, color: Color(0xFFD4AF37)),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFD4AF37)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide:
                            BorderSide(color: Color(0xFFD4AF37), width: 2),
                      ),
                      hintStyle: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: realizarLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text('ENTRAR',
                          style:
                              TextStyle(color: Colors.black, fontSize: 18)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/cadastro'),
                    child: const Text('CRIAR CONTA',
                        style: TextStyle(
                            color: Color(0xFFD4AF37), fontSize: 16)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
