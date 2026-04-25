import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../services/app_config.dart';
import '../../services/payment_service.dart';

class UpgradePlanModal {
  static const List<_PlanOption> _planOptions = [
    _PlanOption(
      years: 1,
      amountLabel: '₱5,000',
      subtitle: 'Billed annually',
    ),
    _PlanOption(
      years: 3,
      amountLabel: '₱13,000',
      subtitle: 'Save 13% • Billed every 3 years',
      isPopular: true,
    ),
    _PlanOption(
      years: 5,
      amountLabel: '₱22,000',
      subtitle: 'Save 12% • Billed every 5 years',
    ),
  ];

  static Future<void> show(BuildContext context) async {
    // 1. Show Plan Selection
    final selectedPlan = await _showPlanSelection(context);
    if (selectedPlan == null) return;

    // 2. Plan is selected, show payment modal
    if (!context.mounted) return;
    await _showPaymentModal(context, selectedPlan);
  }

  static Future<_PlanOption?> _showPlanSelection(BuildContext context) async {
    return showDialog<_PlanOption>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.workspace_premium,
                    color: Color(0xFFFF6F00),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Upgrade Your Plan',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: Color(0xFF0A173D),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select a subscription plan to continue using all Premium features without interruption.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 24),
                  
                  ..._planOptions.map((plan) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(plan),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: plan.isPopular
                                  ? const Color(0xFFFF6F00)
                                  : Colors.grey.shade300,
                              width: plan.isPopular ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            color: plan.isPopular
                                ? const Color(0xFFFF6F00).withValues(alpha: 0.05)
                                : Colors.white,
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: plan.isPopular
                                        ? const Color(0xFFFF6F00)
                                        : Colors.grey.shade400,
                                    width: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${plan.years} Year${plan.years > 1 ? 's' : ''}',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0A173D),
                                          ),
                                        ),
                                        if (plan.isPopular) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFF6F00),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'POPULAR',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      plan.subtitle,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                plan.amountLabel,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0A173D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade600,
                    ),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Future<void> _showPaymentModal(BuildContext context, _PlanOption plan) async {
    final messenger = ScaffoldMessenger.of(context);
    bool isProcessing = false;
    String? errorMessage;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: isProcessing ? null : () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Secure Checkout',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0A173D),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Summary Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Selected Plan', style: TextStyle(color: Colors.black54, fontSize: 13)),
                                Text(
                                  '${plan.years} Year${plan.years > 1 ? 's' : ''}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ],
                            ),
                            Text(
                              plan.amountLabel,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      const Icon(Icons.lock_outline, size: 48, color: Colors.green),
                      const SizedBox(height: 16),
                      const Text(
                        'You will be redirected to PayMongo to securely complete your payment using GCash, PayMaya, or Credit/Debit Card.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 24),
                      
                      if (errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                            ],
                          ),
                        ),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: isProcessing
                              ? null
                              : () async {
                                  setState(() {
                                    errorMessage = null;
                                    isProcessing = true;
                                  });

                                  try {
                                    final authService = Provider.of<AuthService>(context, listen: false);
                                    final user = authService.currentUser;
                                    if (user == null || user['user_id'] == null) {
                                      setState(() {
                                        errorMessage = 'User not found. Please log in again.';
                                        isProcessing = false;
                                      });
                                      return;
                                    }
                                    
                                    final userId = user['user_id'];
                                    final result = await PaymentService.createCheckoutSession(
                                      userId: userId,
                                      years: plan.years,
                                    );
                                    
                                    if (result['success'] == true) {
                                      final checkoutUrl = result['checkout_url'];
                                      final launched = await PaymentService.launchCheckout(checkoutUrl);
                                      
                                      if (launched) {
                                        if (dialogContext.mounted) {
                                          Navigator.of(dialogContext).pop();
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text('Redirecting to secure PayMongo checkout...'),
                                              backgroundColor: Colors.green,
                                              duration: Duration(seconds: 4),
                                            ),
                                          );
                                        }
                                      } else {
                                        setState(() {
                                          errorMessage = 'Could not launch payment URL';
                                        });
                                      }
                                    } else {
                                      setState(() {
                                        errorMessage = 'Checkout failed: ${result['message']}';
                                      });
                                    }
                                  } catch (e) {
                                    setState(() {
                                      errorMessage = 'Network error: ' + e.toString();
                                    });
                                  } finally {
                                    setState(() => isProcessing = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6F00),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: isProcessing
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  'Proceed to Checkout',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PlanOption {
  final int years;
  final String amountLabel;
  final String subtitle;
  final bool isPopular;

  const _PlanOption({
    required this.years,
    required this.amountLabel,
    required this.subtitle,
    this.isPopular = false,
  });
}
