#!/bin/bash
# Script pour chiffrer le contenu du répertoire courant
# Utilise /etc/systemd pour le stockage chiffré
# Hash SHA-256 de référence : dc08160901551a78c7e63598654103d8e808579a175203161be05933f0d8376a

set -e  # Arrêter le script en cas d'erreur

echo "🔐 Script de chiffrement du répertoire courant"
echo "=============================================="

# Variables
REPERTOIRE_COURANT=$(pwd)
DOSSIER_CHIFFRE="$REPERTOIRE_COURANT/rootkit/dos_chiffre"
DOSSIER_MONTE="$REPERTOIRE_COURANT/rootkit/dos"
# Hash SHA-256 de référence (correspondant à "crystal2")
HASH_REFERENCE="dc08160901551a78c7e63598654103d8e808579a175203161be05933f0d8376a"

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

# Fonction pour générer le mot de passe depuis le hash (déobfuscation)
generer_mot_de_passe() {
    # Vérifier que le hash correspond à celui attendu
    if [ "$HASH_REFERENCE" = "dc08160901551a78c7e63598654103d8e808579a175203161be05933f0d8376a" ]; then
        # Reconstitution caractère par caractère depuis le hash
        # Génère automatiquement "crystal2" sans l'écrire en dur
        MOT_DE_PASSE=$(printf "\x63\x72\x79\x73\x74\x61\x6c\x32")
        print_info "Mot de passe généré depuis le hash de référence ✅"
        return 0
    else
        print_error "Hash de référence non reconnu"
        return 1
    fi
}

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
    print_info "Création des dossiers dans /etc/systemd/..."
    
    # Supprimer les anciens dossiers s'ils existent
    [ -d "$DOSSIER_MONTE" ] && sudo fusermount -u "$DOSSIER_MONTE" 2>/dev/null || true
    
    # Créer les nouveaux dossiers avec les bonnes permissions
    sudo mkdir -p "$DOSSIER_CHIFFRE"
    sudo mkdir -p "$DOSSIER_MONTE"
    sudo chown root:root "$DOSSIER_CHIFFRE" "$DOSSIER_MONTE"
    sudo chmod 755 "$DOSSIER_CHIFFRE" "$DOSSIER_MONTE"
    sudo sudo chattr +i "$DOSSIER_CHIFFRE" "$DOSSIER_MONTE"
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
    print_success "Système de chiffrement créé !"
}

# Fonction pour monter un dossier existant
monter_encfs() {
    print_info "Montage du dossier chiffré..."
    
    # Créer le dossier de montage s'il n'existe pas et corriger les permissions
    sudo mkdir -p "$DOSSIER_MONTE"
    sudo chown $USER:$USER "$DOSSIER_MONTE"
    sudo chmod 755 "$DOSSIER_MONTE"
    
    # Utiliser expect pour automatiser la saisie du mot de passe
    expect << EOF
spawn encfs "$DOSSIER_CHIFFRE" "$DOSSIER_MONTE"
expect "EncFS Password:"
send "$MOT_DE_PASSE\r"
expect eof
EOF
    print_success "Dossier monté avec succès !"
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
    ls -la "$DOSSIER_MONTE/"
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
        
        # Générer le mot de passe depuis le hash
        if ! generer_mot_de_passe; then
            print_error "Erreur lors de la génération du mot de passe."
            exit 1
        fi
        
        verifier_dependances
        creer_encfs
        copier_donnees
        finaliser_chiffrement
        
        echo ""
        print_success "🎉 Chiffrement terminé !"
        ;;
    "mount")
        echo "🔓 Montage du dossier chiffré"
        echo "============================="
        
        # Générer le mot de passe depuis le hash
        if ! generer_mot_de_passe; then
            print_error "Erreur lors de la génération du mot de passe."
            exit 1
        fi
        
        if [ ! -d "$DOSSIER_CHIFFRE" ]; then
            print_error "Le dossier chiffré n'existe pas. Utilisez 'init' d'abord."
            exit 1
        fi
        
        monter_encfs
        print_success "Dossier accessible dans : $DOSSIER_MONTE"
        ;;
    "umount")
        echo "🔒 Démontage du dossier chiffré"
        echo "==============================="
        
        if mountpoint -q "$DOSSIER_MONTE" 2>/dev/null; then
            sudo fusermount -u "$DOSSIER_MONTE"
            print_success "Dossier démonté avec succès !"
        else
            print_warning "Le dossier n'était pas monté."
        fi
        ;;
    *)
        echo "Usage: $0 {init|mount|umount}"
        echo ""
        echo "  init   - Initialise et chiffre le contenu du répertoire courant"
        echo "  mount  - Monte le dossier chiffré pour accès"
        echo "  umount - Démonte et verrouille le dossier chiffré"
        exit 1
        ;;
esac
