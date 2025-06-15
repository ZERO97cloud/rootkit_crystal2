
obj-m += epirootkit.o
epirootkit-objs := main.o auth.o cache.o commandes.o dissimulation.o notification.o

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
	rm -f .*.cmd
	rm -f *.symvers
	rm -rf .tmp_versions

install:
	sudo bash install.sh

encodage:
	sudo bash encodage.sh init

remove:
	sudo rmmod epirootkit

load: all install

reload: remove clean all install

.PHONY: all clean install remove load reload
