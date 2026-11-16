import 'dart:async';

import 'package:flutter/material.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/data/firestore/order_firestore.dart';
import 'package:neom_core/data/firestore/product_firestore.dart';
import 'package:neom_core/data/firestore/transaction_firestore.dart';
import 'package:neom_core/domain/model/app_order.dart';
import 'package:neom_core/domain/model/app_product.dart';
import 'package:neom_core/domain/model/app_transaction.dart';
import 'package:neom_core/domain/model/wallet.dart';
import 'package:neom_core/domain/repository/wallet_repository.dart';
import 'package:neom_core/domain/use_cases/user_service.dart';
import 'package:neom_core/domain/use_cases/wallet_service.dart';
import 'package:neom_core/utils/constants/app_payment_constants.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'package:neom_core/utils/enums/app_currency.dart';
import 'package:neom_core/utils/enums/product_type.dart';
import 'package:neom_core/utils/neom_error_logger.dart';
import 'package:sint/sint.dart';
import 'package:sint_sentinel/sint_sentinel_core.dart';

import '../data/firestore/wallet_firestore.dart';

class WalletController extends SintController implements WalletService  {

  static String _maskEmail(String email) {
    final trimmed = email.trim();
    final at = trimmed.indexOf('@');
    if (at <= 1) return '***';
    return '${trimmed[0]}***${trimmed.substring(at)}';
  }

  final userServiceImpl = Sint.find<UserService>();
  final WalletRepository walletRepository = WalletFirestore();

  RxBool isLoading = true.obs;

  Wallet? wallet;
  Map<String, AppTransaction> transactions = {};
  Map<String, AppOrder> orders = {};

  Rx<AppProduct> appCoinProduct = AppProduct().obs;
  List<AppProduct> appCoinProducts = [];
  List<AppProduct> appCoinStaticProducts = [];
  RxDouble paymentAmount = 0.0.obs;

  Rx<AppCurrency> paymentCurrency = AppCurrency.mxn.obs;

  RxBool isButtonDisabled = false.obs;
  bool sellAppCoins = false;
  bool _isClosed = false;
  
  AppTransaction? transaction;

  @override
  void onInit() {
    super.onInit();
    AppConfig.logger.d("Wallet Controller");
    try {
      transaction?.senderId = userServiceImpl.user.email.trim();
      unawaited(loadWalletInfo());
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'onInit');
      if (!_isClosed) {
        isLoading.value = false;
      }
    }
  }


  @override
  void onReady() {
    super.onReady();
  }

  @override
  void onClose() {
    _isClosed = true;
    isLoading.close();
    appCoinProduct.close();
    paymentAmount.close();
    paymentCurrency.close();
    isButtonDisabled.close();
    super.onClose();
  }

  Future<void> loadWalletInfo() async {
    final ownerEmail = userServiceImpl.user.email.trim();
    AppConfig.logger.d("Loading Wallet Info for ${_maskEmail(ownerEmail)}");

    try {
      if (ownerEmail.isNotEmpty) {
        await loadWallet();
        await loadTransactions();
        await loadOrders();
      }
      //TODO await loadCoinProducts();
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'loadWalletInfo');
    } finally {
      if (!_isClosed) {
        isLoading.value = false;
        update([AppPageIdConstants.walletHistory]);
      }
    }
  }

  Future<void> loadWallet() async {
    final ownerEmail = userServiceImpl.user.email.trim();
    AppConfig.logger.t("Loading Wallet for ${_maskEmail(ownerEmail)}");
    wallet = await SintSentinel.guard(
      () => walletRepository.getOrCreate(ownerEmail),
      tag: 'WalletController.loadWallet',
    );
  }

  Future<void> loadTransactions() async {
    final ownerEmail = userServiceImpl.user.email.trim();
    AppConfig.logger.d("Loading Transactions for ${_maskEmail(ownerEmail)}");

    final fetched = await SintSentinel.guard(
      () => TransactionFirestore().retrieveByEmail(ownerEmail),
      tag: 'WalletController.loadTransactions',
    );
    List<AppTransaction> transactionsToSort = fetched.values.toList();
    transactionsToSort.sort((a, b) => a.createdTime.compareTo(b.createdTime));
    transactions.clear();
    for(AppTransaction transaction in transactionsToSort.reversed) {
      transactions[transaction.id] = transaction;
    }
  }

  Future<void> loadOrders() async {
    final ownerEmail = userServiceImpl.user.email.trim();
    AppConfig.logger.d("Loading Orders for ${_maskEmail(ownerEmail)}");

    final fetched = await SintSentinel.guard(
      () => OrderFirestore().retrieveFromList(userServiceImpl.user.orderIds),
      tag: 'WalletController.loadOrders',
    );
    List<AppOrder> ordersToSort = fetched.values.toList();
    ordersToSort.sort((a, b) => a.createdTime.compareTo(b.createdTime));
    orders.clear();
    for(AppOrder order in ordersToSort.reversed) {
      orders[order.id] = order;
    }
  }

  Future<void> loadCoinProducts() async {
    final fetched = await SintSentinel.guard(
      () => ProductFirestore().retrieveProductsByType(type: ProductType.appCoin),
      tag: 'WalletController.loadCoinProducts',
    );
    appCoinProducts = List<AppProduct>.from(fetched);
    appCoinStaticProducts = List<AppProduct>.from(fetched);

    if(appCoinProducts.isNotEmpty) {
      appCoinProducts.sort((a, b) => a.qty.compareTo(b.qty));
      appCoinProduct.value = appCoinProducts.first;

      paymentCurrency.value = appCoinProduct.value.salePrice?.currency ?? AppCurrency.mxn;
      paymentAmount.value = appCoinProduct.value.salePrice?.amount ?? 0;
    }
  }


  @override
  void changeAppCoinProduct(AppProduct selectedProduct) {
    AppConfig.logger.d("Changing appCoin Qty to acquire to ${selectedProduct.qty}");

    // newGigCoinProduct = gigCoinProducts.where(
    //         (product) => product.id == newGigCoinProduct.id).first;
    
    try {
      appCoinProduct.value = selectedProduct;
      final regularCurrency = appCoinProduct.value.regularPrice?.currency;
      final saleAmt = appCoinProduct.value.salePrice?.amount;
      if (regularCurrency != null && regularCurrency != paymentCurrency.value) {
        setActualCurrency(productCurrency: regularCurrency);
      } else if (saleAmt != null) {
        changePaymentAmount(newAmount: saleAmt);
      }
      //gigCoinProduct = selectedProduct;


      appCoinProducts.removeWhere((product) => product.id == appCoinProduct.value.id);
      appCoinProducts.add(appCoinProduct.value);
      appCoinProducts.sort((a, b) => a.qty.compareTo(b.qty));
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'changeAppCoinProduct');
    }

    update([AppPageIdConstants.walletHistory]);
  }

  @override
  void setActualCurrency({required AppCurrency productCurrency}) {

    try {

      if(productCurrency != paymentCurrency.value) {
        AppConfig.logger.d("Changing currency of product from ${productCurrency.name} to $paymentCurrency");
        appCoinProduct.value.regularPrice?.currency = paymentCurrency.value;
        appCoinProduct.value.salePrice?.currency = paymentCurrency.value;
        changePaymentAmount();
      } else {
        AppConfig.logger.d("Product Currency is the same one as actual: $paymentCurrency");
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'setActualCurrency');
    }

    update([AppPageIdConstants.walletHistory]);
  }

  @override
  void changePaymentCurrency({required AppCurrency newCurrency}) {

    try {

      if(newCurrency != paymentCurrency.value) {
        AppConfig.logger.d("Changing currency from $paymentCurrency to ${newCurrency.name}");
        paymentCurrency.value = newCurrency;
        appCoinProduct.value.regularPrice?.currency = paymentCurrency.value;
        appCoinProduct.value.salePrice?.currency = paymentCurrency.value;
        changePaymentAmount();
      } else {
        AppConfig.logger.d("Payment Currency is the same one: $paymentCurrency");
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'changePaymentCurrency');
    }

    update([AppPageIdConstants.walletHistory]);
  }

  @override
  void changePaymentAmount({double newAmount = 0}) {

    bool amountChanged = false;

    double newRegularAmount = 0.0;
    double newSaleAmount = 0.0;

    try {
      if(paymentAmount.value != newAmount) {
        AppConfig.logger.d("Changing paymentAmount from $paymentAmount");
        final baseProduct = appCoinStaticProducts
            .where((product) => product.id == appCoinProduct.value.id)
            .firstOrNull;
        if (baseProduct?.regularPrice == null || baseProduct?.salePrice == null) {
          if (newAmount.isFinite && newAmount >= 0) {
            paymentAmount.value = newAmount;
          }
          update([AppPageIdConstants.walletHistory]);
          return;
        }
        double originalRegularAmount = baseProduct!.regularPrice!.amount;
        double originalSaleAmount = baseProduct.salePrice!.amount;
        AppConfig.logger.d("Original regular amount $originalRegularAmount & Original sale amount $originalSaleAmount");
        switch(paymentCurrency.value) {
          case (AppCurrency.usd):
            newRegularAmount = originalRegularAmount
                * AppPaymentConstants.mxnToUsd;
            newSaleAmount = originalSaleAmount
                * AppPaymentConstants.mxnToUsd;
            amountChanged = true;
            break;
          case (AppCurrency.eur):
            newRegularAmount = originalRegularAmount
                * AppPaymentConstants.mxnToEur;
            newSaleAmount = originalSaleAmount
                * AppPaymentConstants.mxnToEur;
            amountChanged = true;
            break;
          case (AppCurrency.mxn):
            newRegularAmount = originalRegularAmount;
            newSaleAmount = originalSaleAmount;
            amountChanged = true;
            break;
          case (AppCurrency.gbp):
            newRegularAmount = originalRegularAmount
                * AppPaymentConstants.mxnToGbp;
            newSaleAmount = originalSaleAmount
                * AppPaymentConstants.mxnToGbp;
            amountChanged = true;
            break;
          case (AppCurrency.appCoin):
            break;
        }

        if(amountChanged) {
          newSaleAmount = newSaleAmount.ceilToDouble();
          newRegularAmount = newRegularAmount.ceilToDouble();
          paymentAmount.value = newSaleAmount;
          appCoinProduct.value.regularPrice?.amount = newRegularAmount;
          appCoinProduct.value.salePrice?.amount = newSaleAmount;
        }
      } else {
        AppConfig.logger.d("Payment amount is the same one: $paymentAmount");
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'changePaymentAmount');
    }

    update([AppPageIdConstants.walletHistory]);
  }


  @override
  Future<void> payAppProduct(BuildContext context) async {
    AppConfig.logger.d("Entering payAppProduct Method");

    try {
      if (appCoinProduct.value.salePrice != null &&
          paymentAmount.value.isFinite &&
          paymentAmount.value > 0) {
        appCoinProduct.value.salePrice!.amount = paymentAmount.value;
        appCoinProduct.value.salePrice!.currency = paymentCurrency.value;
        Sint.toNamed(AppRouteConstants.orderConfirmation, arguments: [appCoinProduct.value]);
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_bank', operation: 'payAppProduct');
    }

    update([AppPageIdConstants.walletHistory]);
  }


}
