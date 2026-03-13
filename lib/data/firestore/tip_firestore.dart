import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/data/firestore/constants/app_firestore_collection_constants.dart';
import 'package:neom_core/domain/model/tip.dart';

import '../../domain/repository/tip_repository.dart';

class TipFirestore implements TipRepository {

  final _collection = FirebaseFirestore.instance
      .collection(AppFirestoreCollectionConstants.tips);

  @override
  Future<String> createTip(Tip tip) async {
    AppConfig.logger.d("Creating tip from ${tip.senderId} to ${tip.recipientId}");

    try {
      tip.createdTime = DateTime.now().millisecondsSinceEpoch;

      if (tip.id.isEmpty) {
        tip.id = "${tip.senderId}_${tip.recipientId}_${tip.createdTime}";
      }

      await _collection.doc(tip.id).set(tip.toJSON());
      AppConfig.logger.i("Tip ${tip.id} created successfully.");
      return tip.id;
    } catch (e) {
      AppConfig.logger.e("Error creating tip: ${e.toString()}");
    }

    return '';
  }

  @override
  Future<List<Tip>> getTipsForProfile(String recipientId, {int limit = 20, int? lastCreatedTime}) async {
    AppConfig.logger.d("Getting tips for profile: $recipientId");

    List<Tip> tips = [];

    try {
      Query query = _collection
          .where('recipientId', isEqualTo: recipientId)
          .orderBy('createdTime', descending: true)
          .limit(limit);

      if (lastCreatedTime != null) {
        query = query.startAfter([lastCreatedTime]);
      }

      QuerySnapshot querySnapshot = await query.get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        Tip tip = Tip.fromJSON(data as Map<String, dynamic>);
        if (tip.id.isEmpty) tip.id = doc.id;
        tips.add(tip);
      }

      AppConfig.logger.d("${tips.length} tips retrieved for profile $recipientId");
    } catch (e) {
      AppConfig.logger.e("Error getting tips for profile $recipientId: ${e.toString()}");
    }

    return tips;
  }

  @override
  Future<List<Tip>> getTipsSentBy(String senderId, {int limit = 20, int? lastCreatedTime}) async {
    AppConfig.logger.d("Getting tips sent by: $senderId");

    List<Tip> tips = [];

    try {
      Query query = _collection
          .where('senderId', isEqualTo: senderId)
          .orderBy('createdTime', descending: true)
          .limit(limit);

      if (lastCreatedTime != null) {
        query = query.startAfter([lastCreatedTime]);
      }

      QuerySnapshot querySnapshot = await query.get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        Tip tip = Tip.fromJSON(data as Map<String, dynamic>);
        if (tip.id.isEmpty) tip.id = doc.id;
        tips.add(tip);
      }

      AppConfig.logger.d("${tips.length} tips retrieved sent by $senderId");
    } catch (e) {
      AppConfig.logger.e("Error getting tips sent by $senderId: ${e.toString()}");
    }

    return tips;
  }

  @override
  Future<List<Tip>> getTopSupporters(String recipientId, {int limit = 10}) async {
    AppConfig.logger.d("Getting top supporters for: $recipientId");

    List<Tip> topSupporters = [];

    try {
      /// Fetch recent tips for this recipient and aggregate client-side by senderId.
      QuerySnapshot querySnapshot = await _collection
          .where('recipientId', isEqualTo: recipientId)
          .orderBy('createdTime', descending: true)
          .limit(200)
          .get();

      /// Aggregate total amount per sender.
      Map<String, Tip> senderMap = {};

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        Tip tip = Tip.fromJSON(data as Map<String, dynamic>);
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

      if (topSupporters.length > limit) {
        topSupporters = topSupporters.sublist(0, limit);
      }

      AppConfig.logger.d("${topSupporters.length} top supporters found for $recipientId");
    } catch (e) {
      AppConfig.logger.e("Error getting top supporters for $recipientId: ${e.toString()}");
    }

    return topSupporters;
  }

  @override
  Future<double> getTotalTipsReceived(String recipientId) async {
    AppConfig.logger.d("Getting total tips received for: $recipientId");

    double total = 0;

    try {
      QuerySnapshot querySnapshot = await _collection
          .where('recipientId', isEqualTo: recipientId)
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        if (data == null) continue;
        Tip tip = Tip.fromJSON(data as Map<String, dynamic>);
        total += tip.amount;
      }

      AppConfig.logger.d("Total tips received for $recipientId: $total");
    } catch (e) {
      AppConfig.logger.e("Error getting total tips for $recipientId: ${e.toString()}");
    }

    return total;
  }

}
