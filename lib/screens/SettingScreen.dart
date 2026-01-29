import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import 'AdminLoginPage.dart';
import 'OxygeneScreen.dart';
import 'StatsScreen.dart';
import 'AlertesScreen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref('settings');
  final DatabaseReference _alertesRef = FirebaseDatabase.instance.ref('alertes');
  final TextEditingController _emailController = TextEditingController();

  bool _alertesCritiques = true;
  bool _rapportsEmail = true;
  bool _alertesEmail = false;
  bool _isLoading = true;
  int _nombreAlertesNonAcquittees = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _setupAlertesListener();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // Écouter le nombre d'alertes non acquittées
  void _setupAlertesListener() {
    _alertesRef.onValue.listen(
          (DatabaseEvent event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;

        if (mounted) {
          if (data != null) {
            int count = 0;
            data.forEach((key, value) {
              final alerte = Map<String, dynamic>.from(value);
              if (alerte['resolu'] == false && alerte['acquittee'] == false) {
                count++;
              }
            });

            setState(() {
              _nombreAlertesNonAcquittees = count;
            });
          } else {
            setState(() {
              _nombreAlertesNonAcquittees = 0;
            });
          }
        }
      },
      onError: (error) {
        print('Erreur alertes: $error');
      },
    );
  }

  void _loadSettings() {
    _databaseRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        setState(() {
          _alertesCritiques = data['alertesCritiques'] ?? true;
          _rapportsEmail = data['rapportsEmail'] ?? true;
          _alertesEmail = data['alertesEmail'] ?? false;
          _emailController.text = data['emailNotifications'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _saveSettings() {
    _databaseRef.set({
      'alertesCritiques': _alertesCritiques,
      'rapportsEmail': _rapportsEmail,
      'alertesEmail': _alertesEmail,
      'emailNotifications': _emailController.text.trim(),
    });
  }

  void _showEmailDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Configurer l\'email',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Saisissez l\'adresse email pour recevoir les alertes critiques',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF8E8E93),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'exemple@email.com',
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF0A7AFF)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF0A7AFF), width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Annuler',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (_emailController.text.trim().isNotEmpty &&
                    _emailController.text.contains('@')) {
                  _saveSettings();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Email enregistré avec succès'),
                      backgroundColor: Color(0xFF34C759),
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Veuillez saisir un email valide'),
                      backgroundColor: Color(0xFFFF3B30),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A7AFF),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Enregistrer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Réglages',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF0A7AFF),
        ),
      )
          : SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Carte Profil Admin
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A7AFF).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.engineering,
                      color: Color(0xFF0A7AFF),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Admin Principal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'admin@airliquide.com',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A7AFF).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: Color(0xFF0A7AFF),
                        size: 20,
                      ),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Section NOTIFICATIONS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'NOTIFICATIONS',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSwitchTile(
                    icon: Icons.sms_outlined,
                    iconColor: const Color(0xFFFF9500),
                    iconBgColor: const Color(0xFFFF9500).withOpacity(0.1),
                    title: 'Alertes Critiques (SMS)',
                    value: _alertesCritiques,
                    onChanged: (value) {
                      setState(() {
                        _alertesCritiques = value;
                      });
                      _saveSettings();
                    },
                  ),
                  const Divider(height: 1, indent: 88),
                  _buildSwitchTile(
                    icon: Icons.email_outlined,
                    iconColor: const Color(0xFF0A7AFF),
                    iconBgColor: const Color(0xFF0A7AFF).withOpacity(0.1),
                    title: 'Rapports par Email',
                    value: _rapportsEmail,
                    onChanged: (value) {
                      setState(() {
                        _rapportsEmail = value;
                      });
                      _saveSettings();
                    },
                  ),
                  const Divider(height: 1, indent: 88),
                  _buildEmailAlertTile(),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Section SÉCURITÉ
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'SÉCURITÉ',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildNavigationTile(
                    icon: Icons.lock_outline,
                    iconColor: const Color(0xFF8E8E93),
                    iconBgColor: const Color(0xFFF2F2F7),
                    title: 'Changer mot de passe',
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 88),
                  _buildNavigationTile(
                    icon: Icons.security_outlined,
                    iconColor: const Color(0xFF8E8E93),
                    iconBgColor: const Color(0xFFF2F2F7),
                    title: 'Double Authentification',
                    trailing: const Text(
                      'Activé',
                      style: TextStyle(
                        color: Color(0xFF34C759),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Section APPLICATION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'APPLICATION',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400],
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildNavigationTile(
                    icon: Icons.language_outlined,
                    iconColor: const Color(0xFF8E8E93),
                    iconBgColor: const Color(0xFFF2F2F7),
                    title: 'Langue',
                    trailing: const Text(
                      'Français',
                      style: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 15,
                      ),
                    ),
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: 88),
                  _buildNavigationTile(
                    icon: Icons.help_outline,
                    iconColor: const Color(0xFF8E8E93),
                    iconBgColor: const Color(0xFFF2F2F7),
                    title: 'Aide & Support',
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Bouton Déconnexion
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminLoginPage(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Déconnexion',
                  style: TextStyle(
                    color: Color(0xFFFF3B30),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildEmailAlertTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFF3B30).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.mark_email_unread_outlined,
              color: Color(0xFFFF3B30),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alertes Critiques (Email)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                if (_alertesEmail && _emailController.text.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _emailController.text,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8E8E93),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (_alertesEmail) ...[
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF0A7AFF), size: 20),
              onPressed: _showEmailDialog,
            ),
            const SizedBox(width: 4),
          ],
          Switch(
            value: _alertesEmail,
            onChanged: (value) {
              if (value && _emailController.text.isEmpty) {
                _showEmailDialog();
              }
              setState(() {
                _alertesEmail = value;
              });
              _saveSettings();
            },
            activeColor: const Color(0xFF0A7AFF),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF0A7AFF),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
            if (trailing != null) ...[
              trailing,
              const SizedBox(width: 8),
            ],
            const Icon(
              Icons.chevron_right,
              color: Color(0xFF8E8E93),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.dashboard, 'Monitor', false),
              _buildNavItem(Icons.show_chart, 'Stats', false),
              _buildNavItem(Icons.notifications_outlined, 'Alertes', false),
              _buildNavItem(Icons.settings, 'Réglages', true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return GestureDetector(
      onTap: () {
        if (!isActive) {
          switch (label) {
            case 'Monitor':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OxygeneScreen(),
                ),
              );
              break;
            case 'Stats':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const StatsScreen(),
                ),
              );
              break;
            case 'Alertes':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AlertesScreen(),
                ),
              );
              break;
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isActive
                      ? const Color(0xFF0A7AFF)
                      : const Color(0xFF8E8E93),
                  size: 24,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive
                        ? const Color(0xFF0A7AFF)
                        : const Color(0xFF8E8E93),
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
            // Badge pour les alertes
            if (label == 'Alertes' && _nombreAlertesNonAcquittees > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _nombreAlertesNonAcquittees > 9
                        ? '9+'
                        : '$_nombreAlertesNonAcquittees',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}