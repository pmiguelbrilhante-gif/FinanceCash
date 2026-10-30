import 'package:flutter_test/flutter_test.dart';
import 'package:financecash/services/extrato_importer.dart';

void main() {
  group('ExtratoImporter', () {
    test('reconhece o CSV do Nubank', () {
      final transacoes = ExtratoImporter.processarCsv('''
Data,Valor,Identificador,Descrição
2026-08-03,-20.50,id-1,Supermercado
2026-08-03,100.00,id-2,PIX recebido
''');

      expect(transacoes, hasLength(2));
      expect(transacoes.first.type, 'despesa');
      expect(transacoes.first.value, 20.50);
      expect(transacoes.last.type, 'receita');
    });

    test('reconhece o CSV do Inter com cabeçalho antes das transações', () {
      final transacoes = ExtratoImporter.processarCsv('''
Extrato Conta Corrente
Período;01/08/2026 a 03/08/2026
Data Lançamento;Histórico;Descrição;Valor;Saldo
01/08/2026;PIX;PIX enviado;-10,00;90,00
02/08/2026;PIX;PIX recebido;50,00;140,00
''');

      expect(transacoes, hasLength(2));
      expect(transacoes.first.type, 'despesa');
      expect(transacoes.first.value, 10);
      expect(transacoes.last.type, 'receita');
    });
  });
}