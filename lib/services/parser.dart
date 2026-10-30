import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';


const String kBackendUrl = 'https://seu-backend.com/api/parse';


final List<_Padrao> _padroes = [
  
  _Padrao(
    regex: RegExp(
      r'Compra\s+(?:de\s+)?R\$\s*([\d.,]+)\s+(?:aprovada\s+)?(?:em|no|na)\s+(.+?)(?:\s+para|\s+no\s+cart|\.|$)',
      caseSensitive: false,
    ),
    tipo: 'despesa',
    grupoValor: 1,
    grupoDesc: 2,
  ),

  _Padrao(
    regex: RegExp(
      r'(?:compra|pago|pagamento)\s+(?:no\s+)?(?:d[ée]bito|cr[ée]dito)\s+(?:em|no|na|de\s+R\$\s*)?([\d.,]+)?\s*(?:em|no|na|-\s*)\s*(.+?)(?:\.|$)',
      caseSensitive: false,
    ),
    tipo: 'despesa',
    grupoValor: 1,
    grupoDesc: 2,
  ),
  
  _Padrao(
    regex: RegExp(
      r'(?:Voc[êe]\s+enviou|PIX\s+enviado|Transfer[êe]ncia\s+enviada)\s+(?:de\s+)?R\$\s*([\d.,]+)\s+(?:para|a)\s+(.+?)(?:\s+creditado|\.|$)',
      caseSensitive: false,
    ),
    tipo: 'despesa',
    grupoValor: 1,
    grupoDesc: 2,
    prefixoDesc: 'PIX para ',
  ),
  
  _Padrao(
    regex: RegExp(
      r'(?:Voc[êe]\s+recebeu|PIX\s+recebido|Transfer[êe]ncia\s+recebida)\s+(?:de\s+)?R\$\s*([\d.,]+)\s+(?:de|por)\s+(.+?)(?:\s+creditado|\.|$)',
      caseSensitive: false,
    ),
    tipo: 'receita',
    grupoValor: 1,
    grupoDesc: 2,
    prefixoDesc: 'PIX de ',
  ),
  
  _Padrao(
    regex: RegExp(
      r'Pagamento\s+(?:de\s+)?(?:boleto|conta)?\s*(?:de\s+)?R\$\s*([\d.,]+)\s+(?:para|referente|de|em)?\s*(.+?)(?:\.|$)',
      caseSensitive: false,
    ),
    tipo: 'despesa',
    grupoValor: 1,
    grupoDesc: 2,
  ),
 
  _Padrao(
    regex: RegExp(r'R\$\s*([\d.,]+)', caseSensitive: false),
    tipo: 'despesa',
    grupoValor: 1,
    grupoDesc: -1,
    isFallback: true,
  ),
];

class _Padrao {
  final RegExp regex;
  final String tipo;
  final int grupoValor;
  final int grupoDesc;
  final String prefixoDesc;
  final bool isFallback;

  const _Padrao({
    required this.regex,
    required this.tipo,
    required this.grupoValor,
    required this.grupoDesc,
    this.prefixoDesc = '',
    this.isFallback = false,
  });
}



final Map<String, List<String>> _categorias = {
  'Alimentação': ['supermercado', 'mercado', 'hortifruti', 'padaria', 'ifood', 'restaurante', 'lanchonete', 'burger', 'pizza', 'delivery', 'açougue'],
  'Transporte': ['posto', 'uber', 'combustivel', 'gasolina', 'estacionamento', '99', 'indriver', 'onibus', 'metro'],
  'Saúde': ['farmacia', 'drogaria', 'clinica', 'hospital', 'medico', 'odonto', 'droga'],
  'Educação': ['escola', 'faculdade', 'curso', 'livraria', 'universidade', 'colegio'],
  'Lazer': ['cinema', 'netflix', 'spotify', 'steam', 'amazon prime', 'hbo', 'ingresso', 'clube'],
  'Casa': ['luz', 'energia', 'agua', 'condominio', 'aluguel', 'internet', 'gas', 'iptu'],
  'Comunicação': ['claro', 'vivo', 'tim', 'oi', 'net'],
  'Salário': ['salario', 'salário', 'folha', 'holerite'],
};

String _classificar(String nome) {
  final lower = nome.toLowerCase();
  for (final entry in _categorias.entries) {
    if (entry.value.any((p) => lower.contains(p))) return entry.key;
  }
  return 'Outros';
}

double _normalizarValor(String texto) {
  var t = texto.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (t.contains(',') && t.contains('.')) {
    if (t.lastIndexOf(',') > t.lastIndexOf('.')) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    } else {
      t = t.replaceAll(',', '');
    }
  } else if (t.contains(',')) {
    t = t.replaceAll(',', '.');
  }
  return double.tryParse(t) ?? 0;
}

String _titulo(String texto) {
  var t = texto
      .replaceAll(RegExp(r'para o cartão.*', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s*APROVADA\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'[\.\!\?]+$'), '')
      .trim();
  return t.split(RegExp(r'\s+')).map((p) =>
      p.isEmpty ? p : p[0].toUpperCase() + p.substring(1).toLowerCase()).join(' ');
}


Map<String, dynamic>? _parseLocal(String titulo, String corpo) {
  final candidatos = [corpo, titulo, '$titulo $corpo'];

  for (final padrao in _padroes) {
    for (final texto in candidatos) {
      final m = padrao.regex.firstMatch(texto);
      if (m == null) continue;

      final valor = _normalizarValor(m.group(padrao.grupoValor) ?? '');
      if (valor <= 0) continue;

      String desc;
      if (padrao.isFallback) {
        final lower = texto.toLowerCase();
        final ehReceita = lower.contains('receb') || lower.contains('crédit') || lower.contains('credit') || lower.contains('pix de');
        desc = _titulo(corpo.isNotEmpty ? corpo : titulo);
        return {
          'descricao': desc.length > 40 ? desc.substring(0, 40) : desc,
          'valor': valor,
          'tipo': ehReceita ? 'receita' : 'despesa',
          'categoria': _classificar(desc),
        };
      } else {
        final rawDesc = padrao.grupoDesc > 0 ? (m.group(padrao.grupoDesc) ?? '') : corpo;
        desc = '${padrao.prefixoDesc}${_titulo(rawDesc)}';
        return {
          'descricao': desc.trim(),
          'valor': valor,
          'tipo': padrao.tipo,
          'categoria': _classificar(rawDesc),
        };
      }
    }
  }
  return null;
}

Future<Map<String, dynamic>?> _parseBackend(String texto) async {
  try {
    final response = await http.post(
      Uri.parse(kBackendUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'texto': texto}),
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode != 200) return null;
    final parsed = jsonDecode(response.body) as Map<String, dynamic>;
    if (parsed.containsKey('erro')) return null;
    return {
      'descricao': parsed['descricao'] ?? texto,
      'valor': (parsed['valor'] as num?)?.toDouble() ?? 0,
      'tipo': parsed['tipo'] ?? 'despesa',
      'categoria': parsed['categoria'] ?? 'Outros',
    };
  } catch (_) {
    return null;
  }
}

Future<Transaction?> parseNotificacao(String titulo, String corpo) async {
  final local = _parseLocal(titulo, corpo);
  if (local != null) {
    return _toTransaction(local);
  }


  final backendData = await _parseBackend('$titulo $corpo');
  if (backendData != null && (backendData['valor'] as double) > 0) {
    return _toTransaction(backendData);
  }
  return null;
}

Transaction? parseNotificacaoSync(String texto) {
  final local = _parseLocal(texto, texto);
  if (local == null) return null;
  return _toTransaction(local);
}

Transaction _toTransaction(Map<String, dynamic> data) => Transaction(
  id: DateTime.now().millisecondsSinceEpoch.toString(),
  description: data['descricao'],
  value: (data['valor'] as double),
  type: data['tipo'],
  category: data['categoria'],
  date: DateTime.now(),
  automatic: true,
);