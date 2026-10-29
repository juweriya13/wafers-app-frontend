import 'package:flutter/material.dart';
import '../auth_service.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback onLogout;
  final VoidCallback onProfileUpdated;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onLogout,
    required this.onProfileUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserModel _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  void _showEditDietDialog() {
    String selectedDiet = _currentUser.dietaryPreference;
    final List<String> options = ['Veg', 'Non-Veg', 'Vegan', 'Jain'];
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? const Color(0xFFD4B996) : const Color(0xFF4A2E1B);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Dietary Preference', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((opt) {
              return RadioListTile<String>(
                activeColor: primaryColor,
                title: Text(opt),
                value: opt,
                groupValue: selectedDiet,
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedDiet = val);
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final updated = _currentUser.copyWith(dietaryPreference: selectedDiet);
                await AuthService.updateProfile(updated);
                if (mounted) {
                  setState(() => _currentUser = updated);
                  widget.onProfileUpdated();
                }
              },
              child: Text('Save', style: TextStyle(color: isDark ? const Color(0xFF121212) : Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmLogoutDialog() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to sign out of your account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              await AuthService.logout();
              widget.onLogout();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9F6F0);
    final Color surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final Color primaryColor = isDark ? const Color(0xFFD4B996) : const Color(0xFF4A2E1B);
    final Color onPrimaryColor = isDark ? const Color(0xFF121212) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF3E2723);
    final Color textSecondaryColor = isDark ? Colors.white54 : const Color(0xFF8D7B68);
    final Color borderColor = isDark ? Colors.white10 : const Color(0xFFEBE3D5);

    String initials = _currentUser.fullName.isNotEmpty
        ? _currentUser.fullName.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Profile & Settings',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Header Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 42,
                      backgroundColor: primaryColor,
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: onPrimaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _currentUser.fullName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${_currentUser.username} • ${_currentUser.email}',
                      style: TextStyle(fontSize: 13, color: textSecondaryColor),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: primaryColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, size: 16, color: primaryColor),
                          const SizedBox(width: 6),
                          Text(
                            _currentUser.isGuest ? 'Guest Access' : 'Verified Health Scanner',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Quick Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildStatTile(
                      icon: Icons.qr_code_scanner,
                      label: 'Total Scans',
                      value: '${_currentUser.totalScans}',
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      primaryColor: primaryColor,
                      textSecondaryColor: textSecondaryColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildStatTile(
                      icon: Icons.eco_outlined,
                      label: 'Preference',
                      value: _currentUser.dietaryPreference,
                      surfaceColor: surfaceColor,
                      borderColor: borderColor,
                      textColor: textColor,
                      primaryColor: primaryColor,
                      textSecondaryColor: textSecondaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Account & Preferences List
              Text(
                'Personalization',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    _buildSettingsTile(
                      icon: Icons.restaurant_menu_rounded,
                      title: 'Dietary Preference',
                      subtitle: _currentUser.dietaryPreference,
                      onTap: _showEditDietDialog,
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                      primaryColor: primaryColor,
                    ),
                    Divider(height: 1, color: borderColor),
                    _buildSettingsTile(
                      icon: Icons.family_restroom_rounded,
                      title: 'Target Focus',
                      subtitle: _currentUser.targetGroup,
                      onTap: () {},
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                      primaryColor: primaryColor,
                    ),
                    Divider(height: 1, color: borderColor),
                    _buildSettingsTile(
                      icon: Icons.calendar_today_rounded,
                      title: 'Member Since',
                      subtitle: _currentUser.memberSince,
                      onTap: null,
                      textColor: textColor,
                      textSecondaryColor: textSecondaryColor,
                      primaryColor: primaryColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Logout Button
              ElevatedButton.icon(
                onPressed: _showConfirmLogoutDialog,
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('Sign Out of NutriLens', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  foregroundColor: Colors.red,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: Colors.red.withOpacity(0.2)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String label,
    required String value,
    required Color surfaceColor,
    required Color borderColor,
    required Color textColor,
    required Color primaryColor,
    required Color textSecondaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: primaryColor, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: textSecondaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    required Color textColor,
    required Color textSecondaryColor,
    required Color primaryColor,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: primaryColor, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: textColor, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(color: textSecondaryColor, fontSize: 12)),
      trailing: onTap != null
          ? Icon(Icons.arrow_forward_ios_rounded, size: 14, color: textSecondaryColor)
          : null,
      onTap: onTap,
    );
  }
}
