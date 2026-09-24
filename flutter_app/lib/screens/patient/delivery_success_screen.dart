import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import 'patient_home_screen.dart';

class DeliverySuccessScreen extends StatelessWidget {
  final String orderId;
  const DeliverySuccessScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 90, height: 90,
              decoration: const BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, color: AppColors.primary, size: 56),
            ),
            const SizedBox(height: 24),
            const Text('Delivery Successful!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Your order has been delivered successfully.',
              style: TextStyle(color: AppColors.textGrey), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('#${orderId.substring(0, 8).toUpperCase()}',
              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 32),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.star, color: Colors.amber, size: 32),
              const Icon(Icons.star, color: Colors.amber, size: 32),
              const Icon(Icons.star, color: Colors.amber, size: 32),
              const Icon(Icons.star, color: Colors.amber, size: 32),
              Icon(Icons.star_outline, color: Colors.grey[300], size: 32),
            ]),
            const SizedBox(height: 6),
            const Text('Rate your experience', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
            const SizedBox(height: 32),
            PharmaButton(
              label: 'Back to Home',
              onPressed: () => Navigator.pushAndRemoveUntil(context,
                MaterialPageRoute(builder: (_) => const PatientHomeScreen()), (r) => false),
            ),
          ]),
        ),
      ),
    );
  }
}
