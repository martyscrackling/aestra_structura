import 'package:flutter/material.dart';

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
    String paymentMethod = 'card';
    final cardNumberController = TextEditingController();
    final cardNameController = TextEditingController();
    final cardExpiryController = TextEditingController();
    final cardCvvController = TextEditingController();
    final gcashNumberController = TextEditingController();

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
                constraints: const BoxConstraints(maxWidth: 500),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                              'Payment Details',
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
                        
                        const Text(
                          'Payment Method',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _PaymentMethodSelector(
                                icon: Icons.credit_card,
                                label: 'Card',
                                isSelected: paymentMethod == 'card',
                                onTap: isProcessing ? null : () => setState(() {
                                  paymentMethod = 'card';
                                  errorMessage = null;
                                }),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _PaymentMethodSelector(
                                icon: Icons.phone_android,
                                label: 'GCash',
                                isSelected: paymentMethod == 'gcash',
                                onTap: isProcessing ? null : () => setState(() {
                                  paymentMethod = 'gcash';
                                  errorMessage = null;
                                }),
                              ),
                            ),
                          ],
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
                        
                        if (paymentMethod == 'card') ...[
                          TextField(
                            controller: cardNameController,
                            enabled: !isProcessing,
                            decoration: _inputDecoration('Name on Card'),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: cardNumberController,
                            enabled: !isProcessing,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('Card Number (16 digits)'),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: cardExpiryController,
                                  enabled: !isProcessing,
                                  decoration: _inputDecoration('MM/YY'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: cardCvvController,
                                  enabled: !isProcessing,
                                  keyboardType: TextInputType.number,
                                  obscureText: true,
                                  decoration: _inputDecoration('CVV'),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 180,
                                  height: 180,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.blue.shade200, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withValues(alpha: 0.1),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Icon(Icons.qr_code_2, size: 100, color: Color(0xFF005CEE)), // GCash Blue
                                      SizedBox(height: 8),
                                      Text(
                                        'AESTRA STRUCTURA',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Color(0xFF005CEE),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Scan this QR code using your GCash app to pay. Once completed, enter the reference number below.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black54, fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: gcashNumberController,
                                  enabled: !isProcessing,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration('GCash Ref. No. (e.g. 1000293...)'),
                                ),
                              ],
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: isProcessing
                                ? null
                                : () async {
                                    setState(() {
                                      errorMessage = null;
                                    });
                                    
                                    // Validation
                                    if (paymentMethod == 'card') {
                                      if (cardNameController.text.trim().isEmpty ||
                                          cardNumberController.text.trim().isEmpty ||
                                          cardExpiryController.text.trim().isEmpty ||
                                          cardCvvController.text.trim().isEmpty) {
                                        setState(() => errorMessage = 'Please fill in all card details.');
                                        return;
                                      }
                                    } else {
                                      if (gcashNumberController.text.trim().isEmpty) {
                                        setState(() => errorMessage = 'Please enter your GCash Reference Number to verify payment.');
                                        return;
                                      }
                                    }
                                    
                                    setState(() => isProcessing = true);
                                    
                                    // MOCK PAYMENT PROCESSING
                                    await Future.delayed(const Duration(seconds: 2));
                                    
                                    setState(() => isProcessing = false);
                                    
                                    if (dialogContext.mounted) {
                                      Navigator.of(dialogContext).pop();
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text('Processing ${plan.years} year payment via ${paymentMethod.toUpperCase()}! (Simulation complete)'),
                                          backgroundColor: Colors.green,
                                          duration: const Duration(seconds: 4),
                                        )
                                      );
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
                                    'Pay ${plan.amountLabel}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6F00)),
      ),
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

class _PaymentMethodSelector extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _PaymentMethodSelector({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFFF6F00) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? const Color(0xFFFF6F00).withValues(alpha: 0.05) : Colors.white,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFFF6F00) : Colors.grey.shade500,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFFFF6F00) : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
