import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

import 'OxygeneScreen.dart';
import 'SettingScreen.dart';
import 'AlertesScreen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _selectedTank = 'oxygene'; // Tank sélectionné par défaut

  // Données du tank sélectionné
  double _pression = 0.0;
  double _temperature = 0.0;
  int _niveau = 0;
  String _etatVanne = 'inconnu';
  bool _isLoading = true;
  int _nombreAlertesNonAcquittees = 0;

  // Référence Firebase pour les alertes
  final DatabaseReference _alertesRef = FirebaseDatabase.instance.ref('alertes');

  // Valeurs de référence pour calculer les variations
  final Map<String, double> _referencePression = {
    'oxygene': 14.0,
    'co2': 45.0,
    'acetylene': 12.0,
  };

  final Map<String, double> _referenceTemperature = {
    'oxygene': 60.0,
    'co2': -20.0,
    'acetylene': 20.0,
  };

  @override
  void initState() {
    super.initState();
    _loadTankData();
    _setupAlertesListener();
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

  void _loadTankData() {
    setState(() {
      _isLoading = true;
    });

    final DatabaseReference tankRef = FirebaseDatabase.instance.ref('tanks/$_selectedTank');

    tankRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;

      if (data != null && mounted) {
        setState(() {
          _pression = (data['pression'] ?? 0).toDouble();
          _temperature = (data['temperature'] ?? 0).toDouble();
          _niveau = (data['niveau'] ?? 0).toInt();
          _etatVanne = data['etat_vanne'] ?? 'inconnu';
          _isLoading = false;
        });
      }
    });
  }

  void _switchTank(String tank) {
    setState(() {
      _selectedTank = tank;
    });
    _loadTankData();
  }

  // Calcul de la variation en pourcentage
  double _calculateVariation(double current, double reference) {
    if (reference == 0) return 0;
    return ((current - reference) / reference) * 100;
  }

  // Fonction helper pour obtenir la version Android
  Future<int> _getAndroidVersion() async {
    if (Platform.isAndroid) {
      // Par défaut, on suppose Android 13+
      // Vous pouvez utiliser device_info_plus pour obtenir la vraie version
      return 33;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF0A7AFF),
                ),
              )
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTankSelector(),
                    const SizedBox(height: 24),
                    _buildStatsCards(),
                    const SizedBox(height: 24),
                    _buildPressureChart(),
                    const SizedBox(height: 24),
                    _buildRecentReports(),
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
        color: Colors.white,
      ),
      child: const Text(
        'Statistiques',
        style: TextStyle(
          color: Color(0xFF0A7AFF),
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTankSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          _buildTabButton('Dioxygène', 'oxygene'),
          _buildTabButton('CO₂', 'co2'),
          _buildTabButton('Acétylène', 'acetylene'),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, String tankId) {
    final bool isSelected = _selectedTank == tankId;

    return Expanded(
      child: GestureDetector(
        onTap: () => _switchTank(tankId),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0A7AFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF8E8E93),
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    double tempVariation = _calculateVariation(
        _temperature, _referenceTemperature[_selectedTank] ?? 0);

    double niveauVariation = _calculateVariation(
        _niveau.toDouble(), 75.0 // Référence pour le niveau
    );

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Température\nmoyenne',
            '${_temperature.toStringAsFixed(1)}°C',
            tempVariation,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Niveau\nmoyen',
            '$_niveau%',
            niveauVariation,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, double variation) {
    final bool isPositive = variation >= 0;
    final Color variationColor =
    isPositive ? const Color(0xFF34C759) : const Color(0xFFFF3B30);

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
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF8E8E93),
              fontSize: 14,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${isPositive ? '+' : ''}${variation.toStringAsFixed(1)}%',
            style: TextStyle(
              color: variationColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPressureChart() {
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
          const Text(
            'Pression Moyenne (Bars)',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: _buildBarChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    // Simulation de données basées sur la pression actuelle
    final List<double> weekData = [
      _pression * 0.9,
      _pression * 0.95,
      _pression * 0.92,
      _pression * 1.05,
      _pression * 0.98,
      _pression, // Aujourd'hui (mis en évidence)
      _pression * 0.97,
    ];

    final double maxValue = weekData.reduce((a, b) => a > b ? a : b);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (index) {
        final double value = weekData[index];
        final double heightFactor = value / maxValue;
        final bool isToday = index == 5;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(
                    color: isToday
                        ? const Color(0xFFFFB800)
                        : const Color(0xFF8E8E93),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 150 * heightFactor,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isToday
                          ? [
                        const Color(0xFFFFB800),
                        const Color(0xFFFFB800)
                      ]
                          : [
                        const Color(0xFF0A7AFF),
                        const Color(0xFF0A7AFF).withOpacity(0.3)
                      ],
                    ),
                    borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildRecentReports() {
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
              const Text(
                'Rapports Récents',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Afficher tous les rapports
                  print('Voir tous les rapports');
                },
                child: const Text(
                  'Voir tout',
                  style: TextStyle(
                    color: Color(0xFF0A7AFF),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildReportItem(
            'Rapport Mensuel',
            'Octobre 2023 • PDF',
            Colors.blue.shade50,
            Icons.picture_as_pdf,
          ),
          const SizedBox(height: 12),
          _buildReportItem(
            'Données Capteurs',
            'Export CSV • 4.4 MB',
            Colors.green.shade50,
            Icons.table_chart,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _exportReport();
              },
              icon: const Icon(Icons.download, size: 20),
              label: const Text(
                'Exporter Rapport Complet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A7AFF),
                foregroundColor: Colors.white,
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
    );
  }

  Widget _buildReportItem(
      String title, String subtitle, Color bgColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.grey.shade700, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Fonction d'export améliorée
  void _exportReport() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Exporter Rapport',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choisissez le format d\'export :',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              _buildExportOption('PDF', Icons.picture_as_pdf),
              const SizedBox(height: 8),
              _buildExportOption('CSV', Icons.table_chart),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExportOption(String format, IconData icon) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _performExport(format);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E5EA)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF0A7AFF)),
            const SizedBox(width: 12),
            Text(
              'Exporter en $format',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Fonction pour effectuer l'export réel
  Future<void> _performExport(String format) async {
    // Afficher un message de chargement
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Text('Génération du rapport $format...'),
          ],
        ),
        backgroundColor: const Color(0xFF0A7AFF),
        duration: const Duration(seconds: 3),
      ),
    );

    try {
      String filePath;

      if (format == 'PDF') {
        filePath = await _generatePDF();
      } else {
        filePath = await _generateCSV();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Rapport $format exporté!\n$filePath'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF34C759),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Erreur: $e')),
              ],
            ),
            backgroundColor: const Color(0xFFFF3B30),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<String> _generatePDF() async {
    final pdf = pw.Document();

    // Récupérer le nom du tank
    String tankName = _selectedTank == 'oxygene'
        ? 'Oxygène'
        : _selectedTank == 'co2'
        ? 'CO₂'
        : 'Acétylène';

    // Date actuelle
    final now = DateTime.now();
    final dateStr =
        '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    // Créer le document PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // En-tête
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Rapport de Supervision',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Erium Burkina',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // Informations générales
              pw.Text(
                'Tank: $tankName',
                style:
                pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Date: $dateStr',
                style: const pw.TextStyle(
                    fontSize: 14, color: PdfColors.grey700),
              ),

              pw.SizedBox(height: 30),

              // Tableau des données
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    // En-tête du tableau
                    pw.TableRow(
                      decoration:
                      const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        _buildTableCell('Paramètre', isHeader: true),
                        _buildTableCell('Valeur', isHeader: true),
                        _buildTableCell('Unité', isHeader: true),
                      ],
                    ),
                    // Pression
                    pw.TableRow(
                      children: [
                        _buildTableCell('Pression'),
                        _buildTableCell(_pression.toStringAsFixed(1)),
                        _buildTableCell('bars'),
                      ],
                    ),
                    // Température
                    pw.TableRow(
                      children: [
                        _buildTableCell('Température'),
                        _buildTableCell(_temperature.toStringAsFixed(1)),
                        _buildTableCell('°C'),
                      ],
                    ),
                    // Niveau
                    pw.TableRow(
                      children: [
                        _buildTableCell('Niveau'),
                        _buildTableCell('$_niveau'),
                        _buildTableCell('%'),
                      ],
                    ),
                    // État vanne
                    pw.TableRow(
                      children: [
                        _buildTableCell('État Vanne'),
                        _buildTableCell(_etatVanne.toUpperCase()),
                        _buildTableCell('-'),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 30),

              // Analyse
              pw.Text(
                'Analyse',
                style:
                pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                _getAnalysisText(),
                style: const pw.TextStyle(
                    fontSize: 12, color: PdfColors.grey800),
              ),

              pw.Spacer(),

              // Pied de page
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 10),
              pw.Text(
                'Document généré automatiquement par le Système de Supervision Erium Burkina',
                style: const pw.TextStyle(
                    fontSize: 10, color: PdfColors.grey600),
                textAlign: pw.TextAlign.center,
              ),
            ],
          );
        },
      ),
    );

    // Sauvegarder le PDF dans le stockage externe (pas besoin de permission)
    try {
      // Obtenir le répertoire de stockage externe de l'application
      Directory? appDir;

      if (Platform.isAndroid) {
        // Stockage externe accessible sans permission
        appDir = await getExternalStorageDirectory();
      } else {
        appDir = await getApplicationDocumentsDirectory();
      }

      if (appDir == null) {
        throw Exception('Impossible d\'accéder au stockage');
      }

      // Créer le nom du fichier
      final fileName =
          'Rapport_${tankName.replaceAll('₂', '2')}_${now.day}-${now.month}-${now.year}_${now.hour}h${now.minute.toString().padLeft(2, '0')}.pdf';

      // Chemin complet du fichier
      final filePath = '${appDir.path}/$fileName';
      final file = File(filePath);

      // Sauvegarder le PDF
      await file.writeAsBytes(await pdf.save());

      print('PDF sauvegardé: $filePath');
      return filePath;
    } catch (e) {
      print('Erreur lors de la sauvegarde du PDF: $e');
      // En cas d'erreur, sauvegarder dans le répertoire temporaire
      final output = await getTemporaryDirectory();
      final file = File(
          '${output.path}/rapport_${_selectedTank}_${now.millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      return file.path;
    }
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(10),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 14 : 12,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  String _getAnalysisText() {
    String tankName = _selectedTank == 'oxygene'
        ? 'oxygène'
        : _selectedTank == 'co2'
        ? 'CO₂'
        : 'acétylène';

    // Normes selon le tank
    String normesPression = '';
    if (_selectedTank == 'oxygene') {
      normesPression = '12-16 bars';
    } else if (_selectedTank == 'co2') {
      normesPression = '40-50 bars';
    } else {
      normesPression = '10-15 bars';
    }

    String analysis =
        'Le tank de $tankName présente les caractéristiques suivantes:\n\n';

    // Analyse de la pression
    analysis +=
    '• Pression: ${_pression.toStringAsFixed(1)} bars (norme: $normesPression)\n';

    // Analyse du niveau
    if (_niveau >= 70) {
      analysis += '• Niveau: $_niveau% - Tank plein\n';
    } else if (_niveau >= 40) {
      analysis +=
      '• Niveau: $_niveau% - Niveau moyen, surveillance recommandée\n';
    } else {
      analysis += '• Niveau: $_niveau% - Niveau bas, remplissage nécessaire\n';
    }

    // État de la vanne
    analysis += '• Vanne: ${_etatVanne.toUpperCase()}\n';

    return analysis;
  }

  Future<String> _generateCSV() async {
    final now = DateTime.now();
    final dateStr =
        '${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    String tankName = _selectedTank == 'oxygene'
        ? 'Oxygène'
        : _selectedTank == 'co2'
        ? 'CO₂'
        : 'Acétylène';

    // Créer le contenu CSV
    List<List<dynamic>> rows = [
      ['Rapport de Supervision - Erium Burkina'],
      ['Tank', tankName],
      ['Date', dateStr],
      [''],
      ['Paramètre', 'Valeur', 'Unité'],
      ['Pression', _pression.toStringAsFixed(1), 'bars'],
      ['Température', _temperature.toStringAsFixed(1), '°C'],
      ['Niveau', _niveau, '%'],
      ['État Vanne', _etatVanne, '-'],
    ];

    String csv = const ListToCsvConverter().convert(rows);

    // Sauvegarder le CSV dans le stockage externe (pas besoin de permission)
    try {
      // Obtenir le répertoire de stockage externe de l'application
      Directory? appDir;

      if (Platform.isAndroid) {
        // Stockage externe accessible sans permission
        appDir = await getExternalStorageDirectory();
      } else {
        appDir = await getApplicationDocumentsDirectory();
      }

      if (appDir == null) {
        throw Exception('Impossible d\'accéder au stockage');
      }

      final fileName =
          'Rapport_${tankName.replaceAll('₂', '2')}_${now.day}-${now.month}-${now.year}_${now.hour}h${now.minute.toString().padLeft(2, '0')}.csv';
      final filePath = '${appDir.path}/$fileName';
      final file = File(filePath);

      await file.writeAsString(csv);
      print('CSV sauvegardé: $filePath');
      return filePath;
    } catch (e) {
      print('Erreur lors de la sauvegarde du CSV: $e');
      final output = await getTemporaryDirectory();
      final file = File(
          '${output.path}/rapport_${_selectedTank}_${now.millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv);
      return file.path;
    }
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
              _buildNavItem(Icons.show_chart, 'Stats', true),
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