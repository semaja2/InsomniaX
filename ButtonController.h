/* ButtonController */

#include <Cocoa/Cocoa.h>
//#include <CoreServices/CoreServices.h>
//#include <ApplicationServices/ApplicationServices.h>
//#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
//#include <IOKit/pwr_mgt/IOPMLib.h> //Needed for newer IOKit Idle Sleep
#include <IOKit/kext/KextManager.h>
#include <IOKit/ps/IOPSKeys.h>
#include <IOKit/pwr_mgt/IOPM.h>
#include <IOKit/ps/IOPowerSources.h>
#import "auth_tool_run.c"
//#import "DiskImageUtilities.m"
//#import "AuthorizedTaskManager.m"
#import "LaunchAtLoginController.h"
#import "ShortcutRecorder/ShortcutRecorder.h"
//#import "SensorsModule.h"
#import "HotKey/PTHotKeyCenter.h"
#import "HotKey/PTHotKey.h"
#include "smc.h"


#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/sysctl.h>

//#import "PowerObserver.h"
//#import "Context.h"
//#define OBSERVATION_UPDATE @"GKB: Observation Update"
//#define OBSERVATION_OBSERVER @"Observation Name"
//#define OBSERVATION_OBSERVATION @"Observation Description"


#define POWER_OTHER -1
#define POWER_AC 0
#define POWER_BATTERY 1
#define POWER_UPS 2

#define SUCCESS 4

/* Versioning system for Insomnia, vital to ensure we can update our kext */
#define insomnia_name @"Insomnia_r11.kext"
#define insomnia_id @"net.semaja2.kext.insomnia"
#define kReadmeVersion @"Lic-2.1.9"

int intLastPowerState;

int licence = 1;

bool debug = false;
bool cpuSafetyIsAvailable = true;

char *smcSensorKey = SMC_KEY_CPU_0_PROXIMITY;

@class PTHotKey;

@interface ButtonController : NSObject <NSApplicationDelegate, NSUserNotificationCenterDelegate>
{
	
#pragma mark Menu Item Outlets
    IBOutlet	NSMenu				*statusMenu;
	IBOutlet	NSMenuItem			*statusInsomniaItem;
    IBOutlet	NSMenuItem			*statusIdleSleepItem;
    
    IBOutlet    NSMenuItem          *disableLidSleepOnACItem;
    IBOutlet    NSMenuItem          *disableIdleSleepOnACItem;
    
    IBOutlet    NSMenuItem          *disableLidSleepForItem;
    IBOutlet    NSMenuItem          *disableIdleSleepForItem;
    
    IBOutlet    NSMenuItem          *sleepDisplayItem;
    
    IBOutlet    NSSlider            *disableLidSleepForSlider;
    IBOutlet    NSSlider            *disableIdleSleepForSlider;
    
    IBOutlet    NSMenuItem          *soundMenuItem;
    
    IBOutlet    NSMenuItem          *CPUSafetyItem;
    
    IBOutlet    NSMenuItem          *StartOnLoginItem;
    
    IBOutlet    SRRecorderControl   *lidSR;
    IBOutlet    SRRecorderControl   *idleSR;
    IBOutlet    SRRecorderControl   *displaySleepSR;
    
                PTHotKey			*lidHotKey;
                PTHotKey			*idleHotKey;
                PTHotKey			*displaySleepHotKey;
    
    IBOutlet    NSMenuItem          *lidHotKeyItem;
    IBOutlet	NSPanel				*idleHotKeyPanel;
    IBOutlet	NSPanel				*lidHotKeyPanel;
    IBOutlet	NSPanel				*displaySleepHotKeyPanel;
	
                NSUserDefaults      *defaults;

#pragma mark Load/Unload Sound/Images
				NSStatusItem		*statusItem;
				NSImage				*LidSleepImage;
				NSImage				*IdleSleepImage;
                NSImage				*NormalImage;
                NSImage             *LidIdleSleepImage;
				NSSound				*loadSound;
				NSSound				*unloadSound;
                NSSound				*idleEnableSound;
                NSSound				*idleDisableSound;

	
#pragma mark NSTimers
				NSTimer				*jigglerTimer;
                NSTimer             *CPUTempSafetyTimer;
                NSTimer             *enableLidSleepTimer;
                NSTimer             *enableIdleSleepTimer;
                NSTimer             *systemTimer;

#pragma mark Misc
				NSString			*insomniaPath;
				NSPanel				*readmePanel;
                NSTextField         *logoSubText;
                NSButton            *agreeButton;
                NSButton            *disagreeButton;
    
                int                 boolPrevLidSleepState;
                int                 boolPrevIdleSleepState;
                int                 licence;
    
                float               CPUSafetyTemp;
                NSString            *deviceModel;
                bool                disableInsomniaFunction;
    
                CFRunLoopSourceRef powerNotifierRunLoopSource;
    
//                /* sleep management */
//                IOPMAssertionID systemSleepAssertionID;
}



#pragma mark Menu Item Methods
- (IBAction)insomnia:(id)sender;
- (IBAction)idleSleepItem:(id)sender;

- (IBAction)sleepDisplay:(id)sender;
- (IBAction)soundItem:(id)sender;
- (IBAction)disableLidSleepOnAC:(id)sender;
- (IBAction)disableIdleSleepOnAC:(id)sender;

- (IBAction)disableLidSleepFor:(id)sender;
- (IBAction)disableIdleSleepFor:(id)sender;

- (IBAction)idleHotKeyItem:(id)sender;
- (IBAction)lidHotKeyItem:(id)sender;

- (IBAction)startOnLogin:(id)sender;

- (IBAction)readmeItem:(id)sender;

- (IBAction)aboutItem:(id)sender;

- (IBAction)runDiagnostics:(id)sender;
- (IBAction)uninstall:(id)sender;

- (IBAction)quitInsomniaX:(id)sender;
- (void)appWillTerminate:(NSApplication *)sender;
#pragma mark Insomnia Methods
- (BOOL)insomniaState;
- (void)setInsomniaStatus;
- (void)setInsomniaState:(BOOL)state;
- (void)setStatusIcon;
- (IBAction)CPUSafety:(id)sender;
-(void)setCPUSafetyState:(BOOL)state;
-(void)setIdleSleepState:(bool)state;
-(bool)getIdleSleepState;
-(void)powerSourceChanged:(unsigned int) status;

-(void)makeReadme;
-(IBAction)acceptButton:(id)sender;

-(float)getTemperatureForKey:(char*)key;
-(void)CPUSafetyCheck:(NSTimer *)timer;

-(void)backgroundThread:(NSTimer *)timer;
-(void)disableLidSleepForTimer:(NSTimer *)timer;
-(void)disableIdleSleepForTimer:(NSTimer *)timer;
-(NSString*)convertTimeIntervalToString:(NSTimeInterval)timeInterval;
-(NSString *) machineModel;
- (void)shortcutRecorder:(SRRecorderControl *)aRecorder keyComboDidChange:(KeyCombo)newKeyCombo;
- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification;
-(void)sendNotificationWithTitle:(NSString *)title andText:(NSString *)text;
@end