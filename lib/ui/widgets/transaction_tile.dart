import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/utils/constants/app_assets.dart';
import 'package:neom_commons/utils/datetime_utilities.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/domain/model/app_transaction.dart';
import 'package:neom_core/utils/enums/app_currency.dart';
import 'package:sint/sint.dart';

class TransactionTile extends StatelessWidget {
  final AppTransaction transaction;
  final String walletId;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.walletId,
  });

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.all(10),
      child: ListTile(
        leading: Image.asset(AppAssets.appCoin, height: 40),
        title: Text(transaction.description.isNotEmpty ? transaction.description : transaction.type.name.tr.capitalize,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(DateTimeUtilities.dateFormat(transaction.createdTime),
          style: const TextStyle(fontSize: 15),
        ),
        trailing: Text('${transaction.recipientId == walletId ? '+' : '-'} ${transaction.amount} ${transaction.currency != AppCurrency.appCoin ?  transaction.currency.name.tr.toUpperCase() : ''}',
            style: const TextStyle(
                color: AppColor.white,
                fontSize: 18)
        ),
        // onTap: () => Sint.toNamed(AppRouteConstants.transactionDetails, arguments: [transaction]),
      ),
    );
  }
}

String getAmountToDisplay(AppTransaction transaction) {
  AppConfig.logger.t("Transaction amount: ${transaction.amount}");

  double amount = transaction.amount;

  // Check if the amount is an integer
  if (amount.floor() == amount) {
    return amount.toInt().toString(); // Convert to integer and format
  } else {
    return amount.toStringAsFixed(1); // Format with two decimal places
  }

}

String getCurrencyToDisplay(AppTransaction transaction) {

  AppCurrency currency = AppCurrency.appCoin;
  currency = transaction.currency;

  ///DEPRECATED 090824
  // switch(order.saleType) {
  //   case SaleType.product:
  //
  //     break;
  //   case SaleType.event:
  //     currency = order.event!.coverPrice!.currency;
  //     break;
  //   case SaleType.booking:
  //     // TODO: Handle this case.
  //     break;
  //   case SaleType.digitalItem:
  //     currency = order.releaseItem!.digitalPrice!.currency;
  //     break;
  //   case SaleType.physicalItem:
  //     currency = order.releaseItem!.physicalPrice!.currency;
  //     break;
  // }

  return currency.name;
}
