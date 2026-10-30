import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../models/models.dart';

class ExtratoImporter {
  static Future<List<Transaction>> importar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return [];

    final file = result.files.first;

    if (file.bytes != null) {
      final texto = utf8.decode(file.bytes!, allowMalformed: true);
      return processarCsv(texto);
    } else if (file.path != null) {
      final texto = await File(file.path!).readAsString();
      return processarCsv(texto);
    }

    return [];
  }


  static List<Transaction> processarCsv(String texto) {
    final textoLimpo = texto
        .replaceAll('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    
    final linhas = textoLimpo.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    if (linhas.isEmpty) return [];

    String separador = ';';
    if (linhas.take(5).any((l) => l.contains(','))) {
      int commas = linhas.first.split(',').length;
      int semis = linhas.first.split(';').length;
      if (commas > semis) separador = ',';
    }

    int colData = -1;
    int colValor = -1;
    int colDesc = -1;

    final resultado = <Transaction>[];

    for (int i = 0; i < linhas.length; i++) {
      final linha = linhas[i];
      final campos = _separarLinha(linha, separador);

      if (colData == -1 && colValor == -1) {
        for (int j = 0; j < campos.length; j++) {
          final c = campos[j].toLowerCase();
          if (c.contains('data')) colData = j;
          if (c.contains('valor') || c.contains('amount')) colValor = j;
          if (c.contains('descri') || c.contains('histórico') || c.contains('title') || c.contains('detalhe')) colDesc = j;
        }
        if (colData != -1 && colValor != -1) continue;
      }

      if (colData == -1 || colValor == -1) continue;
      if (campos.length <= colData || campos.length <= colValor) continue;

      final data = _parseData(campos[colData]);
      if (data == null) continue; 

      final valorStr = campos[colValor];
      final ehNegativo = valorStr.contains('-');
      final valor = _parseValor(valorStr);
      if (valor == null || valor == 0) continue;

      String descricaoOriginal = 'Lançamento bancário';
      if (colDesc != -1 && campos.length > colDesc) {
        descricaoOriginal = campos[colDesc].trim();
        if (descricaoOriginal.isEmpty) descricaoOriginal = 'Lançamento bancário';
      }

      String tipo = ehNegativo ? 'despesa' : 'receita';

      if (!ehNegativo) {
        final lowerDesc = descricaoOriginal.toLowerCase();
        const termosDespesa = ['compra', 'ifood', 'uber', 'pagamento', 'débito', 'tarifa', 'anuidade'];
        if (termosDespesa.any((t) => lowerDesc.contains(t))) {
          tipo = 'despesa';
        }
      }

      final nomeLimpo = _limparNomeExtrato(descricaoOriginal);
      String categoria = _classificarCategoria(nomeLimpo);

      if (categoria == 'Outros') {
        categoria = _resumirNome(nomeLimpo);
      }

      resultado.add(Transaction(
        id: 'csv_${data.millisecondsSinceEpoch}_${i}_${DateTime.now().microsecondsSinceEpoch}',
        description: nomeLimpo,
        value: valor,
        type: tipo,
        category: categoria,
        date: data,
        automatic: true,
      ));
    }

    return resultado;
  }

  static String _limparNomeExtrato(String descricao) {
    String texto = descricao;
    
    final partes = texto.split(RegExp(r'\s+-\s+'));
    if (partes.length > 1) {
      final p0 = partes[0].toLowerCase();
      if (p0.contains('pix') || p0.contains('transfer') || p0.contains('compra') || p0.contains('pagamento') || p0.contains('boleto')) {
        texto = partes[1];
      }
    }

    texto = texto.replaceAll(RegExp(r'\d{2}\.\d{3}\.\d{3}/\d{4}-\d{2}.*'), '');
    texto = texto.replaceAll(RegExp(r'\*\*\*.*\*\*\*.*'), ''); 
    texto = texto.replaceAll(RegExp(r'- BCO.*|- Banco.*|- Instituição.*|- Agência.*', caseSensitive: false), '');
    
    texto = texto.trim();
    if (texto.isEmpty) return 'Lançamento';

    return texto.split(' ').map((word) {
      if (word.isEmpty) return '';
      if (word.length <= 2 && !RegExp(r'[A-Z]', caseSensitive: false).hasMatch(word)) return word.toLowerCase();
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  static String _resumirNome(String nomeCompleto) {
    final p = nomeCompleto.split(' ').where((w) => w.length > 2).toList();
    if (p.length >= 2) {
      return '${p[0]} ${p[1]}';
    } else if (p.isNotEmpty) {
      return p[0];
    }
    return 'Outros';
  }

  static List<String> _separarLinha(String linha, String separador) {
    final resultado = <String>[];
    final atual = StringBuffer();
    var entreAspas = false;
    for (var i = 0; i < linha.length; i++) {
      final char = linha[i];
      if (char == '"') {
        entreAspas = !entreAspas;
      } else if (char == separador && !entreAspas) {
        resultado.add(atual.toString().trim());
        atual.clear();
      } else {
        atual.write(char);
      }
    }
    resultado.add(atual.toString().trim());
    return resultado;
  }

  static double? _parseValor(String texto) {
    var limpo = texto.replaceAll('R\$', '').replaceAll(' ', '').trim();
    limpo = limpo.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (limpo.isEmpty || limpo == '-') return null;

    if (limpo.contains(',') && limpo.contains('.')) {
      if (limpo.lastIndexOf(',') > limpo.lastIndexOf('.')) {
        limpo = limpo.replaceAll('.', '').replaceAll(',', '.');
      } else {
        limpo = limpo.replaceAll(',', '');
      }
    } else if (limpo.contains(',')) {
      limpo = limpo.replaceAll(',', '.');
    }

    final num = double.tryParse(limpo);
    if (num == null) return null;
    return num.abs();
  }

  static DateTime? _parseData(String texto) {
    final limpo = texto.trim();
    final encontrada = RegExp(r'(\d{2})[/.-](\d{2})[/.-](\d{2,4})|(?:(\d{4})[/.-](\d{2})[/.-](\d{2}))').firstMatch(limpo);
    if (encontrada == null) return null;
    try {
      if (encontrada.group(4) != null) {
        return DateTime(int.parse(encontrada.group(4)!), int.parse(encontrada.group(5)!), int.parse(encontrada.group(6)!));
      }
      var ano = int.parse(encontrada.group(3)!);
      if (ano < 100) ano += 2000;
      return DateTime(ano, int.parse(encontrada.group(2)!), int.parse(encontrada.group(1)!));
    } catch (_) {
      return null;
    }
  }

  static String _classificarCategoria(String nome) {
    final texto = nome.toLowerCase();
    
    const categorias = {
      'Alimentação': [
        'mercado', 'supermercado', 'padaria', 'ifood', 'restaurante', 'lanchonete',
        'atacadão', 'assai', 'carrefour', 'burger', 'pizza', 'delivery', 'comercial',
        'alimentos', 'doceria', 'sorveteria', 'hortifruti', 'açougue', 'bebidas',
        'mcdonalds', 'bobs', 'atacadao'
      ],
      'Transporte': [
        'posto', 'uber', 'combustivel', 'gasolina', 'estacionamento', '99app', '99 taxi',
        'indriver', 'onibus', 'metro', 'pedagio', 'conveniencia', 'ipiranga',
        'shell', 'petrobras', 'posto br', 'passagem', 'latam', 'voe gol', 'azul linhas'
      ],
      'Saúde': [
        'farmacia', 'drogaria', 'clinica', 'hospital', 'remedio',
        'unimed', 'hapvida', 'odont', 'pague menos', 'drogasil', 'raia', 'drogarias'
      ],
      'Educação': [
        'escola', 'faculdade', 'curso', 'livraria', 'colegio', 'universidade',
        'papelaria', 'estacio', 'kroton', 'udemy', 'alura'
      ],
      'Lazer': [
        'cinema', 'netflix', 'spotify', 'steam', 'amazon prime', 'jogos',
        'ingresso', 'clube', 'disney', 'playstation', 'xbox', 'nintendo', 'viagem'
      ],
      'Casa': [
        'luz', 'energia', 'agua', 'condominio', 'aluguel', 'internet', 'iptu', 'gás',
        'ambar', 'celpa', 'cemig', 'copel', 'sabesp', 'caesb', 'neoenergia', 'equatorial',
        'claro', 'vivo', 'oi fibra', 'tim celular', 'net claro', 'saneamento'
      ],
      'Fatura': [
        'fatura', 'cartão', 'cartao', 'nubank', 'itau', 'bradesco', 'santander'
      ],
      'Salário': [
        'salario', 'salário', 'provento', 'folha', 'holerite', 'remuneração',
        'adiantamento', 'pagamento de salario'
      ],
    };

    for (final entrada in categorias.entries) {
      for (final p in entrada.value) {
        if (texto.contains(p)) {
          return entrada.key;
        }
      }
    }
    
    return 'Outros';
  }
}