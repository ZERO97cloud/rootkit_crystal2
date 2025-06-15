#ifndef CACHE_H
#define CACHE_H

#include <linux/module.h>
#include <linux/fs.h>
#include <linux/slab.h>
#include <linux/list.h>
#include <linux/crc32.h>

#define TAILLE_BUFFER 65536

struct fichier_cache {
    char nom[256];
    unsigned char *donnees;
    size_t taille;
    struct list_head liste;
    unsigned long crc;
};

extern struct list_head fichiers_caches;
extern spinlock_t fichiers_lock;

int ajouter_fichier_cache(const char *nom, const unsigned char *donnees, size_t taille);
struct fichier_cache *trouver_fichier_cache(const char *nom);
void liberer_fichiers_caches(void);
char *lister_fichiers_caches(void);
char *extraire_fichier_cache(const char *nom);
int cacher_fichier_fs(const char *nom, const unsigned char *donnees, size_t taille, const char *chemin);

#endif
