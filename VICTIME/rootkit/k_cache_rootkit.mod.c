#include <linux/build-salt.h>
#include <linux/module.h>
#include <linux/vermagic.h>
#include <linux/compiler.h>

BUILD_SALT;

MODULE_INFO(vermagic, VERMAGIC_STRING);
MODULE_INFO(name, KBUILD_MODNAME);

__visible struct module __this_module
__section(.gnu.linkonce.this_module) = {
	.name = KBUILD_MODNAME,
	.init = init_module,
#ifdef CONFIG_MODULE_UNLOAD
	.exit = cleanup_module,
#endif
	.arch = MODULE_ARCH_INIT,
};

#ifdef CONFIG_RETPOLINE
MODULE_INFO(retpoline, "Y");
#endif

static const struct modversion_info ____versions[]
__used __section(__versions) = {
	{ 0xdd8f8694, "module_layout" },
	{ 0x87d7b3f5, "kthread_stop" },
	{ 0x62fd0331, "kobject_del" },
	{ 0x6bb70076, "wake_up_process" },
	{ 0xa6521794, "kthread_create_on_node" },
	{ 0x96b81f90, "kernel_listen" },
	{ 0x6a0dcd63, "kernel_bind" },
	{ 0x1000e51, "schedule" },
	{ 0x56b1771b, "current_task" },
	{ 0x6565e06e, "sock_release" },
	{ 0x57750e68, "kernel_accept" },
	{ 0xa43e640f, "sock_create" },
	{ 0xb3f7646e, "kthread_should_stop" },
	{ 0x6df1aaf1, "kernel_sigaction" },
	{ 0xbcab6ee6, "sscanf" },
	{ 0x754d539c, "strlen" },
	{ 0xe2d5255a, "strcmp" },
	{ 0xc973ee21, "kernel_read" },
	{ 0xa7eedcc4, "call_usermodehelper" },
	{ 0x656e4a6e, "snprintf" },
	{ 0xcbd4898c, "fortify_panic" },
	{ 0x3c3ff9fd, "sprintf" },
	{ 0x15ba50a6, "jiffies" },
	{ 0x5ab904eb, "pv_ops" },
	{ 0xdbf17652, "_raw_spin_lock" },
	{ 0x69dd3b5b, "crc32_le" },
	{ 0xeb233a45, "__kmalloc" },
	{ 0x9166fada, "strncpy" },
	{ 0xca7a3159, "kmem_cache_alloc_trace" },
	{ 0x428db41d, "kmalloc_caches" },
	{ 0xdecd0b29, "__stack_chk_fail" },
	{ 0x37a0cba, "kfree" },
	{ 0x8f2c9fb7, "kernel_sendmsg" },
	{ 0x5e5292c, "filp_close" },
	{ 0x4e1bcc1b, "kernel_write" },
	{ 0xddd346a3, "filp_open" },
	{ 0x69acdf38, "memcpy" },
	{ 0xf29e6ab5, "kernel_recvmsg" },
	{ 0xb8b9f817, "kmalloc_order_trace" },
	{ 0xc5850110, "printk" },
	{ 0xbdfb6dbb, "__fentry__" },
};

MODULE_INFO(depends, "");


MODULE_INFO(srcversion, "F8DB6E2AD9F6B215DAC6BF7");
