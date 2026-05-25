import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../theme/app_theme.dart';
import '../services/revenuecat_service.dart';
import '../state/app_state.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  final _revenueCat = RevenueCatService();

  Package? _monthlyPackage;
  bool _isLoadingOfferings = true;
  bool _isPurchasing = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() {
      _isLoadingOfferings = true;
      _loadError = null;
    });

    try {
      final offerings = await _revenueCat.fetchOfferings();
      final current = offerings?.current;
      Package? monthly = current?.monthly;
      monthly ??= current?.availablePackages.isNotEmpty == true
          ? current!.availablePackages.first
          : null;

      if (!mounted) return;
      setState(() {
        _monthlyPackage = monthly;
        _isLoadingOfferings = false;
        if (monthly == null) {
          _loadError = 'No subscription packages are available right now.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingOfferings = false;
        _loadError = 'Could not load subscription options.';
      });
    }
  }

  Future<void> _handlePurchase() async {
    final package = _monthlyPackage;
    if (package == null || _isPurchasing) return;

    setState(() => _isPurchasing = true);

    try {
      final customerInfo = await _revenueCat.purchasePackage(package);
      if (!mounted) return;

      if (_revenueCat.isPremiumActive(customerInfo)) {
        context.read<AppState>().setPremium(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome to FlowJournal Plus!')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase completed, but premium is not active yet.'),
          ),
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase failed: ${errorCode.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _handleRestore() async {
    if (_isPurchasing) return;

    setState(() => _isPurchasing = true);

    try {
      final customerInfo = await _revenueCat.restorePurchases();
      if (!mounted) return;

      if (_revenueCat.isPremiumActive(customerInfo)) {
        context.read<AppState>().setPremium(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchases restored!')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active subscription found.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  String get _priceLabel {
    final package = _monthlyPackage;
    if (package == null) return 'Subscribe';
    return 'Subscribe for ${package.storeProduct.priceString}/mo';
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isLoadingOfferings || _isPurchasing;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: IconButton(
                  icon: Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: isBusy ? null : () => Navigator.pop(context),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('✨', style: TextStyle(fontSize: 48)),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Unlock FlowJournal Plus',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Get the most out of your journal with premium features.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    _buildFeatureItem(
                      icon: '🎨',
                      title: 'Premium Themes',
                      description:
                          'Unlock all mood-based color palettes and typography styles.',
                    ),
                    _buildFeatureItem(
                      icon: '🎙',
                      title: 'Longer Voice Entries',
                      description:
                          'Record up to 60 minutes continuously without interruptions.',
                    ),
                    _buildFeatureItem(
                      icon: '☁️',
                      title: 'Secure Cloud Backup',
                      description:
                          'Never lose a memory with automatic end-to-end encrypted sync.',
                    ),
                    _buildFeatureItem(
                      icon: '📊',
                      title: 'Deep AI Insights',
                      description:
                          'Get profound analysis on your emotional patterns and habits.',
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -4),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_loadError != null) ...[
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  GestureDetector(
                    onTap: isBusy || _monthlyPackage == null ? null : _handlePurchase,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isBusy || _monthlyPackage == null
                            ? AppColors.accentPrimary.withValues(alpha: 0.5)
                            : AppColors.accentPrimary,
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        boxShadow: AppShadows.glow,
                      ),
                      child: _isLoadingOfferings || _isPurchasing
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              _priceLabel,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: isBusy ? null : _handleRestore,
                        child: Text(
                          'Restore Purchases',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required String icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
