#!/bin/bash
echo
echo "####################################################"
echo "###### Insomnia v2.1.8 loader security patch  ######"
echo "###### by m4rkw - https://m4.rkw.io/blog.html ######";
echo "####################################################"
echo

function usage()
{
  echo "Usage: $0 [--install]"
  exit
}

function install()
{
  if [ "`whoami`" != "root" ] ; then
    echo "This script requires root privileges."
    exit 1
  fi
  if [ -e /Applications/InsomniaX.app/Contents/Resources/loader_patch_backup ] ; then
    echo "This patch already seems to be installed."
    exit 1
  fi
  mv /Applications/InsomniaX.app/Contents/Resources/loader /Applications/InsomniaX.app/Contents/Resources/loader_patch_backup
  chmod -s /Applications/InsomniaX.app/Contents/Resources/loader_patch_backup
  chown -R root:wheel /Applications/InsomniaX.app
  cat > /tmp/loader.c <<EOF
#include <unistd.h>

void load_kext()
{
  execl("/sbin/kextload", "kextload", "/Applications/InsomniaX.app/Contents/Resources/Insomnia_r11.kext", NULL);
}

void unload_kext()
{
  execl("/sbin/kextunload", "kextunload", "/Applications/InsomniaX.app/Contents/Resources/Insomnia_r11.kext", NULL);
}

int main(int ac, char *av[])
{
  char c;
  int i;

  for (i=0; i<33; i++) {
    read(STDIN_FILENO, (char *)&c, 1);
  }

  if (c == 1) {
    load_kext();
  } else if (c == 2) {
    unload_kext();
  }

  return 0;
}
EOF
  gcc -o /Applications/InsomniaX.app/Contents/Resources/loader /tmp/loader.c
  rm -f /tmp/loader.c
  chmod 4755 /Applications/InsomniaX.app/Contents/Resources/loader

  echo "Patch installed. The vulnerable loader binary has been replaced and is no longer exploitable."
  echo
}

if [ "$1" == "--install" ] ; then
  install
else
  usage
fi
