import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class QrPayPage extends StatefulWidget {
  const QrPayPage({Key? key}) : super(key: key);
  @override
  State<QrPayPage> createState() => _QrPayPageState();
}

class _QrPayPageState extends State<QrPayPage> {
  bool _scanned = false;
  late final MobileScannerController _cameraController;
  String? _licenseId;
  String? _payerId;

  static const _checkLicenseUrl = 'https://barrest.tech/check_license.php';
  static const _getByOwnerUrl = 'https://barrest.tech/get_restaurante_by_id.php';

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(facing: CameraFacing.back);
    _loadLicense();
    _loadPayerId();
  }

  Future<void> _loadLicense() async {
    try {
      final resp = await http.get(Uri.parse(_checkLicenseUrl));
      if (resp.statusCode == 200) {
        final map = json.decode(resp.body) as Map<String, dynamic>;
        if (map['licensed'] == true) setState(() => _licenseId = map['id'] as String);
      }
    } catch (_) {}
  }

  Future<void> _loadPayerId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('usuario_id');
    if (id != null && id.isNotEmpty) setState(() => _payerId = id);
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_scanned || _licenseId == null || _payerId == null) return;
    final raw = capture.barcodes.first.rawValue;
    if (raw == null) return;

    _scanned = true;
    _cameraController.stop();

    try {
      final qr = json.decode(raw) as Map<String, dynamic>;
      final ownerId = qr['usuario_id'] as String;
      final valor = (qr['valor'] as num).toDouble();
      final uri = Uri.parse('$_getByOwnerUrl?license=${Uri.encodeComponent(_licenseId!)}&owner_id=${Uri.encodeComponent(ownerId)}');
      final r = await http.get(uri);
      if (r.statusCode == 200) {
        final j = json.decode(r.body) as Map<String, dynamic>;
        final nome = j['nome'] as String? ?? '(sem nome)';
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => QrPayResultPage(
              restauranteNome: nome,
              valor: valor,
              payerId: _payerId!,
              payeeId: ownerId,
              licenseId: _licenseId!,
            ),
          ),
        );
      } else {
        throw 'HTTP ${r.statusCode}';
      }
    } catch (e) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentStatusPage(
            success: false,
            message: 'Falha ao processar QR: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2D24),
      appBar: AppBar(
        title: const Text('Pagar via QR Code'),
        backgroundColor: const Color(0xFF1E2D24),
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
      ),
      body: MobileScanner(
        controller: _cameraController,
        onDetect: _onDetect,
      ),
    );
  }
}

class QrPayResultPage extends StatefulWidget {
  final String restauranteNome;
  final double valor;
  final String payerId;
  final String payeeId;
  final String licenseId;
  const QrPayResultPage({
    Key? key,
    required this.restauranteNome,
    required this.valor,
    required this.payerId,
    required this.payeeId,
    required this.licenseId,
  }) : super(key: key);

  @override
  State<QrPayResultPage> createState() => _QrPayResultPageState();
}

class _QrPayResultPageState extends State<QrPayResultPage> {
  bool _processing = false;
  static const _processPaymentUrl = 'https://barrest.tech/process_payment.php';

  Future<void> _confirmPayment() async {
    setState(() => _processing = true);
    try {
      final basicAuth = 'Basic ${base64Encode(utf8.encode(':${widget.licenseId}'))}';
      final resp = await http.post(
        Uri.parse(_processPaymentUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': basicAuth,
        },
        body: json.encode({
          'payer_id': widget.payerId,
          'payee_id': widget.payeeId,
          'valor': widget.valor,
        }),
      );

      final data = json.decode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 200 && data['status'] == 'success') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentStatusPage(
              success: true,
              message: 'Pagou a ${widget.restauranteNome}',
              amount: widget.valor,
            ),
          ),
        );
      } else {
        throw data['message'] ?? 'Erro ${resp.statusCode}';
      }
    } catch (e) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentStatusPage(
            success: false,
            message: e.toString(),
          ),
        ),
      );
    } finally {
      setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E2D24),
      appBar: AppBar(
        title: const Text('Confirmar Pagamento'),
        backgroundColor: const Color(0xFF1E2D24),
        iconTheme: const IconThemeData(color: Color(0xFFD4AF37)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.payment, size: 80, color: Color(0xFFD4AF37)),
            const SizedBox(height: 24),
            Text(widget.restauranteNome,
                style: const TextStyle(color: Colors.white, fontSize: 18)),
            const SizedBox(height: 12),
            Text('Valor: R\$ ${widget.valor.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton(
              onPressed: _processing ? null : _confirmPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _processing
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('CONFIRMAR PAGAMENTO',
                      style: TextStyle(color: Colors.black, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentStatusPage extends StatelessWidget {
  final bool success;
  final String message;
  final double? amount;

  const PaymentStatusPage({
    Key? key,
    required this.success,
    required this.message,
    this.amount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: success ? Colors.green[900] : Colors.red[900],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                success ? Icons.check_circle_outline : Icons.error_outline,
                size: 100,
                color: Colors.white,
              ),
              const SizedBox(height: 24),
              Text(
                success ? 'Pagamento Confirmado' : 'Pagamento Falhou',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                message + (amount != null ? '\nR\$ ${amount!.toStringAsFixed(2)}' : ''),
                style: const TextStyle(color: Colors.white70, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 12),
                ),
                child: Text(
                  'Voltar',
                  style: TextStyle(
                    color: success ? Colors.green[900] : Colors.red[900],
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}