import 'dart:async';

import 'package:neom_commons/utils/constants/translations/message_translation_constants.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/data/api/app_platform_api.dart';
import 'package:neom_core/utils/neom_error_logger.dart';
import 'package:neom_core/data/firestore/transaction_firestore.dart';
import 'package:neom_core/domain/model/app_transaction.dart';
import 'package:neom_core/domain/model/wallet.dart';
import 'package:neom_core/domain/repository/wallet_repository.dart';
import 'package:neom_core/domain/use_cases/bank_service.dart';
import 'package:neom_core/domain/use_cases/user_service.dart';
import 'package:neom_core/utils/enums/transaction_status.dart';
import 'package:neom_core/utils/enums/transaction_type.dart';
import 'package:sint/sint.dart';

import '../../utils/constants/bank_constants.dart';
import '../firestore/wallet_firestore.dart';

/// Bank controller implementing [BankService] for transaction processing.
///
/// Uses repository pattern for wallet operations, enabling easier testing
/// and potential backend changes without affecting business logic.
class BankController implements BankService {

  static final BankController _instance = BankController._internal();

  factory BankController() {
    _instance.init();
    return _instance;
  }

  BankController._internal();
  bool _isInitialized = false;

  /// Repository for wallet operations (injectable for testing)
  final WalletRepository _walletRepository = WalletFirestore();

  TransactionStatus transactiontStatus = TransactionStatus.pending;
  Wallet wallet = Wallet();

  @override
  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    AppConfig.logger.t('AppBankController Controller Initialization');

    try {
      if (Sint.isRegistered<UserService>()) {
        final email = Sint.find<UserService>().user.email;
        if (email.isNotEmpty) {
          final loaded = await _walletRepository.getOrCreate(email);
          if (loaded != null) {
            wallet = loaded;
          }
        }
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'init');
    }
  }

  @override
  Future<bool> processTransaction(AppTransaction transaction) async {
    AppConfig.logger.d('Processing transaction: ${transaction.id}');

    try {
      final senderKey = (transaction.senderId?.isNotEmpty ?? false)
          ? transaction.senderId!
          : (Sint.isRegistered<UserService>() ? Sint.find<UserService>().user.email : wallet.id);
      if (senderKey.isNotEmpty) {
        final refreshed = await _walletRepository.getOrCreate(senderKey);
        if (refreshed != null) {
          wallet = refreshed;
        }
      }

      if(BankConstants.userTransactions.contains(transaction.type)
          && (wallet.balance < transaction.amount)) {
        AppConfig.logger.e(MessageTranslationConstants.notEnoughFundsMsg.tr);
        return false;
      }

      if(await _walletRepository.addTransaction(transaction)) {
        AppConfig.logger.d('Transaction added successfully: ${transaction.id}');
        transaction.status = TransactionStatus.completed;
        if (BankConstants.userTransactions.contains(transaction.type)) {
          wallet.balance = (wallet.balance - transaction.amount).clamp(0.0, double.infinity);
        }
      } else {
        AppConfig.logger.d('Failed to add transaction: ${transaction.id}');
        transaction.status = TransactionStatus.failed;
      }

      if (!AppPlatformApi.isEnabled && transaction.id.isNotEmpty) {
        TransactionFirestore().updateStatus(transaction.id, transaction.status);
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'processTransaction');
      return false;
    }

    return transaction.status == TransactionStatus.completed;
  }

  @override
  Future<bool> addCoinsToWallet(String walletId, double amount, {TransactionType transactionType = TransactionType.purchase}) async {
    AppConfig.logger.d('Adding $amount coins to wallet: $walletId');

    AppTransaction transaction = AppTransaction(
      amount: amount,
      recipientId: walletId,
      type: transactionType,
    );

    try {
      transaction.id = await TransactionFirestore().insert(transaction);
      if(transaction.amount > 0) {
        if(await _walletRepository.addTransaction(transaction)) {
          AppConfig.logger.d('Coins added to wallet: $walletId');
          transaction.status = TransactionStatus.completed;
        } else {
          AppConfig.logger.e('Failed to add coins to wallet: $walletId');
          transaction.status = TransactionStatus.failed;
        }
        TransactionFirestore().updateStatus(transaction.id, transaction.status);
      } else {
        return false;
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'addCoinsToWallet');
      return false;
    }

    return transaction.status == TransactionStatus.completed;
  }

}
