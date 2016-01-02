/*
	File:			Insomnia.h
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
#include <IOKit/IOLib.h>
#include <IOKit/pwr_mgt/RootDomain.h>

#define kClamshellStateClosed true
#define kClamshellStateOpened false

class InsomniaK : public IOService {
    OSDeclareDefaultStructors(InsomniaK);

public:
    // driver startup and shutdown
    virtual bool init(OSDictionary * = 0);
    virtual bool start(IOService* provider);
    virtual void free();
	virtual IOReturn message(UInt32 type, IOService *provider, void *argument = 0);
	virtual bool send_event(UInt32 msg);
	
private:
	bool				currentLidState;
	bool				clamShellOpenedMessageSent;
};