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

// AuthorizedTaskManager mirrors an NSFileManager method,
// but uses NSTask or AuthorizationExecuteWithPrivileges to invoke
// tools to do the job.  This allows us to be using the same tools 
// regardless of whether the operation is authenticated with admin privs or not.
// The differences between the auth and the non-auth code path is thus
// minimized.
//
// Note that despite the similar names to NSFileManager methods,
// this method observes the semantics of its underlying tool (ditto)
//
// USAGE NOTE: when running the task with admin privileges, this waits on any  
// child process, since AEWP doesn't tell us the child's pid.  This could be  
// fooled by any other child process that quits in the window between launch and 
// completion of our actual tool.  The effect could be harmless, it could be a
// lack of synchronicity, or it could be an incorrect result for the 
// move/copy/etc operation.  See method runTaskForPath:withArguments:
//
// BUILD NOTE: link to Security.framework

#import <Cocoa/Cocoa.h>
#include <Security/Security.h>

// supports common file manager tasks that may require admin privileges
@interface AuthorizedTaskManager : NSObject {
  AuthorizationRef commonAuthorizationRef_;
}

+ (AuthorizedTaskManager *)sharedAuthorizedTaskManager;

// authorize creates and copies admin rights, raising the admin name/password
// dialog if necessary (usually not necessary if this object has been authorized
// recently and not deauthorized)
- (BOOL)authorize;

// deauthorize dumps any existing authorization. Calling authorize afterwards
// will raise the admin password dialog
- (void)deauthorize;

// isAuthorized determines if authorization has been done, though does
// not indicate if a timeout will require the user to re-auth via
// the dialog again, so don't base UI decisions on this
- (BOOL)isAuthorized;


// copyPath:toPath calls ditto -rsrcFork
- (BOOL)copyPath:(NSString *)src toPath:(NSString *)dest;
@end
