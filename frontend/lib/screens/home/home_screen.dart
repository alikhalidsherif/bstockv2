import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/app_config.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Scaffold(
          backgroundColor: AppConfig.backgroundColor,
          appBar: AppBar(
            title: Text(
              auth.organization?.name ?? 'Bstock',
              style: TextStyle(
                color: AppConfig.textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: AppConfig.backgroundColor,
            elevation: 0,
            actions: [
              IconButton(
                icon: Icon(Icons.logout, color: AppConfig.textColor),
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppConfig.textColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Phone: ${auth.user?.phoneNumber ?? "N/A"}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppConfig.subtextColor,
                  ),
                ),
                Text(
                  'Role: ${auth.role ?? "N/A"}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppConfig.subtextColor,
                  ),
                ),
                SizedBox(height: 32),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    children: [
                      _buildFeatureCard(
                        context,
                        icon: Icons.inventory_2_outlined,
                        title: 'Inventory',
                        color: AppConfig.primaryColor,
                      ),
                      _buildFeatureCard(
                        context,
                        icon: Icons.point_of_sale,
                        title: 'Sales',
                        color: AppConfig.successColor,
                      ),
                      _buildFeatureCard(
                        context,
                        icon: Icons.analytics_outlined,
                        title: 'Analytics',
                        color: Color(0xFFFF9500),
                      ),
                      _buildFeatureCard(
                        context,
                        icon: Icons.settings,
                        title: 'Settings',
                        color: AppConfig.subtextColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title - Coming Soon!')),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: color,
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppConfig.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
