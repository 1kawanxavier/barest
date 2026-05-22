import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DeletarContaPage extends StatefulWidget {
  const DeletarContaPage({super.key});

  @override
  State<DeletarContaPage> createState() => _DeletarContaPageState();
}

class _DeletarContaPageState extends State<DeletarContaPage> {
  bool carregando = false;

  Future<void> deletarConta() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir conta?'),
        content: const Text(
          'Essa ação é permanente. Sua conta e seus dados serão removidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Excluir',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => carregando = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final usuarioId = prefs.getString('usuario_id');

      if (usuarioId == null || usuarioId.isEmpty) {
        throw 'Usuário não identificado.';
      }

      final response = await http.post(
        Uri.parse('https://barrest.tech/delete_account.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'usuario_id': usuarioId}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        await prefs.clear();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conta excluída com sucesso.')),
        );

        Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
      } else {
        throw data['message'] ?? 'Erro ao excluir conta.';
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2D24),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2D24),
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        title: const Text(
          'Excluir conta',
          style: TextStyle(color: Color(0xFFD4AF37)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFD4AF37),
              size: 60,
            ),
            const SizedBox(height: 20),
            const Text(
              'Excluir sua conta',
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ao excluir sua conta, seus dados pessoais serão removidos permanentemente. Essa ação não pode ser desfeita.',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: carregando ? null : deletarConta,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: carregando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'EXCLUIR CONTA PERMANENTEMENTE',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}