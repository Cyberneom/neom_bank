import 'package:flutter/material.dart';
import 'package:sint/sint.dart';
import 'package:neom_commons/app_flavour.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:neom_commons/ui/widgets/appbar_child.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';
import 'package:neom_commons/utils/constants/translations/app_translation_constants.dart';
import 'package:neom_core/domain/model/app_transaction.dart';
import 'package:neom_core/utils/enums/wallet_status.dart';

import '../utils/constants/bank_translation_constants.dart';
import 'wallet_controller.dart';
import 'widgets/transaction_tile.dart';
import 'widgets/wallet_card.dart';
import 'widgets/wallet_widgets.dart';

class WalletHistoryPage extends StatelessWidget {
  const WalletHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SintBuilder<WalletController>(
      id: AppPageIdConstants.walletHistory,
      init: WalletController(),
      builder: (controller) => Scaffold(
        appBar:  PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: AppBarChild(title: AppTranslationConstants.wallet.tr)
        ),
        backgroundColor: AppFlavour.getBackgroundColor(),
        body: Stack(
          children: [
            Container(
              decoration: AppTheme.appBoxDecoration,
              height: AppTheme.fullHeight(context),
              child: controller.isLoading.value ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTheme.heightSpace20,
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: WalletCard(),
                    ),
                    AppTheme.heightSpace20,
                    Divider(thickness: 1, color: AppColor.white80),
                    SizedBox(
                      width: AppTheme.fullWidth(context),
                      child: Text(
                        BankTranslationConstants.transactionsHistory.tr,
                        style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Divider(thickness: 1, color: AppColor.white80),
                    SizedBox(
                      height: AppTheme.fullHeight(context)*0.5,
                      child: controller.transactions.isNotEmpty ? ListView.builder(
                          itemCount: controller.transactions.length,
                          itemBuilder: (context, index) {
                            AppTransaction transaction = controller.transactions.values.elementAt(index);
                            return TransactionTile(transaction: transaction, walletId: controller.wallet?.id ?? '',);
                          }
                      ) :  buildNoHistoryToShow(context, controller),
                    ),
                  ],
                ),
              ),
            ),
            if(!controller.isLoading.value && controller.wallet?.status != WalletStatus.active)
              Positioned.fill(
                child: AbsorbPointer( // Prevents interaction with widgets below
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.9), // Semi-transparent grey/black overlay
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.padding20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColor.white,
                              size: 60,
                            ),
                            AppTheme.heightSpace20,
                            Text(
                              BankTranslationConstants.walletNotActive.tr,
                              style: const TextStyle(
                                fontSize: 22.0,
                                fontWeight: FontWeight.bold,
                                color: AppColor.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            AppTheme.heightSpace10,
                            Text(
                              BankTranslationConstants.contactSupportForActivation.tr,
                              style: const TextStyle(
                                fontSize: 16.0,
                                color: Colors.white70,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

}
