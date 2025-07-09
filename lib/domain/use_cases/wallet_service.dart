import 'package:flutter/material.dart';
import 'package:neom_core/domain/model/app_product.dart';
import 'package:neom_core/utils/enums/app_currency.dart';

abstract class WalletService {

  void changeAppCoinProduct(AppProduct selectedProduct);
  void setActualCurrency({required AppCurrency productCurrency});
  void changePaymentCurrency({required AppCurrency newCurrency});
  void changePaymentAmount({double newAmount = 0});
  Future<void> payAppProduct(BuildContext context);

}
