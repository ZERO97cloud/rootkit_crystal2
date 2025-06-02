obj-m += k_cache_rootkit.o

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

install:
	sudo bash install.sh
clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
