import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/data/firestore/constants/app_firestore_collection_constants.dart';
import 'package:neom_core/domain/model/tip.dart';
import 'package:neom_core/utils/neom_error_logger.dart';
import 'package:sint_sentinel/sint_sentinel_core.dart';

import '../../domain/repository/tip_repository.dart';
import '../../utils/tip_message_sanitizer.dart';
import 'wallet_firestore.dart';

class TipFirestore implements TipRepository {
  static const double maxTipAmount = 1000000.0;
  static final RegExp _dunderDocIdRe = RegExp(r'^__.*__$');
  static const Set<String> _prototypePollutionKeys = {
    '__proto__',
    'constructor',
    'prototype',
  };

  static bool isSafeTipPartyId(String raw) => WalletFirestore.isSafeWalletId(raw);

  static String _safeDocSegment(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll('..', '_')
        .replaceAll(
          RegExp(
            r'[/\\\x00-\x1F\x7F-\x9F\u061C\u200B-\u200F\u2028\u2029\u202A-\u202E\u2060\u2066-\u2069\uFEFF\s]+',
          ),
          '_',
        );
    if (cleaned.isEmpty ||
        cleaned == '.' ||
        _dunderDocIdRe.hasMatch(cleaned) ||
        _prototypePollutionKeys.contains(cleaned.toLowerCase())) {
      return 'anon';
    }
    if (cleaned.length <= 48) return cleaned;
    var end = 48;
    final prev = cleaned.codeUnitAt(end - 1);
    if (prev >= 0xD800 && prev <= 0xDBFF) {
      end -= 1;
    }
    return end <= 0 ? 'anon' : cleaned.substring(0, end);
  }

  static bool isValidTip(Tip tip) {
    return tip.amount.isFinite &&
        tip.amount > 0 &&
        tip.amount <= maxTipAmount &&
        isSafeTipPartyId(tip.senderId) &&
        isSafeTipPartyId(tip.recipientId) &&
        tip.senderId.trim().toLowerCase() !=
            tip.recipientId.trim().toLowerCase();
  }

  CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection(
        AppFirestoreCollectionConstants.tips,
      );

  @override
  Future<String> createTip(Tip tip) async {
    if (!isValidTip(tip)) {
      AppConfig.logger.w('Rejected invalid tip payload.');
      return '';
    }
    tip.senderId = tip.senderId.trim();
    tip.recipientId = tip.recipientId.trim();
    tip.message = TipMessageSanitizer.sanitize(tip.message);
    AppConfig.logger.d("Creating tip from ${tip.senderId} to ${tip.recipientId}");

    try {
      tip.createdTime = DateTime.now().millisecondsSinceEpoch;

      if (!isSafeTipPartyId(tip.id) || tip.id.length > 128) {
        tip.id =
            "${_safeDocSegment(tip.senderId)}_${_safeDocSegment(tip.recipientId)}_${tip.createdTime}";
      }

      await SintSentinel.guardWrite(
        () => _collection.doc(tip.id).set(tip.toJSON()),
        tag: 'TipFirestore.createTip',
      );
      AppConfig.logger.i("Tip ${tip.id} created successfully.");
      return tip.id;
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'createTip');
    }

    return '';
  }

  @override
  Future<List<Tip>> getTipsForProfile(String recipientId, {int limit = 20, int? lastCreatedTime}) async {
    if (!isSafeTipPartyId(recipientId)) return [];
    final cleanRecipient = recipientId.trim();
    AppConfig.logger.d("Getting tips for profile: $cleanRecipient");

    List<Tip> tips = [];
    final safeLimit = TipMessageSanitizer.clampLimit(limit, maxLimit: 200);

    try {
      Query query = _collection
          .where('recipientId', isEqualTo: cleanRecipient)
          .orderBy('createdTime', descending: true)
          .limit(safeLimit);

      if (lastCreatedTime != null) {
        query = query.startAfter([lastCreatedTime]);
      }

      QuerySnapshot querySnapshot = await SintSentinel.guard(
        () => query.get(),
        tag: 'TipFirestore.getTipsForProfile',
      );

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        Tip tip = Tip.fromJSON(data as Map<String, dynamic>);
        if (tip.id.isEmpty) tip.id = doc.id;
        tips.add(tip);
      }

      AppConfig.logger.d("${tips.length} tips retrieved for profile $cleanRecipient");
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'getTipsForProfile');
    }

    return tips;
  }

  @override
  Future<List<Tip>> getTipsSentBy(String senderId, {int limit = 20, int? lastCreatedTime}) async {
    if (!isSafeTipPartyId(senderId)) return [];
    final cleanSender = senderId.trim();
    AppConfig.logger.d("Getting tips sent by: $cleanSender");

    List<Tip> tips = [];
    final safeLimit = TipMessageSanitizer.clampLimit(limit, maxLimit: 200);

    try {
      Query query = _collection
          .where('senderId', isEqualTo: cleanSender)
          .orderBy('createdTime', descending: true)
          .limit(safeLimit);

      if (lastCreatedTime != null) {
        query = query.startAfter([lastCreatedTime]);
      }

      QuerySnapshot querySnapshot = await SintSentinel.guard(
        () => query.get(),
        tag: 'TipFirestore.getTipsSentBy',
      );

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        Tip tip = Tip.fromJSON(data as Map<String, dynamic>);
        if (tip.id.isEmpty) tip.id = doc.id;
        tips.add(tip);
      }

      AppConfig.logger.d("${tips.length} tips retrieved sent by $cleanSender");
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'getTipsSentBy');
    }

    return tips;
  }

  @override
  Future<List<Tip>> getTopSupporters(String recipientId, {int limit = 10}) async {
    if (!isSafeTipPartyId(recipientId)) return [];
    final cleanRecipient = recipientId.trim();
    AppConfig.logger.d("Getting top supporters for: $cleanRecipient");

    List<Tip> topSupporters = [];

    try {
      /// Fetch recent tips for this recipient and aggregate client-side by senderId.
      QuerySnapshot querySnapshot = await SintSentinel.guard(
        () => _collection
            .where('recipientId', isEqualTo: cleanRecipient)
            .orderBy('createdTime', descending: true)
            .limit(200)
            .get(),
        tag: 'TipFirestore.getTopSupporters',
      );

      /// Aggregate total amount per sender.
      final safeLimit = TipMessageSanitizer.clampLimit(limit, maxLimit: 200);
      Map<String, Tip> senderMap = {};

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        Tip tip = Tip.fromJSON(data as Map<String, dynamic>);
        if (!tip.amount.isFinite ||
            tip.amount <= 0 ||
            tip.amount > maxTipAmount) {
          continue;
        }
        if (tip.id.isEmpty) tip.id = doc.id;

        if (senderMap.containsKey(tip.senderId)) {
          senderMap[tip.senderId]!.amount += tip.amount;
        } else {
          senderMap[tip.senderId] = tip;
        }
      }

      /// Sort by aggregated amount descending and take top N.
      topSupporters = senderMap.values.toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));

      if (topSupporters.length > safeLimit) {
        topSupporters = topSupporters.sublist(0, safeLimit);
      }

      AppConfig.logger.d("${topSupporters.length} top supporters found for $cleanRecipient");
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'getTopSupporters');
    }

    return topSupporters;
  }

  @override
  Future<double> getTotalTipsReceived(String recipientId) async {
    if (!isSafeTipPartyId(recipientId)) return 0;
    final cleanRecipient = recipientId.trim();
    AppConfig.logger.d("Getting total tips received for: $cleanRecipient");

    double total = 0;

    try {
      QuerySnapshot querySnapshot = await SintSentinel.guard(
        () => _collection
            .where('recipientId', isEqualTo: cleanRecipient)
            .limit(1000)
            .get(),
        tag: 'TipFirestore.getTotalTipsReceived',
      );

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        Tip tip = Tip.fromJSON(data as Map<String, dynamic>);
        if (tip.amount.isFinite &&
            tip.amount > 0 &&
            tip.amount <= maxTipAmount) {
          total += tip.amount;
        }
      }

      AppConfig.logger.d("Total tips received for $cleanRecipient: $total");
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'getTotalTipsReceived');
    }

    return total;
  }

}
