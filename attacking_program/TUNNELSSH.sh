#!/bin/bash

if ss -tln | grep -q ':9000 '; then
  echo "Tunnel SSH déjà actif sur le port 9000."
else
  ssh -N -f -L 9000:localhost:8005 vagrant@10.0.3.11
  echo "Tunnel SSH lancé sur le port 9000."
fi
