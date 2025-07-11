import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:neom_commons/utils/constants/app_assets.dart';
import 'package:neom_commons/utils/constants/app_translation_constants.dart';

import '../wallet_controller.dart';

Widget buildNoHistoryToShow(BuildContext context, WalletController _){
  return Padding(
    padding: const EdgeInsets.only(left: 15, right: 15),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[        
        Text(
          AppTranslationConstants.appCoinComingSoon.tr,
          style: const TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
        AppTheme.heightSpace20,
        Image.asset(AppAssets.appCoin, height: 150),
        AppTheme.heightSpace20,
        Text(
          AppTranslationConstants.noHistoryToShow.tr,
          style: const TextStyle(
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
      ],
    ),
  );
}
