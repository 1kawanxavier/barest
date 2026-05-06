import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const kCheckLicenseUrl         = 'https://barrest.tech/check_license.php';
const kGetReportFaturamentoUrl = 'https://barrest.tech/admin/get_report_faturamento.php';

class RelatoriosPage extends StatefulWidget {
  const RelatoriosPage({Key? key}) : super(key: key);

  @override
  State<RelatoriosPage> createState() => _RelatoriosPageState();
}

class _RelatoriosPageState extends State<RelatoriosPage> {
  bool carregando = true;
  String? erro;
  double faturamentoTotal = 0, lucroTotal = 0;
  List<FlSpot> revSpots = [], lrcSpots = [];
  List<String> revLabels = [], lrcLabels = [];

  @override
  void initState() {
    super.initState();
    _fetchRelatorio();
  }

  Future<void> _fetchRelatorio() async {
    setState(() => carregando = true);

    try {
      // valida licença
      final licResp = await http.get(Uri.parse(kCheckLicenseUrl))
          .timeout(const Duration(seconds: 5));
      if (licResp.statusCode != 200) throw 'Licença inválida (${licResp.statusCode})';
      final licJson = json.decode(licResp.body);
      if (licJson['licensed'] != true) throw 'Licença inativa';
      final licenseId = licJson['id'].toString();

      // busca relatório completo
      final uri = Uri.parse('$kGetReportFaturamentoUrl?license=$licenseId');
      final resp = await http.get(uri).timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) throw 'Erro ${resp.statusCode} ao buscar relatório';

      final data = json.decode(resp.body);
      if (data['success'] != true) throw data['error'] ?? 'Resposta inesperada';

      // parse totals
      faturamentoTotal = _toDouble(data['faturamento_total']);
      lucroTotal       = _toDouble(data['lucro_total']);

      // parse histórico faturamento
      revSpots.clear(); revLabels.clear();
      for (var i = 0; i < (data['historico_faturamento'] as List).length; i++) {
        final row = data['historico_faturamento'][i];
        revSpots.add(FlSpot(i.toDouble(), _toDouble(row['total'])));
        revLabels.add(row['dia']);
      }

      // parse histórico lucro
      lrcSpots.clear(); lrcLabels.clear();
      for (var i = 0; i < (data['historico_lucro'] as List).length; i++) {
        final row = data['historico_lucro'][i];
        lrcSpots.add(FlSpot(i.toDouble(), _toDouble(row['total'])));
        lrcLabels.add(row['dia']);
      }

      setState(() => carregando = false);
    } catch (e) {
      setState(() { erro = e.toString(); carregando = false; });
    }
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  Widget _buildChart(List<FlSpot> spots, List<String> labels) {
    const bgDark = Color(0xFF1E2D24);
    return SizedBox(
      height: 200,           // gráfico menor
      child: LineChart(
        LineChartData(
          backgroundColor: bgDark,
          gridData: FlGridData(show: true),
          borderData: FlBorderData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= labels.length) return const SizedBox();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(labels[idx].split('T').first,
                        style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          ),
          lineBarsData: [
            LineChartBarData(spots: spots, isCurved: true, barWidth: 2, dotData: FlDotData(show: true)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF1E2D24);
    const gold   = Color(0xFFD4AF37);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        title: const Text('Relatórios', style: TextStyle(color: gold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: carregando
            ? const Center(child: CircularProgressIndicator(color: gold))
            : erro != null
                ? Center(child: Text(erro!, style: const TextStyle(color: Colors.redAccent)))
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Faturamento Total: R\$ ${faturamentoTotal.toStringAsFixed(2)}',
                            style: const TextStyle(color: gold, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildChart(revSpots, revLabels),

                        const SizedBox(height: 24),
                        Text('Lucro Total: R\$ ${lucroTotal.toStringAsFixed(2)}',
                            style: const TextStyle(color: gold, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        _buildChart(lrcSpots, lrcLabels),
                      ],
                    ),
                  ),
      ),
    );
  }
}
