import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class AlertesScreen extends StatefulWidget {
  const AlertesScreen({Key? key}) : super(key: key);

  @override
  State<AlertesScreen> createState() => _AlertesScreenState();
}

class _AlertesScreenState extends State<AlertesScreen> {
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref();

  List<Map<String, dynamic>> _alertesEnCours = [];
  List<Map<String, dynamic>> _alertesHistorique = [];
  bool _isLoading = true;
  bool _showEnCours = true;

  // Données des tanks pour surveillance
  double _pressionOxygene = 0.0;
  double _pressionCO2 = 0.0;
  double _temperatureOxygene = 0.0;
  double _temperatureCO2 = 0.0;

  @override
  void initState() {
    super.initState();
    _setupRealtimeListeners();
    _loadAlertesFromDatabase();
  }

  void _setupRealtimeListeners() {
    // Surveillance du tank d'oxygène
    _databaseRef.child('tanks/oxygene').onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _pressionOxygene = (data['pression'] ?? 0).toDouble();
          _temperatureOxygene = (data['temperature'] ?? 0).toDouble();
        });
        _checkAndCreateAlert('Oxygène', _pressionOxygene, _temperatureOxygene);
      }
    });

    // Surveillance du tank de CO2
    _databaseRef.child('tanks/co2').onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _pressionCO2 = (data['pression'] ?? 0).toDouble();
          _temperatureCO2 = (data['temperature'] ?? 0).toDouble();
        });
        _checkAndCreateAlert('CO₂', _pressionCO2, _temperatureCO2);
      }
    });
  }

  void _checkAndCreateAlert(String tankName, double pression, double temperature) {
    // Vérifier si la pression dépasse 17 bars
    if (pression > 17) {
      _createAlert(
        type: 'CRITIQUE',
        titre: 'Surpression $tankName',
        description: 'Pression critique détectée: ${pression.toStringAsFixed(1)} bars',
        tankName: tankName,
        valeur: pression,
        probleme: 'surpression',
      );
    }
    // Vérifier si la pression est trop basse
    else if (pression < 12) {
      _createAlert(
        type: 'CRITIQUE',
        titre: 'Pression Basse $tankName',
        description: 'Pression insuffisante: ${pression.toStringAsFixed(1)} bars',
        tankName: tankName,
        valeur: pression,
        probleme: 'pression_basse',
      );
    }

    // Vérifier la température
    if (temperature > 35) {
      _createAlert(
        type: 'AVERTISSEMENT',
        titre: 'Température Élevée',
        description: 'Température élevée détectée: ${temperature.toStringAsFixed(1)}°C sur tank $tankName',
        tankName: tankName,
        valeur: temperature,
        probleme: 'temperature_elevee',
      );
    }

    // Vérifier si les problèmes sont résolus et mettre à jour les alertes en conséquence
    _verifierResolutionProblemes(tankName, pression, temperature);
  }

  void _verifierResolutionProblemes(String tankName, double pression, double temperature) {
    // Parcourir les alertes en cours pour ce tank
    for (var alerte in _alertesEnCours) {
      if (alerte['tankName'] == tankName && alerte['resolu'] != true) {
        bool problemResolu = false;

        // Vérifier selon le type de problème
        String probleme = alerte['probleme'] ?? '';

        if (probleme == 'surpression' && pression <= 17) {
          problemResolu = true;
        } else if (probleme == 'pression_basse' && pression >= 12) {
          problemResolu = true;
        } else if (probleme == 'temperature_elevee' && temperature <= 35) {
          problemResolu = true;
        }

        // Si le problème est résolu, marquer l'alerte comme résolue
        if (problemResolu) {
          String alerteId = alerte['id'];
          _databaseRef.child('alertes/$alerteId').update({
            'resolu': true,
            'dateResolution': DateTime.now().toIso8601String(),
          });
        }
      }
    }
  }

  void _createAlert({
    required String type,
    required String titre,
    required String description,
    required String tankName,
    required double valeur,
    required String probleme,
  }) {
    final alerteId = DateTime.now().millisecondsSinceEpoch.toString();
    final alerteData = {
      'id': alerteId,
      'type': type,
      'titre': titre,
      'description': description,
      'tankName': tankName,
      'valeur': valeur,
      'probleme': probleme,
      'timestamp': DateTime.now().toIso8601String(),
      'acquittee': false,
      'resolu': false,
    };

    // Vérifier si une alerte similaire existe déjà
    bool alerteExiste = _alertesEnCours.any((alerte) =>
    alerte['titre'] == titre &&
        alerte['resolu'] == false
    );

    if (!alerteExiste) {
      _databaseRef.child('alertes/$alerteId').set(alerteData);
    }
  }

  void _loadAlertesFromDatabase() {
    _databaseRef.child('alertes').onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null) {
        List<Map<String, dynamic>> enCours = [];
        List<Map<String, dynamic>> historique = [];

        data.forEach((key, value) {
          final alerte = Map<String, dynamic>.from(value);
          alerte['id'] = key;

          if (alerte['resolu'] == true) {
            historique.add(alerte);
          } else {
            enCours.add(alerte);
          }
        });

        // Trier par timestamp (plus récent en premier)
        enCours.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
        historique.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));

        setState(() {
          _alertesEnCours = enCours;
          _alertesHistorique = historique;
          _isLoading = false;
        });
      } else {
        setState(() {
          _alertesEnCours = [];
          _alertesHistorique = [];
          _isLoading = false;
        });
      }
    });
  }

  void _acquitterAlerte(String alerteId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Prendre connaissance',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: const Text(
            'Confirmez-vous avoir pris connaissance de cette alerte ?\n\nNote: L\'alerte restera en cours jusqu\'à ce que les valeurs redeviennent normales.',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF8E8E93),
            ),
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
                _databaseRef.child('alertes/$alerteId').update({
                  'acquittee': true,
                  'dateAcquittement': DateTime.now().toIso8601String(),
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Prise de connaissance enregistrée'),
                    backgroundColor: Color(0xFF34C759),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A7AFF),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Confirmer',
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

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'À l\'instant';
      } else if (difference.inHours < 1) {
        return 'Il y a ${difference.inMinutes} min';
      } else if (difference.inDays < 1) {
        return DateFormat('HH:mm').format(dateTime);
      } else {
        return DateFormat('dd/MM, HH:mm').format(dateTime);
      }
    } catch (e) {
      return 'Date inconnue';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabSelector(),
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF0A7AFF),
                ),
              )
                  : _buildAlertesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Text(
            'Alertes',
            style: TextStyle(
              color: Color(0xFF0A7AFF),
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (_alertesEnCours.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFF3B30),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_active,
                color: Colors.white,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showEnCours = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _showEnCours ? const Color(0xFF0A7AFF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'En cours',
                      style: TextStyle(
                        color: _showEnCours ? Colors.white : const Color(0xFF8E8E93),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_alertesEnCours.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _showEnCours ? Colors.white : const Color(0xFF0A7AFF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_alertesEnCours.length}',
                          style: TextStyle(
                            color: _showEnCours ? const Color(0xFF0A7AFF) : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showEnCours = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_showEnCours ? const Color(0xFF0A7AFF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Historique',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !_showEnCours ? Colors.white : const Color(0xFF8E8E93),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertesList() {
    final alertes = _showEnCours ? _alertesEnCours : _alertesHistorique;

    if (alertes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showEnCours ? Icons.check_circle_outline : Icons.history,
              size: 64,
              color: const Color(0xFFE5E5EA),
            ),
            const SizedBox(height: 16),
            Text(
              _showEnCours ? 'Aucune alerte en cours' : 'Aucun historique',
              style: const TextStyle(
                color: Color(0xFF8E8E93),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tout fonctionne normalement',
              style: TextStyle(
                color: Color(0xFFAEAEB2),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: alertes.length,
      itemBuilder: (context, index) {
        final alerte = alertes[index];
        return _buildAlerteCard(alerte);
      },
    );
  }

  Widget _buildAlerteCard(Map<String, dynamic> alerte) {
    final type = alerte['type'] ?? 'INFO';
    final titre = alerte['titre'] ?? 'Alerte';
    final description = alerte['description'] ?? '';
    final timestamp = alerte['timestamp'] ?? '';
    final acquittee = alerte['acquittee'] ?? false;
    final resolu = alerte['resolu'] ?? false;
    final alerteId = alerte['id'] ?? '';

    Color couleurBordure;
    Color couleurIcon;
    Color couleurFond;
    IconData icon;

    if (resolu) {
      // Alerte résolue (dans l'historique)
      couleurBordure = const Color(0xFF34C759);
      couleurIcon = const Color(0xFF34C759);
      couleurFond = Colors.white;
      icon = Icons.check_circle;
    } else {
      // Alerte en cours
      switch (type) {
        case 'CRITIQUE':
          couleurBordure = const Color(0xFFFF3B30);
          couleurIcon = const Color(0xFFFF3B30);
          couleurFond = const Color(0xFFFFF5F5);
          icon = Icons.error_outline;
          break;
        case 'AVERTISSEMENT':
          couleurBordure = const Color(0xFFFF9500);
          couleurIcon = const Color(0xFFFF9500);
          couleurFond = const Color(0xFFFFF8F0);
          icon = Icons.warning_amber;
          break;
        default:
          couleurBordure = const Color(0xFF0A7AFF);
          couleurIcon = const Color(0xFF0A7AFF);
          couleurFond = const Color(0xFFF0F7FF);
          icon = Icons.info_outline;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: resolu ? Colors.white : couleurFond,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: resolu ? const Color(0xFFE5E5EA) : couleurBordure,
          width: resolu ? 1 : 2,
        ),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: couleurIcon.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: couleurIcon,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              titre,
                              style: TextStyle(
                                color: resolu ? const Color(0xFF8E8E93) : Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                decoration: resolu ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          Text(
                            _formatTimestamp(timestamp),
                            style: const TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          description,
                          style: TextStyle(
                            color: resolu
                                ? const Color(0xFFAEAEB2)
                                : const Color(0xFF8E8E93),
                            fontSize: 14,
                          ),
                        ),
                      ],
                      if (!resolu) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (acquittee)
                              Row(
                                children: const [
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: Color(0xFF34C759),
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Pris en compte',
                                    style: TextStyle(
                                      color: Color(0xFF34C759),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            else if (type == 'CRITIQUE')
                              Row(
                                children: const [
                                  Icon(
                                    Icons.shield_outlined,
                                    color: Color(0xFFFF3B30),
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Action requise',
                                    style: TextStyle(
                                      color: Color(0xFFFF3B30),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                      if (resolu) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: const [
                            Icon(
                              Icons.check_circle,
                              color: Color(0xFF34C759),
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Problème résolu',
                              style: TextStyle(
                                color: Color(0xFF34C759),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!resolu && !acquittee)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: couleurBordure.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => _acquitterAlerte(alerteId),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(14),
                            bottomRight: Radius.circular(14),
                          ),
                        ),
                      ),
                      child: Text(
                        'Prendre connaissance',
                        style: TextStyle(
                          color: couleurIcon,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}