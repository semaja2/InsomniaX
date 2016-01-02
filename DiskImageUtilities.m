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

#include <unistd.h>

#import "DiskImageUtilities.h"
#import "AuthorizedTaskManager.h"

static NSString* const kHDIUtilPath = @"/usr/bin/hdiutil";

@interface DiskImageUtilities (PrivateMethods_handleApplicationLaunchFromReadOnlyDiskImage)
+ (BOOL)canWriteToPath:(NSString *)path;
+ (void)copyAndLaunchAppAtPath:(NSString *)oldPath
               toDirectoryPath:(NSString *)newDirectory;
+ (void)killAppAtPath:(NSString *)appPath;
@end

@implementation DiskImageUtilities

// checks if the current app is running from a disk image,
// displays a dialog offering to copy to /Applications, and
// does the copying

+ (void)handleApplicationLaunchCheck {
  
  NSString * const kLastLaunchedPathKey = @"LastLaunchedPath";
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  
  NSString *lastLaunchedPath = [defaults objectForKey:kLastLaunchedPathKey];
  NSString *mainBundlePath = [[NSBundle mainBundle] bundlePath];
  
    // ? should we ask every time the user runs from a read-only disk image
  if (![mainBundlePath hasPrefix:@"/Applications"] && ![lastLaunchedPath isEqualToString:mainBundlePath]) {
      // we're running from a disk image
      
      [NSApp activateIgnoringOtherApps:YES];
      
      NSString *displayName = [[NSFileManager defaultManager] displayNameAtPath:mainBundlePath];
      NSString *msg1template = NSLocalizedString(@"Would you like to copy %@ to your computer's Applications folder and run it from there?", "%@ will be replaced with 'SyncBar'");
      NSString *msg1 = [NSString stringWithFormat:msg1template, displayName];
      NSString *msg2 = NSLocalizedString(@"%@ is currently running outside of the Applications folder on the system drive. Copying may replace an older version in the Applications folder.", "%@ will be replaced with 'SyncBar'.");
      NSString *btnOK = NSLocalizedString(@"Copy", "Button to copy SyncBar to the Applications folder from the disk image if needed");
      NSString *btnCancel = NSLocalizedString(@"Don't Copy", "Button to proceed without copying SyncBar to the Applications folder");
      
      int result = NSRunAlertPanel(msg1, msg2, btnOK, btnCancel, NULL, displayName);
      if (result == NSAlertDefaultReturn) {
        // copy to /Applications and launch from there
        
        NSArray *appsPaths = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory,
                                                                 NSLocalDomainMask,
                                                                 YES);
        if ([appsPaths count] > 0) {
          
          [self copyAndLaunchAppAtPath:mainBundlePath
                       toDirectoryPath:[appsPaths objectAtIndex:0]];  
          // calls exit(0) on successful copy/launch
        } else {
          NSLog(@"Cannot make applications folder path");
        }
      } else {
		  // we don't need to check this bundle path again
		  [defaults setObject:mainBundlePath forKey:kLastLaunchedPathKey];
	  }
    }
}

// copies an application from the given path to a new directory, if necessary
// authenticating as admin or killing a running process at that location
+ (void)copyAndLaunchAppAtPath:(NSString *)oldPath
               toDirectoryPath:(NSString *)newDirectory {
  
  NSString *pathInApps = [newDirectory stringByAppendingPathComponent:[oldPath lastPathComponent]];
  BOOL isDir;
  BOOL dirPathExists = [[NSFileManager defaultManager]
                      fileExistsAtPath:pathInApps isDirectory:&isDir] && isDir;
  
  AuthorizedTaskManager *authTaskMgr = [AuthorizedTaskManager sharedAuthorizedTaskManager];
  
  // We must authenticate as admin if we don't have write permission
  // in the /Apps directory, or if there's already an app there
  // with the same name and we don't have permission to write to it
  BOOL mustAuth = (![self canWriteToPath:newDirectory] 
                   || (dirPathExists && ![self canWriteToPath:pathInApps]));
  
  if (!mustAuth || [authTaskMgr authorize]) {
    
    [self killAppAtPath:pathInApps];
    
    BOOL didCopy = [authTaskMgr copyPath:oldPath
                                  toPath:pathInApps];
    if (didCopy) {
      // launch the new copy and bail
      LSLaunchURLSpec spec;
      spec.appURL = (CFURLRef) [NSURL fileURLWithPath:pathInApps];
      spec.launchFlags = kLSLaunchNewInstance;
      spec.itemURLs = NULL;
      spec.passThruParams = NULL;
      spec.asyncRefCon = NULL;
      
      OSStatus err = LSOpenFromURLSpec(&spec, NULL); // NULL -> don't care about the launched URL
      if (err == noErr) {
        exit(0);
      } else {
        NSLog(@"DiskImageUtilities: Error %d launching \"%@\"", err, pathInApps);
      }
    } else {
      // copying to /Applications failed 
      NSLog(@"DiskImageUtilities: Error copying to \"%@\"", pathInApps);     
    }
  } else {
    // user cancelled admin auth 
  }
  
}

// looks for an app running from the specified path, and calls KillProcess on it
+ (void)killAppAtPath:(NSString *)appPath {
  
  // get the FSRef for bundle of the the target app to kill
  FSRef targetFSRef;
  OSStatus err = FSPathMakeRef((const UInt8 *)[appPath fileSystemRepresentation],
                               &targetFSRef, nil);
  if (err == noErr) {
    
    // search for a PSN of a process with the bundle at that location, if any
    ProcessSerialNumber psn = { 0, kNoProcess };
    while (GetNextProcess(&psn) == noErr) {
      
      FSRef compareFSRef;
      if (GetProcessBundleLocation(&psn, &compareFSRef) == noErr
          && FSCompareFSRefs(&compareFSRef, &targetFSRef) == noErr) {
        
        // we found an app running from that path; kill it
        err = KillProcess(&psn);
        if (err != noErr) {
          NSLog(@"DiskImageUtilities: Could not kill process at %@, error %d",
                appPath, err);
        } 
      }
    }
  }
}

// canWriteToPath checks for permissions to write into the directory |path|
+ (BOOL)canWriteToPath:(NSString *)path {
  int stat = access([path fileSystemRepresentation], (W_OK | R_OK));
  return (stat == 0);
}

@end
