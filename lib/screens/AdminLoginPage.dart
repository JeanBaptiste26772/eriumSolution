import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'AssistanceSecuriteScreen.dart';
import 'OxygeneScreen.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({Key? key}) : super(key: key);

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final TextEditingController _identifiantController = TextEditingController();
  final TextEditingController _motDePasseController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _identifiantController.dispose();
    _motDePasseController.dispose();
    super.dispose();
  }

  // Fonction pour se connecter avec Firebase Auth
  Future<void> _seConnecter() async {
    final identifiant = _identifiantController.text.trim();
    final motDePasse = _motDePasseController.text.trim();

    // Vérifier que les champs ne sont pas vides
    if (identifiant.isEmpty || motDePasse.isEmpty) {
      _afficherErreur('Veuillez remplir tous les champs');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Convertir l'identifiant en email pour Firebase Auth
      final email = '$identifiant@erium.local';

      // Tenter de se connecter avec Firebase Auth
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: motDePasse,
      );

      // Connexion réussie - Naviguer vers l'écran principal
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const OxygeneScreen(),
          ),
              (route) => false, // Supprime toute la pile de navigation
        );
      }
    } on FirebaseAuthException catch (e) {
      // Gérer les erreurs de connexion
      String messageErreur;

      switch (e.code) {
        case 'user-not-found':
          messageErreur = 'Identifiant incorrect';
          break;
        case 'wrong-password':
          messageErreur = 'Mot de passe incorrect';
          break;
        case 'invalid-credential':
          messageErreur = 'Identifiant incorrect';
          break;
        case 'invalid-email':
          messageErreur = 'Format d\'identifiant invalide';
          break;
        case 'user-disabled':
          messageErreur = 'Ce compte a été désactivé';
          break;
        case 'too-many-requests':
          messageErreur = 'Trop de tentatives. Réessayez plus tard';
          break;
        case 'network-request-failed':
          messageErreur = 'Erreur réseau. Vérifiez votre connexion';
          break;
        default:
          messageErreur = 'Erreur de connexion: ${e.message}';
      }

      _afficherErreur(messageErreur);
    } catch (e) {
      _afficherErreur('Une erreur inattendue s\'est produite');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Afficher un message d'erreur
  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF3B30),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo de l'entreprise
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Image.asset(
                    'assets/images/logo_erium.jpg',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 32),

                // Titre
                const Text(
                  "Supervision d'EIS d'Erium\nBurkina",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Sous-titre
                Text(
                  "Connexion sécurisée administrateur",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[400],
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 48),

                // Carte de connexion
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Champ Identifiant
                      const Text(
                        "Identifiant",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _identifiantController,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          hintText: "admin_sys_01",
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF0B7FD9),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Champ Mot de passe
                      const Text(
                        "Mot de passe",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _motDePasseController,
                        enabled: !_isLoading,
                        obscureText: _obscurePassword,
                        onSubmitted: (_) => _seConnecter(),
                        decoration: InputDecoration(
                          hintText: "••••••••••••",
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 16,
                            letterSpacing: 2,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF0B7FD9),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey[400],
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF2C3E50),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Bouton Se connecter
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _seConnecter,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0B7FD9),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            disabledBackgroundColor: Colors.grey[300],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                              : const Text(
                            "Se connecter",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Lien Mot de passe oublié
                      Center(
                        child: TextButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AssistanceSecuriteScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            "Mot de passe oublié ?",
                            style: TextStyle(
                              color: Color(0xFF0B7FD9),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}