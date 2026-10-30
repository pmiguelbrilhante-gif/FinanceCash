import 'dart:convert';

class Transaction {
  String id;
  String description;
  double value;
  String type; 
  String category;
  DateTime date;
  bool automatic;

  Transaction({
    required this.id,
    required this.description,
    required this.value,
    required this.type,
    required this.category,
    required this.date,
    this.automatic = false,
  });

  Transaction copyWith({
    String? description,
    double? value,
    String? type,
    String? category,
    DateTime? date,
  }) =>
      Transaction(
        id: id,
        description: description ?? this.description,
        value: value ?? this.value,
        type: type ?? this.type,
        category: category ?? this.category,
        date: date ?? this.date,
        automatic: automatic,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'value': value,
        'type': type,
        'category': category,
        'date': date.toIso8601String(),
        'automatic': automatic,
      };

  factory Transaction.fromJson(Map<String, dynamic> j) {
    return Transaction(
      id: j['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      description: j['description']?.toString() ?? '',
      // Tenta converter qualquer formato numérico com segurança
      value: double.tryParse(j['value']?.toString() ?? '0') ?? 0.0,
      type: j['type']?.toString() ?? 'despesa',
      category: j['category']?.toString() ?? 'Outros',
      date: j['date'] != null ? DateTime.tryParse(j['date'].toString()) ?? DateTime.now() : DateTime.now(),
      automatic: j['automatic'] ?? false,
    );
  }
}

class FixedExpense {
  String id;
  String name;
  double value;
  int dueDay; 

  FixedExpense({
    required this.id,
    required this.name,
    required this.value,
    this.dueDay = 10,
  });

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'value': value, 'dueDay': dueDay};

  factory FixedExpense.fromJson(Map<String, dynamic> j) => FixedExpense(
        id: j['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: j['name']?.toString() ?? '',
        value: double.tryParse(j['value']?.toString() ?? '0') ?? 0.0,
        dueDay: int.tryParse(j['dueDay']?.toString() ?? '10') ?? 10,
      );
}

class IncomeSource {
  String id;
  String name;
  double value;
  int receiveDay;
  int? receiveMonth; 

  IncomeSource({required this.id, required this.name, required this.value, this.receiveDay = 1, this.receiveMonth});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'value': value, 'receiveDay': receiveDay, 'receiveMonth': receiveMonth};

  factory IncomeSource.fromJson(Map<String, dynamic> j) => IncomeSource(
        id: j['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: j['name']?.toString() ?? '',
        value: double.tryParse(j['value']?.toString() ?? '0') ?? 0.0,
        receiveDay: int.tryParse(j['receiveDay']?.toString() ?? '1') ?? 1,
        receiveMonth: j['receiveMonth'] != null ? int.tryParse(j['receiveMonth'].toString()) : null,
      );
}

class Investment {
  String id;
  String name;
  double amount;
  double yieldRate;
  String type; 

  Investment({required this.id, required this.name, required this.amount, this.yieldRate = 0.0, this.type = 'Renda Fixa'});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'amount': amount, 'yieldRate': yieldRate, 'type': type};

  factory Investment.fromJson(Map<String, dynamic> j) => Investment(
        id: j['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: j['name']?.toString() ?? '',
        amount: double.tryParse(j['amount']?.toString() ?? '0') ?? 0.0,
        yieldRate: double.tryParse(j['yieldRate']?.toString() ?? '0') ?? 0.0,
        type: j['type']?.toString() ?? 'Renda Fixa',
      );
}

const List<String> kCategories = [
  'Alimentação',
  'Transporte',
  'Casa',
  'Saúde',
  'Educação',
  'Lazer',
  'Salário',
  'Fatura',
  'Investimentos',
  'Outros',
];
