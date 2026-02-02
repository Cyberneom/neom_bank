import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:sint/sint.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/utils/constants/translations/common_translation_constants.dart';
import 'package:neom_core/domain/model/app_product.dart';
import 'package:neom_core/utils/core_utilities.dart';
import 'package:neom_core/utils/enums/app_currency.dart';
import 'package:rflutter_alert/rflutter_alert.dart';

import '../../utils/constants/bank_translation_constants.dart';
import '../wallet_controller.dart';

void showGetAppCoinsAlert(BuildContext context, WalletController controller) {
  Alert(
      context: context,
      style: AlertStyle(
          backgroundColor: AppColor.main50,
          titleStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          titleTextAlign: TextAlign.justify
      ),
      title: BankTranslationConstants.acquireAppCoinsMsg.tr,
      content: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${BankTranslationConstants.appCoinsToAcquire.tr}:",
                style: const TextStyle(fontSize: 15),
              ),
              Obx(()=> DropdownButton<AppProduct>(
                items: controller.appCoinProducts.map((AppProduct product) {
                  return DropdownMenuItem<AppProduct>(
                    value: product,
                    child: Text(product.qty.toString()),
                  );
                }).toList(),
                onChanged: (AppProduct? newProduct) {
                  controller.changeAppCoinProduct(newProduct!);
                },
                value: controller.appCoinProduct.value,
                alignment: Alignment.center,
                icon: const Icon(Icons.arrow_downward),
                iconSize: 20,
                elevation: 16,
                style: const TextStyle(color: Colors.white),
                dropdownColor: AppColor.main75,
                underline: Container(
                  height: 1,
                  color: Colors.grey,
                ),
              ),),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${CommonTranslationConstants.paymentCurrency.tr}: ",
                style: const TextStyle(fontSize: 15),
              ),
              Obx(()=> DropdownButton<String>(
                items: AppCurrency.values.getRange(0, 1).map((AppCurrency currency) {
                  return DropdownMenuItem<String>(
                    value: currency.name,
                    child: Text(currency.name.toUpperCase()),
                  );
                }).where((currency) => currency.value != AppCurrency.appCoin.name)
                    .toList(),
                onChanged: (String? paymentCurrencyStr) {
                  controller.changePaymentCurrency(newCurrency:
                  EnumToString.fromString(AppCurrency.values, paymentCurrencyStr ?? AppCurrency.mxn.name)
                      ?? AppCurrency.mxn
                  );
                },
                value: controller.paymentCurrency.value.name,
                alignment: Alignment.center,
                icon: const Icon(Icons.arrow_downward),
                iconSize: 20,
                elevation: 16,
                style: const TextStyle(color: Colors.white),
                dropdownColor: AppColor.main75,
                underline: Container(
                  height: 1,
                  color: Colors.grey,
                ),
              ),
              ),
            ],
          ),
          Obx(()=> Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${CommonTranslationConstants.totalToPay.tr.capitalizeFirst}:",
                style: const TextStyle(fontSize: 15),
              ),
              Row(
                children: [
                  Text("${CoreUtilities.getCurrencySymbol(controller.paymentCurrency.value)} ${controller.paymentAmount.value}",
                    style: const TextStyle(fontSize: 15),
                  ),
                ],
              ),
            ],
          ),
          ),
        ],
      ),
      buttons: [
        DialogButton(
          color: AppColor.bondiBlue75,
          onPressed: () async {
            if(!controller.isButtonDisabled.value) {
              await controller.payAppProduct(context);
            }
          },
          child: Obx(()=> controller.isLoading.value
              ? const Center(child: CircularProgressIndicator())
              : Text(BankTranslationConstants.proceedToOrder.tr,
            style: const TextStyle(fontSize: 15),
          ),
          ),
        ),
      ]
  ).show();
}
