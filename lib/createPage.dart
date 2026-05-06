import 'dart:convert';
import 'package:barrestapp/text/politica_texto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;                   // Para requisições HTTP
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kRegisterUrl = 'https://barrest.tech/register_user.php';

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  bool aceitouTermos = false;

  final nomeController  = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();

  String gerarHash(String senha) {
    final bytes = utf8.encode(senha);
    return sha256.convert(bytes).toString();
  }

  bool validarEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  Future<void> cadastrarUsuario() async {
    final nome  = nomeController.text.trim();
    final email = emailController.text.trim();
    final senha = senhaController.text.trim();

    // 1) Validações de UI
    if (!aceitouTermos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Você deve aceitar os Termos e Condições')),
      );
      return;
    }
    if (nome.isEmpty || !validarEmail(email) || senha.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha os campos corretamente (senha mínima 6 caracteres)'),
        ),
      );
      return;
    }

    final senhaHash = gerarHash(senha);
    final payload = jsonEncode({
      'nome': nome,
      'email': email,
      'senha_hash': senhaHash,
      'nivel': 1,  // consumidor padrão
    });

    http.Response resp;
    try {
      resp = await http
          .post(
            Uri.parse(kRegisterUrl),
            headers: {'Content-Type': 'application/json'},
            body: payload,
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao conectar ao servidor. Tente novamente.')),
      );
      return;
    }

    if (resp.statusCode == 200) {
      Map<String, dynamic>? data;
      try {
        data = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {
        data = null;
      }

      if (data != null && data['success'] == true) {
        // tenta extrair user ou fallback
        final userMap = data['user'] as Map<String, dynamic>?;
        final userId = userMap?['id']?.toString() ?? data['id']?.toString();
        final userNivel = userMap?['nivel'] as int? ?? 1;
        final userNome = userMap?['nome'] as String? ?? nome;

        if (userId != null) {
          // Salvar sessão do usuário
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('usuario_id', userId);
          await prefs.setInt('usuario_nivel', userNivel);
          await prefs.setString('usuario_nome', userNome);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cadastro realizado com sucesso!')),
        );
        // Limpa formulário
        nomeController.clear();
        emailController.clear();
        senhaController.clear();
        setState(() => aceitouTermos = false);
        // Navega
        Navigator.pushReplacementNamed(context, '/categoria');
      } else if (data != null) {
        final msg = data['message'] ?? 'Não foi possível criar sua conta.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Resposta inválida do servidor.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro no servidor: ${resp.statusCode}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final alturaTela = MediaQuery.of(context).size.height;

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
                  Semantics(
                    label:
                        'Logo da Barrest: um garfo à esquerda e uma faca à direita formando uma moldura que envolve uma casa estilizada com dois telhados. Abaixo, a palavra BARREST em letras maiúsculas.',
                    child: Image.asset(
                      'assets/logo-Transparente.png',
                      width: 200,
                      height: 200,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sua reserva perfeita',
                    style: TextStyle(
                      fontSize: 20,
                      color: Color(0xFFD4AF37),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Criar conta',
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                  const SizedBox(height: 24),

                  // Campo Nome
                  TextField(
                    controller: nomeController,
                    decoration: InputDecoration(
                      hintText: 'Nome',
                      prefixIcon: const Icon(Icons.person, color: Color(0xFFD4AF37)),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFD4AF37)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFD4AF37), width: 2),
                      ),
                      hintStyle: const TextStyle(color: Colors.white70),
                    ),
                    keyboardType: TextInputType.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),

                  // Campo E-mail
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      hintText: 'E-mail',
                      prefixIcon: const Icon(Icons.email, color: Color(0xFFD4AF37)),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFD4AF37)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFD4AF37), width: 2),
                      ),
                      hintStyle: const TextStyle(color: Colors.white70),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),

                  // Campo Senha
                  TextField(
                    controller: senhaController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Senha',
                      prefixIcon: const Icon(Icons.lock, color: Color(0xFFD4AF37)),
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFD4AF37)),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFD4AF37), width: 2),
                      ),
                      hintStyle: const TextStyle(color: Colors.white70),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),

                  // Checkbox Termos
                  Row(
                    children: [
                      Checkbox(
                        value: aceitouTermos,
                        activeColor: const Color(0xFFD4AF37),
                        checkColor: Colors.black,
                        onChanged: (v) => setState(() => aceitouTermos = v ?? false),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: const Color(0xFF1E2D24),
                                title: const Text(
                                  'Política de Privacidade e Termos',
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: SingleChildScrollView(
                                  child: Text(
                                    textoPolitica,
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      setState(() => aceitouTermos = true);
                                      Navigator.of(context).pop();
                                    },
                                    child: const Text(
                                      'FECHAR',
                                      style: TextStyle(color: Color(0xFFD4AF37)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Text(
                            'Aceito os Termos e Condições',
                            style: TextStyle(
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () {
                            // aqui você define a rota para estabelecimentos
                            Navigator.pushNamed(context, '/cadastroEmpresa');
                          },
                          child: const Text(
                            'Sou estabelecimento',
                            style: TextStyle(
                              color: Color(0xFFD4AF37), // dourado
                              decoration: TextDecoration.none, // sem sublinhado
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  // Botão Cadastrar
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: aceitouTermos
                            ? const Color(0xFFD4AF37)
                            : Colors.grey,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: aceitouTermos ? cadastrarUsuario : null,
                      child: const Text(
                        'CRIAR CONTA',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
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
