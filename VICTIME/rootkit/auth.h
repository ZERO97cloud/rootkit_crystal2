#ifndef AUTH_H
#define AUTH_H

#include <linux/module.h>
#include <linux/slab.h>
#include <crypto/hash.h>
#include <linux/crypto.h>

int calculer_sha256(const char *data, char *hash_hex);
bool verifier_mot_de_passe(const char *password);

#endif
