import 'package:neom_core/domain/model/tip.dart';

abstract class TipRepository {

  Future<String> createTip(Tip tip);
  Future<List<Tip>> getTipsForProfile(String recipientId, {int limit = 20, int? lastCreatedTime});
  Future<List<Tip>> getTipsSentBy(String senderId, {int limit = 20, int? lastCreatedTime});
  Future<List<Tip>> getTopSupporters(String recipientId, {int limit = 10});
  Future<double> getTotalTipsReceived(String recipientId);

}
