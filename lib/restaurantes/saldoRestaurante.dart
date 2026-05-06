import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

class SaldoPage extends StatefulWidget {
  const SaldoPage({super.key});
  @override
  State<SaldoPage> createState() => _SaldoPageState();
}

class _SaldoPageState extends State<SaldoPage> {
  String? licenseId;
  String? usuarioId;
  double saldoAtual = 0.0;
  bool carregando  = true;

  final _valorCtrl = TextEditingController();
  final _pixCtrl   = TextEditingController();

  static const _checkLicenseUrl  = 'https://barrest.tech/check_license.php';
  static const _getSaldoUrl      = 'https://barrest.tech/get_saldo_restaurante.php';
  static const _getTransacoesUrl = 'https://barrest.tech/get_transacoes_restaurante.php';
  static const _postSaqueUrl     = 'https://barrest.tech/post_saque_restaurante.php';

  @override
  void initState() {
    super.initState();
    _init();
  }
  @override
  void dispose() {
    _valorCtrl.dispose();
    _pixCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await _fetchLicense();
      await _fetchUsuario();
      await _fetchSaldo();
      await _fetchTransacoes();
    } catch (e) {
      _showError('Inicialização falhou: $e');
    }
  }

  Future<void> _fetchLicense() async {
    final resp = await http.get(Uri.parse(_checkLicenseUrl));
    if (resp.statusCode != 200) throw 'Não foi possível validar licença';
    final map = json.decode(resp.body) as Map<String, dynamic>;
    if (map['licensed'] != true) throw 'Licença inativa';
    licenseId = map['id'].toString();
  }

  Future<void> _fetchUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('usuario_id');
    if (id == null || id.isEmpty) throw 'Usuário não autenticado';
    usuarioId = id;
  }

  Future<void> _fetchSaldo() async {
    setState(() => carregando = true);
    try {
      final uri = Uri.parse(
        '$_getSaldoUrl?license=${Uri.encodeComponent(licenseId!)}'
        '&usuario_id=${Uri.encodeComponent(usuarioId!)}'
      );
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) throw 'Erro ${resp.statusCode}';
      final data = json.decode(resp.body) as Map<String,dynamic>;
      saldoAtual = double.tryParse(data['valor'].toString()) ?? 0.0;
    } catch (e) {
      _showError('Falha ao carregar saldo: $e');
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  List<Map<String,dynamic>> transacoes = [];

  Future<void> _fetchTransacoes() async {
    try {
      final auth = 'Basic ${base64Encode(utf8.encode(':$licenseId'))}';
      final uri  = Uri.parse('$_getTransacoesUrl?usuario_id=${Uri.encodeComponent(usuarioId!)}');
      final resp = await http.get(uri, headers:{'Authorization': auth});
      if (resp.statusCode != 200) throw 'Erro ${resp.statusCode}';
      final body = json.decode(resp.body) as Map<String,dynamic>;
      if (body['success'] != true) throw body['error'] ?? 'Erro desconhecido';

      final todas = List<Map<String,dynamic>>.from(body['transacoes'] as List);
      // inclui saque ou recebimento
      transacoes = todas.where((t){
        final tipo    = t['tipo'] as String? ?? '';
        final destino = t['destino_id'] as String?;
        return tipo=='saque' || destino==usuarioId;
      }).map((t){
        return {
          'tipo':  t['tipo']  as String,
          'valor': double.tryParse(t['valor'].toString()) ?? 0.0,
          'data':  t['data']  as String,
          'nome':  t['nome']  as String? ?? '',
          // parse de pago: se null => 0
          'pago':  int.tryParse(t['pago'].toString()) ?? 0,
        };
      }).toList();
    } catch(e) {
      _showError('Erro ao buscar transações: $e');
    } finally {
      if (mounted) setState((){});
    }
  }

  void _showError(String msg){
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red)
    );
  }

  Future<void> _onCobrarPressed() async {
    _valorCtrl.clear();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cobrar'),
        scrollable: true,
        content: TextField(
          controller: _valorCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText:'Valor', prefixText:'R\$ '),
        ),
        actions:[
          TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('Gerar QR')),
        ],
      ),
    );
    if(ok!=true) return;
    final valor = double.tryParse(_valorCtrl.text.replaceAll(',','.')) ?? 0.0;
    if(valor<=0){
      _showError('Valor inválido');
      return;
    }
    final payload = json.encode({'usuario_id': usuarioId, 'valor': valor});
    if(!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_)=> QrPage(data: payload)));
  }

  bool isValidCPF(String cpf) {
    final d = cpf.replaceAll(RegExp(r'\D'), '');
    if(d.length!=11||RegExp(r'^(\d)\1{10}\$').hasMatch(d)) return false;
    final nums = d.split('').map(int.parse).toList();
    var sum=0;
    for(var i=0;i<9;i++) sum+=nums[i]*(10-i);
    var mod=sum%11;
    var c1=mod<2?0:11-mod;
    if(c1!=nums[9]) return false;
    sum=0;
    for(var i=0;i<10;i++) sum+=nums[i]*(11-i);
    mod=sum%11;
    var c2=mod<2?0:11-mod;
    return c2==nums[10];
  }

  String detectPixKeyType(String key) {
    final t=key.trim(), d=t.replaceAll(RegExp(r'\D'), '');
    if(RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+\$').hasMatch(t)) return 'Email';
    if(d.length==11 && isValidCPF(d)) return 'CPF';
    if((d.length==10||d.length==11)&&RegExp(r'^[1-9][0-9]{8,9}\$').hasMatch(d)) return 'Celular';
    if(d.length==14) return 'CNPJ';
    return 'Aleatória';
  }

  String formatPixKey(String key, String type){
    final d=key.replaceAll(RegExp(r'\D'), '');
    switch(type){
      case 'CPF':
        final m=RegExp(r'^(\d{3})(\d{3})(\d{3})(\d{2})\$').firstMatch(d);
        if(m!=null) return '${m[1]}.${m[2]}.${m[3]}-${m[4]}';
        break;
      case 'CNPJ':
        final m=RegExp(r'^(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})\$').firstMatch(d);
        if(m!=null) return '${m[1]}.${m[2]}.${m[3]}/${m[4]}-${m[5]}';
        break;
      case 'Celular':
        if(d.length==10||d.length==11){
          final ddd=d.substring(0,2);
          final body=d.length==10
              ? '${d.substring(2,6)}-${d.substring(6)}'
              : '${d.substring(2,7)}-${d.substring(7)}';
          return '($ddd) $body';
        }
        break;
    }
    return key.trim();
  }

  Future<void> _onSacarPressed() async {
    // pede valor
    _valorCtrl.clear();
    final okV=await showDialog<bool>(
      context: context,
      builder: (_)=>AlertDialog(
        title: const Text('Sacar'),
        content: TextField(
          controller: _valorCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal:true),
          decoration: const InputDecoration(labelText:'Valor do saque', prefixText:'R\$ '),
        ),
        actions:[
          TextButton(onPressed: ()=>Navigator.pop(context,false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: ()=>Navigator.pop(context,true), child: const Text('Avançar')),
        ],
      )
    );
    if(okV!=true) return;
    final valor = double.tryParse(_valorCtrl.text.replaceAll(',','.')) ?? 0.0;
    if(valor<=0||valor>saldoAtual){
      _showError('Valor inválido ou maior que o saldo disponível');
      return;
    }
    // pede PIX
    String pixType='';
    _pixCtrl.clear();
    final okP=await showDialog<bool>(
      context: context,
      builder: (_)=>StatefulBuilder(
        builder:(ctx,setState){
          const hints={
            'Email':'exemplo@dominio.com',
            'CPF':'000.000.000-00',
            'CNPJ':'00.000.000/0000-00',
            'Celular':'(99) 99999-9999',
            'Aleatória':'',
          };
          final hint=hints[pixType]??'';
          return AlertDialog(
            title: const Text('Chave PIX'),
            content:Column(
              mainAxisSize: MainAxisSize.min,
              children:[
                TextField(
                  controller: _pixCtrl,
                  decoration: InputDecoration(labelText:'Insira sua chave PIX', hintText:hint),
                  onChanged: (t)=>setState(()=>pixType=detectPixKeyType(t)),
                ),
                if(pixType.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top:8),
                    child: Text('Tipo detectado: $pixType',
                        style: const TextStyle(color:Colors.grey,fontSize:12)),
                  )
              ]
            ),
            actions:[
              TextButton(onPressed:()=>Navigator.pop(ctx,false), child: const Text('Cancelar')),
              ElevatedButton(onPressed:(){
                if(_pixCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx,true);
              }, child: const Text('Confirmar')),
            ]
          );
        }
      )
    );
    final rawKey=_pixCtrl.text.trim();
    if(okP!=true||rawKey.isEmpty){
      _showError('Chave PIX inválida');
      return;
    }
    final type=detectPixKeyType(rawKey);
    final formatted=formatPixKey(rawKey,type);
    if(!mounted) return;
    await showDialog<void>(
      context:context,
      barrierDismissible:false,
      builder:(_)=>AlertDialog(
        title: const Text('Aviso'),
        content: Text('Processando retirada para:\n$formatted'),
        actions:[
          ElevatedButton(onPressed:()=>Navigator.pop(context), child: const Text('OK'))
        ]
      )
    );
    await _performSaque(valor, rawKey);
  }

  Future<void> _performSaque(double valor, String pixKey) async {
    setState(()=>carregando=true);
    try{
      final auth='Basic ${base64Encode(utf8.encode(':$licenseId'))}';
      final resp=await http.post(
        Uri.parse(_postSaqueUrl),
        headers:{'Authorization':auth,'Content-Type':'application/json'},
        body:json.encode({'usuario_id':usuarioId,'valor':valor,'pix_key':pixKey})
      ).timeout(const Duration(seconds:10));
      if(resp.statusCode!=200) throw 'Erro ${resp.statusCode}';
      final body=json.decode(resp.body) as Map<String,dynamic>;
      if(body['success']!=true) throw body['error'] ?? 'Erro desconhecido';
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saque realizado com sucesso'),
          backgroundColor: Colors.green
        )
      );
      await _fetchSaldo();
      await _fetchTransacoes();
    }catch(e){
      _showError('Falha ao sacar: $e');
    }finally{
      if(mounted) setState(()=>carregando=false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2D24),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2D24),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        title: const Text('Saldo', style: TextStyle(color:Color(0xFFD4AF37))),
      ),
      body: carregando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      color: const Color(0xFF2E3D34),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFD4AF37), width:1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical:24,horizontal:16),
                        child: Column(
                          children:[
                            const Text('Saldo Disponível',
                                style: TextStyle(color:Colors.white70,fontSize:16)),
                            const SizedBox(height:12),
                            Text('R\$${saldoAtual.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    color: Color(0xFFD4AF37),
                                    fontSize:28,
                                    fontWeight:FontWeight.bold)),
                          ]
                        ),
                      ),
                    ),
                    const SizedBox(height:24),
                    Row(children:[
                      Expanded(
                        child: Card(
                          color: const Color(0xFF2E3D34),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFD4AF37), width:1),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _onCobrarPressed,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical:20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children:[
                                  Icon(Icons.attach_money,color:Color(0xFFD4AF37),size:30),
                                  SizedBox(height:8),
                                  Text('Cobrar',style:TextStyle(color:Color(0xFFD4AF37),fontSize:14)),
                                ]
                              )
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width:12),
                      Expanded(
                        child: Card(
                          color: const Color(0xFF2E3D34),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFD4AF37), width:1),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _onSacarPressed,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical:20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children:[
                                  Icon(Icons.account_balance,color:Color(0xFFD4AF37),size:30),
                                  SizedBox(height:8),
                                  Text('Sacar',style:TextStyle(color:Color(0xFFD4AF37),fontSize:14)),
                                ]
                              )
                            ),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height:32),
                    const Text('Histórico de Transações',
                        style: TextStyle(color:Color(0xFFD4AF37),fontSize:18,fontWeight:FontWeight.bold)),
                    const SizedBox(height:12),
                    if(transacoes.isEmpty)
                      Container(
                        height:200,
                        alignment:Alignment.center,
                        child: const Text('Nenhuma transação encontrada.',
                            style: TextStyle(color:Colors.white60,fontSize:16)),
                      )
                    else
                      ListView.separated(
                        shrinkWrap:true,
                        physics:const NeverScrollableScrollPhysics(),
                        itemCount:transacoes.length,
                        separatorBuilder:(_,__)=>const Divider(color:Colors.white24),
                        itemBuilder: (context, i) {
                          final t       = transacoes[i];
                          final tipo    = t['tipo'] as String;
                          final valor   = t['valor'] as double;
                          final pago    = (t['pago'] as int) == 1;
                          final isSaque = tipo == 'saque';
                          final sinal   = isSaque ? '-' : '+';
                          final cor     = isSaque
                              ? (pago ? Colors.green : Colors.yellow)
                              : Colors.green;
                          final data = DateTime.tryParse(t['data'] as String) ?? DateTime.now();
                          final dataFmt =
                              '${data.day.toString().padLeft(2,'0')}/'
                              '${data.month.toString().padLeft(2,'0')}/'
                              '${data.year}';
                          final titulo = isSaque
                              ? (pago ? 'Saque concluído' : 'Saque em andamento')
                              : 'Recebido de ${t['nome']}';

                          // usa .abs() aqui para tirar qualquer sinal interno
                          final displayValue = valor.abs().toStringAsFixed(2);

                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(titulo, style: TextStyle(color: cor, fontWeight: FontWeight.bold)),
                            subtitle: Text(dataFmt, style: const TextStyle(color: Colors.white54)),
                            trailing: Text(
                              '$sinal R\$$displayValue',
                              style: TextStyle(color: cor, fontWeight: FontWeight.bold),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

class QrPage extends StatelessWidget {
  final String data;
  const QrPage({required this.data, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2D24),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2D24),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
        title: const Text('QR de Cobrança', style: TextStyle(color:Color(0xFFD4AF37))),
      ),
      body: Center(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: QrImageView(
            data: data,
            version: QrVersions.auto,
            size: 300,
          ),
        ),
      ),
    );
  }
}
