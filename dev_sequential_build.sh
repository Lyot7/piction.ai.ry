#!/bin/bash

# Script optimisé pour lancer 4 devices avec HOT RELOAD
# Builds séquentiels pour éviter les conflits Xcode
# iPhone physique en PREMIER pour optimiser le workflow
# Usage: ./dev_sequential_build.sh

echo "🚀 Lancement mode développement - Build séquentiel"
echo "===================================================="
echo ""

# IDs des simulateurs iPhone 15 Pro
SIMULATOR_1="9BFE58DF-CC5D-4866-9AB7-56CD83A93DDD"  # iPhone 15 Pro - Player 1
SIMULATOR_2="52C6D5F2-F54C-409E-ABEB-598993CA3DD4"  # iPhone 15 Pro - Player 2
SIMULATOR_3="06E64F24-710A-4919-ABBA-BE8508BFAB24"  # iPhone 15 Pro - Player 3

# Détecter l'iPhone physique
echo "🔍 Détection des devices..."
# Extraction robuste: chercher le premier device iOS physique (mobile non-simulator)
PHYSICAL_IPHONE=$(flutter devices | grep "(mobile)" | grep "ios" | grep -v "simulator" | head -1 | sed -n 's/.*• \([0-9A-F-]*\) .*/\1/p')

if [ -z "$PHYSICAL_IPHONE" ]; then
  echo ""
  echo "❌ ERREUR: iPhone physique non détecté"
  echo ""
  echo "💡 Vérifications:"
  echo "   1. Ton iPhone est bien connecté en USB ?"
  echo "   2. Tu as autorisé cet ordinateur sur ton iPhone ?"
  echo "   3. L'iPhone est déverrouillé ?"
  echo ""
  echo "Liste des devices détectés:"
  flutter devices
  echo ""
  exit 1
fi

echo "   ✅ iPhone physique détecté: $PHYSICAL_IPHONE"
echo ""

# 🔥 OPTIMISATION: iPhone en PREMIER, puis simulateurs
DEVICES=("$PHYSICAL_IPHONE" "$SIMULATOR_1" "$SIMULATOR_2" "$SIMULATOR_3")
DEVICE_NAMES=("iPhone d'Eliott (physique)" "Simulateur 1" "Simulateur 2" "Simulateur 3")
DEVICE_COUNT=4

echo "📱 Lancement des simulateurs (après iPhone)..."
echo ""

# Lancer les 3 simulateurs
xcrun simctl boot "$SIMULATOR_1" 2>/dev/null || echo "   ✓ Simulateur 1 déjà lancé"
open -a Simulator --args -CurrentDeviceUDID "$SIMULATOR_1"
sleep 1

xcrun simctl boot "$SIMULATOR_2" 2>/dev/null || echo "   ✓ Simulateur 2 déjà lancé"
open -a Simulator --args -CurrentDeviceUDID "$SIMULATOR_2"
sleep 1

xcrun simctl boot "$SIMULATOR_3" 2>/dev/null || echo "   ✓ Simulateur 3 déjà lancé"
open -a Simulator --args -CurrentDeviceUDID "$SIMULATOR_3"
sleep 2

echo ""
echo "✅ Tous les devices prêts"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔨 BUILD SÉQUENTIEL (iPhone → Simulateurs)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Compteur de devices
DEVICE_NUM=1

# Lancer flutter run séquentiellement pour chaque device
for i in "${!DEVICES[@]}"; do
  DEVICE="${DEVICES[$i]}"
  DEVICE_NAME="${DEVICE_NAMES[$i]}"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📱 Device $DEVICE_NUM/$DEVICE_COUNT : $DEVICE_NAME"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  if [ $DEVICE_NUM -eq 1 ]; then
    echo "🔨 Premier device (iPhone physique) : Build complet..."
    echo "   ⏱️  Cela va prendre 30-40 secondes"
    echo ""

    # Premier device : build complet sur iPhone physique
    flutter run -d "$DEVICE" &
    FIRST_PID=$!

    # Attendre que le premier build soit terminé
    # iPhone physique nécessite plus de temps
    sleep 40

  else
    echo "⚡ Device suivant : Installation rapide (pas de rebuild)..."
    echo "   ⏱️  Cela va prendre 5-10 secondes"
    echo ""

    # Devices suivants : lancer en background
    # Flutter va détecter que le build existe déjà
    flutter run -d "$DEVICE" &

    # Attendre 10 secondes entre chaque device
    sleep 10
  fi

  echo ""
  echo "✅ $DEVICE_NAME lancé"
  echo ""

  DEVICE_NUM=$((DEVICE_NUM + 1))
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 TOUS LES DEVICES SONT LANCÉS (4/4)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "💡 COMMANDES FLUTTER:"
echo "   r  = Hot reload (mise à jour rapide sur TOUS les devices)"
echo "   R  = Hot restart (redémarrage complet)"
echo "   q  = Quitter"
echo "   h  = Aide"
echo ""
echo "⚠️  IMPORTANT:"
echo "   - Tape 'r' dans CE terminal pour hot reload sur tous les devices"
echo "   - Ne ferme pas ce terminal, il contrôle tous les devices"
echo ""
echo "📱 Ordre de build: iPhone → Sim1 → Sim2 → Sim3"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Attendre que tous les processus se terminent
wait
