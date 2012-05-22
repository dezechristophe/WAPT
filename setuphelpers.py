#-------------------------------------------------------------------------------
# Name:        setuphelpers
# Purpose:     common functions to help setup tasks
#
# Author:      33
#
# Created:     22/05/2012
# Copyright:   (c) 33 2012
# Licence:     GPL
#-------------------------------------------------------------------------------
#!/usr/bin/env python
from winshell import *
import urllib,urllib2
import tempfile
import shutil
from regutil import *
import subprocess
import win32pdhutil
import win32api,win32con

import logging
logger = logging.getLogger('wapt-get')

# ensure there is a tempdir available for local work. This is deleted at program exit.
if not 'tempdir' in globals():
    tempdir = tempfile.mkdtemp()
    logger.info('Temporary directory created : %s' % tempdir)

import atexit
@atexit.register
def cleanuptemp():
    if 'tempdir' in globals():
        logger.debug('Removing temporary directory : %s' % tempdir)
        shutil.rmtree(tempdir)

# Temporary dir where to unzip/get all files for setup
# helper assumes files go and comes here per default
packagetempdir = tempdir

def ensure_dir(f):
  """Be sure the directory of f exists on disk. Make it if not"""
  d = os.path.dirname(f)
  if not os.path.exists(d):
    os.makedirs(d)

def create_shortcut(path, target='', wDir='', icon=''):
    ext = path[-3:]
    if ext == 'url':
        shortcut = file(path, 'w')
        shortcut.write('[InternetShortcut]\n')
        shortcut.write('URL=%s' % target)
        shortcut.close()
    else:
        CreateShortcut(path,target,'',wDir,(icon,0),'')

def create_desktop_shortcut(label, target='', wDir='', icon=''):
    if not (label.endswith('.lnk') or label.endswith('.url')):
        label += '.lnk'
    createShortcut(os.path.join(desktop(1),label),target,wDir,icon)

def create_programs_menu_shortcut(label, target='', wDir='', icon=''):
    if not (label.endswith('.lnk') or label.endswith('.url')):
        label += '.lnk'
    createShortcut(os.path.join(start_menu(1),label),target,wDir,icon)

def wgets(url):
    """Return the content of a remote resources as a String"""
    return urllib2.urlopen(url).read()

def wget(url,target):
  """Copy the contents of a file from a given URL
  to a local file.
  """
  if os.path.isdir(target):
    target = os.path.join(target,'')

  (dir,filename) = os.path.split(target)
  if not filename:
    filename = url.split('/')[-1]
  if not dir:
    dir = tempdir

  if not os.path.isdir(dir):
    os.makedirs(dir)

  urllib.urlretrieve(url,os.path.join(dir,filename))
  return os.path.join(dir,filename)

def copyto(filename,target):
    """Copy file from package temporary directory to target"""
    (dir,fn) = os.path.split(filename)
    if not dir:
        dir = tempdir
    shutil.copy(os.path.join(dir,fn),target)

def shellexecandwait(cmd):
    """Runs the command and wait for it termination
    returns exit code"""
    return subprocess.call(cmd,shell=True)

def shelllaunch(cmd):
    os.startfile(cmd)

def registerapplication(applicationname):
    pass

def unregisterapplication(applicationname):
    pass

def isrunning(processname):
    try:
        return len(win32pdhutil.FindPerformanceAttributesByName( processname ))> 0
    except:
        return False

def killalltasks(processname):
    for pid in win32pdhutil.FindPerformanceAttributesByName( processname ):
        handle = win32api.OpenProcess( win32con.PROCESS_TERMINATE, 0, pid )
        win32api.TerminateProcess( handle, 0 )
        win32api.CloseHandle( handle )

def messagebox(title,msg):
    win32api.MessageBox(0, msg, title, win32con.MB_ICONINFORMATION)

if __name__ == '__main__':
    main()
