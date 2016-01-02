#import "ButtonController.h"
static bool stringsAreEqual(CFStringRef a, CFStringRef b)
{
	if (!a || !b) return 0;
    
	return (CFStringCompare(a, b, 0) == kCFCompareEqualTo);
}

static void update (void * context)
{
	ButtonController * self = (__bridge ButtonController *) context;
	
	CFTypeRef blob = IOPSCopyPowerSourcesInfo ();
	CFArrayRef list = IOPSCopyPowerSourcesList (blob);
	
	unsigned int count = CFArrayGetCount (list);
	
	if (count == 0)
		[self powerSourceChanged:POWER_AC];
	
	unsigned int i = 0;
	for (i = 0; i < count; i++) 
	{
		CFTypeRef source;
		CFDictionaryRef description;
		
		source = CFArrayGetValueAtIndex (list, i);
		description = IOPSGetPowerSourceDescription (blob, source);
		
		if (stringsAreEqual (CFDictionaryGetValue (description, CFSTR (kIOPSTransportTypeKey)), CFSTR (kIOPSInternalType))) 
		{
			CFStringRef currentState = CFDictionaryGetValue (description, CFSTR (kIOPSPowerSourceStateKey));
			
			if (stringsAreEqual (currentState, CFSTR (kIOPSACPowerValue)))
				[self powerSourceChanged:POWER_AC];
			else if (stringsAreEqual (currentState, CFSTR (kIOPSBatteryPowerValue)))
				[self powerSourceChanged:POWER_BATTERY];
			//else
			//	[self powerSourceChanged:POWER_OTHER];
		} 
	}
	
	CFRelease (list);
	CFRelease (blob);
}

@implementation ButtonController

#pragma mark NSApplication Methods

- (void) awakeFromNib
{
    defaults = [NSUserDefaults standardUserDefaults];
    //[defaults synchronize];
    licence = [[NSUserDefaults standardUserDefaults] integerForKey:kReadmeVersion];
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] setDelegate:self];
	
    CPUSafetyTemp = 100.0;
    disableInsomniaFunction = false;
    
	if (!licence)
        [self makeReadme];
	
    /* Setup the defaults */
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"CPUSafetyMaxTemp"] != nil)
        CPUSafetyTemp = [[NSUserDefaults standardUserDefaults] floatForKey:@"CPUSafetyMaxTemp"];
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"CPUSafety"] == nil)
        [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"CPUSafety"];
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"debugMode"] != nil)
        debug = [[NSUserDefaults standardUserDefaults] floatForKey:@"debugMode"];
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    

	
    deviceModel = [self machineModel];
    
    
    if ([deviceModel rangeOfString:@"MacBook"].location == NSNotFound && [[NSUserDefaults standardUserDefaults] objectForKey:@"modelCheck"] == nil) {
        disableInsomniaFunction = true;
        [statusInsomniaItem setEnabled:false];
        [statusInsomniaItem setHidden:true];
        [CPUSafetyItem setHidden:true];
        [lidHotKeyItem setHidden:true];
        [disableLidSleepForItem setHidden:true];
        [disableLidSleepOnACItem setHidden:true];
        NSLog(@"Device is not MacBook(%@), Insomnia features disabled!", deviceModel);
    }
    
    
/********************************
 InsomniaX Functions
********************************/
    if (!disableInsomniaFunction) {
        if ([[NSUserDefaults standardUserDefaults] stringForKey:@"CPUSensorKey"] != nil) {
            smcSensorKey = (char*)[[[NSUserDefaults standardUserDefaults] stringForKey:@"CPUSensorKey"] UTF8String];
            smc_init();
            if (SMCGetTemperature(smcSensorKey) == -1.0) {
                NSLog(@"ERROR: Custom defined sensor %s is not valid, return to default", smcSensorKey);
                if (SMCGetTemperature(SMC_KEY_CPU_TEMP) != -1.0) {
                    smcSensorKey = SMC_KEY_CPU_TEMP;
                } else if (SMCGetTemperature(SMC_KEY_CPU_0_DIODE) != -1.0) {
                    smcSensorKey = SMC_KEY_CPU_0_DIODE;
                } else if (SMCGetTemperature(SMC_KEY_CPU_0_HEATSINK) != -1.0) {
                    smcSensorKey = SMC_KEY_CPU_0_HEATSINK;
                } else if (SMCGetTemperature(SMC_KEY_CPU_0_PROXIMITY) != -1.0) {
                    smcSensorKey = SMC_KEY_CPU_0_PROXIMITY;
                } else if (SMCGetTemperature(SMC_KEY_AMBIENT_AIR_0) != -1.0) {
                    smcSensorKey = SMC_KEY_AMBIENT_AIR_0;
                } else if (SMCGetTemperature(SMC_KEY_AMBIENT_AIR_1) != -1.0) {
                    smcSensorKey = SMC_KEY_AMBIENT_AIR_1;
                } else {
                    NSRunAlertPanel(@"InsomniaX", @"ERROR: Unable to find a temperature sensor to monitor for safety system, safety system is disabled, please contact support!", @"Ok", nil, nil);
                    NSLog(@"ERROR: Unable to find a temperature sensor to monitor for safety system, safety system is disabled, please contact support!");
                    cpuSafetyIsAvailable = false;
                }
                [[NSUserDefaults standardUserDefaults] setValue:[NSString stringWithFormat:@"%s",smcSensorKey] forKey:@"CPUSensorKey"];
            }
            smc_close();
            
            //NSLog(@"Loading from defaults");
        } else {
            // Lets try to find the key for the first sensor we find
            smc_init();
            //NSLog(@"Scanning");
            if (SMCGetTemperature(SMC_KEY_CPU_TEMP) != -1.0) {
                smcSensorKey = SMC_KEY_CPU_TEMP;
            } else if (SMCGetTemperature(SMC_KEY_CPU_0_DIODE) != -1.0) {
                smcSensorKey = SMC_KEY_CPU_0_DIODE;
            } else if (SMCGetTemperature(SMC_KEY_CPU_0_HEATSINK) != -1.0) {
                smcSensorKey = SMC_KEY_CPU_0_HEATSINK;
            } else if (SMCGetTemperature(SMC_KEY_CPU_0_PROXIMITY) != -1.0) {
                smcSensorKey = SMC_KEY_CPU_0_PROXIMITY;
            } else if (SMCGetTemperature(SMC_KEY_AMBIENT_AIR_0) != -1.0) {
                smcSensorKey = SMC_KEY_AMBIENT_AIR_0;
            } else if (SMCGetTemperature(SMC_KEY_AMBIENT_AIR_1) != -1.0) {
                smcSensorKey = SMC_KEY_AMBIENT_AIR_1;
            } else {
                NSRunAlertPanel(@"InsomniaX", @"ERROR: Unable to find a temperature sensor to monitor for safety system, safety system is disabled, please contact support!", @"Ok", nil, nil);
                NSLog(@"ERROR: Unable to find a temperature sensor to monitor for safety system, safety system is disabled, please contact support!");
                cpuSafetyIsAvailable = false;
            }
            [[NSUserDefaults standardUserDefaults] setValue:[NSString stringWithFormat:@"%s",smcSensorKey] forKey:@"CPUSensorKey"];

            smc_close();
            
        }
        if (debug && cpuSafetyIsAvailable) NSLog(@"Monitoring sensor %s", smcSensorKey);
        
        if (!cpuSafetyIsAvailable) {
            // Disable CPU Safety Menu
            [CPUSafetyItem setState:NSOffState];
            [CPUSafetyItem setEnabled:false];
            [CPUSafetyItem setTitle:@"CPU Safety is unavailable"];
        } else {
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CPUSafety"])
                [CPUSafetyItem setState:NSOnState];
        }
        
        /* Install latest InsomniaX */
        NSString *supportPath = [NSHomeDirectory() stringByAppendingPathComponent: [NSString stringWithFormat: @"Library/Application Support/%@", [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleName"]]];
        //NSBundle *bundle = [NSBundle mainBundle];
        insomniaPath = [[NSString alloc] initWithString:[NSString stringWithFormat:@"%@/%@", supportPath, insomnia_name]];
        
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:insomniaPath]){
            NSLog(@"Installing Latest Kext");
            
            NSString *source = [[[[[NSBundle mainBundle] bundlePath]
                                stringByAppendingPathComponent:@"Contents"]
                                stringByAppendingPathComponent:@"Resources"]
                                stringByAppendingPathComponent:insomnia_name];
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:source]) {
                [[NSFileManager defaultManager] createDirectoryAtPath:supportPath withIntermediateDirectories:YES attributes:nil error:nil];
                [[NSFileManager defaultManager] copyItemAtPath:source toPath:[supportPath stringByAppendingPathComponent:insomnia_name] error:NULL];
            }
            
            NSLog(@"Latest Insomnia kext is installed at %@", insomniaPath);
        }
        
        /* Initialise and configure the loader */
        myInitAuthCommand();
    }
	
	/********************************	Status Item 	********************************/
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    
    LidSleepImage = [NSImage imageNamed:@"LidSleep"];
    [LidSleepImage setTemplate:true];
    LidIdleSleepImage = [NSImage imageNamed:@"LidIdleSleep"];
    [LidIdleSleepImage setTemplate:true];
    
    IdleSleepImage = [NSImage imageNamed:@"IdleSleep"];
    [IdleSleepImage setTemplate:true];
    NormalImage = [NSImage imageNamed:@"Normal"];
    [NormalImage setTemplate:true];

    
    [statusItem setImage:NormalImage];
    [statusItem setMenu:statusMenu];
    [statusItem setHighlightMode:YES];
    
    /********************************	Load on Login Item 	********************************/
    LaunchAtLoginController *launchController = [[LaunchAtLoginController alloc] init];
    BOOL launch = [launchController launchAtLogin];
    if (launch)
        [StartOnLoginItem setState:NSOnState];
    else
        [StartOnLoginItem setState:NSOffState];

	/*************************** Auto load functions **************************/
    [disableIdleSleepOnACItem setState:[[NSUserDefaults standardUserDefaults] integerForKey:@"disableIdleSleepOnAC"]];
    [disableLidSleepOnACItem setState:[[NSUserDefaults standardUserDefaults] integerForKey:@"disableLidSleepOnAC"]];

    /* Power Source Notification */
    powerNotifierRunLoopSource = IOPSNotificationCreateRunLoopSource (update, (__bridge void *)(self));
    
    if (powerNotifierRunLoopSource)
        CFRunLoopAddSource (CFRunLoopGetCurrent(), powerNotifierRunLoopSource, kCFRunLoopDefaultMode);
    
   
    /* Sets the hotkey */
	if ([[NSUserDefaults standardUserDefaults] integerForKey:@"idleKeyFlags"] != 0){
		int keyCombo = [[NSUserDefaults standardUserDefaults] integerForKey:@"idleKeyCombo"];
		int keyFlags = [[NSUserDefaults standardUserDefaults] integerForKey:@"idleKeyFlags"];
        [idleSR setKeyCombo:SRMakeKeyCombo(keyCombo, keyFlags)];
	}
    
    // Why load something thats not available?
    if (!disableInsomniaFunction) {
        if (!disableInsomniaFunction && [[NSUserDefaults standardUserDefaults] integerForKey:@"lidKeyFlags"] != 0){
            int keyCombo = [[NSUserDefaults standardUserDefaults] integerForKey:@"lidKeyCombo"];
            int keyFlags = [[NSUserDefaults standardUserDefaults] integerForKey:@"lidKeyFlags"];
            [lidSR setKeyCombo:SRMakeKeyCombo(keyCombo, keyFlags)];
        }
    }
    
    /* Sets the hotkey */
    if ([[NSUserDefaults standardUserDefaults] integerForKey:@"displaySleepKeyFlags"] != 0){
        int keyCombo = [[NSUserDefaults standardUserDefaults] integerForKey:@"displaySleepKeyCombo"];
        int keyFlags = [[NSUserDefaults standardUserDefaults] integerForKey:@"displaySleepKeyFlags"];
        [displaySleepSR setKeyCombo:SRMakeKeyCombo(keyCombo, keyFlags)];
    }
    
    /********************************	  Sounds  	 ********************************/
	if ([[NSUserDefaults standardUserDefaults] integerForKey:@"sound"] == TRUE){
        loadSound = [NSSound soundNamed:@"beep3"];
        unloadSound = [NSSound soundNamed:@"beep4"];
        idleEnableSound = [NSSound soundNamed:@"beep1"];
		idleDisableSound = [NSSound soundNamed:@"beep2"];
        [soundMenuItem setState:NSOnState];
	}
    
    [defaults synchronize];
    if ([defaults boolForKey:@"saveStateOnExit"] == TRUE) {
        if (!disableInsomniaFunction && [defaults boolForKey:@"lidSleepState"]) {
            [self setInsomniaState:true];
            [defaults setBool:false forKey:@"lidSleepState"];
        }
        if ([defaults boolForKey:@"idleSleepState"]) {
            [self setIdleSleepState:true];
            [defaults setBool:false forKey:@"idleSleepState"];
        }
    }
    [self setStatusIcon];
    [self setInsomniaStatus];
    
    if (!disableInsomniaFunction && [[NSUserDefaults standardUserDefaults] boolForKey:@"CPUSafety"] && [self insomniaState]) {
        [self setCPUSafetyState:TRUE];
    }
    
    
    /************** Background Thread ****************/
    systemTimer = [NSTimer scheduledTimerWithTimeInterval: 60
                                                           target: self
                                                         selector: @selector(backgroundThread:)
                                                         userInfo: nil
                                                          repeats: YES];
    [[NSRunLoop currentRunLoop] addTimer:systemTimer forMode:NSDefaultRunLoopMode];
    
    
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(appWillTerminate:)
               name:NSApplicationWillTerminateNotification
             object:nil];
}

- (BOOL)userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification{
    return YES;
}

-(void)sendNotificationWithTitle:(NSString *)title andText:(NSString *)text{
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = title;
    notification.informativeText = text;
    notification.soundName = NSUserNotificationDefaultSoundName;
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

-(void)backgroundThread:(NSTimer *)timer{
    if (enableLidSleepTimer != nil) {
        NSDate *lidSleepTimerFire = [enableLidSleepTimer fireDate];
        NSTimeInterval timeInterval = [lidSleepTimerFire timeIntervalSinceNow];
        [disableLidSleepForItem setTitle:[NSString stringWithFormat:@"Lid Sleep will be enabled in %@",[self convertTimeIntervalToString:timeInterval]]];
    }
    
    if (enableIdleSleepTimer != nil) {
        NSDate *idleSleepTimerFire = [enableIdleSleepTimer fireDate];
        NSTimeInterval timeInterval = [idleSleepTimerFire timeIntervalSinceNow];
        [disableIdleSleepForItem setTitle:[NSString stringWithFormat:@"Idle Sleep will be enabled in %@",[self convertTimeIntervalToString:timeInterval]]];
    }
}

-(NSString*)convertTimeIntervalToString:(NSTimeInterval)timeInterval {
    NSInteger ti = (NSInteger)timeInterval;
    NSInteger seconds = ti % 60;
    NSInteger minutes = (ti / 60) % 60;
    NSInteger hours = (ti / 3600);
    NSString *title;
    
    if (hours > 0 && minutes == 0) {
        title = [NSString stringWithFormat:@"%ld hours", hours];
    } else if (hours > 0) {
        title = [NSString stringWithFormat:@"%ld hours and %ld minutes", hours, minutes];
    } else if (minutes > 2) {
        title = [NSString stringWithFormat:@"%ld minutes", minutes];
    } else if (minutes > 0 && seconds == 0) {
        title = [NSString stringWithFormat:@"%ld minutes", minutes];
    } else if (minutes > 0) {
        title = [NSString stringWithFormat:@"%ld minutes and %ld seconds", minutes, seconds];
    } else {
        title = [NSString stringWithFormat:@"%ld seconds", seconds];
    }
    return title;
}

/*
 NSApp - Terminate Notification
 Notify user if they still have Insomnia loaded
 */
- (IBAction)quitInsomniaX:(id)sender{
    bool lidSleepState = [self insomniaState];
    bool idleSleepState = [self getIdleSleepState];
    if (idleSleepState) {
        [NSApp activateIgnoringOtherApps:YES];
        if (NSRunAlertPanel(@"InsomniaX",@"Idle Sleep is Disabled, Idle Sleep will be returned to normal if you continue",@"Continue",@"Cancel",NULL) == NSAlertAlternateReturn)
            return;
        
        [self setIdleSleepState:false];
    }
    
	if (lidSleepState){
		[NSApp activateIgnoringOtherApps:YES];
		if (NSRunAlertPanel(@"InsomniaX",@"Lid Sleep is Disabled, Lid Sleep will be returned to normal if you continue",@"Continue",@"Cancel",NULL) == NSAlertAlternateReturn)
            return;
        
        [self setInsomniaState:false];
    }
    
    
        
    [NSApp terminate:self];
}

- (void)appWillTerminate:(NSApplication *)sender{
    bool lidSleepState = [self insomniaState];
    bool idleSleepState = [self getIdleSleepState];
    [defaults synchronize];
    if ([defaults boolForKey:@"saveStateOnExit"] == TRUE) {
        if (enableLidSleepTimer == nil) {
            [defaults setBool:lidSleepState forKey:@"lidSleepState"];
        }
        if (enableIdleSleepTimer == nil) {
            [defaults setBool:idleSleepState forKey:@"idleSleepState"];
        }
    }
    //return NSTerminateCancel;
}


#pragma mark Menu Items

- (IBAction)insomnia:(id)sender
{
	if (!licence){
		[self makeReadme];
	} else {
		int state = [self insomniaState];
		if (state) {
			[self setInsomniaState:false];
		} else {
			[self setInsomniaState:true];
		}
	}
}

- (IBAction)idleSleepItem:(id)sender {
    if (!licence){
		[self makeReadme];
	} else {
        if ([self getIdleSleepState]) {
            [self setIdleSleepState:false];
        } else {
            [self setIdleSleepState:true];
        }
    }
}


- (IBAction)disableLidSleepFor:(id)sender{
    int timerLength = [disableLidSleepForSlider intValue];
    if (enableLidSleepTimer == nil) {
        enableLidSleepTimer = [NSTimer scheduledTimerWithTimeInterval: timerLength * 60
                                                        target: self
                                                      selector: @selector(disableLidSleepForTimer:)
                                                      userInfo: nil
                                                       repeats: NO];
        [[NSRunLoop currentRunLoop] addTimer:enableLidSleepTimer forMode:NSDefaultRunLoopMode];
    }
    
    [disableLidSleepForItem setTitle:[NSString stringWithFormat:@"Lid Sleep will be enabled in %@", [self convertTimeIntervalToString:timerLength * 60]]];
    [disableLidSleepForItem setEnabled:NO];
    [self sendNotificationWithTitle:@"InsomniaX: Lid Sleep Schedulded" andText:[NSString stringWithFormat:@"Lid Sleep will be enabled in %@", [self convertTimeIntervalToString:timerLength * 60]]];
    [self setInsomniaState:true];
    if (debug) NSLog(@"Disabling lid sleep for %i seconds", timerLength);
    NSWindow *theWindow = [sender window];
    [theWindow close];
}

-(void)disableLidSleepForTimer:(NSTimer *)timer{
    [self setInsomniaState:false];
//    [NSThread sleepForTimeInterval:1.0f];
//    [self setInsomniaStatus];
    [disableLidSleepForItem setTitle:@"Disable Lid Sleep For..."];
    [disableLidSleepForItem setEnabled:true];
    [enableLidSleepTimer invalidate];
    enableLidSleepTimer = nil;
    [self sendNotificationWithTitle:@"InsomniaX: Lid Sleep Enabled" andText:@"Lid Sleep was enabled as scheduled"];
    NSLog(@"Enabling lid sleep as per schedule");
}

- (IBAction)disableIdleSleepFor:(id)sender{
    int timerLength = [disableIdleSleepForSlider intValue];
    if (enableIdleSleepTimer == nil) {
        enableIdleSleepTimer = [NSTimer scheduledTimerWithTimeInterval: timerLength * 60
                                                               target: self
                                                             selector: @selector(disableIdleSleepForTimer:)
                                                             userInfo: nil
                                                              repeats: YES];
        [[NSRunLoop currentRunLoop] addTimer:enableIdleSleepTimer forMode:NSDefaultRunLoopMode];
    }
    
    [disableIdleSleepForItem setTitle:[NSString stringWithFormat:@"Idle Sleep will be enabled in %@", [self convertTimeIntervalToString:timerLength * 60]]];
    [disableIdleSleepForItem setEnabled:NO];
    [self sendNotificationWithTitle:@"InsomniaX: Idle Sleep Schedulded" andText:[NSString stringWithFormat:@"Idle Sleep will be enabled in %@", [self convertTimeIntervalToString:timerLength * 60]]];
    
    [self setIdleSleepState:true];
    if (debug) NSLog(@"Disabling idle sleep for %i seconds", timerLength);
    NSWindow *theWindow = [sender window];
    [theWindow close];
}

-(void)disableIdleSleepForTimer:(NSTimer *)timer{
    [self setIdleSleepState:false];
    [disableIdleSleepForItem setTitle:@"Disable Idle Sleep For..."];
    [disableIdleSleepForItem setEnabled:true];
    [enableIdleSleepTimer invalidate];
    enableIdleSleepTimer = nil;
    [self sendNotificationWithTitle:@"InsomniaX: Idle Sleep Enabled" andText:@"Idle Sleep was enabled as scheduled"];
    NSLog(@"Enabling idle sleep as per schedule");
}

- (IBAction)CPUSafety:(id)sender {
    [[NSUserDefaults standardUserDefaults] synchronize];
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CPUSafety"] == FALSE) {
        if ([self insomniaState]) {
            NSLog(@"Found Insomnia Loaded will now engage CPU Safety");
            [self setCPUSafetyState:TRUE];
        }
        [CPUSafetyItem setState:NSOnState];
        [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"CPUSafety"];
    } else {
        [self setCPUSafetyState:FALSE];
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"CPUSafety"];
        [CPUSafetyItem setState:NSOffState];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setStatusIcon {
    bool lidSleepState = [self insomniaState];
    bool idleSleepState = [self getIdleSleepState];
    
    if (lidSleepState && idleSleepState)
        [statusItem setImage:LidIdleSleepImage];
    else if (lidSleepState)
        [statusItem setImage:LidSleepImage];
    else if (idleSleepState)
        [statusItem setImage:IdleSleepImage];
    else
        [statusItem setImage:NormalImage];
}


- (IBAction)soundItem:(id)sender{
	[[NSUserDefaults standardUserDefaults] synchronize];
    //NSLog(@"Sound Item %@", [[NSUserDefaults standardUserDefaults] integerForKey:@"sound"]);
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"sound"]  == FALSE){
		loadSound = [[NSSound alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"beep3" ofType:@"wav"]
												byReference:YES];
		unloadSound = [[NSSound alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"beep4" ofType:@"wav"]
												  byReference:YES];
        idleEnableSound = [[NSSound alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"beep1" ofType:@"wav"]
                                                      byReference:YES];
		idleDisableSound = [[NSSound alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"beep2" ofType:@"wav"]
                                                       byReference:YES];
        [[NSUserDefaults standardUserDefaults] setBool:TRUE forKey:@"sound"];
        [soundMenuItem setState:NSOnState];
        if (debug) NSLog(@"Sounds enabled");
	} else {
		loadSound = nil;
		unloadSound = nil;
        idleDisableSound = nil;
        idleEnableSound = nil;
        [[NSUserDefaults standardUserDefaults] setBool:FALSE forKey:@"sound"];
        [soundMenuItem setState:NSOffState];
        if (debug) NSLog(@"Sounds disabled");
	}
}

#pragma mark AUTO Load Menu Items


- (IBAction)aboutItem:(id)sender{
	[[NSApplication sharedApplication] orderFrontStandardAboutPanel:nil];
	[NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)disableLidSleepOnAC:(id)sender {
    if ([defaults integerForKey:@"disableLidSleepOnAC"] == true) {
        [disableLidSleepOnACItem setState:NSOffState];
        [defaults setBool:false forKey:@"disableLidSleepOnAC"];
        [defaults setBool:false forKey:@"enableLidSleepOnBattery"];
        if (debug) NSLog(@"Enabling lid sleep on AC");
    } else {
        [disableLidSleepOnACItem setState:NSOnState];
        [defaults setBool:true forKey:@"disableLidSleepOnAC"];
        [defaults setBool:true forKey:@"enableLidSleepOnBattery"];
        if (debug) NSLog(@"Disabling lid sleep on AC");
        NSRunAlertPanel(@"InsomniaX", @"Lid sleep will be disabled while on charger, and enabled while on battery", @"Ok", nil, nil);
    }
    [defaults synchronize];
}
- (IBAction)disableIdleSleepOnAC:(id)sender {
    if ([defaults integerForKey:@"disableIdleSleepOnAC"] == NSOnState) {
        [disableIdleSleepOnACItem setState:NSOffState];
        [defaults setBool:false forKey:@"disableIdleSleepOnAC"];
        [defaults setBool:false forKey:@"enableIdleSleepOnBattery"];
        if (debug) NSLog(@"Enabling idle sleep on AC");
    } else {
        [disableIdleSleepOnACItem setState:NSOnState];
        [defaults setBool:true forKey:@"disableIdleSleepOnAC"];
        [defaults setBool:true forKey:@"enableIdleSleepOnBattery"];
        if (debug) NSLog(@"Disabling idle sleep on AC");
        NSRunAlertPanel(@"InsomniaX", @"Idle sleep will be disabled while on charger, and enabled while on battery", @"Ok", nil, nil);
    }
    [defaults synchronize];
}

- (IBAction)startOnLogin:(id)sender {
    LaunchAtLoginController *launchController = [[LaunchAtLoginController alloc] init];
    BOOL launch = [launchController launchAtLogin];
    if (launch) {
        [launchController setLaunchAtLogin:NO];
        [StartOnLoginItem setState:NSOffState];
        if (debug) NSLog(@"Enabling start at login");
    } else {
        [launchController setLaunchAtLogin:YES];
        [StartOnLoginItem setState:NSOnState];
        if (debug) NSLog(@"Disabling start at login");
    }
}


/* Sleep the display */
- (IBAction)sleepDisplay:(id)sender{
    if (!licence){
		[self makeReadme];
        NSLog(@"Licence not accepted!");
	} else {
        io_registry_entry_t r = IORegistryEntryFromPath(kIOMasterPortDefault, "IOService:/IOResources/IODisplayWrangler");
        if (r) {
            IORegistryEntrySetCFProperty(r, CFSTR("IORequestIdle"), kCFBooleanTrue);
            IOObjectRelease(r);
        }
    }
}

/* Locates the readme file and opens it */
- (IBAction)readmeItem:(id)sender {
	[NSApp activateIgnoringOtherApps:YES];
    [self makeReadme];
}

#pragma mark Insomnia

-(BOOL)insomniaState{
	BOOL kextState;
	CFURLRef bundleURL = KextManagerCreateURLForBundleIdentifier(NULL, (CFStringRef)insomnia_id);
	if (bundleURL == nil) {
		kextState = FALSE;
	} else {
		kextState = TRUE;
	}
	bundleURL = nil;

	if (debug) NSLog(@"Insomnia: %@", kextState ? @"Loaded" : @"Unloaded");
	
	return kextState;
}

-(void)setInsomniaStatus{
    int state = [self insomniaState];
	if (state) {
        [statusInsomniaItem setState:NSOnState];
        //[self sendNotificationWithTitle:@"InsomniaX: Lid Sleep Disabled" andText:@"Lid Sleep is disabled"];
	}
	else {
        [statusInsomniaItem setState:NSOffState];
        //[self sendNotificationWithTitle:@"InsomniaX: Lid Sleep Enabled" andText:@"Lid Sleep is enabled"];
	}
    [self setStatusIcon];
}

- (void)setInsomniaState:(BOOL)state{
	//int result;
	if (!licence){
        NSLog(@"Licence not accepted!");
		[self makeReadme];
		//result = 1;
    } else if (disableInsomniaFunction){
        NSLog(@"Insomnia Functions are currently disabled!");
    } else {
        CFURLRef bundleURL = KextManagerCreateURLForBundleIdentifier(NULL, (CFStringRef)@"org.binaervarianz.driver.insomnia");
        if (bundleURL != nil) {
            NSLog(@"We found a copy of another Insomnia loaded, ABORT!");
            NSRunAlertPanel(@"InsomniaX", @"ERROR: We found another version of Insomnia loaded, we can not continue with this conflict", @"Ok", nil, nil);
        } else {
            const char *CinsomniaPath = [insomniaPath UTF8String];
            if (!state) {
                if ([self insomniaState])
                    myPerformAuthCommand(kMyAuthorizedUnload, (char*)CinsomniaPath);
                
                [self setCPUSafetyState:FALSE];
                
                if ([defaults integerForKey:@"sound"] && loadSound != nil){
                    [loadSound play];
                }
                
                if (enableLidSleepTimer != nil) {
                    [disableLidSleepForItem setTitle:@"Disable Lid Sleep For..."];
                    [disableLidSleepForItem setEnabled:true];
                    [enableLidSleepTimer invalidate];
                    enableLidSleepTimer = nil;
                }
                if (debug) NSLog(@"Enabling Lid Sleep");
            } else {
                if (![self insomniaState])
                    myPerformAuthCommand(kMyAuthorizedLoad, (char*)CinsomniaPath);
                
                if ([[NSUserDefaults standardUserDefaults] boolForKey:@"CPUSafety"] == NSOnState) {
                    [self setCPUSafetyState:TRUE];
                }
                if ([defaults integerForKey:@"sound"] && unloadSound != nil){
                    [unloadSound play];
                }
                if (debug) NSLog(@"Disabling Lid Sleep");
            }
        }
		//[NSApp activateIgnoringOtherApps:YES];
	}
    [NSThread sleepForTimeInterval:1.0f];
    [self setInsomniaStatus];
//    int insomniaState = [self insomniaState];
//    if (insomniaState) {
//        [self sendNotificationWithTitle:@"InsomniaX: Lid Sleep Disabled" andText:@"Lid Sleep is disabled"];
//    }
//    else {
//        [self sendNotificationWithTitle:@"InsomniaX: Lid Sleep Enabled" andText:@"Lid Sleep is enabled"];
//    }
	//return result;
}

- (IBAction)runDiagnostics:(id)sender {
    NSLog(@"Performing diagnostics");
    if (disableInsomniaFunction) {
        NSLog(@"Insomnia functions are disabled, skipping Insomnia diagnostics");
    } else {
        CFURLRef bundleURL;
        bundleURL = KextManagerCreateURLForBundleIdentifier(NULL, (CFStringRef)@"org.binaervarianz.driver.insomnia");
        if (bundleURL != nil) {
            NSLog(@"org.binaervarianz.driver.insomnia is loaded, this will be an issue");
            NSRunAlertPanel(@"InsomniaX", @"ERROR: We found another version of Insomnia loaded, this will cause issues, this Insomnia was loaded by a 3rd party", @"Ok", nil, nil);
        }
        bundleURL = KextManagerCreateURLForBundleIdentifier(NULL, (CFStringRef)@"net.semaja2.kext.insomnia");
        if (bundleURL != nil) {
            NSLog(@"net.semaja2.kext.insomnia was already loaded, we will unload before diagnostics");
            NSRunAlertPanel(@"InsomniaX", @"WARNING: Lid Sleep is current disabled, we will disable for diagnostics", @"Ok", nil, nil);
            [self setInsomniaState:false];
        }
        
        NSLog(@"Running Insomnia diagnostics");
        myPerformAuthCommand(kMyAuthorizedDiag, "null");
    }
    
    NSRunAlertPanel(@"InsomniaX", @"Please wait while the diagnostics report is generated, this may take a few minutes", @"Ok", nil, nil);
    [NSThread sleepForTimeInterval:2.0f];
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:@"/usr/sbin/system_profiler"];
    [task setArguments:@[ @"-xml" ]];
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains (NSDesktopDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *outputFile = [documentsDirectory stringByAppendingString: [NSString stringWithFormat:@"/InsomniaX-Diagnostics-%f.spx", NSDate.date.timeIntervalSince1970 ]];
    [[NSFileManager defaultManager] createFileAtPath:outputFile contents:nil attributes:nil];
    NSFileHandle *outputHandle = [NSFileHandle fileHandleForWritingAtPath:outputFile];
    [task setStandardOutput:outputHandle];
    [task waitUntilExit];
    [task launch];
    [outputHandle closeFile];
    [NSThread sleepForTimeInterval:8.0f];
    NSRunAlertPanel(@"InsomniaX", @"Please send the diagnostics data on your desktop to support@semaja2.net", @"Ok", nil, nil);
}

- (IBAction)uninstall:(id)sender {

//    int result = NSRunAlertPanel(@"InsomniaX", @"InsomniaX will now return lid/idle sleep to normal, and remove its self", @"Uninstall", @"Cancel", nil);
//    
//    myPerformAuthCommand(kMyAuthorizedRemove, "null");
//    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
//    [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:appDomain];
//    [[NSFileManager defaultManager] removeFileAtPath:[[NSBundle mainBundle] bundlePath] handler:nil];
//    [NSApp terminate:self];
    
}


#pragma mark Idle Display Sleep
-(void)setIdleSleepState:(bool)state{
    if (!state) {
        if (debug) NSLog(@"Enabling Idle Sleep");
//        /* prevent the system from sleeping */
//        IOReturn success;
//        CFStringRef reasonForActivity= CFStringCreateWithCString( kCFAllocatorDefault, ("InsomniaX Idle Sleep"), kCFStringEncodingUTF8 );
//        //if ( [self activeVideoPlayback] )
//        //        success = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep, kIOPMAssertionLevelOn, reasonForActivity, &systemSleepAssertionID);
//        //else
//        success = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoIdleSleep, kIOPMAssertionLevelOn, reasonForActivity, &systemSleepAssertionID);
//        CFRelease( reasonForActivity );
//        if (success == kIOReturnSuccess) {
//            if (debug) NSLog(@"Idle Sleep disabled by IOKit");
//            [statusIdleSleepItem setState:NSOffState];
//            if ([defaults integerForKey:@"sound"] && idleDisableSound != nil){
//                [idleDisableSound play];
//            }
//        } else {
//            if (debug) NSLog(@"failed to prevent system sleep through IOKit");
//            [self sendNotificationWithTitle:@"InsomniaX: Failed" andText:@"Failed to disable idle sleep"];
//        }
        if (jigglerTimer != nil) {
            [jigglerTimer invalidate];
            jigglerTimer = nil;
            [statusIdleSleepItem setState:NSOffState];
            if ([defaults integerForKey:@"sound"] && idleDisableSound != nil){
                [idleDisableSound play];
            }

            //[statusIdleSleepItem setTitle:@"Disable Idle Sleep"];
        }
        if (enableIdleSleepTimer != nil) {
            [disableIdleSleepForItem setTitle:@"Disable Idle Sleep For..."];
            [disableIdleSleepForItem setEnabled:true];
            [enableIdleSleepTimer invalidate];
            enableIdleSleepTimer = nil;
        }
        //[self sendNotificationWithTitle:@"InsomniaX: Idle Sleep Enabled" andText:@"Idle Sleep is enabled"];
    } else {
        if (debug) NSLog(@"Disabling Idle Sleep");
//        /* allow the system to sleep again */
//        //if (debug) NSLog(@"releasing sleep blocker (%i)" , systemSleepAssertionID );
//        IOPMAssertionRelease( systemSleepAssertionID );
//        [statusIdleSleepItem setState:NSOnState];
//        if ([defaults integerForKey:@"sound"] && idleEnableSound != nil){
//            [idleEnableSound play];
//        }
        if (jigglerTimer == nil) {
            jigglerTimer = [NSTimer scheduledTimerWithTimeInterval: 5
                                                            target: self
                                                          selector: @selector(shakeIt:)
                                                          userInfo: nil
                                                           repeats: YES];
            [[NSRunLoop currentRunLoop] addTimer:jigglerTimer forMode:NSDefaultRunLoopMode];
            //[statusIdleSleepItem setTitle:@"Enable Idle Sleep"];
            [statusIdleSleepItem setState:NSOnState];
            if ([defaults integerForKey:@"sound"] && idleEnableSound != nil){
                [idleEnableSound play];
            }
        }
        //[self sendNotificationWithTitle:@"InsomniaX: Idle Sleep Disabled" andText:@"Idle Sleep is disabled"];
    }
    [self setStatusIcon];
}

-(bool)getIdleSleepState{
    bool state;
    
    if (jigglerTimer != nil)
        state = TRUE;
    else
        state = FALSE;
    
    return state;
}

-(void)shakeIt:(NSTimer *)timer{
	UpdateSystemActivity(0);
}



#pragma mark Readme
-(void)makeReadme{
    NSLog(@"Displaying readme dialog");
    if (readmePanel == nil) {
            NSView *readmeView;
            NSRect screenRect = [[NSScreen mainScreen] frame];
            float x = screenRect.size.width/2 - 225;
            float y = screenRect.size.height/2 - 300;
            NSRect windowRect = NSMakeRect(x,y,650,450);
            readmePanel = [[NSPanel alloc] initWithContentRect:windowRect
                                                      styleMask:NSTitledWindowMask | NSMiniaturizableWindowMask
                                                        backing:NSBackingStoreBuffered
                                                          defer:NO
                                                         screen:[NSScreen mainScreen]];
            //[readmePanel setReleasedWhenClosed:YES];
            [readmePanel setTitle:NSLocalizedString(@"readmeTitle", @"Readme Panel Title")];
            [readmePanel center];
            [readmePanel setReleasedWhenClosed:FALSE];
            readmeView = [[NSView alloc] initWithFrame:windowRect];
            
            NSImage *logo;
            logo =  [[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"InsomniaX" ofType:@"icns"]];
            
            NSImageView *logoView;
            logoView = [[NSImageView alloc] initWithFrame:NSMakeRect(8,windowRect.size.height - 12 -128,128,128)];
            [logoView setImage:logo];
            [readmeView addSubview:logoView];
            
            NSTextField *versionNumber;
            versionNumber = [[NSTextField alloc] initWithFrame:NSMakeRect(12,50,128,40)];
            NSDictionary *dict = [NSDictionary dictionaryWithObject:[NSFont systemFontOfSize:14.0] forKey:NSFontAttributeName];
            NSDictionary *bolddict = [NSDictionary dictionaryWithObject:[NSFont boldSystemFontOfSize:14.0] forKey:NSFontAttributeName];
            NSMutableAttributedString *str = [[NSMutableAttributedString alloc] initWithString:@"InsomniaX" attributes:bolddict];
                
        //NSString *strVersion;
        //strVersion = [[NSString alloc] initWithString:[NSString stringWithFormat:@"\n Version: %@",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]]];
        
            [str appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"\n Version: %@",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]] attributes:dict]];
            
            [versionNumber setAttributedStringValue:str];
            [versionNumber setBordered:NO];
            [versionNumber setAlignment:NSCenterTextAlignment];
            [versionNumber setEditable:NO];
            [versionNumber setDrawsBackground:NO];
            [readmeView addSubview:versionNumber];
            
            NSTextView *message = [[NSTextView alloc] initWithFrame:NSMakeRect(0,0,650-142-12-16,800)];
            [message setEditable:NO]; 
            [message setRichText:YES];
            [message readRTFDFromFile:[[NSBundle mainBundle] pathForResource:@"Readme" ofType:@"rtf"]];
            NSScrollView *myScrollView =  [[NSScrollView alloc] initWithFrame:NSMakeRect(142,windowRect.size.height - (windowRect.size.height - 72) - 12,650-142-12,windowRect.size.height - 72)];
            [myScrollView setDocumentView:message];
            [myScrollView setHasVerticalScroller:YES];
            [myScrollView setAutohidesScrollers:YES];
            [myScrollView setBorderType:NSGrooveBorder];
            [readmeView addSubview:myScrollView];
            

            logoSubText = [[NSTextField alloc] initWithFrame:NSMakeRect(12,windowRect.size.height - 12 - 256 -12 -128,128,256)];
            [logoSubText setStringValue:NSLocalizedString(@"readmeLicence", @"Readme Panel Licence")];
            [logoSubText setBordered:NO];
            //[logoSubText setAlignment:NSJustifiedTextAlignment];
            [logoSubText setEditable:NO];
            [logoSubText setDrawsBackground:NO];
            [readmeView addSubview:logoSubText];
            
            
            agreeButton = [[NSButton alloc] initWithFrame:NSMakeRect((650 - 100 - 12),12,100,32)];
            [agreeButton setButtonType:NSMomentaryPushInButton];
            [agreeButton setBezelStyle:NSRoundedBezelStyle];
            [agreeButton setAction:@selector(acceptButton:)];
            [agreeButton setTarget:self];
            [agreeButton setTitle:NSLocalizedString(@"Agree", @"Agree")];
            [readmeView addSubview:agreeButton];
            
            
            
            disagreeButton = [[NSButton alloc] initWithFrame:NSMakeRect((650 - 100 - 100 - 12 - 12),12,100,32)];
            [disagreeButton setButtonType:NSMomentaryPushInButton];
            [disagreeButton setBezelStyle:NSRoundedBezelStyle];
            [disagreeButton setAction:@selector(terminate:)];
            [disagreeButton setTarget:NSApp];
            [disagreeButton setTitle:NSLocalizedString(@"Disagree", @"Disagree")];
            [readmeView addSubview:disagreeButton];
            
        
            [readmePanel setContentView:readmeView];
    }
    if ([defaults boolForKey:kReadmeVersion] == TRUE) {
        [logoSubText setHidden:TRUE];
        [disagreeButton setHidden:TRUE];
        [agreeButton setTitle:NSLocalizedString(@"Ok", @"Ok")];
        [agreeButton setAction:@selector(close)];
        [agreeButton setTarget:readmePanel];
    }
	//[readmeView autorelease];
	[readmePanel makeKeyAndOrderFront:self];
    [NSApp activateIgnoringOtherApps:YES];
}

-(IBAction)acceptButton:(id)sender{
	[defaults setBool:TRUE forKey:kReadmeVersion];
	[defaults synchronize];
	licence = [defaults integerForKey:kReadmeVersion];
	[readmePanel close];
}



#pragma mark Temperature Safety
-(float)getTemperatureForKey:(char*)key {
    smc_init();
    float temperature = SMCGetTemperature(key);
    if (debug) NSLog(@"CPU Temp: %f", temperature);
    smc_close();
    return temperature;
}

-(void)CPUSafetyCheck:(NSTimer *)timer{
    //If Insomnia is not even loaded lets skip the check and remove the check
    if ([self insomniaState]) {
        float CPUTemp = [self getTemperatureForKey:smcSensorKey];
        if (debug) NSLog(@"Max CPU Temp: %f, Current CPU Temp: %f", CPUSafetyTemp, CPUTemp);
        if (CPUTemp > CPUSafetyTemp) {
            [self setInsomniaState:false];
            NSLog(@"Returning lid sleep to normal as CPU exceeded safe limits");
            NSRunAlertPanel(@"InsomniaX", @"Lid Sleep was returned to normal due to the CPU exceeding safe limits", @"Ok", nil, nil);
            [self sendNotificationWithTitle:@"InsomniaX: CPU Safety" andText:@"Lid Sleep was enabled as the CPU temperature exceeded safety limits"];
        }
    } else {
        NSLog(@"Could not find Insomnia disable CPU check");
        [self setCPUSafetyState:FALSE];
    }
}

-(void)setCPUSafetyState:(BOOL)state{
    /* CPU Safety Timer */
    if (!cpuSafetyIsAvailable) {
        NSLog(@"Unable to enable CPU Safety due to missing sensors!");
    } else if (state) {
        if (debug) NSLog(@"Engage CPU Safety");
        CPUTempSafetyTimer = [NSTimer scheduledTimerWithTimeInterval: 30
                                                              target: self
                                                            selector: @selector(CPUSafetyCheck:)
                                                            userInfo: nil
                                                             repeats: YES];
        [[NSRunLoop currentRunLoop] addTimer:CPUTempSafetyTimer forMode:NSDefaultRunLoopMode];
    } else {
        if (debug) NSLog(@"Disengage CPU Safety");
        if (CPUTempSafetyTimer != nil) {
            [CPUTempSafetyTimer invalidate];
            CPUTempSafetyTimer = nil;
        }
    }
}

#pragma mark Power
-(void)powerSourceChanged:(unsigned int) status{
    //NSLog(@"Powerevent");
    if (intLastPowerState != status) {
        if (debug) NSLog(@"Power Source Changed");
        bool idleSleepState = [self getIdleSleepState];
        if (status == POWER_BATTERY) {
            if (debug) NSLog(@"On Battery");
            if ([defaults integerForKey:@"disableLidSleepOnBattery"] == NSOnState) {
                [self setInsomniaState:true];
                if (debug) NSLog(@"Disabling Lid Sleep as we are on battery");
                [self sendNotificationWithTitle:@"InsomniaX: Lid Sleep Disabled" andText:@"Disabling Lid Sleep as we are on battery"];
            }
            if ([defaults integerForKey:@"enableLidSleepOnBattery"] == NSOnState) {
                [self setInsomniaState:false];
                if (debug) NSLog(@"Enabling Lid Sleep as we are on battery");
                [self sendNotificationWithTitle:@"InsomniaX: Lid Sleep Enabled" andText:@"Enabling Lid Sleep as we are on battery"];
            }
            
            if ([defaults integerForKey:@"disableIdleSleepOnBattery"] == NSOnState && idleSleepState == FALSE) {
                [self setIdleSleepState:true];
                if (debug) NSLog(@"Disabling Idle Sleep as we are on battery");
                [self sendNotificationWithTitle:@"InsomniaX: Idle Sleep Disabled" andText:@"Disabling Idle Sleep as we are on battery"];
            }
            if ([defaults integerForKey:@"enableIdleSleepOnBattery"] == NSOnState && idleSleepState == TRUE) {
                [self setIdleSleepState:false];
                if (debug) NSLog(@"Enabling Idle Sleep as we are on battery");
                [self sendNotificationWithTitle:@"InsomniaX: Idle Sleep Enabled" andText:@"Enabling Idle Sleep as we are on battery"];
            }
        } else if (status == POWER_AC) {
            if (debug) NSLog(@"On AC");
            if ([defaults integerForKey:@"disableLidSleepOnAC"] == NSOnState) {
                [self setInsomniaState:true];
                if (debug) NSLog(@"Disabling Lid Sleep as we are on AC");
                [self sendNotificationWithTitle:@"InsomniaX: Lid Sleep Disabled" andText:@"Disabling Lid Sleep as we are on AC"];
            }
            if ([defaults integerForKey:@"enableLidSleepOnAC"] == NSOnState) {
                [self setInsomniaState:false];
                if (debug) NSLog(@"Enabling Lid Sleep as we are on AC");
                [self sendNotificationWithTitle:@"InsomniaX: Lid Sleep Enabled" andText:@"Enabling Lid Sleep as we are on AC"];
            }
            
            
            if ([defaults integerForKey:@"disableIdleSleepOnAC"] == NSOnState && idleSleepState == FALSE) {
                [self setIdleSleepState:true];
                if (debug) NSLog(@"Disabling Idle Sleep as we are on AC");
                [self sendNotificationWithTitle:@"InsomniaX: Idle Sleep Disabled" andText:@"Disabling Idle Sleep as we are on AC"];
            }
            if ([defaults integerForKey:@"enableIdleSleepOnAC"] == NSOnState && idleSleepState == TRUE) {
                [self setIdleSleepState:false];
                if (debug) NSLog(@"Enabling Idle Sleep as we are on AC");
                [self sendNotificationWithTitle:@"InsomniaX: Idle Sleep Enabled" andText:@"Enabling Idle Sleep as we are on AC"];
            }
        }
        intLastPowerState = status;
    }
    
}

#pragma mark Hot Key
- (void)shortcutRecorder:(SRRecorderControl *)aRecorder keyComboDidChange:(KeyCombo)newKeyCombo {

    int keyCombo = [aRecorder keyCombo].code;
    int keyFlags = [aRecorder keyCombo].flags;
    
    //NSLog(@"KeyCombo %ld, KeyFlags %ld", keyCombo, keyFlags);
    
    if (aRecorder == idleSR) {
        //NSLog(@"Idle KeyCombo");
        [[NSUserDefaults standardUserDefaults] setInteger:keyCombo forKey:@"idleKeyCombo"];
        [[NSUserDefaults standardUserDefaults] setInteger:keyFlags forKey:@"idleKeyFlags"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        if (idleHotKey != nil) {
        //NSLog(@"Found Key");
        [[PTHotKeyCenter sharedCenter] unregisterHotKey: idleHotKey];
        idleHotKey = nil;
        }
        
        //NSLog(@"Set new key");
        idleHotKey = [[PTHotKey alloc] initWithIdentifier:@"idleHotKey"
                                                   keyCombo:[PTKeyCombo keyComboWithKeyCode:keyCombo
                                                                                  modifiers:[aRecorder cocoaToCarbonFlags: keyFlags]]];
        
        [idleHotKey setTarget: self];
        [idleHotKey setAction: @selector(idleSleepItem:)];
        
        [[PTHotKeyCenter sharedCenter] registerHotKey: idleHotKey];
        
        [statusIdleSleepItem setKeyEquivalent:[aRecorder keyCharsIgnoringModifiers]];
        [statusIdleSleepItem setKeyEquivalentModifierMask:keyFlags];
        
        [idleHotKeyPanel close];
    } else if (aRecorder == lidSR) {
        //NSLog(@"Lid KeyCombo");
        [[NSUserDefaults standardUserDefaults] setInteger:keyCombo forKey:@"lidKeyCombo"];
        [[NSUserDefaults standardUserDefaults] setInteger:keyFlags forKey:@"lidKeyFlags"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        if (lidHotKey != nil) {
            //NSLog(@"Found Key");
            [[PTHotKeyCenter sharedCenter] unregisterHotKey: lidHotKey];
            lidHotKey = nil;
        }
        
        //NSLog(@"Set new key");
        lidHotKey = [[PTHotKey alloc] initWithIdentifier:@"lidHotKey"
                                                 keyCombo:[PTKeyCombo keyComboWithKeyCode:keyCombo
                                                                                modifiers:[aRecorder cocoaToCarbonFlags: keyFlags]]];
        
        [lidHotKey setTarget: self];
        [lidHotKey setAction: @selector(insomnia:)];
        
        [[PTHotKeyCenter sharedCenter] registerHotKey: lidHotKey];
        
        [statusInsomniaItem setKeyEquivalent:[aRecorder keyCharsIgnoringModifiers]];
        [statusInsomniaItem setKeyEquivalentModifierMask:keyFlags];
        
        if (lidHotKeyPanel != nil)
            [lidHotKeyPanel performClose:self];
    } else if (aRecorder == displaySleepSR) {
        //NSLog(@"Lid KeyCombo");
        [[NSUserDefaults standardUserDefaults] setInteger:keyCombo forKey:@"displaySleepKeyCombo"];
        [[NSUserDefaults standardUserDefaults] setInteger:keyFlags forKey:@"displaySleepKeyFlags"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        if (displaySleepHotKey != nil) {
            //NSLog(@"Found Key");
            [[PTHotKeyCenter sharedCenter] unregisterHotKey: displaySleepHotKey];
            displaySleepHotKey = nil;
        }
        
        //NSLog(@"Set new key");
        displaySleepHotKey = [[PTHotKey alloc] initWithIdentifier:@"displaySleepHotKey"
                                                keyCombo:[PTKeyCombo keyComboWithKeyCode:keyCombo
                                                                               modifiers:[aRecorder cocoaToCarbonFlags: keyFlags]]];
        
        [displaySleepHotKey setTarget: self];
        [displaySleepHotKey setAction: @selector(sleepDisplay:)];
        
        [[PTHotKeyCenter sharedCenter] registerHotKey: displaySleepHotKey];
        
        [sleepDisplayItem setKeyEquivalent:[aRecorder keyCharsIgnoringModifiers]];
        [sleepDisplayItem setKeyEquivalentModifierMask:keyFlags];
        
        if (displaySleepHotKey != nil)
            [displaySleepHotKeyPanel performClose:self];
    }
    
    
    
    
}

- (IBAction)idleHotKeyItem:(id)sender {
    [idleHotKeyPanel makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (IBAction)lidHotKeyItem:(id)sender {
    [lidHotKeyPanel makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

-(NSString *) machineModel
{
    size_t len = 0;
    sysctlbyname("hw.model", NULL, &len, NULL, 0);
    
    if (len)
    {
        char *model = malloc(len*sizeof(char));
        sysctlbyname("hw.model", model, &len, NULL, 0);
        NSString *model_ns = [NSString stringWithUTF8String:model];
        free(model);
        return model_ns;
    }
    
    return @"Unknown"; //incase model name can't be read
}

@end