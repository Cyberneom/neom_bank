import 'package:flutter/material.dart';
import 'package:sint/sint.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/data/firestore/order_firestore.dart';
import 'package:neom_core/data/firestore/product_firestore.dart';
import 'package:neom_core/data/firestore/transaction_firestore.dart';
import 'package:neom_core/domain/model/app_order.dart';
import 'package:neom_core/domain/model/app_product.dart';
import 'package:neom_core/domain/model/app_transaction.dart';
import 'package:neom_core/domain/model/wallet.dart';
import 'package:neom_core/domain/use_cases/user_service.dart';
import 'package:neom_core/domain/use_cases/wallet_service.dart';
import 'package:neom_core/utils/constants/app_payment_constants.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'package:neom_core/utils/enums/app_currency.dart';
import 'package:neom_core/utils/enums/product_type.dart';

import 'package:neom_core/domain/repository/wallet_repository.dart';
import '../data/firestore/wallet_firestore.dart';

class WalletController extends SintController implements WalletService  {

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
  
  AppTransaction? transaction;

  @override
  void onInit() async {
    super.onInit();
    AppConfig.logger.d("Wallet Controller");
    try {
      loadWalletInfo();
      // loadOrders();
      transaction?.senderId = userServiceImpl.user.email;
    } catch (e) {
      AppConfig.logger.e(e);
    }

  }


  @override
  void onReady() async {
    try {
    } catch (e) {
      AppConfig.logger.e(e.toString());
    }
  }

  Future<void> loadWalletInfo() async {
    AppConfig.logger.d("Loading Wallet Info for ${userServiceImpl.user.email}");

    try {
      await loadWallet();
      await loadTransactions();
      await loadOrders();
      //TODO await loadCoinProducts();

    } catch (e) {
      AppConfig.logger.e(e.toString());
    }

    isLoading.value = false;
    update([AppPageIdConstants.walletHistory]);
  }
  Future<void> loadWallet() async {
    AppConfig.logger.t("Loading Wallet for ${userServiceImpl.user.email}");
    wallet = await walletRepository.getOrCreate(userServiceImpl.user.email);
  }

  Future<void> loadTransactions() async {
    AppConfig.logger.d("Loading Transactions for ${userServiceImpl.user.email}");

    transactions = await TransactionFirestore().retrieveByEmail(userServiceImpl.user.email);
    List<AppTransaction> transactionsToSort = transactions.values.toList();
    transactionsToSort.sort((a, b) => a.createdTime.compareTo(b.createdTime));
    transactions.clear();
    for(AppTransaction transaction in transactionsToSort.reversed) {
      transactions[transaction.id] = transaction;
    }
  }

  Future<void> loadOrders() async {
    AppConfig.logger.d("Loading Orders for ${userServiceImpl.user.email}");

    orders = await OrderFirestore().retrieveFromList(userServiceImpl.user.orderIds);
    List<AppOrder> ordersToSort = orders.values.toList();
    ordersToSort.sort((a, b) => a.createdTime.compareTo(b.createdTime));
    orders.clear();
    for(AppOrder order in ordersToSort.reversed) {
      orders[order.id] = order;
    }
  }

  Future<void> loadCoinProducts() async {
    appCoinProducts = await ProductFirestore()
        .retrieveProductsByType(type: ProductType.appCoin);

    appCoinStaticProducts =  await ProductFirestore()
        .retrieveProductsByType(type: ProductType.appCoin);

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
      if(appCoinProduct.value.regularPrice!.currency != paymentCurrency.value) {
        // selectedProduct = gigCoinStaticProducts.where(
        //         (product) => product.id == selectedProduct.id).first;
        setActualCurrency(productCurrency: appCoinProduct.value.regularPrice!.currency);
      } else {
        changePaymentAmount(newAmount: appCoinProduct.value.salePrice!.amount);
      }
      //gigCoinProduct = selectedProduct;


      appCoinProducts.removeWhere((product) => product.id == appCoinProduct.value.id);
      appCoinProducts.add(appCoinProduct.value);
      appCoinProducts.sort((a, b) => a.qty.compareTo(b.qty));
    } catch (e) {
      AppConfig.logger.e(e.toString());
    }

    update([AppPageIdConstants.walletHistory]);
  }

  @override
  void setActualCurrency({required AppCurrency productCurrency}) {

    try {

      if(productCurrency != paymentCurrency.value) {
        AppConfig.logger.d("Changing currency of product from ${productCurrency.name} to $paymentCurrency");
        appCoinProduct.value.regularPrice!.currency = paymentCurrency.value;
        appCoinProduct.value.salePrice!.currency = paymentCurrency.value;
        changePaymentAmount();
      } else {
        AppConfig.logger.d("Product Currency is the same one as actual: $paymentCurrency");
      }
    } catch (e) {
      AppConfig.logger.e(e.toString());
    }

    update([AppPageIdConstants.walletHistory]);
  }

  @override
  void changePaymentCurrency({required AppCurrency newCurrency}) {

    try {

      if(newCurrency != paymentCurrency.value) {
        AppConfig.logger.d("Changing currency from $paymentCurrency to ${newCurrency.name}");
        paymentCurrency.value = newCurrency;
        appCoinProduct.value.regularPrice!.currency = paymentCurrency.value;
        appCoinProduct.value.salePrice!.currency = paymentCurrency.value;
        changePaymentAmount();
      } else {
        AppConfig.logger.d("Payment Currency is the same one: $paymentCurrency");
      }
    } catch (e) {
      AppConfig.logger.e(e.toString());
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
        double originalRegularAmount = appCoinStaticProducts.where(
                (product) => product.id == appCoinProduct.value.id).first.regularPrice!.amount;
        double originalSaleAmount = appCoinStaticProducts.where(
                (product) => product.id == appCoinProduct.value.id).first.salePrice!.amount;
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
          AppConfig.logger.d("Actual regular amount ${appCoinProduct.value.regularPrice!.amount}"
              " & Actual sale amount ${appCoinProduct.value.salePrice!.amount}");
          AppConfig.logger.d("New regular amount $newRegularAmount & New sale amount $newSaleAmount");
          appCoinProduct.value.regularPrice!.amount = newRegularAmount;
          appCoinProduct.value.salePrice!.amount = newSaleAmount;
        }
      } else {
        AppConfig.logger.d("Payment amount is the same one: $paymentAmount");
      }
    } catch (e) {
      AppConfig.logger.e(e.toString());
    }

    update([AppPageIdConstants.walletHistory]);
  }


  @override
  Future<void> payAppProduct(BuildContext context) async {
    AppConfig.logger.d("Entering payAppProduct Method");

    try {
      appCoinProduct.value.salePrice!.amount = paymentAmount.value;
      appCoinProduct.value.salePrice!.currency = paymentCurrency.value;
      Sint.toNamed(AppRouteConstants.orderConfirmation, arguments: [appCoinProduct.value]);
    } catch (e) {
      AppConfig.logger.e(e.toString());
    }

    update([AppPageIdConstants.walletHistory]);
  }


}
