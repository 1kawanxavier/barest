import 'package:flutter/material.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();

    // Controlador de animação
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Animação: sobe de baixo para o centro
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0), // Começa fora da tela embaixo
      end: Offset.zero, // Termina no centro
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Inicia a animação
    _controller.forward();

    // Depois de 3 segundos, navega para a home
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacementNamed('/login');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2D24),
      body: Center(
        child: SlideTransition(
          position: _offsetAnimation,
          child: const Image(
            image: AssetImage('assets/logo-Transparente.png'),
            width: 300, // aumentei o tamanho da logo
            height: 300,
          ),
        ),
      ),
    );
  }
}
