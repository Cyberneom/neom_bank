import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:neom_commons/ui/widgets/appbar_child.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';
import 'package:neom_commons/utils/constants/app_translation_constants.dart';
import 'package:neom_core/domain/model/app_transaction.dart';

import '../utils/enums/wallet_status.dart';
import 'wallet_controller.dart';
import 'widgets/transaction_tile.dart';
import 'widgets/wallet_card.dart';
import 'widgets/wallet_widgets.dart';

class WalletHistoryPage extends StatelessWidget {
  const WalletHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<WalletController>(
      id: AppPageIdConstants.walletHistory,
      init: WalletController(),
      builder: (_) => Scaffold(
        appBar:  PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: AppBarChild(title: AppTranslationConstants.wallet.tr)
        ),
        backgroundColor: AppColor.main50,
        body: Stack(
          children: [
            Container(
              decoration: AppTheme.appBoxDecoration,
              height: AppTheme.fullHeight(context),
              child: _.isLoading.value ? const Center(child: CircularProgressIndicator())
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
                        AppTranslationConstants.transactionsHistory.tr,
                        style: const TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Divider(thickness: 1, color: AppColor.white80),
                    SizedBox(
                      height: AppTheme.fullHeight(context)*0.5,
                      child: _.transactions.isNotEmpty ? ListView.builder(
                          itemCount: _.transactions.length,
                          itemBuilder: (context, index) {
                            AppTransaction transaction = _.transactions.values.elementAt(index);
                            return TransactionTile(transaction: transaction, walletId: _.wallet?.id ?? '',);
                          }
                      ) :  buildNoHistoryToShow(context, _),
                    ),
                  ],
                ),
              ),
            ),
            if(!_.isLoading.value && _.wallet?.status != WalletStatus.active)
              Positioned.fill(
                child: AbsorbPointer( // Prevents interaction with widgets below
                  child: Container(
                    color: Colors.black.withOpacity(0.9), // Semi-transparent grey/black overlay
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
                              AppTranslationConstants.walletNotActive.tr,
                              style: const TextStyle(
                                fontSize: 22.0,
                                fontWeight: FontWeight.bold,
                                color: AppColor.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            AppTheme.heightSpace10,
                            Text(
                              AppTranslationConstants.contactSupportForActivation.tr,
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
