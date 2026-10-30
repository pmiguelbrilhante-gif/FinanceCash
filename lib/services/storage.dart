import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import 'package:flutter/foundation.dart';

class Storage {
  // Conecta ao banco de dados na nuvem
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  
  // Identifica quem está usando
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'visitante';

  
  // TRANSAÇÕES
  static Future<List<Transaction>> loadTransactions() async {
    try {
      final doc = await _db.collection('users').doc(_uid).collection('data').doc('transactions').get();
      if (!doc.exists) return [];
      final list = doc.data()?['list'] as List? ?? [];
      return list.map((e) => Transaction.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      debugPrint('🚨 ERRO AO CARREGAR: $e'); 
      return [];
    }
  }

  static Future<void> saveTransactions(List<Transaction> list) async {
    await _db.collection('users').doc(_uid).collection('data').doc('transactions').set({
      'list': list.map((t) => t.toJson()).toList()
    });
  }

  static Future<void> addTransaction(Transaction tx) async {
    final list = await loadTransactions();
    list.insert(0, tx);
    await saveTransactions(list);
  }


  // FONTES DE RENDA (PROVENTOS)
  static Future<List<IncomeSource>> loadIncomes() async {
    try {
      final doc = await _db.collection('users').doc(_uid).collection('data').doc('incomes').get();
      if (!doc.exists) return [];
      final list = doc.data()?['list'] as List? ?? [];
      return list.map((e) => IncomeSource.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      debugPrint('🚨 ERRO AO CARREGAR: $e'); 
      return [];
    }
  }

  static Future<void> saveIncomes(List<IncomeSource> list) async {
    await _db.collection('users').doc(_uid).collection('data').doc('incomes').set({
      'list': list.map((e) => e.toJson()).toList()
    });
  }


  // INVESTIMENTOS
  static Future<List<Investment>> loadInvestments() async {
    try {
      final doc = await _db.collection('users').doc(_uid).collection('data').doc('investments').get();
      if (!doc.exists) return [];
      final list = doc.data()?['list'] as List? ?? [];
      return list.map((e) => Investment.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      debugPrint('🚨 ERRO AO CARREGAR: $e'); 
      return [];
    }
  }

  static Future<void> saveInvestments(List<Investment> list) async {
    await _db.collection('users').doc(_uid).collection('data').doc('investments').set({
      'list': list.map((e) => e.toJson()).toList()
    });
  }

 
  // CONTAS FIXAS
  static Future<List<FixedExpense>> loadFixed() async {
    try {
      final doc = await _db.collection('users').doc(_uid).collection('data').doc('fixed').get();
      if (!doc.exists) return [];
      final list = doc.data()?['list'] as List? ?? [];
      return list.map((e) => FixedExpense.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      debugPrint('🚨 ERRO AO CARREGAR: $e'); 
      return [];
    }
  }

  static Future<void> saveFixed(List<FixedExpense> list) async {
    await _db.collection('users').doc(_uid).collection('data').doc('fixed').set({
      'list': list.map((e) => e.toJson()).toList()
    });
  }

  
  // CONFIGURAÇÕES LOCAIS (ONBOARDING)
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('first_launch') ?? true;
  }

  static Future<void> setFirstLaunchDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_launch', false);
  }
}