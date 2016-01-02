#include "authtool.h"



void printError(int errornum, int command) {
	fprintf(stderr, "\n-----------------------\n");
	fprintf(stderr, "Error recieved while exectuting %d\n", command);
	fprintf(stderr, "Error Code: %d\n", errornum);
	fprintf(stderr, "-----------------------\n");
}

/* Perform the operation specified in myCommand. */
static int performOperation(const MyAuthorizedCommand * myCommand) {
	//char commandToExec[255];
	int result = -1;
	int	status;
	// Retrieve the minor version number to ensure backwards combatibility
#ifdef DEBUG
    fprintf(stderr, "Tool performing command %d.\n", myCommand->authorizedCommandId);
#endif
    
    struct passwd *pw = getpwuid(getuid());
    
    char *homedir = pw->pw_dir;
    
    char *supportPath = strcat(homedir, "/Library/Application Support/InsomniaX");
    const char *kextPath = strcat(supportPath, "/Insomnia_r11.kext");
    
    switch(myCommand->authorizedCommandId)
	{
		case kMyAuthorizedLoad: {
			/* Child code. */
			if(fork() == 0) {
#ifdef DEBUG
                fprintf(stderr, "CHOWN\n");
#endif
                dup2(2,1);
                execl("/usr/sbin/chown", "chown", "-R",  "root:wheel", kextPath, NULL);
			}
			/* Parent code. */
			else {
				wait(&status);
                /* Child code. */
                if(fork() == 0) {
#ifdef DEBUG
                    fprintf(stderr, "KEXTLOAD\n");
#endif
                    dup2(2,1);
                    execl("/sbin/kextload", "kextload", kextPath, NULL);
                }
                /* Parent code. */
                else {
                    wait(&status);
                }
			}
			
			result = status;
			break;
		}
        case kMyAuthorizedDiag: {
            /* Child code. */
            if(fork() == 0) {
                fprintf(stderr, "Running chown\n");
                dup2(2,1);
                execl("/usr/sbin/chown", "chown", "-Rv",  "root:wheel", kextPath, NULL);
            }
            /* Parent code. */
            else {
                wait(&status);
                /* Child code. */
                if(fork() == 0) {
                    fprintf(stderr, "Running kextutil\n");
                    dup2(2,1);
                    execl("/usr/bin/kextutil", "kextutil", "-vvvvvv", kextPath, NULL);
                }
                /* Parent code. */
                else {
                    wait(&status);
                    /* Split the proc into parent/child. */
                    /* Child code. */
                    if(fork() == 0) {
                        fprintf(stderr, "Running kextunload\n");
                        dup2(2,1);
                        execl("/sbin/kextunload", "kextunload", "-vvvvvv", kextPath, NULL);
                    }
                    /* Parent code. */
                    else {
                        wait(&status);
                    }
                }
            }

            result = status;
            break;
        }
		case kMyAuthorizedUnload: {
#ifdef DEBUG
            fprintf(stderr, "Tool performing unload.\n");
#endif
            /* Split the proc into parent/child. */
			/* Child code. */
			if(fork() == 0) {
#ifdef DEBUG
                fprintf(stderr, "KEXTUNLOAD\n");
#endif
                dup2(2,1);
                execl("/sbin/kextunload", "kextunload", kextPath, NULL);
			}
			/* Parent code. */
			else {
				wait(&status);
			}
			result = status;
			break;
		}
        case kMyAuthorizedRemove: {
            fprintf(stderr, "Tool performing unload.\n");
            /* Child code. */
            if(fork() == 0) {
                fprintf(stderr, "KEXTUNLOAD\n");
                dup2(2,1);
                execl("/sbin/kextunload", "kextunload", "-vvvvv", kextPath, NULL);
            }
            /* Parent code. */
            else {
                wait(&status);
//                /* Child code. */
//                if(fork() == 0) {
//                    fprintf(stderr, "Removing KEXT\n");
//                    dup2(2,1);
//                    execl("/bin/rm", "rm", "-rfv", kextPath, NULL);
//                }
//                /* Parent code. */
//                else {
//                    wait(&status);
//                }
            }

            result = status;
            break;
        }
        default: {
#ifdef DEBUG
        fprintf(stderr, "Unrecognized command.\n");
#endif
        break;
        }
	}
	return result;
}
int main(int argc, char * const *argv) {
	// OSStatus status;
    AuthorizationRef auth;
    int bytesRead;
    MyAuthorizedCommand myCommand;
    
    unsigned long path_to_self_size = 0;
    char *path_to_self = NULL;
	
    
    /* MyGetExecutablePath() attempts to use _NSGetExecutablePath() (see NSModule(3)) if it's available in
	 order to get the actual path of the tool. */
	
    path_to_self_size = MAXPATHLEN;
    if (! (path_to_self = malloc(path_to_self_size)))
        exit(kMyAuthorizedCommandInternalError);
    if (_NSGetExecutablePath(path_to_self, &path_to_self_size) == -1)
    {
        /* Try again with actual size */
        if (! (path_to_self = realloc(path_to_self, path_to_self_size + 1)))
            exit(kMyAuthorizedCommandInternalError);
        if (_NSGetExecutablePath(path_to_self, &path_to_self_size) != 0)
            exit(kMyAuthorizedCommandInternalError);
    }                
	
    if (argc == 2 && !strcmp(argv[1], "--self-repair"))
    {
        /*  Self repair code.  We ran ourselves using AuthorizationExecuteWithPrivileges()
		 so we need to make ourselves setuid root to avoid the need for this the next time around. */
        
        struct stat st;
        int fd_tool;
		
#ifdef DEBUG
        fprintf(stderr, "got --self-repair\n");
#endif
        
        /* Recover the passed in AuthorizationRef. */
        if (AuthorizationCopyPrivilegedReference(&auth, kAuthorizationFlagDefaults))
            exit(kMyAuthorizedCommandInternalError);
		
        /* Open tool exclusively, so noone can change it while we bless it */
        fd_tool = open(path_to_self, O_NONBLOCK|O_RDONLY|O_EXLOCK, 0);
		
        if (fd_tool == -1)
        {
#ifdef DEBUG
            fprintf(stderr, "Exclusive open while repairing tool failed: %d.\n", errno);
#endif
            exit(kMyAuthorizedCommandInternalError);
        }
		
        if (fstat(fd_tool, &st))
            exit(kMyAuthorizedCommandInternalError);
        
        if (st.st_uid != 0)
            fchown(fd_tool, 0, st.st_gid);
		
        /* Disable group and world writability and make setuid root. */
        fchmod(fd_tool, (st.st_mode & (~(S_IWGRP|S_IWOTH))) | S_ISUID);
		
        close(fd_tool);
		
#ifdef DEBUG
        fprintf(stderr, "Tool self-repair done.\n");
#endif
		
    }
    else
    {
		
	    AuthorizationExternalForm extAuth;
		
        // Read the Authorization "byte blob" from our input pipe. 
        if (read(0, &extAuth, sizeof(extAuth)) != sizeof(extAuth))
            exit(kMyAuthorizedCommandInternalError);
        
        // Restore the externalized Authorization back to an AuthorizationRef
        if (AuthorizationCreateFromExternalForm(&extAuth, &auth))
            exit(kMyAuthorizedCommandInternalError);
		
        // If we are not running as root we need to self-repair. 
        if (geteuid() != 0)
        {
			
            int status;
            int pid;
            FILE *commPipe = NULL;
            char *arguments[] = { "--self-repair", NULL };
            char buffer[1024];
            int bytesRead;
			
            // Set our own stdin and stdout to be the communication channel with ourself. 
            
#ifdef DEBUG
            fprintf(stderr, "Tool about to self-exec through AuthorizationExecuteWithPrivileges.\n");
#endif
            if (AuthorizationExecuteWithPrivileges(auth, path_to_self, kAuthorizationFlagDefaults, arguments, &commPipe))
                exit(kMyAuthorizedCommandInternalError);
			
            // Read from stdin and write to commPipe. 
            for (;;)
            {
                bytesRead = read(0, buffer, 1024);
                if (bytesRead < 1) break;
                fwrite(buffer, 1, bytesRead, commPipe);
            }
			
            // Flush any remaining output. 
            fflush(commPipe);
            
            // Close the communication pipe to let the child know we are done. 
            fclose(commPipe);
			
            // Wait for the child of AuthorizationExecuteWithPrivileges to exit. 
            pid = wait(&status);
            if (pid == -1 || ! WIFEXITED(status))
                exit(kMyAuthorizedCommandInternalError);
			
            // Exit with the same exit code as the child spawned by AuthorizationExecuteWithPrivileges() 
            exit(WEXITSTATUS(status));
        }
		
    }
	
    /* No need for it anymore */
    if (path_to_self)
        free(path_to_self);
	
#ifdef DEBUG
    fprintf(stderr, "getting command\n");
#endif
    
    /* Read a 'MyAuthorizedCommand' object from stdin. */
    bytesRead = read(0, &myCommand, sizeof(MyAuthorizedCommand));
    
    /* Make sure that we received a full 'MyAuthorizedCommand' object */
    if (bytesRead == sizeof(MyAuthorizedCommand))
    {
		// const char *rightName = rightNameForCommand(&myCommand);
		// AuthorizationItem right = { rightName, 0, NULL, 0 } ;
		// AuthorizationRights rights = { 1, &right };
		// AuthorizationFlags flags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed
        //                            | kAuthorizationFlagExtendRights;
        
        /* Check to see if the user is allowed to perform the tasks stored in 'myCommand'. This may
		 or may not prompt the user for a password, depending on how the system is configured. */
		
		// if(myDebug) fprintf(stderr, "Tool authorizing right %s for command.\n", rightName);
        
		// if (status = AuthorizationCopyRights(auth, &rights, kAuthorizationEmptyEnvironment, flags, NULL))
		// {
		//     if(myDebug) fprintf(stderr, "Tool authorizing command failed authorization: %ld.\n", status);
		//     exit(kMyAuthorizedCommandAuthFailed);
		// }
		
#ifdef DEBUG
        fprintf(stderr, "try to perform a command\n");
#endif
        /* Peform the opertion stored in 'myCommand'. */
        if (performOperation(&myCommand) != 0)
            exit(kMyAuthorizedCommandOperationFailed);
    }
    else
    {
        exit(kMyAuthorizedCommandChildError);
    }
	
    exit(0);
}

