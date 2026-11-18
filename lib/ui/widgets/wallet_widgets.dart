import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:neom_commons/utils/constants/app_assets.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/utils/enums/app_in_use.dart';
import 'package:sint/sint.dart';

import '../../utils/constants/bank_translation_constants.dart';
import '../wallet_controller.dart';

Widget buildNoHistoryToShow(BuildContext context, WalletController _){
  final isGigmeout = AppConfig.instance.appInUse == AppInUse.g;
  return Padding(
    padding: const EdgeInsets.only(left: 15, right: 15),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          isGigmeout
              ? 'Tus GigCoins impulsan directo a los artistas, salas de ensayo y eventos QR'
              : BankTranslationConstants.appCoinComingSoon.tr,
          style: const TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
        AppTheme.heightSpace20,
        Image.asset(AppAssets.appCoin, height: 150),
        AppTheme.heightSpace20,
        Text(
          BankTranslationConstants.noHistoryToShow.tr,
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
