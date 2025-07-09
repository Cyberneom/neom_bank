import 'package:get/get.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'ui/wallet_history_page.dart';

class BankRoutes {

  static final List<GetPage<dynamic>> routes = [
    GetPage(
      name: AppRouteConstants.wallet,
      page: () => const WalletHistoryPage(),
      transition: Transition.leftToRight,
    ),
  ];

}
