import 'dart:typed_data';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../models/models.dart';
import 'save_file.dart';

class RelatorioExporter {
  static final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _data = DateFormat('dd/MM/yyyy');

  static Future<String?> exportar({
    required List<Transaction> transacoes,
    required double gastosFixos,
  }) async {
    final agora = DateTime.now();
    final nome = 'FinanceCash_Relatorio_${DateFormat('yyyy_MM').format(agora)}.pdf';
    
    final bytes = _pdf(transacoes, gastosFixos, agora);
    
    return salvarArquivo(bytes, nome);
  }

  static Uint8List _pdf(List<Transaction> transacoes, double gastosFixos, DateTime agora) {
    final receitas = transacoes.where((t) => t.type == 'receita').fold(0.0, (s, t) => s + t.value);
    final despesasVariaveis = transacoes.where((t) => t.type == 'despesa').fold(0.0, (s, t) => s + t.value);
    final despesasTotais = despesasVariaveis + gastosFixos;
    
    final documento = PdfDocument();
    final pagina = documento.pages.add();
    final tamanho = pagina.getClientSize();
    
    final titulo = PdfStandardFont(PdfFontFamily.helvetica, 19, style: PdfFontStyle.bold);
    final subtitulo = PdfStandardFont(PdfFontFamily.helvetica, 10);
    
    // CABEÇALHO DO RELATÓRIO
    pagina.graphics.drawString('Relatório financeiro', titulo,
        bounds: Rect.fromLTWH(0, 0, tamanho.width, 28));
    pagina.graphics.drawString('Gerado em ${DateFormat('dd/MM/yyyy HH:mm').format(agora)}', subtitulo,
        bounds: Rect.fromLTWH(0, 31, tamanho.width, 18));
    pagina.graphics.drawString('Receitas: ${_moeda.format(receitas)}   •   Despesas: ${_moeda.format(despesasTotais)}   •   Saldo: ${_moeda.format(receitas - despesasTotais)}',
        subtitulo, bounds: Rect.fromLTWH(0, 52, tamanho.width, 20));

    double yPosAtual = 82.0;

    // RESUMO GERAL DE GANHOS E GASTOS
    double fluxoTotal = receitas + despesasTotais;
    if (fluxoTotal > 0) {
      final pctReceitas = (receitas / fluxoTotal) * 100;
      final pctDespesas = (despesasTotais / fluxoTotal) * 100;

      pagina.graphics.drawString('Ganhos vs Gastos (Geral)',
          PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold),
          bounds: Rect.fromLTWH(0, yPosAtual, tamanho.width, 20));
      
      yPosAtual += 20;

      // Barra Entradas (Verde)
      pagina.graphics.drawRectangle(brush: PdfSolidBrush(PdfColor(34, 197, 94)), bounds: Rect.fromLTWH(10, yPosAtual + 2, 10, 10));
      pagina.graphics.drawString('Entradas: ${_moeda.format(receitas)} (${pctReceitas.toStringAsFixed(1)}%)',
          PdfStandardFont(PdfFontFamily.helvetica, 10), bounds: Rect.fromLTWH(25, yPosAtual, 250, 15));
      yPosAtual += 15;

      // Barra Saídas (Vermelho)
      pagina.graphics.drawRectangle(brush: PdfSolidBrush(PdfColor(239, 68, 68)), bounds: Rect.fromLTWH(10, yPosAtual + 2, 10, 10));
      pagina.graphics.drawString('Saídas: ${_moeda.format(despesasTotais)} (${pctDespesas.toStringAsFixed(1)}%)',
          PdfStandardFont(PdfFontFamily.helvetica, 10), bounds: Rect.fromLTWH(25, yPosAtual, 250, 15));
      
      yPosAtual += 30;
    }

    // GRÁFICO DE BARRAS HORIZONTAIS (UM DELES)
    if (despesasTotais > 0) {
      final Map<String, double> porCategoria = {};
      for (final t in transacoes.where((t) => t.type == 'despesa')) {
        porCategoria[t.category] = (porCategoria[t.category] ?? 0) + t.value;
      }
      if (gastosFixos > 0) {
        porCategoria['Gastos Fixos'] = (porCategoria['Gastos Fixos'] ?? 0) + gastosFixos;
      }

      final categoriasSorted = porCategoria.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      
      pagina.graphics.drawString('Despesas por Categoria (Top 5)',
          PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold),
          bounds: Rect.fromLTWH(0, yPosAtual, tamanho.width, 20));

      yPosAtual += 25;
      
      final double valorMaximo = categoriasSorted.first.value;
      const double larguraMaximaBarra = 300.0;

      for (var i = 0; i < categoriasSorted.length && i < 5; i++) {
        final cat = categoriasSorted[i];
        final larguraBarra = (cat.value / valorMaximo) * larguraMaximaBarra;
        final pct = (cat.value / despesasTotais) * 100;

        
        pagina.graphics.drawString(cat.key, PdfStandardFont(PdfFontFamily.helvetica, 10),
            bounds: Rect.fromLTWH(0, yPosAtual, 100, 15));
        
        
        pagina.graphics.drawRectangle(
            brush: PdfSolidBrush(PdfColor(41, 128, 185)),
            bounds: Rect.fromLTWH(100, yPosAtual + 2, larguraBarra > 5 ? larguraBarra : 5, 10));

        
        pagina.graphics.drawString('${_moeda.format(cat.value)} (${pct.toStringAsFixed(1)}%)',
            PdfStandardFont(PdfFontFamily.helvetica, 9),
            bounds: Rect.fromLTWH(105 + larguraBarra, yPosAtual, 150, 15));

        yPosAtual += 20; 
      }
      yPosAtual += 20; 
    }

    // TABELA DE LANÇAMENTOS 
    final grade = PdfGrid();
    grade.columns.add(count: 5);
    grade.headers.add(1);
    final cabecalho = grade.headers[0];
    
    for (var i = 0; i < 5; i++) {
      cabecalho.cells[i].style = PdfGridCellStyle(
        backgroundBrush: PdfSolidBrush(PdfColor(29, 78, 216)),
        textBrush: PdfBrushes.white,
        font: PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold),
      );
    }
    
    cabecalho.cells[0].value = 'Data';
    cabecalho.cells[1].value = 'Descrição';
    cabecalho.cells[2].value = 'Categoria';
    cabecalho.cells[3].value = 'Tipo';
    cabecalho.cells[4].value = 'Valor';
    
    final ordenadas = transacoes.toList()..sort((a, b) => b.date.compareTo(a.date));
    for (final t in ordenadas) {
      final linha = grade.rows.add();
      linha.cells[0].value = _data.format(t.date);
      linha.cells[1].value = t.description;
      linha.cells[2].value = t.category;
      linha.cells[3].value = t.type == 'receita' ? 'Receita' : 'Despesa';
      linha.cells[4].value = _moeda.format(t.value);
    }
    
    if (gastosFixos > 0) {
      final linha = grade.rows.add();
      linha.cells[0].value = _data.format(agora);
      linha.cells[1].value = 'Gastos fixos programados';
      linha.cells[2].value = 'Gastos Fixos';
      linha.cells[3].value = 'Despesa';
      linha.cells[4].value = _moeda.format(gastosFixos);
    }
    
    grade.style = PdfGridStyle(font: PdfStandardFont(PdfFontFamily.helvetica, 8));
    
    
    grade.draw(page: pagina, bounds: Rect.fromLTWH(0, yPosAtual, tamanho.width, 0));

    
    for (var i = 0; i < grade.rows.count; i++) {
      final isReceita = grade.rows[i].cells[3].value == 'Receita';
      final brushCor = isReceita ? PdfSolidBrush(PdfColor(34, 197, 94)) : PdfSolidBrush(PdfColor(239, 68, 68));
      grade.rows[i].cells[4].style = PdfGridCellStyle(
        textBrush: brushCor,
        font: PdfStandardFont(PdfFontFamily.helvetica, 8, style: PdfFontStyle.bold),
      );
    }
    
    
    final gradeLayoutResult = grade.draw(page: pagina, bounds: Rect.fromLTWH(0, yPosAtual, tamanho.width, 0))!;
    yPosAtual = gradeLayoutResult.bounds.bottom + 30; 

    
    if (transacoes.isNotEmpty && yPosAtual < tamanho.height - 150) {
      pagina.graphics.drawString('Evolução do Saldo (Análise Visual)',
          PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold),
          bounds: Rect.fromLTWH(0, yPosAtual, tamanho.width, 20));
      yPosAtual += 25;

      
      pagina.graphics.drawLine(PdfPen(PdfColor(200, 200, 200), width: 1), Offset(0, yPosAtual + 50), Offset(tamanho.width, yPosAtual + 50));
      
      PdfPath caminhoLinha = PdfPath();
      double xAtual = 0;
      double espacoX = tamanho.width / transacoes.length;
      double saldoAcumulado = 0;
      Offset? pontoAnterior; 

      final penLinha = PdfPen(PdfColor(29, 78, 216), width: 2);

      // Calculo dos pontos da linha
      for (int i = ordenadas.length - 1; i >= 0; i--) {
        final t = ordenadas[i];
        saldoAcumulado += t.type == 'receita' ? t.value : -t.value;
        
       
        double normalizadoY = (saldoAcumulado / (fluxoTotal > 0 ? fluxoTotal : 1)) * 50;
        double yPonto = (yPosAtual + 50) - normalizadoY;

        Offset pontoAtual = Offset(xAtual, yPonto);

        
        if (pontoAnterior != null) {
          pagina.graphics.drawLine(penLinha, pontoAnterior, pontoAtual);
        }
        
        pontoAnterior = pontoAtual;
        xAtual += espacoX;
      }
      
      
      pagina.graphics.drawPath(caminhoLinha, pen: PdfPen(PdfColor(29, 78, 216), width: 2));
    }
    
    final arquivoBytes = documento.saveSync();
    documento.dispose();
    return Uint8List.fromList(arquivoBytes);
  }
}