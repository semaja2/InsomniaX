// This is a replacement for InsomniaX's loader (authtool.c) since it had a security
// vulnerability. From https://m4.rkw.io/blog/security-fix-for-insomniax-218.html
// See below for more information:
//
// InsomniaX by Andrew James - http://semaja2.net - is really handy if you want to
// leave your macbook running with the lid closed.
//
// Unfortunately back in June of this year a security vulnerability in the loader
// binary was disclosed that allows the loading of any arbitrary kernel extension
// as a non-root user.
//
// I am today releasing a patch for this exploit that replaces the vulnerable
// loader binary with a new one that loads and unloads the kernel extension
// securely.
//
// https://m4.rkw.io/insomnia_218_patch.sh.txt
// c51110c284a32730d34ffc355c75329b6851a62010463049d2505f1530605e79

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

