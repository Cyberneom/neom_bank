import 'dart:async';

import 'package:get/get.dart';
import 'package:neom_commons/utils/constants/message_translation_constants.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/data/firestore/transaction_firestore.dart';
import 'package:neom_core/domain/model/app_transaction.dart';
import 'package:neom_core/utils/enums/transaction_status.dart';
import 'package:neom_core/utils/enums/transaction_type.dart';

import '../../domain/models/wallet.dart';
import '../../utils/constants/bank_constants.dart';
import '../firestore/wallet_firestore.dart';

class AppBankController {

  static final AppBankController _instance = AppBankController._internal();

  factory AppBankController() {
    _instance._init();
    return _instance;
  }

  AppBankController._internal();
  bool _isInitialized = false;

  TransactionStatus transactiontStatus = TransactionStatus.pending;
  Wallet wallet = Wallet();

  /// Inicialización manual para controlar mejor el ciclo de vida
  Future<void> _init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    AppConfig.logger.t('AppBankController Controller Initialization');

    try {

    } catch (e) {
      AppConfig.logger.e(e.toString());
    }
  }

  Future<bool> processTransaction(AppTransaction transaction) async {
    AppConfig.logger.d('Processing transaction: ${transaction.id}');

    try {
      if(BankConstants.userTransactions.contains(transaction.type)
          && (wallet.balance < transaction.amount)) {
        AppConfig.logger.e(MessageTranslationConstants.notEnoughFundsMsg.tr);
        return false;
      }

      if(await WalletFirestore().addTransaction(transaction)) {
        AppConfig.logger.d('Transaction added successfully: ${transaction.id}');
        transaction.status = TransactionStatus.completed;
      } else {
        AppConfig.logger.d('Failed to add transaction: ${transaction.id}');
        transaction.status = TransactionStatus.failed;
      }

      TransactionFirestore().updateStatus(transaction.id, transaction.status);
    } catch (e) {
      AppConfig.logger.e(e.toString());
      return false;
    }


    return transaction.status == TransactionStatus.completed;
  }

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
        if(await WalletFirestore().addTransaction(transaction)) {
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
    } catch (e) {
      AppConfig.logger.e(e.toString());
      return false;
    }

    return transaction.status == TransactionStatus.completed;
  }

}
