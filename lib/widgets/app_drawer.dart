import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/dashboard/dashboard_screen.dart';
import '../screens/electricity/electricity_screen.dart';
import '../screens/expenses/expense_list_screen.dart';
import '../screens/payments/payment_list_screen.dart';
import '../screens/rent/rent_screen.dart';
import '../screens/reports/reports_screen.dart';
import '../screens/rooms/room_list_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/tenants/tenant_list_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_DrawerItem>[
      _DrawerItem('Dashboard', Icons.dashboard_outlined, (context) => const DashboardScreen()),
      _DrawerItem('Rooms', Icons.meeting_room_outlined, (context) => const RoomListScreen()),
      _DrawerItem('Tenants', Icons.people_outline, (context) => const TenantListScreen()),
      _DrawerItem('Rent', Icons.receipt_outlined, (context) => const RentScreen()),
      _DrawerItem('Electricity', Icons.bolt_outlined, (context) => const ElectricityScreen()),
      _DrawerItem('Payments', Icons.payments_outlined, (context) => const PaymentListScreen()),
      _DrawerItem('Expenses', Icons.build_outlined, (context) => const ExpenseListScreen()),
      _DrawerItem('Reports', Icons.bar_chart_outlined, (context) => const ReportsScreen()),
      _DrawerItem('Search', Icons.search, (context) => const SearchScreen()),
      _DrawerItem('Settings', Icons.settings_outlined, (context) => const SettingsScreen()),
    ];

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Text('Room & Tenant Manager', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                children: items
                    .map((item) => ListTile(
                          leading: Icon(item.icon),
                          title: Text(item.label),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: item.builder));
                          },
                        ))
                    .toList(),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sign out'),
              onTap: () async {
                Navigator.pop(context);
                await FirebaseAuth.instance.signOut();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem {
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  _DrawerItem(this.label, this.icon, this.builder);
}
