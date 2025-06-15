#!/usr/bin/env bash
# auto_ssh_tunnel.sh : scan /24 + tunnel SSH automatique
# Lancement d'un script de configuration dès que le tunnel est disponible
# ----------------------------------------------------------------------
# Usage : ./auto_ssh_tunnel.sh [user] [net_prefix] [remote_port] [local_port]
#   user         : login SSH (défaut root)
#   net_prefix   : ex 10.0.2 (=> 10.0.3.0/24)  [défaut 10.0.3]
#   remote_port  : port distant à scanner      [défaut 8005]
#   local_port   : port local du forward       [défaut 9000]
# ----------------------------------------------------------------------
set -euo pipefail
USER_SSH="${1:-vagrant}"
NET_PREFIX="${2:-10.0.3}"
REMOTE_PORT="${3:-8005}"
LOCAL_PORT="${4:-9000}"
CONFIG_SCRIPT="interface9000.sh"      # script déclenché après le tunnel
[[ ! -f $CONFIG_SCRIPT ]] && { echo "[!] $CONFIG_SCRIPT introuvable"; exit 1; }

echo -e "\e[34m[•]\e[0m Scan réseau ${NET_PREFIX}.0/24 (port $REMOTE_PORT)…"

# 1) Tunnel déjà actif vers n'importe quelle IP ?
if pgrep -f "ssh .*${LOCAL_PORT}:.*:${REMOTE_PORT}.*@.*" >/dev/null; then
  echo -e "\e[33m[ℹ]\e[0m Tunnel déjà établi. Exécution de $CONFIG_SCRIPT…"
  exec python3 "$CONFIG_SCRIPT"
fi

# 2) Port local libre ?
if lsof -i :"$LOCAL_PORT" >/dev/null 2>&1; then
  echo -e "\e[31m[!]\e[0m Port local ${LOCAL_PORT} déjà utilisé par un autre service."
  exit 1
fi

# 3) Trouver une machine ayant le port ouvert
found_ip=""
for i in {1..254}; do
  ip="${NET_PREFIX}.${i}"
  if timeout 0.3 bash -c "echo > /dev/tcp/$ip/$REMOTE_PORT" 2>/dev/null; then
    echo -e "\e[32m[+]\e[0m $ip : port $REMOTE_PORT ouvert"
    found_ip="$ip"; break
  fi
done
[[ -z $found_ip ]] && { echo -e "\e[33m[!]\e[0m Aucune machine trouvée."; exit 1; }

# 4) Vérifier qu'on ne duplique pas exactement le même tunnel
if pgrep -f "ssh .*${LOCAL_PORT}:.*:${REMOTE_PORT}.*${USER_SSH}@${found_ip}" >/dev/null; then
  echo -e "\e[33m[ℹ]\e[0m Tunnel déjà actif vers ${found_ip}. Exécution de $CONFIG_SCRIPT…"
  exec python3 "$CONFIG_SCRIPT"
fi

# 5) Création du tunnel
echo -e "\e[34m[•]\e[0m Création tunnel SSH (${USER_SSH}@${found_ip}) → localhost:${LOCAL_PORT}"

# MODIFICATION IMPORTANTE ICI : utiliser l'IP au lieu de localhost pour assurer 
# que la connexion va au bon hôte, particulièrement pour les connexions distantes
ssh -f -o ConnectTimeout=3 -o StrictHostKeyChecking=no \
    -N -L "${LOCAL_PORT}:${found_ip}:${REMOTE_PORT}" "${USER_SSH}@${found_ip}"

if [[ $? -eq 0 ]]; then
  echo -e "\e[32m[OK]\e[0m Tunnel prêt ! Lancement de $CONFIG_SCRIPT…"
  exec python3 "$CONFIG_SCRIPT"
else
  echo -e "\e[31m[KO]\e[0m Échec création tunnel."
  exit 1
fi
