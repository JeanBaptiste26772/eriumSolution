// Firebase Cloud Function pour envoyer des emails d'alerte
// Fichier: functions/index.js
// Config Gmail ajoutée

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();

// Fonction déclenchée lors de la création d'une nouvelle alerte
exports.envoyerEmailAlerte = functions.database
    .ref("/alertes/{alerteId}")
    .onCreate(async (snapshot, context) => {
      try {
        const alerte = snapshot.val();
        const alerteId = context.params.alerteId;

        // Ne traiter que les alertes critiques
        if (alerte.type !== "CRITIQUE") {
          console.log("Alerte non critique, email non envoyé");
          return null;
        }

        // Créer le transporteur ICI avec valeurs hardcodées en fallback
        const gmailEmail = process.env.GMAIL_EMAIL ||
                "jeanbaptisteouedraogo00@gmail.com";
        const gmailPassword = process.env.GMAIL_PASSWORD ||
                "";

        console.log(`Tentative d'envoi avec email: ${gmailEmail}`);

        // Créer le transporteur à chaque exécution
        const mailTransport = nodemailer.createTransport({
          service: "gmail",
          auth: {
            user: gmailEmail,
            pass: gmailPassword,
          },
        });

        // Récupérer les paramètres utilisateur
        const settingsSnapshot = await admin.database()
            .ref("/settings")
            .once("value");

        const settings = settingsSnapshot.val();

        // Vérifier si l'utilisateur a activé les emails d'alerte
        if (!settings || !settings.alertesEmail) {
          console.log("Alertes par email désactivées");
          return null;
        }

        // Vérifier si l'email est configuré
        const emailDestinataire = settings.emailNotifications;
        if (!emailDestinataire ||
                !emailDestinataire.includes("@")) {
          console.log(
              "Email destinataire non configuré ou invalide",
          );
          return null;
        }

        // Préparer le contenu de l'email
        const mailOptions = {
          from: `Système Supervision Erium <${gmailEmail}>`,
          to: emailDestinataire,
          subject: `🚨 ALERTE CRITIQUE - ${alerte.titre}`,
          html: `
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              body {
                font-family: -apple-system, BlinkMacSystemFont,
                  'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                line-height: 1.6;
                color: #333;
                max-width: 600px;
                margin: 0 auto;
                padding: 20px;
              }
              .header {
                background-color: #FF3B30;
                color: white;
                padding: 20px;
                border-radius: 8px 8px 0 0;
                text-align: center;
              }
              .content {
                background-color: #f5f5f5;
                padding: 30px;
                border-radius: 0 0 8px 8px;
              }
              .alert-box {
                background-color: white;
                padding: 20px;
                border-radius: 8px;
                border-left: 4px solid #FF3B30;
                margin: 20px 0;
              }
              .info-row {
                display: flex;
                justify-content: space-between;
                padding: 10px 0;
                border-bottom: 1px solid #e5e5ea;
              }
              .info-label {
                font-weight: 600;
                color: #8e8e93;
              }
              .info-value {
                color: #000;
                font-weight: 500;
              }
              .footer {
                text-align: center;
                padding: 20px;
                color: #8e8e93;
                font-size: 12px;
              }
            </style>
          </head>
          <body>
            <div class="header">
              <h1 style="margin: 0;">⚠️ ALERTE CRITIQUE</h1>
              <p style="margin: 10px 0 0 0; font-size: 16px;">
                Système de Supervision Erium Burkina
              </p>
            </div>

            <div class="content">
              <div class="alert-box">
                <h2 style="color: #FF3B30; margin-top: 0;">
                  ${alerte.titre}
                </h2>
                <p style="font-size: 16px; margin: 15px 0;">
                  ${alerte.description}
                </p>

                <div class="info-row">
                  <span class="info-label">Tank:</span>
                  <span class="info-value">${alerte.tankName}</span>
                </div>

                <div class="info-row">
                  <span class="info-label">Valeur mesurée:</span>
                  <span class="info-value"
                    style="color: #FF3B30; font-weight: bold;">
                    ${alerte.valeur.toFixed(1)}
                  </span>
                </div>

                <div class="info-row">
                  <span class="info-label">Type d'alerte:</span>
                  <span class="info-value">${alerte.type}</span>
                </div>

                <div class="info-row" style="border-bottom: none;">
                  <span class="info-label">Horodatage:</span>
                  <span class="info-value">
                    ${new Date(alerte.timestamp)
      .toLocaleString("fr-FR")}
                  </span>
                </div>
              </div>

              <div style="background-color: #FFF3F2;
                padding: 15px; border-radius: 8px; margin-top: 20px;">
                <p style="margin: 0; color: #FF3B30;
                  font-weight: 600;">
                  ⚡ Action immédiate requise
                </p>
                <p style="margin: 10px 0 0 0; font-size: 14px;
                  color: #666;">
                  Veuillez vérifier le système et prendre les
                  mesures correctives nécessaires.
                </p>
              </div>

              <div style="text-align: center;">
                <p style="margin: 20px 0 10px 0; color: #8e8e93;">
                  Connectez-vous à l'application pour plus de
                  détails
                </p>
              </div>
            </div>

            <div class="footer">
              <p>
                Cet email a été envoyé automatiquement par le
                système de supervision Erium Burkina
              </p>
              <p>
                Pour modifier vos préférences de notification,
                accédez aux Réglages de l'application
              </p>
            </div>
          </body>
          </html>
        `,
          text: `
ALERTE CRITIQUE - ${alerte.titre}

${alerte.description}

Tank: ${alerte.tankName}
Valeur mesurée: ${alerte.valeur.toFixed(1)}
Type: ${alerte.type}
Horodatage: ${new Date(alerte.timestamp).toLocaleString("fr-FR")}

Action immédiate requise - Veuillez vérifier le système.

---
Système de Supervision Erium Burkina
        `,
        };

        // Envoyer l'email
        await mailTransport.sendMail(mailOptions);

        console.log(
            `Email d'alerte envoyé à ${emailDestinataire} ` +
                `pour l'alerte ${alerteId}`,
        );

        // Enregistrer l'envoi dans la base de données
        await admin.database()
            .ref(`/alertes/${alerteId}`)
            .update({
              emailEnvoye: true,
              dateEnvoiEmail: new Date().toISOString(),
            });

        return null;
      } catch (error) {
        console.error(
            "Erreur lors de l'envoi de l'email:",
            error,
        );
        return null;
      }
    });
