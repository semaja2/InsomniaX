/*
 File:			Insomnia.cpp
 Program:		Insomnia
 Author:			Michael Roßberg/Alexey Manannikov/Dominik Wickenhauser/Andrew James
 Description:	Insomnia is a kext module to disable sleep on ClamshellClosed
 
 Insomnia is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.
 
 Insomnia is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with Insomnia; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */



#include "Insomnia.h"


#define super IOService

OSDefineMetaClassAndStructors(InsomniaK, IOService);

#pragma mark -

/* init function for Insomnia, unchanged from orginal Insomnia */
bool InsomniaK::init(OSDictionary* properties) {
	
	IOLog("Insomnia:init\n");
	
    if (super::init(properties) == false) {
		IOLog("Insomnia::init: super::init failed\n");
		return false;
    }
    return true;
}


//start function for Insomnia, fixed send_event to match other code 
bool InsomniaK::start(IOService* provider) {
	
	IOLog("Insomnia:start\n");
	
	if (!super::start(provider)) {
		IOLog("Insomnia::start: super::start failed\n");
		return false;
    }

	currentLidState =  ((OSBoolean *)getPMRootDomain()->getProperty(kAppleClamshellStateKey))->getValue();

    //actualLidState = currentLidState;

	InsomniaK::send_event(kIOPMDisableClamshell | kIOPMPreventSleep);
    
    //getPMRootDomain()->setProperty(kAppleClamshellCausesSleepKey, false);
    return true;
}


/* free function for Insomnia, fixed send_event to match other code */
void InsomniaK::free() {
	/* Reset the system to orginal state */
    InsomniaK::send_event(kIOPMAllowSleep | kIOPMEnableClamshell);
	//getPMRootDomain()->setProperty(kAppleClamshellCausesSleepKey, true);
    IOLog("Insomnia: Lid close is now processed again.\n");
	
	if (currentLidState == kClamshellStateClosed) {
		IOLog("Insomnia: Lid is closed, let's go to bed now.\n");
        InsomniaK::send_event(kIOPMClamshellClosed);
		InsomniaK::send_event(kIOPMSleepNow);
	} else {
        IOLog("Insomnia: Lid is opened\n");
    }
	IOLog("Insomnia finished\n");
	IOLog("==========================================\n");
    IOLog("Insomnia:end\n");
    super::free();
    return;
}


/* Send power messages to rootDomain */
bool InsomniaK::send_event(UInt32 msg) {
    IOPMrootDomain *root = NULL;
	IOReturn		ret=kIOReturnSuccess;
	
	root = getPMRootDomain();
    if (!root) {
        IOLog("Insomnia: Fatal error could not get RootDomain.\n");
        return false;
    }

	ret = root->receivePowerNotification(msg);
	
	if(ret!=kIOReturnSuccess)
	{
		IOLog("Insomina: Error sending event: %d\n", ret);
	}	else {
		if (msg & kIOPMDisableClamshell ) {
			IOLog("Insomnia: kIOPMDisableClamshell sent to root\n");
		} else if (msg & kIOPMEnableClamshell ) {
			IOLog("Insomnia: kIOPMEnableClamshell sent to root\n");
		} else if (msg & kIOPMClamshellOpened) {
			IOLog("Insomnia: kIOPMClamshellOpened sent to root\n");
        } else if (msg & kIOPMSleepNow) {
            IOLog("Insomnia: kIOPMSleepNow sent to root\n");
		} else if (msg & kIOPMDisableClamshell) {
            IOLog("Insomnia: kIOPMDisableClamshell sent to root\n");
        } else if (msg & kIOPMPreventSleep) {
            IOLog("Insomnia: kIOPMPreventSleep sent to root\n");
        } else {
			IOLog("Insomnia: Unknown message sent to root\n");
		}
	}
    
	return true;
}

IOReturn InsomniaK::message(UInt32 type, IOService * provider, void * argument) {
    IOLog("Insomnia: Message received\n");
    bool receivedLidState = ((OSBoolean *)getPMRootDomain()->getProperty(kAppleClamshellStateKey))->getValue();
    
    // Check if lid state has changed since last message, ignore if the lid state hasnt changed
    if (currentLidState == receivedLidState) {
        IOLog("Insomnia: Message is for duplicate lid state\n");
    } else {
        if (clamShellOpenedMessageSent) {
            IOLog("Insomnia: Ignore this message because its artifical!\n");
            clamShellOpenedMessageSent = false;
        } else {
            currentLidState = receivedLidState;
            if (currentLidState == kClamshellStateClosed) {
                IOLog("Insomnia: Lid was closed\n");
                clamShellOpenedMessageSent = true; // ignore the next message since it's an echo of the next line
                InsomniaK::send_event(kIOPMClamshellOpened);
                
            } else {
                IOLog("Insomnia: Lid was opened\n");
                InsomniaK::send_event(kIOPMDisableClamshell | kIOPMPreventSleep);
            }
        }
    }
    IOLog("========================\n");
	return super::message(type, provider, argument);
}