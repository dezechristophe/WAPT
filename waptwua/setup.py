# -*- coding: utf-8 -*-
from setuphelpers import *

uninstallkey = []

def install():
    print('installing tis-waptwsus')
    waptpython_path = makepath(WAPT.wapt_base_dir,'waptpython.exe')
    waptwua_path = makepath(WAPT.wapt_base_dir,'waptwua')
    waptwuabin_path = WAPT.wapt_base_dir

    mkdirs(makepath(waptwua_path,'cache'))
    mkdirs(waptwuabin_path)
    if task_exists('waptwua'):
        delete_task('waptwua')
    create_daily_task('waptwua',waptpython_path,'"%s" --critical download' % (makepath(waptwuabin_path,'waptwua.py'),))

def uninstall():
    delete_task('waptwua')
    waptwua_path = makepath(WAPT.wapt_base_dir,'waptwua')
    remove_tree(waptwua_path)

