// sshfs.app
// Copyright 2007, Google Inc.
//
// Redistribution and use in source and binary forms, with or without 
// modification, are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice, 
//     this list of conditions and the following disclaimer.
//  2. Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//  3. The name of the author may not be used to endorse or promote products 
//     derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR IMPLIED
// WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
// MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
// EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR 
// OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
// ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#import "AuthorizedTaskManager.h"

@interface AuthorizedTaskManager (PrivateMethods)
- (BOOL)copyRights;
- (int)runTaskForPath:(const char *)path withArguments:(const char **)arguments;
@end

@implementation AuthorizedTaskManager

+ (AuthorizedTaskManager *)sharedAuthorizedTaskManager {
  // a simple singleton pattern; replace with something more heavy-duty
  // if desired
  static AuthorizedTaskManager *manager = nil;
  if (!manager)
    manager = [[AuthorizedTaskManager alloc] init];
  
  return manager;
}

- (void)dealloc {
  [self deauthorize];
  [super dealloc];
}

#pragma mark -

// authorize creates and copies admin rights, raising the admin name/password
// dialog if necessary (usually not necessary if this object has been authorized
// recently and not deauthorized)
- (BOOL)authorize {
  
  BOOL isAuthorized = NO;
  
  if (commonAuthorizationRef_) {
    isAuthorized = [self copyRights];
  } else 	{
    const AuthorizationRights* kNoRightsSpecified = NULL;
    OSStatus err = AuthorizationCreate(kNoRightsSpecified, kAuthorizationEmptyEnvironment, 
                          kAuthorizationFlagDefaults, &commonAuthorizationRef_); 
    
    if (err == errAuthorizationSuccess)	{
      isAuthorized = [self copyRights];
    }
  }
  
  return isAuthorized;
}

// deauthorize dumps any existing authorization. Calling authorize afterwards
// will raise the admin password dialog
- (void)deauthorize {
  if (commonAuthorizationRef_) {
    AuthorizationFree(commonAuthorizationRef_, kAuthorizationFlagDefaults); 
    commonAuthorizationRef_ = 0;
  }	
}

// copyRights actually acquires the admin rights. |commonAuthorizationRef_| must
// have been allocated previously
- (BOOL)copyRights {
  
  NSParameterAssert(commonAuthorizationRef_);
  
  OSStatus err;
  const AuthorizationEnvironment* kDefaultAuthEnvironment = NULL;
  
  AuthorizationFlags theFlags = kAuthorizationFlagDefaults 
    | kAuthorizationFlagPreAuthorize 
    | kAuthorizationFlagExtendRights
    | kAuthorizationFlagInteractionAllowed;
  AuthorizationItem theItems = {kAuthorizationRightExecute, 0, NULL, 0}; 
  AuthorizationRights theRights = {1, &theItems}; 
  
  err = AuthorizationCopyRights(commonAuthorizationRef_, &theRights, 
                                kDefaultAuthEnvironment, theFlags, NULL); 
  if (err == errAuthorizationSuccess) {
    return YES;
  }	
  [self deauthorize];
  return NO;
}

- (BOOL)isAuthorized {
  return (commonAuthorizationRef_ != 0);
}

// runTaskForPath:withArguments executes the tool at the |path| with |arguments|
//
// The tool's exit value is returned
//
// If |commonAuthorizationRef_| is non-nil, then AuthorizationExecuteWithPrivileges
// is used.
//
// runTaskForPath calls AuthorizationExecuteWithPrivileges if the user has
// authenticated, or calls NSTask if the user has not authenticated
//
// NOTE: when running the task with admin privileges, this waits on any child 
// process, since AEWP doesn't tell us the child's pid.  This could be fooled 
// by any other child process that quits in the window between launch and 
// completion of our actual tool.
//
- (int)runTaskForPath:(const char *)path withArguments:(const char **)arguments {
  // waitUntilExit polls the run loop, which could end up calling this reentrantly,
  // (like through networking callbacks) and that's bad if another caller tries
  // to use a file with the same path
  
  static int zReentrancyCount = 0;
  
  assert(zReentrancyCount == 0);// runTaskForPath called reentrantly
  
  zReentrancyCount++;
  
  int result;
  if (!commonAuthorizationRef_) {
    // non-authorized 
    
    // the params are char* since AuthorizationExecuteWithPrivileges needs
    // those, but NSTask wants NSStrings, so convert the char*'s to an
    // array of NSStrings here
    NSMutableArray* argsArray = [NSMutableArray array];
    int idx;
    for (idx = 0; arguments[idx] != NULL; idx++) {
      [argsArray addObject:[NSString stringWithUTF8String:arguments[idx]]];
    }
    
    NSString* pathStr = [NSString stringWithUTF8String:path];
    
    NSTask* task = [NSTask launchedTaskWithLaunchPath:pathStr
                                            arguments:argsArray];
    
    [task waitUntilExit];
    
    result = [task terminationStatus];

  } else {
    
    // authorized
    
    FILE **kNoPipe = NULL;
    AuthorizationFlags myFlags = kAuthorizationFlagDefaults; 
    result = AuthorizationExecuteWithPrivileges(commonAuthorizationRef_, 
                                 path, myFlags, (char *const*) arguments, kNoPipe);
    if (result == 0) {
      int wait_status;
      int pid = wait(&wait_status);
      if (pid == -1 || !WIFEXITED(wait_status))	{
        result = -1;
      } else {
        result = WEXITSTATUS(wait_status);
      }
    }
  }
  
  if (zReentrancyCount > 0) {
    zReentrancyCount--;
  }
  
  return result;
}

// copyPath calls ditto
- (BOOL)copyPath:(NSString *)src toPath:(NSString *)dest {
  char taskPath[] = "/usr/bin/ditto";
  const char* arguments[] = { 
    "-rsrcFork",  // 0: copy resource forks; --rsrc requires 10.3
    NULL,  // 1: src path
    NULL,  // 2: dest path
    NULL 
  };
  arguments[1] = [src fileSystemRepresentation];
  arguments[2] = [dest fileSystemRepresentation];
  
  int status = [self runTaskForPath:taskPath withArguments:arguments];
  return (status == 0);
}

@end
