import 'package:flutter/material.dart';

import '../../models/tenant.dart';
import '../../repositories/tenant_repository.dart';
import '../../widgets/common.dart';
import '../../widgets/status_badge.dart';
import 'tenant_detail_screen.dart';
import 'tenant_form_screen.dart';

class TenantListScreen extends StatefulWidget {
  const TenantListScreen({super.key});

  @override
  State<TenantListScreen> createState() => _TenantListScreenState();
}

class _TenantListScreenState extends State<TenantListScreen> {
  final _tenantRepo = TenantRepository();
  late Future<List<Tenant>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _tenantRepo.getAll();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tenants')),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const TenantFormScreen()));
          _refresh();
        },
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Tenant>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final tenants = snapshot.data!;
            if (tenants.isEmpty) {
              return ListView(
                children: const [EmptyState(message: 'No tenants yet. Tap + to add one.', icon: Icons.people_outline)],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: tenants.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final tenant = tenants[index];
                return Card(
                  child: ListTile(
                    title: Text(tenant.fullName),
                    subtitle: Text(tenant.mobileNumber ?? 'No mobile number'),
                    trailing: StatusBadge.forStatus(tenant.status),
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => TenantDetailScreen(tenantId: tenant.id!)));
                      _refresh();
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
