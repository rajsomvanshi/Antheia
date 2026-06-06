import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../theme/app_theme.dart';
import '../theme/interaction_system.dart';
import '../services/revenuecat_service.dart';
import '../state/preferences_state.dart';

// ═══════════════════════════════════════════════════════════════
// Paywall Screen — Atmospheric Sanctuary Underwriting
//
// Clean editorial layouts presenting pricing as a durable
// support option for continuity, rather than a gamified checkout.
// ═══════════════════════════════════════════════════════════════

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> with SingleTickerProviderStateMixin {
  final _revenueCat = RevenueCatService();

  Package? _monthlyPackage;
  Package? _yearlyPackage;
  
  bool _isLoadingOfferings = true;
  bool _isPurchasing = false;
  String? _loadError;
  
  // Phase 3 post-purchase thank you state
  bool _showThankYou = false;
  int _selectedTierIndex = 0; // 0 = Yearly (Recommended), 1 = Monthly

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
      Package? yearly = current?.annual;
      
      // Fallbacks if current fields are missing
      if (monthly == null || yearly == null) {
        final available = current?.availablePackages ?? [];
        for (final pkg in available) {
          if (pkg.packageType == PackageType.monthly) monthly = pkg;
          if (pkg.packageType == PackageType.annual) yearly = pkg;
        }
      }

      if (!mounted) return;
      setState(() {
        _monthlyPackage = monthly;
        _yearlyPackage = yearly;
        _isLoadingOfferings = false;
        if (monthly == null && yearly == null) {
          _loadError = 'No subscription tiers are currently available.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingOfferings = false;
        _loadError = 'Could not retrieve sanctuary offerings.';
      });
    }
  }

  Future<void> _handlePurchase() async {
    final package = _selectedTierIndex == 0 ? _yearlyPackage : _monthlyPackage;
    if (package == null || _isPurchasing) return;

    setState(() => _isPurchasing = true);

    try {
      final customerInfo = await _revenueCat.purchasePackage(package);
      if (!mounted) return;

      if (_revenueCat.isPremiumActive(customerInfo)) {
        context.read<PreferencesState>().setPremium(true);
        AppHaptics.success();
        
        // Phase 3: Hypnotic post-purchase thank you fade sequence
        setState(() => _showThankYou = true);
        await Future.delayed(const Duration(seconds: 5));
        if (!mounted) return;
        if (ModalRoute.of(context)?.isCurrent == true) {
          Navigator.pop(context, true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment registered, updating session...')),
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification halted: ${errorCode.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sanctuary binding failed: $e')),
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
        context.read<PreferencesState>().setPremium(true);
        AppHaptics.success();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome back. Premium active.')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No active sanctuary underwriter found.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sanctuary restoration failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isBusy = _isLoadingOfferings || _isPurchasing;

    return Scaffold(
      backgroundColor: _showThankYou ? const Color(0xFF100F0E) : colors.bg,
      body: AnimatedCrossFade(
        duration: const Duration(milliseconds: 1000),
        crossFadeState: _showThankYou ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        firstCurve: Curves.easeInOut,
        secondCurve: Curves.easeInOut,
        
        // ─── First child: The Paywall Content ───
        firstChild: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height,
          child: Stack(
            children: [
              const Positioned.fill(
                child: IgnorePointer(
                  child: CinematicGrain(seed: 23, animate: false),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    // Header Quiet Exit
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 20, top: 12),
                        child: IconButton(
                          icon: Icon(Icons.close_rounded, color: colors.textSecondary.withValues(alpha: 0.6), size: 20),
                          onPressed: isBusy ? null : () => Navigator.pop(context),
                        ),
                      ),
                    ),
                    
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            
                            // Poetic Display Title
                            Text(
                              'PRESERVE YOUR STORY',
                              style: TextStyle(
                                fontFamily: 'Cormorant Garamond',
                                fontSize: 26,
                                fontWeight: FontWeight.normal,
                                color: colors.text,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Poetic Subtitle
                            Text(
                              'Antheia Premium connects your thoughts and underwrites the absolute security of your memory library.',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                color: colors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 40),
                            
                            // Premium Gated features
                            _buildBenefitRow(
                              colors: colors,
                              title: 'Semantic Search',
                              desc: 'Search your thoughts by concept, meaning, and emotional connection rather than simple keywords.',
                            ),
                            _buildBenefitRow(
                              colors: colors,
                              title: 'Sanctuary Library & AI Connections',
                              desc: 'Dynamically clusters recurring themes and patterns (e.g. solitude, growth, family) curated silently by the system.',
                            ),
                            _buildBenefitRow(
                              colors: colors,
                              title: 'Memory Geography Maps',
                              desc: 'Display coordinates not as tech logs but as the physical chapters of the travels defining your life.',
                            ),
                            _buildBenefitRow(
                              colors: colors,
                              title: 'Durable Sync & Cloud Backup',
                              desc: 'Continuous cloud sync replication under SQLite outbox WAL-security guarantees no reflection is ever lost.',
                            ),
                            
                            const SizedBox(height: 36),
                          ],
                        ),
                      ),
                    ),
                    
                    // Purchase Actions Section
                    Container(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
                      decoration: BoxDecoration(
                        color: colors.bg,
                        border: Border(
                          top: BorderSide(color: colors.hairline, width: 0.5),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_loadError != null) ...[
                            Text(
                              _loadError!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: colors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          
                          // Annual Tier Selection Button
                          _buildTierButton(
                            colors: colors,
                            index: 0,
                            title: 'Annual Plan',
                            price: _yearlyPackage?.storeProduct.priceString ?? '\$29.99',
                            period: 'year',
                            subtitle: '(Recommended) Underwrite your archive\'s continuity.',
                          ),
                          const SizedBox(height: 12),
                          
                          // Monthly Tier Selection Button
                          _buildTierButton(
                            colors: colors,
                            index: 1,
                            title: 'Monthly Plan',
                            price: _monthlyPackage?.storeProduct.priceString ?? '\$4.99',
                            period: 'month',
                            subtitle: 'Flexible backup support month-to-month.',
                          ),
                          const SizedBox(height: 28),
                          
                          // Central Purchase Action
                          GestureDetector(
                            onTap: isBusy || (_yearlyPackage == null && _monthlyPackage == null)
                                ? null
                                : _handlePurchase,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: isBusy
                                    ? colors.accent.withValues(alpha: 0.5)
                                    : colors.accent,
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(color: colors.hairline, width: 0.5),
                              ),
                              child: isBusy
                                  ? const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Secure Sanctuary',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Restore Link
                          GestureDetector(
                            onTap: isBusy ? null : _handleRestore,
                            child: Text(
                              'Restore purchases',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary.withValues(alpha: 0.7),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // ─── Second child: Hypnotic Post-Purchase Screen ───
        secondChild: GestureDetector(
          onTap: () {
            AppHaptics.light();
            Navigator.pop(context, true);
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height,
            color: const Color(0xFF100F0E), // Pure dark canvas
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 42),
                  child: Text(
                    'Thank you for supporting the preservation of this archive.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Cormorant Garamond',
                      fontSize: 22,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFFD0B08A), // gold accent
                      height: 1.6,
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                Text(
                  'Tap anywhere or wait a moment to return.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFFF2F0EB).withValues(alpha: 0.3),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitRow({
    required ResolvedColors colors,
    required String title,
    required String desc,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.accent,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Cormorant Garamond',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: colors.textSecondary.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierButton({
    required ResolvedColors colors,
    required int index,
    required String title,
    required String price,
    required String period,
    required String subtitle,
  }) {
    final active = _selectedTierIndex == index;
    
    return GestureDetector(
      onTap: () {
        AppHaptics.subtle();
        setState(() => _selectedTierIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: active
              ? colors.accent.withValues(alpha: 0.05)
              : colors.surface.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? colors.accent : colors.hairline,
            width: active ? 1.2 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: active ? FontWeight.bold : FontWeight.w500,
                          color: colors.text,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$price / $period',
                        style: TextStyle(
                          fontFamily: 'Cormorant Garamond',
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Cormorant Garamond',
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: colors.textSecondary.withValues(alpha: active ? 0.9 : 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
