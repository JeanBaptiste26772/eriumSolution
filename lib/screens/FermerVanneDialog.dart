import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class FermerVanneDialog extends StatefulWidget {
  final String? tankId;

  const FermerVanneDialog({Key? key, this.tankId}) : super(key: key);

  @override
  State<FermerVanneDialog> createState() => _FermerVanneDialogState();
}

class _FermerVanneDialogState extends State<FermerVanneDialog> {
  final List<TextEditingController> _pinControllers = List.generate(
    4,
        (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    4,
        (index) => FocusNode(),
  );

  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String _getPinValue() {
    return _pinControllers.map((c) => c.text).join();
  }

  /// Vérifie le PIN dans Firebase
  Future<bool> _verifyPinFromFirebase(String enteredPin) async {
    try {
      final DatabaseReference pinRef =
      FirebaseDatabase.instance.ref('settings/operator_pin');

      final snapshot = await pinRef.get();

      if (!snapshot.exists) {
        // Si le PIN n'existe pas dans Firebase, on peut le créer
        // avec une valeur par défaut (optionnel)
        return false;
      }

      final storedPin = snapshot.value as String;
      return enteredPin == storedPin;
    } catch (e) {
      print('Erreur lors de la vérification du PIN: $e');
      return false;
    }
  }

  Future<void> _handleConfirm() async {
    final pin = _getPinValue();

    if (pin.length != 4) {
      setState(() {
        _errorMessage = 'Veuillez entrer les 4 chiffres du PIN';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // Vérifier le PIN avec Firebase
      final isPinCorrect = await _verifyPinFromFirebase(pin);

      if (!isPinCorrect) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'PIN incorrect. Veuillez réessayer.';
        });
        return;
      }

      String tankId = widget.tankId ?? 'oxygene';

      final DatabaseReference tankRef =
      FirebaseDatabase.instance.ref('tanks/$tankId');
      final DatabaseReference historiqueRef =
      FirebaseDatabase.instance.ref('historique/$tankId');

      // 1. Mettre à jour l'état de la vanne
      await tankRef.update({
        'etat_vanne': 'ferme',
      });

      // 2. Enregistrer dans l'historique
      await historiqueRef.push().set({
        'action': 'ferme',
        'timestamp': DateTime.now().toIso8601String(),
        'user': 'admin_sys_01',
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Vanne fermée avec succès'),
              ],
            ),
            backgroundColor: Color(0xFFFF3B30),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtenir la taille de l'écran
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculer les dimensions adaptatives
    final dialogPadding = screenWidth < 360 ? 16.0 : 24.0;
    final iconSize = screenWidth < 360 ? 48.0 : 56.0;
    final pinBoxSize = screenWidth < 360 ? 50.0 : 60.0;
    final titleFontSize = screenWidth < 360 ? 18.0 : 20.0;
    final descriptionFontSize = screenWidth < 360 ? 13.0 : 14.0;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: screenHeight * 0.1,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.8,
          maxWidth: 500,
        ),
        child: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.all(dialogPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icône
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFE5E5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    color: const Color(0xFFFF3B30),
                    size: iconSize * 0.57,
                  ),
                ),
                SizedBox(height: screenWidth < 360 ? 16 : 20),

                // Titre
                Text(
                  'Fermer la vanne',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  'Cette action nécessite une confirmation. Entrez votre PIN pour confirmer la fermeture.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: descriptionFontSize,
                    color: const Color(0xFF8E8E93),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: screenWidth < 360 ? 20 : 24),

                // Label
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'PIN de l\'opérateur',
                    style: TextStyle(
                      fontSize: descriptionFontSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Cases PIN - Responsive avec espacement adaptatif
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(4, (index) {
                    return Container(
                      width: pinBoxSize,
                      height: pinBoxSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFF0A7AFF),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _pinControllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        obscureText: true,
                        style: TextStyle(
                          fontSize: screenWidth < 360 ? 20 : 24,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && index < 3) {
                            _focusNodes[index + 1].requestFocus();
                          }
                          if (value.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                          // Efface l'erreur quand l'user tape
                          if (_errorMessage.isNotEmpty) {
                            setState(() {
                              _errorMessage = '';
                            });
                          }
                        },
                      ),
                    );
                  }),
                ),

                // Message d'erreur
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE5E5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFFF3B30),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                              color: Color(0xFFFF3B30),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: screenWidth < 360 ? 20 : 24),

                // Boutons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            vertical: screenWidth < 360 ? 12 : 16,
                          ),
                        ),
                        child: Text(
                          'Annuler',
                          style: TextStyle(
                            fontSize: screenWidth < 360 ? 15 : 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF8E8E93),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3B30),
                          padding: EdgeInsets.symmetric(
                            vertical: screenWidth < 360 ? 12 : 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : Text(
                          'Confirmer',
                          style: TextStyle(
                            fontSize: screenWidth < 360 ? 15 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}