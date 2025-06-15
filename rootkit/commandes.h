#ifndef COMMANDES_H
#define COMMANDES_H

#include <linux/module.h>
#include <linux/fs.h>
#include <linux/slab.h>
#include <linux/socket.h>
#include <linux/syscalls.h>
#include <net/sock.h>

#define TAILLE_BUFFER 65536
#define MAX_TAILLE_FICHIER (5 * 1024 * 1024)

char *executer_commande(char *cmd);
char *lire_fichier(char *chemin);
int recevoir_fichier(struct socket *sock_client, const char *nom, const char *methode, const char *chemin);

#endif
