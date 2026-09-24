import 'package:flutter/material.dart';
import '../../utils/constants.dart';
import '../../widgets/shared_widgets.dart';
import 'patient_home_screen.dart';

class PickupSuccessScreen extends StatelessWidget {
  final String orderId;
  final String pickupCode;
  final String pharmacyName;
  final String pharmacyAddress;

  const PickupSuccessScreen({
    super.key,
    required this.orderId,
    required this.pickupCode,
    required this.pharmacyName,
    required this.pharmacyAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            const SizedBox(height: 20),
            Container(
              width: 90, height: 90,
              decoration: const BoxDecoration(color: AppColors.lightGreen, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, color: AppColors.primary, size: 56),
            ),
            const SizedBox(height: 20),
            const Text('Order Confirmed!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Your order is ready at the pharmacy.',
              style: TextStyle(color: AppColors.textGrey, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 24),

            // Pharmacy info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.lightGreen, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.local_pharmacy_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(pharmacyName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                ]),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(pharmacyAddress,
                    style: const TextStyle(fontSize: 12, color: AppColors.textGrey)),
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Pickup code
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: [
                const Text('Your Pickup Code', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Text(
                  pickupCode,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                  ),
                ),
                const SizedBox(height: 6),
                const Text('Show this code at the pharmacy counter',
                  style: TextStyle(color: Colors.white60, fontSize: 11), textAlign: TextAlign.center),
              ]),
            ),
            const SizedBox(height: 16),

            // Order summary
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Order #', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                Text(orderId.substring(0, 8).toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 28),

            // Actions
            PharmaButton(
              label: 'Get Directions',
              onPressed: () {},
              icon: Icons.directions,
            ),
            const SizedBox(height: 10),
            PharmaButton(
              label: 'Back to Home',
              outlined: true,
              onPressed: () => Navigator.pushAndRemoveUntil(context,
                MaterialPageRoute(builder: (_) => const PatientHomeScreen()), (r) => false),
            ),
          ]),
        ),
      ),
    );
  }
}
