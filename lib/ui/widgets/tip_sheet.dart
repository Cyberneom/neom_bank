import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:neom_core/domain/use_cases/tip_service.dart';
import 'package:neom_core/domain/use_cases/wallet_service.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'package:neom_core/utils/enums/tip_tier.dart';
import 'package:sint/sint.dart';

import '../../utils/constants/tip_translation_constants.dart';
import '../wallet_controller.dart';

/// A modal bottom sheet that allows users to send a tip (GigCoins)
/// to a recipient by selecting a [TipTier] and an optional message.
///
/// Displays tier cards (Aplauso, Cafe, Cuerdas, Amplificador),
/// a message text field, the user's current balance, and either the send
/// button or a direct CTA to buy the starter pack (10 GigCoins for $50 MXN)
/// when the user does not have enough GigCoins.
class TipSheet extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final String? contextType;
  final String? contextId;
  final double? initialBalanceOverride;
  final Future<void> Function(BuildContext context)? onBuyStarterPack;

  const TipSheet({
    super.key,
    required this.recipientId,
    required this.recipientName,
    this.contextType,
    this.contextId,
    this.initialBalanceOverride,
    this.onBuyStarterPack,
  });

  static Future<void> show(
    BuildContext context, {
    required String recipientId,
    required String recipientName,
    String? contextType,
    String? contextId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TipSheet(
        recipientId: recipientId,
        recipientName: recipientName,
        contextType: contextType,
        contextId: contextId,
      ),
    );
  }

  @override
  State<TipSheet> createState() => _TipSheetState();
}

class _TipSheetState extends State<TipSheet> {

  TipTier _selectedTier = TipTier.aplauso;
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;
  bool _isLoadingBalance = false;
  WalletController? _walletController;

  @override
  void initState() {
    super.initState();
    if (widget.initialBalanceOverride == null) {
      _walletController = _resolveWalletController();
      if (_walletController != null) {
        _isLoadingBalance = _walletController!.wallet == null;
        _walletController!.loadWallet().whenComplete(() {
          if (mounted) {
            setState(() => _isLoadingBalance = false);
          }
        });
      }
    }
  }

  WalletController? _resolveWalletController() {
    if (Sint.isRegistered<WalletController>()) {
      return Sint.find<WalletController>();
    }
    if (Sint.isRegistered<WalletService>()) {
      final ws = Sint.find<WalletService>();
      if (ws is WalletController) return ws;
    }
    return Sint.put(WalletController());
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double currentBalance =
        widget.initialBalanceOverride ?? _walletController?.wallet?.balance ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColor.getMain(),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            AppTheme.heightSpace10,
            _buildHeader(),
            AppTheme.heightSpace20,
            _buildTierCards(),
            AppTheme.heightSpace20,
            _buildMessageField(),
            AppTheme.heightSpace10,
            _buildBalanceRow(currentBalance),
            AppTheme.heightSpace20,
            _buildSendButton(currentBalance),
          ],
        ),
      ),
    );
  }

  /// Drag handle indicator at the top of the sheet.
  Widget _buildHandle() {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  /// Header with the recipient name.
  Widget _buildHeader() {
    return Text(
      '${TipTranslationConstants.tipSupportArtist.tr} ${widget.recipientName}',
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// Three horizontally laid out tier cards.
  Widget _buildTierCards() {
    return Row(
      children: TipTier.values.map((tier) {
        final bool isSelected = _selectedTier == tier;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedTier = tier),
            child: _TipTierCard(
              tier: tier,
              isSelected: isSelected,
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Optional message field.
  Widget _buildMessageField() {
    return TextField(
      controller: _messageController,
      maxLength: 100,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: TipTranslationConstants.tipMessageHint.tr,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        labelText: TipTranslationConstants.tipMessage.tr,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.amber, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// Shows the user's current GigCoin balance.
  Widget _buildBalanceRow(double currentBalance) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.wallet_rounded, color: Colors.white.withValues(alpha: 0.6), size: 18),
        const SizedBox(width: 6),
        Text(
          '${TipTranslationConstants.tipBalance.tr}: ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        Text(
          '${currentBalance.truncate()} ${TipTranslationConstants.tipCoins.tr}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Send tip button when balance is sufficient; otherwise directs the user
  /// straight to purchase the starter pack (10 GigCoins for $50 MXN).
  Widget _buildSendButton(double currentBalance) {
    if (_isLoadingBalance) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber.withValues(alpha: 0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Colors.black,
            ),
          ),
        ),
      );
    }

    final bool hasEnoughBalance = currentBalance >= _selectedTier.coins;

    if (!hasEnoughBalance) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amberAccent.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: [
                const Text('🪙', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    TipTranslationConstants.tipNoCoinsSubtitle.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : () => _openBuyStarterPack(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
              icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 20),
              label: Text(
                TipTranslationConstants.tipBuyStarterPack.tr,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () {
              Sint.back();
              Sint.toNamed(AppRouteConstants.wallet);
            },
            icon: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Colors.white70,
              size: 16,
            ),
            label: Text(
              TipTranslationConstants.tipOpenWallet.tr,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    final bool canSend = !_isSending;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: canSend ? () => _sendTip() : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: canSend ? 4 : 0,
        ),
        child: _isSending
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.black,
                ),
              )
            : Text(
                '${TipTranslationConstants.tipSend.tr}  ${_selectedTier.coins} ${TipTranslationConstants.tipCoins.tr}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
      ),
    );
  }

  Future<void> _openBuyStarterPack(BuildContext context) async {
    Sint.back();
    if (widget.onBuyStarterPack != null) {
      await widget.onBuyStarterPack!(context);
      return;
    }
    await _walletController?.buyGigCoinPack(
      context,
      qty: WalletController.starterGigCoinsQty,
    );
  }

  /// Sends the tip using the [TipService] and shows feedback.
  Future<void> _sendTip() async {
    setState(() => _isSending = true);

    try {
      final TipService tipService = Sint.find<TipService>();
      final bool success = await tipService.sendTip(
        recipientId: widget.recipientId,
        tier: _selectedTier,
        message: _messageController.text.trim().isNotEmpty
            ? _messageController.text.trim()
            : null,
        contextType: widget.contextType,
        contextId: widget.contextId,
      );

      if (!mounted) return;

      if (success) {
        await _walletController?.loadWallet();
        if (!mounted) return;
        Sint.back();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${TipTranslationConstants.tipThankYou.tr} ${widget.recipientName}',
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        await _walletController?.loadWallet();
        if (!mounted) return;
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(TipTranslationConstants.tipInsufficientBalance.tr),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}

/// A single tier selection card displaying emoji, name, and coin amount.
class _TipTierCard extends StatelessWidget {
  final TipTier tier;
  final bool isSelected;

  const _TipTierCard({
    required this.tier,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColor.surfaceElevated
            : AppColor.surfaceDim,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? Colors.amber : Colors.white.withValues(alpha: 0.15),
          width: isSelected ? 2 : 0.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _tierEmoji,
            style: TextStyle(fontSize: isSelected ? 32 : 26),
          ),
          const SizedBox(height: 8),
          Text(
            _tierTranslationKey.tr,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '${tier.coins} ${TipTranslationConstants.tipCoins.tr}',
            style: TextStyle(
              color: isSelected ? Colors.amber : Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String get _tierEmoji {
    switch (tier) {
      case TipTier.aplauso:
        return '\uD83D\uDC4F';
      case TipTier.cafe:
        return '\u2615';
      case TipTier.cuerdas:
        return '\uD83C\uDFB8';
      case TipTier.amplificador:
        return '\uD83D\uDD0A';
    }
  }

  String get _tierTranslationKey {
    switch (tier) {
      case TipTier.aplauso:
        return TipTranslationConstants.tipAplauso;
      case TipTier.cafe:
        return TipTranslationConstants.tipCafe;
      case TipTier.cuerdas:
        return TipTranslationConstants.tipCuerdas;
      case TipTier.amplificador:
        return TipTranslationConstants.tipAmplificador;
    }
  }
}
