import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/models.dart';
import '../services/storage.dart';
import '../services/extrato_importer.dart';
import '../services/relatorio_exporter.dart';
import '../main.dart';

const kBlue = Color(0xFF1d4ed8);
const kBorder = Color(0xFF334155);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Transaction> _transactions = [];
  List<FixedExpense> _fixed = [];
  List<IncomeSource> _incomesList = [];
  List<Investment> _investments = [];
  
  int _tab = 0;
  final _pageCtrl = PageController();
  final _fmt = NumberFormat.simpleCurrency(locale: 'pt_BR');

  final List<String> _shortcuts = ['Pix', 'Transferência', 'Pagamento', 'Mercado', 'Combustível', 'Farmácia', 'Lazer', 'Ifood', 'Cinema',];

  @override
  void initState() {
    super.initState();
    
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _loadAll();
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final t = await Storage.loadTransactions();
    final f = await Storage.loadFixed();
    final inc = await Storage.loadIncomes();
    final inv = await Storage.loadInvestments();
    if (mounted) {
      setState(() {
        _transactions = t;
        _fixed = f;
        _incomesList = inc;
        _investments = inv;
      });
      _verificarVencimentosProximos();
      
      
      _configurarNotificacoesWeb();
    }
  }

  
  Future<void> _configurarNotificacoesWeb() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      NotificationSettings settings = await messaging.requestPermission(
        alert: true, badge: true, sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken(
          vapidKey: "BJBGbCf40xy-_7TX0oNOEVBHXurxpPavmkTP4bJI85OspSpU30TmvHP4nSgscgcYAxJNZSTNPW1lN2uDtzhTLbQ",
        );
        debugPrint("Token do dispositivo Web: $token");
      }
      
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          _showSnack('🔔 ${message.notification!.title}: ${message.notification!.body}');
        }
      });
    } catch (e) {
      debugPrint("Notificações desativadas ou com erro: $e");
    }
  }

  void _verificarVencimentosProximos() {
    final hoje = DateTime.now().day;
    for (var f in _fixed) {
      int diasRestantes = f.dueDay - hoje;
      if (diasRestantes >= 0 && diasRestantes <= 3) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showSnack('⚠️ Atenção: A conta "${f.name}" vence em breve (Dia ${f.dueDay})!');
        });
      }
    }
  }

  double get _totalProventos {
    final hoje = DateTime.now();
    return _incomesList.where((i) {
      final mesValido = i.receiveMonth == null || i.receiveMonth == hoje.month;
      final diaValido = hoje.day >= i.receiveDay;
      return mesValido && diaValido;
    }).fold(0, (s, i) => s + i.value);
  }
  double get _incomesTx => _transactions.where((t) => t.type == 'receita').fold(0, (s, t) => s + t.value);
  double get _expensesTx => _transactions.where((t) => t.type == 'despesa').fold(0, (s, t) => s + t.value);
  double get _fixedTotal => _fixed.fold(0, (s, f) => s + f.value);
  double get _balance => _totalProventos + _incomesTx - _expensesTx - _fixedTotal;

  void _goToTab(int i) {
    setState(() => _tab = i);
    _pageCtrl.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgCard = isDark ? const Color(0xFF1e293b) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('FinanceCash', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
      ),
      body: PageView(
        controller: _pageCtrl,
        dragStartBehavior: DragStartBehavior.start,
        onPageChanged: (i) => setState(() => _tab = i),
        children: [
          _buildDashboard(bgCard, isDark),
          _buildFinanceiro(bgCard, isDark),
          _buildConfiguracoes(bgCard, isDark),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), selectedIcon: Icon(Icons.account_balance_wallet), label: 'Financeiro'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Configurações'),
        ],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: () => _showTxForm(),
              backgroundColor: kBlue,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  
  // ABA 1: DASHBOARD
 
  Widget _buildDashboard(Color bgCard, bool isDark) {
    final now = DateTime.now();
    final inicioMes = DateTime(now.year, now.month, 1);
    final txMes = _transactions.where((t) => t.date.isAfter(inicioMes.subtract(const Duration(seconds: 1)))).toList();
    
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1e3a8a), Color(0xFF1e293b)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            const Text('Saldo Real Atual', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 4),
            Text(_fmt.format(_balance),
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold,
                    color: _balance >= 0 ? Colors.green : Colors.red)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _resumoItem('📈 Entradas', _totalProventos + _incomesTx, Colors.green),
                _resumoItem('📉 Saídas', _expensesTx + _fixedTotal, Colors.red),
              ],
            ),
          ]),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: bgCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBlue.withValues(alpha: 0.4))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.upload_file, color: kBlue, size: 20),
              SizedBox(width: 8),
              Text('Importar Extrato Bancário', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
            const SizedBox(height: 4),
            const Text('Importe o extrato em CSV para registrar lançamentos automaticamente.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _importarExtrato,
                icon: const Icon(Icons.folder_open_outlined, size: 18),
                label: const Text('Selecionar arquivo (CSV)'),
                style: ElevatedButton.styleFrom(backgroundColor: kBlue, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        const Text('Atalhos de Lançamento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _shortcuts.map((s) => ActionChip(
            label: Text(s),
            backgroundColor: bgCard,
            onPressed: () => _showTxForm(initialDesc: s),
          )).toList(),
        ),
        const SizedBox(height: 20),

        const Text('Finance Analysis (Evolução Mensal)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        if (txMes.isNotEmpty) ...[
          Builder(builder: (context) {
            
            final int diasNoMes = DateTime(now.year, now.month + 1, 0).day;
            List<FlSpot> despesasSpots = [];
            List<FlSpot> receitasSpots = [];
            
            for (int i = 1; i <= diasNoMes; i++) {
              double d = txMes.where((t) => t.date.day == i && t.type == 'despesa').fold(0.0, (s, t) => s + t.value);
              double r = txMes.where((t) => t.date.day == i && t.type == 'receita').fold(0.0, (s, t) => s + t.value);
              despesasSpots.add(FlSpot(i.toDouble(), d));
              receitasSpots.add(FlSpot(i.toDouble(), r));
            }

            return Container(
              height: 250,
              padding: const EdgeInsets.only(top: 24, bottom: 12, left: 12, right: 24),
              decoration: BoxDecoration(color: bgCard, borderRadius: BorderRadius.circular(16)),
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          if (val.toInt() % 5 != 0) return const SizedBox(); // Mostra de 5 em 5 dias
                          return Text('${val.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey));
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: receitasSpots,
                      isCurved: true, color: Colors.green, barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: Colors.green.withValues(alpha: 0.1)),
                    ),
                    LineChartBarData(
                      spots: despesasSpots,
                      isCurved: true, color: Colors.red, barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: Colors.red.withValues(alpha: 0.1)),
                    ),
                  ],
                ),
              ),
            );
          }),
        ] else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: bgCard, borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.center,
            child: const Text('Nenhuma movimentação este mês.', style: TextStyle(color: Colors.grey)),
          ),

        const SizedBox(height: 24),

        // Aqui em tese é onde era pra aparecer a lista dos ultimos lançamentos
        const Text('Últimos Lançamentos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        if (_transactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            child: const Text('Nenhum histórico encontrado.', style: TextStyle(color: Colors.grey)),
          )
        else
          ListView.builder(
            shrinkWrap: true, 
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _transactions.length > 10 ? 10 : _transactions.length,
            itemBuilder: (context, i) {
              final tx = _transactions[i];
              final isDespesa = tx.type == 'despesa';
              
              return Card(
                color: bgCard,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: isDespesa ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                    child: Icon(isDespesa ? Icons.arrow_downward : Icons.arrow_upward, 
                                color: isDespesa ? Colors.red : Colors.green, size: 20),
                  ),
                  title: Text(tx.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('${DateFormat('dd/MM/yyyy').format(tx.date)}  •  ${tx.category}', 
                                 style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (isDespesa ? '- ' : '+ ') + _fmt.format(tx.value),
                        style: TextStyle(color: isDespesa ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _showTxForm(editing: tx), // Abre o formulário em modo de edição
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                        onPressed: () {
                          setState(() => _transactions.removeWhere((t) => t.id == tx.id));
                          Storage.saveTransactions(_transactions);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 80),
      ]),
    );
  }


  // ABA 2: FINANCEIRO

  Widget _buildFinanceiro(Color bgCard, bool isDark) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Fontes de Renda (Proventos)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.add_circle, color: kBlue), onPressed: () => _showProventoForm()),
        ],
      ),
      const SizedBox(height: 4),
      if (_incomesList.isEmpty)
        const Text('Nenhuma fonte de renda cadastrada.', style: TextStyle(color: Colors.grey, fontSize: 12))
      else
        ..._incomesList.map((inc) => Card(
          color: bgCard,
          child: ListTile(
            title: Text(inc.name),
            subtitle: Text(_fmt.format(inc.value)),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showProventoForm(editing: inc)),
              IconButton(
                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                onPressed: () {
                  setState(() => _incomesList.removeWhere((i) => i.id == inc.id));
                  Storage.saveIncomes(_incomesList);
                },
              ),
            ]),
          ),
        )),
      const SizedBox(height: 20),

      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Contas Fixas & Vencimentos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.add_circle, color: Colors.orange), onPressed: () => _showFixoForm()),
        ],
      ),
      const SizedBox(height: 4),
      if (_fixed.isEmpty)
        const Text('Nenhuma conta fixa cadastrada.', style: TextStyle(color: Colors.grey, fontSize: 12))
      else
        ..._fixed.map((fix) => Card(
          color: bgCard,
          child: ListTile(
            leading: const Icon(Icons.receipt_long, color: Colors.orange),
            title: Text(fix.name),
            subtitle: Text('Vence dia ${fix.dueDay} • ${_fmt.format(fix.value)}'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showFixoForm(editing: fix)),
              IconButton(
                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                onPressed: () {
                  setState(() => _fixed.removeWhere((f) => f.id == fix.id));
                  Storage.saveFixed(_fixed);
                },
              ),
            ]),
          ),
        )),
      const SizedBox(height: 20),

      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Investimentos & Aplicações', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          IconButton(icon: const Icon(Icons.add_circle, color: Colors.green), onPressed: () => _showInvestimentoForm()),
        ],
      ),
      const SizedBox(height: 4),
      if (_investments.isEmpty)
        const Text('Nenhum investimento cadastrado.', style: TextStyle(color: Colors.grey, fontSize: 12))
      else ...[
        ..._investments.map((inv) => Card(
          color: bgCard,
          child: ListTile(
            leading: const Icon(Icons.trending_up, color: Colors.green),
            title: Text('${inv.name} (${inv.type})'),
            subtitle: Text('Capital: ${_fmt.format(inv.amount)} • Rendimento: ${inv.yieldRate}% a.m.'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showInvestimentoForm(editing: inv)),
              IconButton(
                icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                onPressed: () {
                  setState(() => _investments.removeWhere((i) => i.id == inv.id));
                  Storage.saveInvestments(_investments);
                },
              ),
            ]),
          ),
        )),
        const SizedBox(height: 16),
        
        // essa parte gera um gráfico bacaninha 
        Container(
          height: 220,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: bgCard, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                    sections: _investments.asMap().entries.map((e) {
                      final cores = [Colors.teal, Colors.blue, Colors.orange, Colors.purple, Colors.red, Colors.green];
                      return PieChartSectionData(
                        value: e.value.amount,
                        color: cores[e.key % cores.length],
                        radius: 30,
                        showTitle: false,
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _investments.length,
                  itemBuilder: (context, i) {
                    final inv = _investments[i];
                    final cores = [Colors.teal, Colors.blue, Colors.orange, Colors.purple, Colors.red, Colors.green];
                    final total = _investments.fold(0.0, (s, val) => s + val.amount);
                    final pct = total > 0 ? (inv.amount / total) * 100 : 0.0;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: cores[i % cores.length])),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(inv.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                                Text('${pct.toStringAsFixed(1)}% (${_fmt.format(inv.amount)})', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ],
      const SizedBox(height: 20),
      
      // parte do PDF
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bgCard, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Relatório Gerencial em PDF', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          const Text('Exporte gráficos e o histórico completo do mês.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _exportarRelatorio(_transactions),
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Baixar Relatório Completo'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 80),
    ]);
  }
  

  // ABA 3: CONFIGURAÇÕES
  
  Widget _buildConfiguracoes(Color bgCard, bool isDark) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        return ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Aparência', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Modo Claro'),
            subtitle: const Text('Alternar entre tema escuro e claro'),
            value: !isDark,
            activeThumbColor: kBlue,
            onChanged: (val) {
              themeNotifier.value = val ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          const SizedBox(height: 24),

         
          const Text('Dados do Aplicativo', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            color: bgCard,
            child: ListTile(
              leading: const Icon(Icons.history, color: kBlue),
              title: const Text('Histórico Completo'),
              subtitle: const Text('Ver, editar ou apagar todos os lançamentos'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showHistoricoCompleto(bgCard),
            ),
          ),
          const SizedBox(height: 24),

          const Text('Conta & Nuvem', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (user != null)
            Card(
              color: bgCard,
              child: ListTile(
                leading: CircleAvatar(backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null),
                title: Text(user.displayName ?? 'Usuário'),
                subtitle: Text(user.email ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.logout, color: Colors.red),
                  onPressed: () async => await FirebaseAuth.instance.signOut(),
                ),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: _loginGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 24),
              label: const Text('Entrar com Google'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            ),
          const SizedBox(height: 80),
        ]);
      },
    );
  }

  void _showTxForm({String? initialDesc, Transaction? editing}) {
    String desc = editing?.description ?? initialDesc ?? '';
    double val = editing?.value ?? 0;
    
    
    String type = editing?.type ?? ((desc.toLowerCase().contains('transferência') || desc.toLowerCase().contains('pix')) ? 'receita' : 'despesa');

    String cat = editing?.category ?? 'Outros';
    
    
    if (editing == null) {
      if (desc.toLowerCase().contains('mercado') || desc.toLowerCase().contains('ifood')) { cat = 'Alimentação'; type = 'despesa'; }
      else if (desc.toLowerCase().contains('combustível')) { cat = 'Transporte'; type = 'despesa'; }
      else if (desc.toLowerCase().contains('farmácia')) { cat = 'Saúde'; type = 'despesa'; }
    }

    
    String dropdownCat = kCategories.contains(cat) ? cat : 'Outros';

    final descCtrl = TextEditingController(text: desc);
    final valCtrl = TextEditingController(text: val > 0 ? val.toStringAsFixed(2) : '');
    final customCatCtrl = TextEditingController(text: dropdownCat == 'Outros' && editing != null ? cat : '');

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, top: 20, left: 20, right: 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(editing == null ? 'Novo Lançamento' : 'Editar Lançamento', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            
            // aqui é o seletor de tipo, se é Receita ou Despesa
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'despesa', label: Text('Saída'), icon: Icon(Icons.arrow_downward, color: Colors.red)),
                ButtonSegment(value: 'receita', label: Text('Entrada'), icon: Icon(Icons.arrow_upward, color: Colors.green)),
              ],
              selected: {type},
              onSelectionChanged: (Set<String> newSelection) => setStateModal(() => type = newSelection.first),
            ),
            const SizedBox(height: 12),

            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Descrição', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: valCtrl, decoration: const InputDecoration(labelText: 'Valor (R\$)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            
            DropdownButtonFormField<String>(
              initialValue: dropdownCat,
              items: kCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setStateModal(() => dropdownCat = v!),
              decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
            ),
            
            
            if (dropdownCat == 'Outros') ...[
              const SizedBox(height: 8),
              TextField(controller: customCatCtrl, decoration: const InputDecoration(labelText: 'Digite a categoria', border: OutlineInputBorder())),
            ],

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                val = double.tryParse(valCtrl.text.replaceAll(',', '.')) ?? 0;
                if (descCtrl.text.isEmpty || val <= 0) return;
                
                String categoriaFinal = dropdownCat == 'Outros' && customCatCtrl.text.isNotEmpty ? customCatCtrl.text : dropdownCat;

                if (editing == null) {

                  // essa parte cria um lançamento
                  final tx = Transaction(id: DateTime.now().millisecondsSinceEpoch.toString(), description: descCtrl.text, value: val, type: type, category: categoriaFinal, date: DateTime.now());
                  setState(() => _transactions = [tx, ..._transactions]);
                } else {
                  // já essa atualiza um lançamento existente
                  setState(() {
                    editing.description = descCtrl.text;
                    editing.value = val;
                    editing.type = type;
                    editing.category = categoriaFinal;
                  });
                }
                
                Storage.saveTransactions(_transactions);
                Navigator.pop(ctx);
              },
              child: const Text('Salvar'),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  void _showProventoForm({IncomeSource? editing}) {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final valCtrl = TextEditingController(text: editing != null ? editing.value.toStringAsFixed(2) : '');
    final dayCtrl = TextEditingController(text: editing != null ? editing.receiveDay.toString() : '1');
    final monthCtrl = TextEditingController(text: editing?.receiveMonth?.toString() ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(editing == null ? 'Nova Fonte de Renda' : 'Editar Provento'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome (Ex: Salário, Aluguel)')),
          const SizedBox(height: 8),
          TextField(controller: valCtrl, decoration: const InputDecoration(labelText: 'Valor (R\$)'), keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: dayCtrl, decoration: const InputDecoration(labelText: 'Dia'), keyboardType: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: monthCtrl, decoration: const InputDecoration(labelText: 'Mês (Opcional)'), keyboardType: TextInputType.number)),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(valCtrl.text.replaceAll(',', '.')) ?? 0;
              final d = int.tryParse(dayCtrl.text) ?? 1;
              final m = int.tryParse(monthCtrl.text); // Se vazio, fica nulo

              if (nameCtrl.text.isEmpty || v <= 0) return;
              if (editing == null) {
                _incomesList.add(IncomeSource(id: DateTime.now().millisecondsSinceEpoch.toString(), name: nameCtrl.text, value: v, receiveDay: d, receiveMonth: m));
              } else {
                editing.name = nameCtrl.text;
                editing.value = v;
                editing.receiveDay = d;
                editing.receiveMonth = m;
              }
              Storage.saveIncomes(_incomesList);
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showInvestimentoForm({Investment? editing}) {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final amtCtrl = TextEditingController(text: editing != null ? editing.amount.toStringAsFixed(2) : '');
    final rateCtrl = TextEditingController(text: editing != null ? editing.yieldRate.toStringAsFixed(2) : '');
    String selectedType = editing?.type ?? 'Renda Fixa';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          title: Text(editing == null ? 'Novo Investimento' : 'Editar Investimento'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome do Ativo')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedType,
              items: ['Renda Fixa', 'Ações', 'FIIs', 'Criptomoedas', 'Negócio Próprio'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setStateModal(() => selectedType = v!),
              decoration: const InputDecoration(labelText: 'Categoria'),
            ),
            const SizedBox(height: 8),
            TextField(controller: amtCtrl, decoration: const InputDecoration(labelText: 'Capital Investido (R\$)'), keyboardType: TextInputType.number),
            const SizedBox(height: 8),
            TextField(controller: rateCtrl, decoration: const InputDecoration(labelText: 'Rendimento Estimado (% a.m.)'), keyboardType: TextInputType.number),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                final a = double.tryParse(amtCtrl.text.replaceAll(',', '.')) ?? 0;
                final r = double.tryParse(rateCtrl.text.replaceAll(',', '.')) ?? 0;
                if (nameCtrl.text.isEmpty || a <= 0) return;
                
                if (editing == null) {
                  _investments.add(Investment(id: DateTime.now().millisecondsSinceEpoch.toString(), name: nameCtrl.text, amount: a, yieldRate: r, type: selectedType));
                } else {
                  editing.name = nameCtrl.text;
                  editing.amount = a;
                  editing.yieldRate = r;
                  editing.type = selectedType;
                }
                Storage.saveInvestments(_investments);
                setState(() {});
                Navigator.pop(ctx);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFixoForm({FixedExpense? editing}) {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final valCtrl = TextEditingController(text: editing != null ? editing.value.toStringAsFixed(2) : '');
    final dayCtrl = TextEditingController(text: editing != null ? editing.dueDay.toString() : '10');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(editing == null ? 'Nova Conta Fixa' : 'Editar Conta Fixa'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome da Conta (Ex: Aluguel)')),
          const SizedBox(height: 8),
          TextField(controller: valCtrl, decoration: const InputDecoration(labelText: 'Valor Mensal (R\$)'), keyboardType: TextInputType.number),
          const SizedBox(height: 8),
          TextField(controller: dayCtrl, decoration: const InputDecoration(labelText: 'Dia do Vencimento (1 a 31)'), keyboardType: TextInputType.number),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(valCtrl.text.replaceAll(',', '.')) ?? 0;
              final d = int.tryParse(dayCtrl.text) ?? 10;
              if (nameCtrl.text.isEmpty || v <= 0) return;
              if (editing == null) {
                _fixed.add(FixedExpense(id: DateTime.now().millisecondsSinceEpoch.toString(), name: nameCtrl.text, value: v, dueDay: d));
              } else {
                editing.name = nameCtrl.text;
                editing.value = v;
                editing.dueDay = d;
              }
              Storage.saveFixed(_fixed);
              setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _importarExtrato() async {
    final txs = await ExtratoImporter.importar();
    if (txs.isNotEmpty) {
      setState(() => _transactions = [...txs, ..._transactions]);
      Storage.saveTransactions(_transactions);
      
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('${txs.length} itens importados!'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: txs.length,
              itemBuilder: (c, i) => ListTile(
                leading: Icon(txs[i].type == 'despesa' ? Icons.remove_circle : Icons.add_circle, 
                  color: txs[i].type == 'despesa' ? Colors.red : Colors.green),
                title: Text(txs[i].description, style: const TextStyle(fontSize: 14)),
                subtitle: Text(txs[i].category, style: const TextStyle(fontSize: 12)),
                trailing: Text(_fmt.format(txs[i].value), 
                  style: TextStyle(color: txs[i].type == 'despesa' ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          actions: [
            ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Concluir'))
          ],
        ),
      );
    }
  }

  Future<void> _exportarRelatorio(List<Transaction> txs) async {
    await RelatorioExporter.exportar(transacoes: txs, gastosFixos: _fixedTotal);
    _showSnack('Relatório PDF gerado com sucesso!');
  }

  Future<void> _loginGoogle() async {
    try {
      await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      _showSnack('Login com Google realizado com sucesso!');
    } catch (e) {
      _showSnack('Erro ao entrar com Google: $e');
    }
  }

  Widget _resumoItem(String label, double value, Color color) => Column(children: [
    Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    Text(_fmt.format(value), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
  ]);
  
  void _showHistoricoCompleto(Color bgCard) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => Container(
          height: MediaQuery.of(ctx).size.height * 0.9, // Ocupa 90% da tela
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Tracinho decorativo no topo
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 12),
              const Text('Todos os Lançamentos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              
              Expanded(
                child: _transactions.isEmpty
                    ? const Center(child: Text('Nenhum histórico encontrado.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _transactions.length,
                        itemBuilder: (context, i) {
                          final tx = _transactions[i];
                          final isDespesa = tx.type == 'despesa';
                          
                          return Card(
                            color: bgCard,
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              leading: CircleAvatar(
                                backgroundColor: isDespesa ? Colors.red.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                child: Icon(isDespesa ? Icons.arrow_downward : Icons.arrow_upward, 
                                            color: isDespesa ? Colors.red : Colors.green, size: 20),
                              ),
                              title: Text(tx.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text('${DateFormat('dd/MM/yyyy').format(tx.date)}  •  ${tx.category}', 
                                             style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    (isDespesa ? '- ' : '+ ') + _fmt.format(tx.value),
                                    style: TextStyle(color: isDespesa ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18),
                                    onPressed: () {
                                      Navigator.pop(ctx); // Fecha o painel de histórico
                                      _showTxForm(editing: tx); // Abre o formulário de edição
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                    onPressed: () {
                                      setState(() => _transactions.removeWhere((t) => t.id == tx.id));
                                      setStateModal(() {}); // Atualiza o histórico na hora
                                      Storage.saveTransactions(_transactions);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}