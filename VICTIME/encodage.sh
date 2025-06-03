#!/bin/bash

# Script pour chiffrer le contenu du répertoire courant
# Utilise /tmp pour le stockage chiffré
# Mot de passe : toto94

set -e  # Arrêter le script en cas d'erreur

echo "🔐 Script de chiffrement du répertoire courant"
echo "=============================================="

# Variables
REPERTOIRE_COURANT=$(pwd)
DOSSIER_CHIFFRE="/etc/systemd/.dos_chiffre"
DOSSIER_MONTE="/etc/systemd/.dos"
MOT_DE_PASSE="toto94"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour afficher avec couleurs
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# Fonction pour vérifier l'installation
verifier_dependances() {
    print_info "Vérification des dépendances..."
    
    if ! command -v encfs &> /dev/null; then
        print_warning "EncFS n'est pas installé. Installation..."
        sudo apt update && sudo apt install -y encfs
    fi
    
    if ! command -v expect &> /dev/null; then
        print_warning "Expect n'est pas installé. Installation..."
        sudo apt install -y expect
    fi
    
    print_success "Toutes les dépendances sont installées !"
}

# Fonction pour créer le système chiffré
creer_encfs() {
    print_info "Création des dossiers dans /tmp..."
    
    # Supprimer les anciens dossiers s'ils existent
    [ -d "$DOSSIER_MONTE" ] && fusermount -u "$DOSSIER_MONTE" 2>/dev/null || true
    
    
    # Créer les nouveaux dossiers
    mkdir -p "$DOSSIER_CHIFFRE"
    mkdir -p "$DOSSIER_MONTE"
    
    print_info "Initialisation du chiffrement EncFS..."
    
    # Utiliser expect pour automatiser la saisie
    expect << EOF
spawn encfs "$DOSSIER_CHIFFRE" "$DOSSIER_MONTE"
expect "?>"
send "\r"
expect "New Encfs Password:"
send "$MOT_DE_PASSE\r"
expect "Verify Encfs Password:"
send "$MOT_DE_PASSE\r"
expect eof
EOF

    print_success "Système de chiffrement créé dans /tmp !"
}

# Fonction pour copier les données
copier_donnees() {
    print_info "Répertoire courant : $REPERTOIRE_COURANT"
    
    # Vérifier qu'il y a des fichiers à copier
    if [ -z "$(ls -A "$REPERTOIRE_COURANT" 2>/dev/null)" ]; then
        print_warning "Le répertoire courant est vide !"
        return
    fi
    
    print_info "Copie de tous les fichiers vers le dossier chiffré..."
    
    # Copier tous les fichiers (y compris les fichiers cachés)
    cp -r "$REPERTOIRE_COURANT"/.[!.]* "$DOSSIER_MONTE/" 2>/dev/null || true
    cp -r "$REPERTOIRE_COURANT"/* "$DOSSIER_MONTE/" 2>/dev/null || true
    
    print_success "Copie terminée !"
    
    # Afficher ce qui a été copié
    print_info "Fichiers copiés dans le dossier chiffré :"
}



# Fonction pour finaliser le chiffrement
finaliser_chiffrement() {
    print_info "Verrouillage du dossier chiffré..."
    fusermount -u "$DOSSIER_MONTE"
    print_success "Dossier verrouillé avec succès !"
}


# Menu principal
case "$1" in
    "init")
        echo "🚀 Processus de chiffrement complet du répertoire courant"
        echo "========================================================"
        
        verifier_dependances
        creer_encfs
        copier_donnees
        finaliser_chiffrement
        
        echo ""
        print_success "🎉 Chiffrement terminé !"
        ;;
    *)
        print_error "Option invalide : $1"
        exit 1
        ;;
esac

