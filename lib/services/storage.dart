import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';
import 'package:flutter/foundation.dart';

class Storage {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;


  static String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  // TRANSAÇÕES
  static Future<List<Transaction>> loadTransactions([String? targetUid]) async {
    final uid = targetUid ?? currentUid ?? 'visitante';
    try {
      final doc = await _db.collection('users').doc(uid).collection('data').doc('transactions').get();
      if (!doc.exists) return [];
      final list = doc.data()?['list'] as List? ?? [];
      return list.map((e) => Transaction.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      debugPrint('🚨 ERRO AO CARREGAR TRANSAÇÕES (UID: $uid): $e');
      return [];
    }
  }

  static Future<void> saveTransactions(List<Transaction> list, [String? targetUid]) async {
    final uid = targetUid ?? currentUid ?? 'visitante';
    try {
      await _db.collection('users').doc(uid).collection('data').doc('transactions').set({
        'list': list.map((t) => t.toJson()).toList()
      });
      debugPrint('✅ TRANSAÇÕES SALVAS COM SUCESSO (UID: $uid)');
    } catch (e) {
      debugPrint('🚨 ERRO AO SALVAR TRANSAÇÕES (UID: $uid): $e');
    }
  }

  // FONTES DE RENDA
  static Future<List<IncomeSource>> loadIncomes([String? targetUid]) async {
    final uid = targetUid ?? currentUid ?? 'visitante';
    try {
      final doc = await _db.collection('users').doc(uid).collection('data').doc('incomes').get();
      if (!doc.exists) return [];
      final list = doc.data()?['list'] as List? ?? [];
      return list.map((e) => IncomeSource.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      debugPrint('🚨 ERRO AO CARREGAR PROVENTOS (UID: $uid): $e');
      return [];
    }
  }

  static Future<void> saveIncomes(List<IncomeSource> list, [String? targetUid]) async {
    final uid = targetUid ?? currentUid ?? 'visitante';
    try {
      await _db.collection('users').doc(uid).collection('data').doc('incomes').set({
        'list': list.map((e) => e.toJson()).toList()
      });
    } catch (e) {
      debugPrint('🚨 ERRO AO SALVAR PROVENTOS (UID: $uid): $e');
    }
  }

  // INVESTIMENTOS
  static Future<List<Investment>> loadInvestments([String? targetUid]) async {
    final uid = targetUid ?? currentUid ?? 'visitante';
    try {
      final doc = await _db.collection('users').doc(uid).collection('data').doc('investments').get();
      if (!doc.exists) return [];
      final list = doc.data()?['list'] as List? ?? [];
      return list.map((e) => Investment.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      debugPrint('🚨 ERRO AO CARREGAR INVESTIMENTOS (UID: $uid): $e');
      return [];
    }
  }

  static Future<void> saveInvestments(List<Investment> list, [String? targetUid]) async {
    final uid = targetUid ?? currentUid ?? 'visitante';
    try {
      await _db.collection('users').doc(uid).collection('data').doc('investments').set({
        'list': list.map((e) => e.toJson()).toList()
      });
    } catch (e) {
      debugPrint('🚨 ERRO AO SALVAR INVESTIMENTOS (UID: $uid): $e');
    }
  }

  // CONTAS FIXAS
  static Future<List<FixedExpense>> loadFixed([String? targetUid]) async {
    final uid = targetUid ?? currentUid ?? 'visitante';
    try {
      final doc = await _db.collection('users').doc(uid).collection('data').doc('fixed').get();
      if (!doc.exists) return [];
      final list = doc.data()?['list'] as List? ?? [];
      return list.map((e) => FixedExpense.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      debugPrint('🚨 ERRO AO CARREGAR CONTAS FIXAS (UID: $uid): $e');
      return [];
    }
  }

  static Future<void> saveFixed(List<FixedExpense> list, [String? targetUid]) async {
    final uid = targetUid ?? currentUid ?? 'visitante';
    try {
      await _db.collection('users').doc(uid).collection('data').doc('fixed').set({
        'list': list.map((e) => e.toJson()).toList()
      });
    } catch (e) {
      debugPrint('🚨 ERRO AO SALVAR CONTAS FIXAS (UID: $uid): $e');
    }
  }

  // CONFIGURAÇÕES
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('first_launch') ?? true;
  }

  static Future<void> setFirstLaunchDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_launch', false);
  }
}