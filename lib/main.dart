import 'package:barrestapp/admin/inicio.dart';
import 'package:barrestapp/deletarContaPage.dart';
import 'package:flutter/material.dart';

// Suas páginas
import 'package:barrestapp/splashPage.dart';
import 'package:barrestapp/loginPage.dart';
import 'package:barrestapp/createPage.dart';
import 'package:barrestapp/cadastroEmpresa.dart';
import 'package:barrestapp/categoriaPage.dart';
import 'package:barrestapp/esqueceuSenha.dart';
import 'package:barrestapp/historico_page.dart';
import 'package:barrestapp/restaurantes/editar_cardapio_page.dart';
import 'package:barrestapp/restaurantes/adicionarItemPage.dart';
import 'package:barrestapp/empresaInicioPage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Barrest App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashPage(),
        '/login': (context) => const LoginPage(),
        '/cadastro': (context) => const CadastroPage(),
        '/categoria': (context) => const CategoriasPage(),
        '/historico': (context) => const HistoricoPage(),
        '/esqueceuSenha': (context) => const EsqueceuSenhaPage(),
        '/cadastroEmpresa': (context) => const CadastroEmpresaPage(),
        '/empresaInicioPage': (context) => const EmpresaInicioPage(),
        '/editarCardapio': (context) => const EditarCardapioPage(),
        '/adicionarItem': (context) => const AdicionarItemPage(),
        '/adminPage': (_)            => const AdminPage(),
        '/deletarConta': (context) => const DeletarContaPage(),
      },
    );
  }
}
