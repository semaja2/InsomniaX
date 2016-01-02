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

#import <Cocoa/Cocoa.h>

// hdiutil utility routines

// NOTE: These uses NSTask to invoke /usr/bin/hdiutil. Because we wait for the 
// task to finish, our run loop is polled during hdiutil's execution, 
// potentially leading to reentrancy.

@interface DiskImageUtilities : NSObject 

// copies the current app from a read-only disk image to /Applications, with user approval
//
// Call this every time from -applicationWillFinishLaunching
//
// The app must have these strings in its localizable.strings file:
//
// "DiskImageCopyTitle" = "Would you like to copy %@ to your computer's Applications folder and run it from there?";
// "DiskImageCopyMsg" = "%@ is currently running from the Disk Image, and must be copied for full functionality. Copying may replace an older version in the Applications directory.";
// "DiskImageCopyOK" = "Copy";
// "DiskImageCopyCancel" = "Don't Copy";

+ (void)handleApplicationLaunchCheck;

@end
