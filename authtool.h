#include <Carbon/Carbon.h>

#include <Security/Authorization.h>
#include <sys/param.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <sys/fcntl.h>
#include <sys/errno.h>
#include <stdlib.h>
#include <mach-o/dyld.h>
#include <unistd.h>
#include <sys/types.h>
#include <pwd.h>
#include <stdio.h>
#include <string.h>

//#define DEBUG
//#define insomnia_name @"Insomnia_r9.kext"



// Command Ids
enum
{
    kMyAuthorizedLoad = 1,
    kMyAuthorizedUnload = 2,
	kMyAuthorizedHibernateInstant = 3,
	kMyAuthorizedHibernateNormal = 4,
	kMyAuthorizedHibernateDisable = 5,
	kMyAuthorizedHibernateInstall = 6,
	kMyAuthorizedRemove = 7,
    kMyAuthorizedDiag = 8
};



// Command structure
typedef struct MyAuthorizedCommand
{
    int authorizedCommandId;
	
    char file[1024];
	
} MyAuthorizedCommand;



// Exit codes (positive values) and return codes from exec function
enum
{
    kMyAuthorizedCommandInternalError = -1,
    kMyAuthorizedCommandSuccess = 0,
    kMyAuthorizedCommandExecFailed,
    kMyAuthorizedCommandChildError,
    kMyAuthorizedCommandAuthFailed,
    kMyAuthorizedCommandOperationFailed
};

//long osMinor;