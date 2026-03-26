import 'package:neom_core/app_config.dart';
import 'package:neom_core/utils/neom_error_logger.dart';
import 'package:neom_core/data/firestore/transaction_firestore.dart';
import 'package:neom_core/domain/model/app_transaction.dart';
import 'package:neom_core/domain/model/tip.dart';
import 'package:neom_core/domain/use_cases/bank_service.dart';
import 'package:neom_core/domain/use_cases/tip_service.dart';
import 'package:neom_core/domain/use_cases/user_service.dart';
import 'package:neom_core/utils/enums/app_currency.dart';
import 'package:neom_core/utils/enums/tip_tier.dart';
import 'package:neom_core/utils/enums/transaction_status.dart';
import 'package:neom_core/utils/enums/transaction_type.dart';
import 'package:sint/sint.dart';

import '../firestore/tip_firestore.dart';

/// Tip controller implementing [TipService] for tip processing.
///
/// Handles sending tips between users, including balance validation,
/// transaction creation, and wallet debit/credit operations.
class TipController extends SintController implements TipService {

  final TipFirestore _tipFirestore = TipFirestore();
  final TransactionFirestore _transactionFirestore = TransactionFirestore();

  final topSupporters = <Tip>[].obs;
  final isLoading = false.obs;

  @override
  Future<bool> sendTip({
    required String recipientId,
    required TipTier tier,
    String? message,
    String? contextType,
    String? contextId,
  }) async {
    AppConfig.logger.d("Sending ${tier.name} tip to $recipientId");

    try {
      isLoading.value = true;

      /// Get current user info via UserService.
      final UserService userService = Sint.find<UserService>();
      final currentUser = userService.user;
      final currentProfile = userService.profile;

      if (currentUser.email.isEmpty) {
        AppConfig.logger.e("Cannot send tip: user email is empty.");
        return false;
      }

      /// Get BankService to process the transaction.
      final BankService bankService = Sint.find<BankService>();

      /// Validate sender has enough balance.
      final double tipAmount = tier.coins.toDouble();

      /// Create the Tip model.
      final int now = DateTime.now().millisecondsSinceEpoch;
      final Tip tip = Tip(
        senderId: currentProfile.id,
        senderName: currentProfile.name,
        senderAvatarUrl: currentProfile.photoUrl,
        recipientId: recipientId,
        tier: tier,
        amount: tipAmount,
        message: message,
        contextType: contextType,
        contextId: contextId,
        createdTime: now,
      );

      /// Create AppTransaction for the tip.
      AppTransaction transaction = AppTransaction(
        amount: tipAmount,
        type: TransactionType.tip,
        senderId: currentUser.email,
        recipientId: recipientId,
        description: 'Tip: ${tier.name} (${tier.coins} coins)',
        currency: AppCurrency.appCoin,
        status: TransactionStatus.pending,
        createdTime: now,
      );

      /// Insert transaction record first.
      transaction.id = await _transactionFirestore.insert(transaction);

      if (transaction.id.isEmpty) {
        AppConfig.logger.e("Failed to create transaction record for tip.");
        return false;
      }

      /// Process the transaction (debit sender, credit recipient).
      final bool transactionSuccess = await bankService.processTransaction(transaction);

      if (!transactionSuccess) {
        AppConfig.logger.e("Tip transaction failed for ${transaction.id}");
        return false;
      }

      /// Create the tip record in Firestore.
      final String tipId = await _tipFirestore.createTip(tip);

      if (tipId.isEmpty) {
        AppConfig.logger.e("Failed to create tip record. Transaction ${transaction.id} was processed.");
        return false;
      }

      AppConfig.logger.i("Tip $tipId sent successfully. Transaction: ${transaction.id}");
      return true;
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'sendTip');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Future<List<Tip>> getTopSupporters(String recipientId, {int limit = 10}) async {
    AppConfig.logger.d("Getting top supporters for $recipientId");

    try {
      isLoading.value = true;
      final supporters = await _tipFirestore.getTopSupporters(recipientId, limit: limit);
      topSupporters.assignAll(supporters);
      return supporters;
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'getTopSupporters');
      return [];
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Future<List<Tip>> getTipsForProfile(String recipientId, {int limit = 20}) async {
    AppConfig.logger.d("Getting tips for profile $recipientId");

    try {
      isLoading.value = true;
      return await _tipFirestore.getTipsForProfile(recipientId, limit: limit);
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'getTipsForProfile');
      return [];
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Future<List<Tip>> getTipsSentBy(String senderId, {int limit = 20}) async {
    AppConfig.logger.d("Getting tips sent by $senderId");

    try {
      isLoading.value = true;
      return await _tipFirestore.getTipsSentBy(senderId, limit: limit);
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'getTipsSentBy');
      return [];
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Future<double> getTotalTipsReceived(String recipientId) async {
    AppConfig.logger.d("Getting total tips received for $recipientId");

    try {
      return await _tipFirestore.getTotalTipsReceived(recipientId);
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'getTotalTipsReceived');
      return 0;
    }
  }

}
