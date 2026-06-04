import 'package:flutter/material.dart';

import '../../features/payments/data/payment_instance.dart';

class PaymentStatusIconOption {
  const PaymentStatusIconOption({
    required this.status,
    required this.label,
    required this.icon,
    required this.color,
    required this.expectedAssetPath,
    this.assetPath,
  });

  final PaymentStatus status;
  final String label;
  final IconData icon;
  final Color color;
  final String expectedAssetPath;
  final String? assetPath;
}

PaymentStatusIconOption paymentStatusIcon(
  PaymentStatus status, {
  bool? isAutopay,
}) {
  return switch (status) {
    PaymentStatus.future => const PaymentStatusIconOption(
      status: PaymentStatus.future,
      label: 'Manual: futuro',
      icon: Icons.event_outlined,
      color: Color(0xFF2F6FB4),
      expectedAssetPath: 'assets/icons/status/manual_futuro.png',
      assetPath: 'assets/icons/status/manual_futuro.png',
    ),
    PaymentStatus.upcoming => const PaymentStatusIconOption(
      status: PaymentStatus.upcoming,
      label: 'Manual: proximo',
      icon: Icons.event_available_outlined,
      color: Color(0xFF946200),
      expectedAssetPath: 'assets/icons/status/manual_proximo.png',
      assetPath: 'assets/icons/status/manual_proximo.png',
    ),
    PaymentStatus.dueSoon => const PaymentStatusIconOption(
      status: PaymentStatus.dueSoon,
      label: 'Manual: atencion',
      icon: Icons.notification_important_outlined,
      color: Color(0xFFC44900),
      expectedAssetPath: 'assets/icons/status/manual_atencion.png',
      assetPath: 'assets/icons/status/manual_atencion.png',
    ),
    PaymentStatus.overdue => const PaymentStatusIconOption(
      status: PaymentStatus.overdue,
      label: 'Manual: vencido',
      icon: Icons.warning_amber_outlined,
      color: Color(0xFFC62828),
      expectedAssetPath: 'assets/icons/status/manual_vencido.png',
      assetPath: 'assets/icons/status/manual_vencido.png',
    ),
    PaymentStatus.paid => PaymentStatusIconOption(
      status: PaymentStatus.paid,
      label: isAutopay == true ? 'Automatico: pagado' : 'Manual: pagado',
      icon: Icons.check_circle_outline,
      color: const Color(0xFF2E7D32),
      expectedAssetPath: isAutopay == true
          ? 'assets/icons/status/automatico_pagado.png'
          : 'assets/icons/status/manual_pagado.png',
      assetPath: isAutopay == true
          ? 'assets/icons/status/automatico_pagado.png'
          : 'assets/icons/status/manual_pagado.png',
    ),
    PaymentStatus.autopayDueSoon => const PaymentStatusIconOption(
      status: PaymentStatus.autopayDueSoon,
      label: 'Automatico: pronto pago',
      icon: Icons.account_balance_wallet_outlined,
      color: Color(0xFF946200),
      expectedAssetPath: 'assets/icons/status/automatico_pronto_pago.png',
      assetPath: 'assets/icons/status/automatico_pronto_pago.png',
    ),
    PaymentStatus.autopayFuture => const PaymentStatusIconOption(
      status: PaymentStatus.autopayFuture,
      label: 'Automatico: futuro',
      icon: Icons.account_balance_outlined,
      color: Color(0xFF2F6FB4),
      expectedAssetPath: 'assets/icons/status/automatico_futuro.png',
      assetPath: 'assets/icons/status/automatico_futuro.png',
    ),
    PaymentStatus.autopayPendingConfirmation => const PaymentStatusIconOption(
      status: PaymentStatus.autopayPendingConfirmation,
      label: 'Automatico: por confirmar',
      icon: Icons.fact_check_outlined,
      color: Color(0xFF946200),
      expectedAssetPath: 'assets/icons/status/automatico_por_confirmar.png',
      assetPath: 'assets/icons/status/automatico_por_confirmar.png',
    ),
    PaymentStatus.pending => const PaymentStatusIconOption(
      status: PaymentStatus.pending,
      label: 'Pendiente',
      icon: Icons.hourglass_empty_outlined,
      color: Color(0xFF455A64),
      expectedAssetPath: 'assets/icons/status/status_pending.png',
    ),
    PaymentStatus.active => const PaymentStatusIconOption(
      status: PaymentStatus.active,
      label: 'Activo',
      icon: Icons.play_circle_outline,
      color: Color(0xFF1E6C66),
      expectedAssetPath: 'assets/icons/status/status_active.png',
    ),
    PaymentStatus.autopayOverdueConfirmation => const PaymentStatusIconOption(
      status: PaymentStatus.autopayOverdueConfirmation,
      label: 'Automatico: por confirmar',
      icon: Icons.fact_check_outlined,
      color: Color(0xFF946200),
      expectedAssetPath: 'assets/icons/status/automatico_por_confirmar.png',
      assetPath: 'assets/icons/status/automatico_por_confirmar.png',
    ),
    PaymentStatus.notApplicableException => const PaymentStatusIconOption(
      status: PaymentStatus.notApplicableException,
      label: 'Excepcion',
      icon: Icons.block_outlined,
      color: Color(0xFF607D8B),
      expectedAssetPath: 'assets/icons/status/status_exception.png',
    ),
    PaymentStatus.cancelled => const PaymentStatusIconOption(
      status: PaymentStatus.cancelled,
      label: 'Cancelado',
      icon: Icons.cancel_outlined,
      color: Color(0xFF757575),
      expectedAssetPath: 'assets/icons/status/status_cancelled.png',
    ),
    PaymentStatus.cancelledByRecalculation => const PaymentStatusIconOption(
      status: PaymentStatus.cancelledByRecalculation,
      label: 'Recalculado',
      icon: Icons.update_disabled_outlined,
      color: Color(0xFF757575),
      expectedAssetPath: 'assets/icons/status/status_recalculated.png',
    ),
  };
}

class PaymentStatusIconBadge extends StatelessWidget {
  const PaymentStatusIconBadge({
    required this.status,
    this.isAutopay,
    this.size = 42,
    this.showBackground = true,
    super.key,
  });

  final PaymentStatus status;
  final bool? isAutopay;
  final double size;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final option = paymentStatusIcon(status, isAutopay: isAutopay);
    final fallbackIcon = Icon(
      option.icon,
      size: size * 0.54,
      color: option.color,
    );
    final icon = option.assetPath == null
        ? fallbackIcon
        : Image.asset(
            option.assetPath!,
            width: size * 0.64,
            height: size * 0.64,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => fallbackIcon,
          );

    if (!showBackground) {
      return Tooltip(message: option.label, child: icon);
    }

    return Tooltip(
      message: option.label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: option.color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: option.color.withValues(alpha: 0.32)),
        ),
        alignment: Alignment.center,
        child: icon,
      ),
    );
  }
}
