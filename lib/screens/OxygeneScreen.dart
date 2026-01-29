import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'Co2Screen.dart';
import 'FermerVanneDialog.dart';
import 'OuvrirVanneDialog.dart';
import 'SettingScreen.dart';
import 'StatsScreen.dart';
import 'AlertesScreen.dart';

class OxygeneScreen extends StatefulWidget {
  const OxygeneScreen({Key? key}) : super(key: key);

  @override
  State<OxygeneScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<OxygeneScreen> {
  // Références Firebase (nullable pour initialisation lazy)
  DatabaseReference? _databaseRef;
  DatabaseReference? _alertesRef;
  bool _firebaseReady = false;

  // Variables pour stocker les données
  double _pression = 0.0;
  double _temperature = 0.0;
  int _niveau = 0;
  String _etatVanne = 'inconnu';
  String _statut = 'Chargement...';
  bool _isLoading = true;
  int _nombreAlertesNonAcquittees = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Attend la frame suivante puis initialise Firebase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeFirebase();
      }
    });
  }

  // Initialisation Firebase après que l'app soit prête
  void _initializeFirebase() {
    try {
      setState(() {
        _databaseRef = FirebaseDatabase.instance.ref('tanks/oxygene');
        _alertesRef = FirebaseDatabase.instance.ref('alertes');
        _firebaseReady = true;
      });
      _setupRealtimeListener();
      _setupAlertesListener();
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur Firebase: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // Écouter les changements en temps réel depuis Firebase
  void _setupRealtimeListener() {
    if (_databaseRef == null) return;

    _databaseRef!.onValue.listen(
          (DatabaseEvent event) {
        final data = event.snapshot.value as Map<dynamic, dynamic>?;

        if (data != null && mounted) {
          setState(() {
            _pression = (data['pression'] ?? 0).toDouble();
            _temperature = (data['temperature'] ?? 0).toDouble();
            _niveau = (data['niveau'] ?? 0).toInt();
            _etatVanne = data['etat_vanne'] ?? 'inconnu';
            _statut = data['statut'] ?? 'Stable';
            _isLoading = false;
            _errorMessage = null;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Erreur de connexion Firebase';
            _isLoading = false;
          });
        }
      },
    );
  }

  // Écouter le nombre d'alertes non acquittées
  void _setupAlertesListener() {
    if (_alertesRef == null) return;

    _alertesRef!.onValue.listen(
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

  @override
  Widget build(BuildContext context) {
    // Afficher l'erreur si présente
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Color(0xFFFF3B30),
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                      _isLoading = true;
                    });
                    _initializeFirebase();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A7AFF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Afficher le chargement si Firebase n'est pas prêt
    if (!_firebaseReady || _isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F5),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFF0A7AFF),
              ),
              SizedBox(height: 16),
              Text(
                'Connexion en cours...',
                style: TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cartes Pression et Température côte à côte (comme CO2)
                    Row(
                      children: [
                        Expanded(child: _buildPressionCard()),
                        const SizedBox(width: 16),
                        Expanded(child: _buildTemperatureCard()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTankLevelCard(),
                    const SizedBox(height: 24),
                    _buildOxygenTankControl(),
                    const SizedBox(height: 16),
                    _buildSwitchButton(),
                  ],
                ),
              ),
            ),
            _buildBottomNavigation(),
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
        color: Color(0xFF0A7AFF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header responsive
          LayoutBuilder(
            builder: (context, constraints) {
              // Si l'écran est très petit, empiler verticalement
              if (constraints.maxWidth < 350) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Système de\nsupervision',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.bar_chart, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Erium Burkina',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              } else {
                // Écrans normaux : côte à côte
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'Système de\nsupervision',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.bar_chart, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Erium Burkina',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF34C759),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'Administrateur du système',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPressionCard() {
    // Calcul dynamique du statut et de la couleur
    String pressionStatut = 'Normal';
    Color pressionCouleur = const Color(0xFF34C759);
    double pressionFactor = 0.5;

    if (_pression < 12) {
      pressionStatut = 'Bas';
      pressionCouleur = const Color(0xFFFF3B30);
      pressionFactor = _pression / 16;
    } else if (_pression > 16) {
      pressionStatut = 'Haut';
      pressionCouleur = const Color(0xFFFF9500);
      pressionFactor = 1.0;
    } else {
      pressionFactor = _pression / 16;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        double cardPadding = constraints.maxWidth < 180 ? 12 : 20;

        return Container(
          padding: EdgeInsets.all(cardPadding),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5EA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.speed,
                      color: Color(0xFF8E8E93),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Pression',
                      style: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: _pression.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(
                        text: ' bars',
                        style: TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: pressionFactor.clamp(0.0, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: pressionCouleur,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'Norme: 12-16',
                      style: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    pressionStatut,
                    style: TextStyle(
                      color: pressionCouleur,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTemperatureCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double cardPadding = constraints.maxWidth < 180 ? 12 : 20;

        return Container(
          padding: EdgeInsets.all(cardPadding),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A7AFF).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.thermostat,
                      color: Color(0xFF0A7AFF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Temp',
                      style: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: _temperature.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(
                        text: ' °C',
                        style: TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: (_temperature / 100).clamp(0.0, 1.0),
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A7AFF),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _statut,
                  style: const TextStyle(
                    color: Color(0xFF34C759),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTankLevelCard() {
    // Déterminer le statut du niveau
    String niveauTexte = 'Bas';
    Color niveauCouleur = const Color(0xFFFF3B30);

    if (_niveau >= 70) {
      niveauTexte = 'Plein';
      niveauCouleur = const Color(0xFF34C759);
    } else if (_niveau >= 40) {
      niveauTexte = 'Moyen';
      niveauCouleur = const Color(0xFFFF9500);
    }

    return Container(
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A7AFF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.waves,
              color: Color(0xFF0A7AFF),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Niveau du tank',
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      flex: 0,
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$_niveau%',
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: '  $niveauTexte',
                              style: const TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E5EA),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: (_niveau / 100).clamp(0.0, 1.0),
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: niveauCouleur,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOxygenTankControl() {
    bool vanneOuverte = _etatVanne.toLowerCase() == 'ouvert';

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'Contrôle du Tank d\'oxygène',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Com',
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF2F2F7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.settings,
                      color: Color(0xFF8E8E93),
                      size: 28,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: vanneOuverte
                            ? const Color(0xFF34C759)
                            : const Color(0xFFFF3B30),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vanneOuverte ? 'Ecoulement' : 'Fermé',
                      style: TextStyle(
                        color: vanneOuverte
                            ? const Color(0xFF34C759)
                            : const Color(0xFFFF3B30),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          color: Color(0xFF0A7AFF),
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Double validation requise',
                            style: TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF8E8E93),
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: vanneOuverte
                      ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FermerVanneDialog(),
                      ),
                    );
                  }
                      : null,
                  icon: const Icon(Icons.power_settings_new, color: Color(0xFFFF3B30)),
                  label: const Text(
                    'Fermer',
                    style: TextStyle(
                      color: Color(0xFFFF3B30),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFFFF3B30), width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: !vanneOuverte
                      ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OuvrirVanneDialog(),
                      ),
                    );
                  }
                      : null,
                  icon: const Icon(Icons.toggle_on, color: Colors.white, size: 24),
                  label: const Text(
                    'Ouvrir vanne',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A7AFF),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const Co2Screen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.sync,
              color: Color(0xFF0A7AFF),
              size: 20,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'Basculer vers contrôle Tank CO',
                      style: TextStyle(
                        color: Color(0xFF0A7AFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: '₂',
                      style: TextStyle(
                        color: Color(0xFF0A7AFF),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
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
              _buildNavItem(Icons.dashboard, 'Monitor', true),
              _buildNavItem(Icons.show_chart, 'Stats', false),
              _buildNavItem(Icons.notifications_outlined, 'Alertes', false),
              _buildNavItem(Icons.settings_outlined, 'Réglages', false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive) {
    return GestureDetector(
      onTap: () {
        switch (label) {
          case 'Monitor':
            print('Déjà sur Monitor');
            break;
          case 'Stats':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StatsScreen(),
              ),
            );
            print('Navigation vers Stats');
            break;
          case 'Alertes':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AlertesScreen(),
              ),
            );
            break;
          case 'Réglages':
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SettingsScreen(),
              ),
            );
            print('Navigation vers Réglages');
            break;
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
                  color: isActive ? const Color(0xFF0A7AFF) : const Color(0xFF8E8E93),
                  size: 24,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? const Color(0xFF0A7AFF) : const Color(0xFF8E8E93),
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