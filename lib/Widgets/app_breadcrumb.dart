import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medical_app/theme.dart';

class BreadcrumbItem {
  final String label;
  final String? route;
  final VoidCallback? onTap;

  const BreadcrumbItem({
    required this.label,
    this.route,
    this.onTap,
  });
}

class AppBreadcrumb extends StatelessWidget {
  final List<BreadcrumbItem> items;

  const AppBreadcrumb({
    super.key,
    required this.items,
  });

  void _handleTap(BuildContext context, BreadcrumbItem item) {
    if (item.onTap != null) {
      item.onTap!();
      return;
    }
    if (item.route != null && item.route!.isNotEmpty) {
      Navigator.pushReplacementNamed(context, item.route!);
      return;
    }
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeItems = items.isNotEmpty
        ? items
        : const [BreadcrumbItem(label: 'Page')];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, -0.08),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: ValueKey(safeItems.map((e) => e.label).join('/')),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            const Icon(Icons.home_rounded, size: 16, color: AppColors.textMuted),
            const _Slash(),
            ...List.generate(safeItems.length, (index) {
              final isLast = index == safeItems.length - 1;
              final item = safeItems[index];

              final tile = InkWell(
                onTap: isLast ? null : () => _handleTap(context, item),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    item.label,
                    style: isLast
                        ? GoogleFonts.dmSans(
                            color: AppColors.primaryDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          )
                        : GoogleFonts.dmSans(
                            color: AppColors.textSecond,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                  ),
                ),
              );

              if (isLast) return tile;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [tile, const _Slash()],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Slash extends StatelessWidget {
  const _Slash();

  @override
  Widget build(BuildContext context) {
    return Text(
      '/',
      style: GoogleFonts.dmSans(
        color: AppColors.textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
