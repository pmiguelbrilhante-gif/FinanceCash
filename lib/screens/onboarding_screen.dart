import 'package:flutter/material.dart';
import '../services/storage.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  void _next() {
    if (_page < 2) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
   
    await Storage.setFirstLaunchDone();
    if (!mounted) return;
    
  
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f172a),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _page == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _page == i ? const Color(0xFF1d4ed8) : Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              onPageChanged: (i) => setState(() => _page = i),
              children: [_buildPage1(), _buildPage2(), _buildPage3()],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1d4ed8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _page < 2 ? 'Continuar' : 'Começar a usar',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // tela de boas-vindas
  Widget _buildPage1() => const Padding(
    padding: EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('💰', style: TextStyle(fontSize: 80)),
      SizedBox(height: 32),
      Text('Bem-vindo ao FinanceCash',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center),
      SizedBox(height: 16),
      Text(
        'Sua nova central de gestão financeira.\n\nAssuma o controle absoluto, descubra exatamente para onde o seu dinheiro está indo e tome decisões mais inteligentes no dia a dia.',
        style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.6),
        textAlign: TextAlign.center,
      ),
    ]),
  );


  Widget _buildPage2() => const Padding(
    padding: EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('📂', style: TextStyle(fontSize: 80)),
      SizedBox(height: 32),
      Text('Importação Simples',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center),
      SizedBox(height: 16),
      Text(
        'Chega de digitar tudo do zero!\n\nImporte os extratos bancários em formato CSV com poucos cliques ou registre seus ganhos e despesas manualmente de forma rápida.',
        style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.6),
        textAlign: TextAlign.center,
      ),
    ]),
  );

  // tela dos gráficos e relatórios
  Widget _buildPage3() => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      _buildMiniChart(),
      const SizedBox(height: 32),
      const Text('Visão Clara e Completa',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center),
      const SizedBox(height: 16),
      const Text(
        'Acompanhe a evolução do seu patrimônio com gráficos semanais, mensais e anuais.\n\nExporte relatórios em PDF de cair o queixo e alcance suas metas financeiras!',
        style: TextStyle(color: Colors.grey, fontSize: 15, height: 1.6),
        textAlign: TextAlign.center,
      ),
    ]),
  );


  Widget _buildMiniChart() {
    return SizedBox(
      height: 90,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _bar(40, Colors.red),
          _bar(70, Colors.green),
          _bar(30, Colors.red),
          _bar(90, Colors.green),
          _bar(50, Colors.orange), 
        ],
      ),
    );
  }


  Widget _bar(double height, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 18,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
    );
  }
}