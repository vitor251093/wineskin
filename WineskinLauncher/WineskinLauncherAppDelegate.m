//
//  WineskinAppDelegate.m
//  Wineskin
//
//  Copyright 2014 by The Wineskin Project and Urge Software LLC All rights reserved.
//  Licensed for use under the LGPL <http://www.gnu.org/licenses/lgpl-2.1.txt>
//

#import "WineskinLauncherAppDelegate.h"

#import <ObjectiveC_Extension/ObjectiveC_Extension.h>

#import "NSPathUtilities.h"
#import "NSPortDataLoader.h"

@implementation WineskinLauncherAppDelegate

static NSPortManager* portManager;

-(NSPortManager*)portManager
{
    @synchronized([self class])
    {
        if (!portManager)
        {
            portManager = [NSPortManager managerForWrapperAtPath:[[NSBundle mainBundle] bundlePath]];
        }
        
        return portManager;
    }
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
    [globalFilesToOpen addObjectsFromArray:filenames];
    if (wrapperRunning)
    {
        [NSThread detachNewThreadSelector:@selector(secondaryRun:) toTarget:self withObject:[globalFilesToOpen copy]];
        [globalFilesToOpen removeAllObjects];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[window setLevel:NSStatusWindowLevel];
	[waitWheel startAnimation:self];
	
	[self installEngine];
	if ([globalFilesToOpen containsObject:@"WSS-InstallICE"]) exit(0);
    
	// Normal run
    [NSThread detachNewThreadSelector:@selector(mainRun:) toTarget:self withObject:[globalFilesToOpen copy]];
    [globalFilesToOpen removeAllObjects];
    wrapperRunning=YES;
}

- (void)applicationWillFinishLaunching:(NSNotification*)aNotification
{
    appNameWithPath = self.portManager.path;
    contentsFold = [NSString stringWithFormat:@"%@/Contents",appNameWithPath];
    frameworksFold = [NSString stringWithFormat:@"%@/Frameworks",contentsFold];
    winePrefix = [NSString stringWithFormat:@"%@/Resources",contentsFold];
    
    appName = appNameWithPath.lastPathComponent.stringByDeletingPathExtension;
    tmpFolder = [NSString stringWithFormat:@"/tmp/%@",[appNameWithPath stringByReplacingOccurrencesOfString:@"/" withString:@"xWSx"]];
    tmpwineFolder = [NSString stringWithFormat:@"/tmp/.wine-501/"];
    
    globalFilesToOpen = [[NSMutableArray alloc] init];
    fm = [NSFileManager defaultManager];
    wrapperRunning = NO;
    removeX11TraceFromLog = NO;
    primaryRun = YES;
    
    CGEventRef event = CGEventCreate(NULL);
    CGEventFlags modifiers = CGEventGetFlags(event);
    CFRelease(event);
    
    if ((modifiers & kCGEventFlagMaskAlternate)   == kCGEventFlagMaskAlternate ||
        (modifiers & kCGEventFlagMaskSecondaryFn) == kCGEventFlagMaskSecondaryFn)
    {
        [self doSpecialStartup];
    }
}

- (void)doSpecialStartup
{
	//when holding modifier key
	NSString* theSystemCommand = [NSString stringWithFormat: @"open \"%@/Wineskin.app\"", [[NSBundle mainBundle] bundlePath]];
	system([theSystemCommand UTF8String]);
    [NSApp terminate:nil];
}

- (NSString *)systemCommand:(NSString *)command
{
	FILE *fp;
	char buff[512];
	NSMutableString *returnString = [[NSMutableString alloc] init];
	fp = popen([command cStringUsingEncoding:NSUTF8StringEncoding], "r");
	while (fgets( buff, sizeof buff, fp))
    {
        [returnString appendString:[NSString stringWithCString:buff encoding:NSUTF8StringEncoding]];
    }
	pclose(fp);
    
    //cut out trailing new line
	if ([returnString hasSuffix:@"\n"])
    {
        [returnString deleteCharactersInRange:NSMakeRange([returnString length]-1,1)];
    }
	return [NSString stringWithString:returnString];
}

- (void)mainRun:(NSArray*)filesToOpen
{
    @autoreleasepool
    {
        // TODO need to add option to make wrapper run in AppSupport (shadowcopy) so that no files will ever be written in the app
        // TODO need to make all the temp files inside the wrapper run correctly using BundleID and in /tmp.  If they don't exist, assume everything is fine.
        // TODO add blocks to sections that need them for variables to free up memory.
    
        NSMutableArray *filesToRun = [[NSMutableArray alloc] init];
        theDisplayNumber = [[NSMutableString alloc] init];
        NSMutableString *wineRunLocation = [[NSMutableString alloc] init];
        NSMutableString *programNameAndPath = [[NSMutableString alloc] init];
        NSMutableString *cliCustomCommands = [[NSMutableString alloc] init];
        NSMutableString *programFlags = [[NSMutableString alloc] init];
        NSMutableString *vdResolution = [[NSMutableString alloc] init];
        fullScreenResolutionBitDepth = [[NSMutableString alloc] init];
        [fullScreenResolutionBitDepth setString:@"unset"];
        xQuartzX11BinPID = [[NSMutableString alloc] init];
        gammaCorrection = [[NSMutableString alloc] init];
        BOOL runWithStartExe = NO;
        fullScreenOption = NO;
        //useRandR = NO;
        useGamma = YES;
        debugEnabled = NO;
        BOOL cexeRun = NO;
        BOOL nonStandardRun = NO;
        BOOL openingFiles = NO;
        
        NSString *wssCommand;
        if (filesToOpen.count > 0)
        {
            wssCommand = filesToOpen[0];
        }
        else
        {
            wssCommand = @"nothing";
        }
        if ([wssCommand isEqualToString:@"CustomEXE"]) cexeRun = YES;
        
        [fm createDirectoryAtPath:tmpFolder withIntermediateDirectories:YES];
        [self systemCommand:[NSString stringWithFormat:@"chmod -R 777 \"%@\"",tmpFolder]];
        
        lockfile        = [NSString stringWithFormat:@"%@/lockfile",tmpFolder];
        wineLogFile     = [NSString stringWithFormat:@"%@/Logs/LastRunWine.log",winePrefix];
        wineTempLogFile = [NSString stringWithFormat:@"%@/LastRunWineTemp.log",tmpFolder];
        x11LogFile      = [NSString stringWithFormat:@"%@/Logs/LastRunX11.log",winePrefix];
        useMacDriver    = [self checkToUseMacDriver];
        useXQuartz      = [self checkToUseXQuartz];
        
        //exit if the lock file exists, another user is running this wrapper currently
        BOOL lockFileAlreadyExisted = NO;
        if ([fm fileExistsAtPath:lockfile])
        {
            //read in lock file to get user name of who locked it, if same user name ignore
            if (![[[self readFileToStringArray:lockfile] objectAtIndex:0] isEqualToString:NSUserName()])
            {
                CFUserNotificationDisplayNotice(0, 0, NULL, NULL, NULL, CFSTR("ERROR"), CFSTR("Another user on this system is currently using this application\n\nThey must exit the application before you can use it."), NULL);
                return;
            }
                lockFileAlreadyExisted = YES;
        }
        else
        {
            //create lockfile that we are already in use
            [self writeStringArray:@[NSUserName()] toFile:lockfile];
            [self systemCommand:[NSString stringWithFormat:@"chmod -R 777 \"%@\"",tmpFolder]];
        }
        
        //fix Wine names which also is setting for bundle ID
        [self fixWineExecutableNames];
        
        //open Info.plist to read all needed info
        NSPortManager *cexeManager = nil;
        NSString *resolutionTemp;
        
        //check to make sure CFBundleName is not WineskinNavyWrapper, if it is, change it to current wrapper name
        if ([[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_NAME] isEqualToString:@"WineskinNavyWrapper"])
        {
            [self.portManager setPlistObject:appName forKey:WINESKIN_WRAPPER_PLIST_KEY_NAME];
        }
        [self.portManager setPlistObject:[NSString stringWithFormat:@"%@.wineskin.prefs",wineName]
                                  forKey:WINESKIN_WRAPPER_PLIST_KEY_IDENTIFIER];
        [self.portManager synchronizePlist];
        
        //need to handle it different if its a cexe
        if (!cexeRun)
        {
            [programNameAndPath setString:[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH]];
            [programFlags       setString:[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH_FLAGS]];
            fullScreenOption = [[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_SCREEN_OPTIONS_IS_FULLSCREEN] intValue];
            resolutionTemp   =  [self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_SCREEN_OPTIONS_CONFIGURATIONS];
            runWithStartExe  = [[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH_IS_NOT_EXE] intValue];
            //useRandR = [[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_SCREEN_OPTIONS_ARE_AUTOMATIC] intValue];
        }
        else
        {
            cexeManager = [NSPortManager managerForCustomExeAtPath:[NSString stringWithFormat:@"%@/%@",
                                                                    appNameWithPath,[filesToOpen objectAtIndex:1]]];
            [programNameAndPath setString:[cexeManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH]];
            [programFlags       setString:[cexeManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH_FLAGS]];
            fullScreenOption           = [[cexeManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_SCREEN_OPTIONS_IS_FULLSCREEN] intValue];
            resolutionTemp             =  [cexeManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_SCREEN_OPTIONS_CONFIGURATIONS];
            runWithStartExe            = [[cexeManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH_IS_NOT_EXE] intValue];
            //useGamma = [[cexeManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_GAMMA_CORRECTION] intValue];
            //useRandR = [[cexeManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_SCREEN_OPTIONS_ARE_AUTOMATIC] intValue];
        }
        
        debugEnabled = [[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_DEBUG_MODE] intValue];
        //forceWrapperQuartzWM = [[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_DECORATE_WINDOW] intValue];
        //useXQuartz = [[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_USE_XQUARTZ] intValue];
        
        //set correct dyldFallBackLibraryPath
        if (useXQuartz)
        {
            dyldFallBackLibraryPath = [NSString stringWithFormat:@"/opt/X11/lib:/opt/local/lib:%@:%@/wswine.bundle/lib:%@/wswine.bundle/lib64:/usr/lib:/usr/libexec:/usr/lib/system:/usr/X11/lib:/usr/X11R6/lib",frameworksFold,frameworksFold,frameworksFold];
        }
        else
        {
            dyldFallBackLibraryPath = [NSString stringWithFormat:@"%@:%@/wswine.bundle/lib:%@/wswine.bundle/lib64:/usr/lib:/usr/libexec:/usr/lib/system:/opt/X11/lib:/opt/local/lib:/usr/X11/lib:/usr/X11R6/lib",frameworksFold,frameworksFold,frameworksFold];
        }
        
        [gammaCorrection setString:[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_GAMMA_CORRECTION]];
        x11PListFile = [NSString stringWithFormat:@"%@/Library/Preferences/%@.plist",NSHomeDirectory(),
                        [self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_IDENTIFIER]];
        NSString *uLimitNumber;
        if ([[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_MAX_OF_10240_FILES] intValue])
        {
            uLimitNumber = @"launchctl limit maxfiles 10240 10240;ulimit -n 10240 > /dev/null 2>&1;";
        }
        else
        {
            uLimitNumber = @"";
        }
        
        //if any program flags, need to add a space to the front of them
        if (!([programFlags isEqualToString:@""]))
        {
            [programFlags insertString:@" " atIndex:0];
        }
        
        [NSPortDataLoader getValuesFromResolutionString:resolutionTemp inBlock:
         ^(BOOL virtualDesktop, NSString *resolution, int colors, int sleep)
        {
            //resolutionTemp needs to be stripped for resolution info, bit depth, and switch pause
            [vdResolution setString:resolution ? [resolution stringByReplacingOccurrencesOfString:@"x" withString:@" "] :
                                                 WINESKIN_WRAPPER_PLIST_VALUE_SCREEN_OPTIONS_NO_VIRTUAL_DESKTOP];
            
            if ([self->fullScreenResolutionBitDepth isEqualToString:@"unset"])
            {
                [self->fullScreenResolutionBitDepth setString:[NSString stringWithFormat:@"%d",colors]];
            }
            
            //make sure vdReso has a space, not an x
            self->currentResolution = [self getScreenResolution];
            if ([vdResolution isEqualToString:WINESKIN_WRAPPER_PLIST_VALUE_SCREEN_OPTIONS_CURRENT_RESOLUTION])
            {
                [vdResolution setString:self->currentResolution];
            }
        }];
        
        [cliCustomCommands setString:[self.portManager plistObjectForKey:@"CLI Custom Commands"]];
        if (!([cliCustomCommands hasSuffix:@";"]) && ([cliCustomCommands length] > 0))
        {
            [cliCustomCommands appendString:@";"];
        }
        
        //******* fix all data correctly
        //list of possile options
        //WSS-installer {path/file}	- Installer is calling the program
        //WSS-winecfg 				- need to run winecfg
        //WSS-cmd					- need to run cmd
        //WSS-regedit 				- need to run regedit
        //WSS-taskmgr 				- need to run taskmgr
        //WSS-uninstaller			- run uninstaller
        //WSS-wineprefixcreate		- need to run wineboot, refresh wrapper
        //WSS-wineprefixcreatenoregs- same as above, doesn't load default regs
        //WSS-wineboot				- run simple wineboot, no deletions or loading regs. mshtml=disabled
        //WSS-winetricks {command}	- winetricks is being run
        //WSS-wineserverkill        - tell winesever to kill all wine processes from wrapper
        //debug 					- run in debug mode, keep logs
        //CustomEXE {appname}		- running a custom EXE with appname
        //starts with a"/" 			- will be 1+ path/filename to open
        //no command line args		- normal run
        
        NSMutableArray *winetricksCommands = [[NSMutableArray alloc] init];
        if ([filesToOpen count] > 1)
        {
            [winetricksCommands addObjectsFromArray:[filesToOpen subarrayWithRange:NSMakeRange(1, [filesToOpen count]-1)]];
        }
        if ([filesToOpen count] > 0)
        {
            if ([wssCommand hasPrefix:@"/"]) //if wssCommand starts with a / its file(s) passed in to open
            {
                for (NSString *item in filesToOpen)
                {
                    [filesToRun addObject:item];
                }
                openingFiles=YES;
            }
            else if ([wssCommand hasPrefix:@"WSS-"]) //if wssCommand starts with WSS- its a special command
            {
                debugEnabled = YES; //need logs in special commands
                useGamma = NO;
                if ([wssCommand isEqualToString:@"WSS-wineserverkill"])
                {
                [NSThread detachNewThreadSelector:@selector(wineBootStuckProcess) toTarget:self withObject:nil];
                NSArray* command = @[
                                     [NSString stringWithFormat:@"export PATH=\"%@/wswine.bundle/bin:%@/bin:$PATH:/opt/local/bin:/opt/local/sbin\";",frameworksFold,frameworksFold],
                                     [NSString stringWithFormat:@"export WINEPREFIX=\"%@\";",winePrefix],
                                     [NSString stringWithFormat:@"DYLD_FALLBACK_LIBRARY_PATH=\"%@\"",dyldFallBackLibraryPath],
                                     @"wineserver -k"];
                [self systemCommand:[command componentsJoinedByString:@" "]];
                usleep(3000000);
                }
                if ([wssCommand isEqualToString:@"WSS-installer"]) //if its in the installer, need to know if normal windows are forced
                {
                    if ([[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_INSTALLER_WITH_NORMAL_WINDOWS] intValue] == 1)
                    {
                        [fullScreenResolutionBitDepth setString:@"24"];
                        [vdResolution setString:WINESKIN_WRAPPER_PLIST_VALUE_SCREEN_OPTIONS_NO_VIRTUAL_DESKTOP];
                        fullScreenOption = NO;
                        //sleepNumber = 0;
                    }
                    [programNameAndPath setString:[filesToOpen objectAtIndex:1]]; // second argument full path and file name to run
                    runWithStartExe = YES; //installer always uses start.exe
                }
                else //any WSS that isn't the installer
                {
                    [fullScreenResolutionBitDepth setString:@"24"]; // all should force normal windows
                    [vdResolution setString:WINESKIN_WRAPPER_PLIST_VALUE_SCREEN_OPTIONS_NO_VIRTUAL_DESKTOP];
                    fullScreenOption = NO;
                    //sleepNumber = 0;
                    //should only use this line for winecfg cmd regedit and taskmgr, other 2 do nonstandard runs and wont use this line
                    if ([wssCommand isEqualToString:@"WSS-regedit"])
                    {
                        [programNameAndPath setString:@"/windows/regedit.exe"];
                    }
                    else
                    {
                        if ([wssCommand isEqualToString:@"WSS-cmd"])
                        {
                            runWithStartExe=YES;
                        }
                        [programNameAndPath setString:[NSString stringWithFormat:@"/windows/system32/%@.exe",[wssCommand stringByReplacingOccurrencesOfString:@"WSS-" withString:@""]]];
                    }
                    [programFlags setString:@""]; // just in case there were some flags... don't use on these.
                    if ([wssCommand isEqualToString:@"WSS-wineboot"] || [wssCommand isEqualToString:@"WSS-wineprefixcreate"] || [wssCommand isEqualToString:@"WSS-wineprefixcreatenoregs"])
                    {
                        nonStandardRun=YES;
                    }
                }
            }
            else if ([wssCommand isEqualToString:@"debug"]) //if wssCommand is debug, run in debug mode
            {
                debugEnabled=YES;
                NSLog(@"Debug Mode enabled");
            }
        }
        
        //if vdResolution is bigger than currentResolution, need to downsize it
        if (![vdResolution isEqualToString:WINESKIN_WRAPPER_PLIST_VALUE_SCREEN_OPTIONS_NO_VIRTUAL_DESKTOP])
        {
            int xRes = [[vdResolution getFragmentAfter:nil andBefore:@" "] intValue];
            int yRes = [[vdResolution getFragmentAfter:@" " andBefore:nil] intValue];
            int xResMax = [[currentResolution getFragmentAfter:nil andBefore:@" "] intValue];
            int yResMax = [[currentResolution getFragmentAfter:@" " andBefore:nil] intValue];
            if (xRes > xResMax || yRes > yResMax)
            {
                [vdResolution setString:currentResolution];
            }
        }
        
        //fix wine run paths
        if (![programNameAndPath hasPrefix:@"/"])
        {
            [programNameAndPath insertString:@"/" atIndex:0];
        }
        
        [wineRunLocation setString:[programNameAndPath substringToIndex:[programNameAndPath rangeOfString:@"/" options:NSBackwardsSearch].location]];
        NSString *wineRunFile = programNameAndPath.lastPathComponent;
        
        //add path to drive C if its not an installer
        if (!([wssCommand isEqualToString:@"WSS-installer"]))
        {
            [wineRunLocation insertString:[NSString stringWithFormat:@"%@/drive_c",winePrefix] atIndex:0];
        }
        
        //**********make sure that the set executable is found if normal run
        if (!openingFiles && !([wssCommand hasPrefix:@"WSS-"]) &&
            !([fm fileExistsAtPath:[NSString stringWithFormat:@"%@/%@",wineRunLocation,wineRunFile]]))
        {
            //error, file doesn't exist, and its not a special command
            NSLog(@"Error! Set executable not found.  Wineskin.app running instead.");
            system([[NSString stringWithFormat:@"open \"%@/Wineskin.app\"",appNameWithPath] UTF8String]);
            [fm removeItemAtPath:lockfile];
            [fm removeItemAtPath:tmpFolder];
            [fm removeItemAtPath:tmpwineFolder];
            exit(0);
        }
        //********** Wineskin Customizer start up script
        system([[NSString stringWithFormat:@"\"%@/Scripts/WineskinStartupScript\"",winePrefix] UTF8String]);
            
        //****** if CPUs Disabled, disable all but 1 CPU
        NSString *cpuCountInput;
        if ([[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_SINGLE_CPU] intValue] == 1)
        {
            cpuCountInput = [self systemCommand:@"hwprefs cpu_count 2>/dev/null"];
            int i, cpuCount = [cpuCountInput intValue];
            for (i = 2; i <= cpuCount; ++i)
            {
                [self systemCommand:[NSString stringWithFormat:@"hwprefs cpu_disable %d",i]];
            }
        }
        
        if (lockFileAlreadyExisted)
        {
            //if lockfile already existed, then this instance was launched when another is the main one.
            //We need to pass the parameters given to WineskinLauncher over to the correct run of this program
            WineStart *wineStartInfo = [[WineStart alloc] init];
            [wineStartInfo setWssCommand:wssCommand];
            [wineStartInfo setWinetricksCommands:winetricksCommands];
            [self handleWineskinLauncherDirectSecondaryRun:wineStartInfo];
            BOOL killWineskin = YES;
            
            // check if XQuartz is even running
            if (!useMacDriver && [self systemCommand:@"killall -s X11.bin 2>&1"].length > 0)
            {
                //ignore if no XQuartz is running, must have been in error
                NSLog(@"Lockfile ignored because no running XQaurtz processes found");
                lockFileAlreadyExisted = NO;
                killWineskin = NO;
            }
            
            if (killWineskin)
            {
                exit(0);
                //[NSApp terminate:nil];
            }
        }
        if (!useMacDriver)
        {
            if (!lockFileAlreadyExisted)
            {
                //**********set a new display number
                srand((unsigned)time(0));
                int randomint = 5+(int)(rand()%9994);
                if (randomint < 0)
                {
                    randomint = randomint * (-1);
                }
                [theDisplayNumber setString:[NSString stringWithFormat:@":%@",[[NSNumber numberWithLong:randomint] stringValue]]];
                //**********start the X server
                if (useXQuartz)
                {
                    NSLog(@"Wineskin: Starting XQuartz");
                    [self startXQuartz];
                }
                else
                {
                    NSLog(@"Wineskin: XQuartz Started, PID = %@", xQuartzX11BinPID);
                }
            }
        }
        //**********set user folders
        [self setUserFolders:([[self.portManager plistObjectForKey:@"Symlinks In User Folder"] intValue] == 1)];
        
        //********** fix wineprefix
        [self fixWinePrefixForCurrentUser];
        
        //********** If setting GPU info, do it
        if ([[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_AUTOMATICALLY_DETECT_GPU] intValue] == 1)
        {
            [self tryToUseGPUInfo];
        }
        
        //**********start wine
        WineStart *wineStartInfo = [[WineStart alloc] init];
        [wineStartInfo setFilesToRun:filesToRun];
        [wineStartInfo setProgramFlags:programFlags];
        [wineStartInfo setWineRunLocation:wineRunLocation];
        [wineStartInfo setVdResolution:vdResolution];
        [wineStartInfo setCliCustomCommands:cliCustomCommands];
        [wineStartInfo setRunWithStartExe:runWithStartExe];
        [wineStartInfo setNonStandardRun:nonStandardRun];
        [wineStartInfo setOpeningFiles:openingFiles];
        [wineStartInfo setWssCommand:wssCommand];
        [wineStartInfo setULimitNumber:uLimitNumber];
        [wineStartInfo setWineDebugLine:[self.portManager plistObjectForKey:@"WINEDEBUG="]];
        [wineStartInfo setWinetricksCommands:winetricksCommands];
        [wineStartInfo setWineRunFile:wineRunFile];
        [self startWine:wineStartInfo];
        
        //change fullscreen reso if needed
        if (fullScreenOption)
        {
            [self setResolution:vdResolution];
        }
	
        //for xorg1.11.0+, log files are put in ~/Library/Logs.  Need to move to correct place if in Debug
        if (debugEnabled)
        {
            if (useXQuartz)
            {
                [self systemCommand:[NSString stringWithFormat:@"echo \"No X11 Log info when using XQuartz!\n\" > \"%@\"",x11LogFile]];
            }
            NSString *versionFile = [NSString stringWithFormat:@"%@/wswine.bundle/version",frameworksFold];
            if ([fm fileExistsAtPath:versionFile])
            {
                NSArray *tempArray = [self readFileToStringArray:versionFile];
                [self systemCommand:[NSString stringWithFormat:@"echo \"Engine Used: %@\" >> \"%@\"",[tempArray objectAtIndex:0],x11LogFile]];
            }
            //use mini detail level so no personal information can be displayed
            [self systemCommand:[NSString stringWithFormat:@"system_profiler -detailLevel mini SPHardwareDataType SPDisplaysDataType >> \"%@\"",x11LogFile]];
        }
        
        //**********sleep and monitor in background while app is running
        [self sleepAndMonitor];
        
        //****** if CPUs Disabled, re-enable them
        if ([[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_SINGLE_CPU] intValue] == 1)
        {
            int i, cpuCount = [cpuCountInput intValue];
            for ( i = 2; i <= cpuCount; ++i)
            {
                [self systemCommand:[NSString stringWithFormat:@"hwprefs cpu_enable %d",i]];
            }
        }
            
        //********** Wineskin Customizer shut down script
        system([[NSString stringWithFormat:@"\"%@/Scripts/WineskinShutdownScript\"",winePrefix] UTF8String]);
        
        //********** app finished, time to clean up and shut down
        if ([[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_AUTOMATICALLY_DETECT_GPU] intValue] == 1)
        {
            [self removeGPUInfo];
        }
        [self cleanUpAndShutDown];
        return;
	}
}

- (void)secondaryRun:(NSArray*)filesToOpen
{
    @autoreleasepool
    {
        primaryRun = NO;
        NSMutableArray *filesToRun = [[NSMutableArray alloc] init];
        NSMutableString *wineRunLocation = [[NSMutableString alloc] init];
        NSMutableString *programNameAndPath = [[NSMutableString alloc] init];
        NSMutableString *cliCustomCommands = [[NSMutableString alloc] init];
        NSMutableString *programFlags = [[NSMutableString alloc] init];
        BOOL runWithStartExe = NO;
        BOOL nonStandardRun = NO;
        BOOL openingFiles = NO;
        NSString *wssCommand;
        if ([filesToOpen count] > 0)
        {
            wssCommand = [filesToOpen objectAtIndex:0];
        }
        else
        {
            wssCommand = @"nothing";
        }
        
        NSPortManager *cexeManager;
        NSString *resolutionTemp;
        
        //need to handle it different if its a cexe
        if ([wssCommand isEqualToString:@"CustomEXE"])
        {
            cexeManager = [NSPortManager managerForCustomExeAtPath:[NSString stringWithFormat:@"%@/%@",
                                                                    appNameWithPath,[filesToOpen objectAtIndex:1]]];
            [programNameAndPath setString:[cexeManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH]];
            [programFlags setString:[cexeManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH_FLAGS]];
            resolutionTemp = [cexeManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_SCREEN_OPTIONS_CONFIGURATIONS];
            runWithStartExe = [[cexeManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH_IS_NOT_EXE] intValue];
        }
        else
        {
            [programNameAndPath setString:[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH]];
            [programFlags setString:[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH_FLAGS]];
            resolutionTemp = [self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_SCREEN_OPTIONS_CONFIGURATIONS];
            runWithStartExe = [[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH_IS_NOT_EXE] intValue];
        }
        
        //if any program flags, need to add a space to the front of them
        if (!([programFlags isEqualToString:@""]))
        {
            [programFlags insertString:@" " atIndex:0];
        }
        
        [cliCustomCommands setString:[self.portManager plistObjectForKey:@"CLI Custom Commands"]];
        if (!([cliCustomCommands hasSuffix:@";"]) && ([cliCustomCommands length] > 0))
        {
            [cliCustomCommands appendString:@";"];
        }
        
        //******* fix all data correctly
        //list of possile options
        //WSS-installer {path/file}	- Installer is calling the program
        //WSS-winecfg 				- need to run winecfg
        //WSS-cmd					- need to run cmd
        //WSS-regedit 				- need to run regedit
        //WSS-taskmgr 				- need to run taskmgr
        //WSS-uninstaller			- run uninstaller
        //WSS-wineprefixcreate		- need to run wineboot, refresh wrapper
        //WSS-wineprefixcreatenoregs- same as above, doesn't load default regs
        //WSS-wineboot				- run simple wineboot, no deletions or loading regs. mshtml=disabled
        //WSS-winetricks {command}	- winetricks is being run
        //WSS-wineserverkill        - tell winesever to kill all wine processes from wrapper
        //debug 					- run in debug mode, keep logs
        //CustomEXE {appname}		- running a custom EXE with appname
        //starts with a"/" 			- will be 1+ path/filename to open
        //no command line args		- normal run
        
        NSMutableArray *winetricksCommands = [[NSMutableArray alloc] init];
        if ([filesToOpen count] > 1)
        {
            [winetricksCommands addObjectsFromArray:[filesToOpen subarrayWithRange:NSMakeRange(1, filesToOpen.count-1)]];
        }
        if ([filesToOpen count] > 0)
        {
            if ([wssCommand hasPrefix:@"/"]) //if wssCommand starts with a / its file(s) passed in to open
            {
                for (NSString *item in filesToOpen)
                {
                    [filesToRun addObject:item];
                }
                openingFiles=YES;
            }
            else if ([wssCommand hasPrefix:@"WSS-"]) //if wssCommand starts with WSS- its a special command
            {
                if ([wssCommand isEqualToString:@"WSS-installer"]) //if its in the installer, need to know if normal windows are forced
                {
                    // do not run the installer if the wrapper is already running!
                    CFUserNotificationDisplayNotice(0, 0, NULL, NULL, NULL, CFSTR("ERROR"), CFSTR("Error: Do not try to run the Installer if the wrapper is already running something else!"), NULL);
                    NSLog(@"Error: Do not try to run the Installer if the wrapper is already running something else!");
                    return;
                }
                else //any WSS that isn't the installer
                {
                    //should only use this line for winecfg cmd regedit and taskmgr, other 2 do nonstandard runs and wont use this line
                    if ([wssCommand isEqualToString:@"WSS-regedit"])
                    {
                        [programNameAndPath setString:@"/windows/regedit.exe"];
                    }
                    else
                    {
                        if ([wssCommand isEqualToString:@"WSS-cmd"])
                        {
                            runWithStartExe=YES;
                        }
                        [programNameAndPath setString:[NSString stringWithFormat:@"/windows/system32/%@.exe",[wssCommand stringByReplacingOccurrencesOfString:@"WSS-" withString:@""]]];
                    }
                    [programFlags setString:@""]; // just in case there were some flags... don't use on these.
                    if ([wssCommand isEqualToString:@"WSS-wineboot"] || [wssCommand isEqualToString:@"WSS-wineprefixcreate"] || [wssCommand isEqualToString:@"WSS-wineprefixcreatenoregs"])
                    {
                        nonStandardRun=YES;
                    }
                }
            }
        }
        
        //fix wine run paths
        if (![programNameAndPath hasPrefix:@"/"])
        {
            [programNameAndPath insertString:@"/" atIndex:0];
        }
        
        [wineRunLocation setString:[programNameAndPath substringToIndex:[programNameAndPath rangeOfString:@"/" options:NSBackwardsSearch].location]];
        NSString *wineRunFile = programNameAndPath.lastPathComponent;
        
        //add path to drive C if its not an installer
        if (!([wssCommand isEqualToString:@"WSS-installer"]))
        {
            [wineRunLocation insertString:[NSString stringWithFormat:@"%@/drive_c",winePrefix] atIndex:0];
        }
        
        //**********start wine
        WineStart *wineStartInfo = [[WineStart alloc] init];
        [wineStartInfo setFilesToRun:filesToRun];
        [wineStartInfo setProgramFlags:programFlags];
        [wineStartInfo setWineRunLocation:wineRunLocation];
        [wineStartInfo setVdResolution:@"secondary"];
        [wineStartInfo setCliCustomCommands:cliCustomCommands];
        [wineStartInfo setRunWithStartExe:runWithStartExe];
        [wineStartInfo setNonStandardRun:nonStandardRun];
        [wineStartInfo setOpeningFiles:openingFiles];
        [wineStartInfo setWssCommand:wssCommand];
        [wineStartInfo setULimitNumber:@""];
        [wineStartInfo setWineDebugLine:[self.portManager plistObjectForKey:@"WINEDEBUG="]];
        [wineStartInfo setWinetricksCommands:winetricksCommands];
        [wineStartInfo setWineRunFile:wineRunFile];
        [self startWine:wineStartInfo];
	}
}

- (void)handleWineskinLauncherDirectSecondaryRun:(WineStart *)wineStart
{
    //if lockfile already existed, then this instance was launched when another is the main one.
    //We need to pass the parameters given to WineskinLauncher over to the correct run of this program
    //WSS-installer {path/file}	-need to send file path to main
    //WSS-winecfg 				- need to send path to winecfg.exe to main
    //WSS-cmd					- need to send path to cmd.exe to main
    //WSS-regedit 				- need to send path to regedit.exe to main
    //WSS-taskmgr 				- need to send path to taskmgr.exe to main
    //WSS-uninstaller			- need to send path to uninstaller.exe to main
    //WSS-wineprefixcreate		- need to error, saying this cannot run while the wrapper is running
    //WSS-wineprefixcreatenoregs- need to error, saying this cannot run while the wrapper is running
    //WSS-wineboot				- need to error, saying this cannot run while the wrapper is running
    //WSS-winetricks {command}	- need to error, saying this cannot run while the wrapper is running
    //WSS-wineserverkill        - tell winesever to kill all wine processes from wrapper
    //debug 					- need to error, saying this cannot run while the wrapper is running
    //CustomEXE {appname}		- need to send path to cexe to main
    //starts with a"/" 			- need to just pass this one to main
    //no command line args		- else condition... nothing to do, don't do anything.
    
    NSString *wssCommand = [wineStart getWssCommand];
    NSArray *otherCommands = [wineStart getWinetricksCommands];
    NSString *theFileToRun;
    
    NSDictionary* fileToRunForCommand = @{
                                @"WSS-installer":   otherCommands[0],
                                @"WSS-wineserverkill":   otherCommands[0],
                                @"WSS-winecfg":     [NSString stringWithFormat:@"%@/drive_c/windows/system32/winecfg.exe",winePrefix],
                                @"WSS-cmd":         [NSString stringWithFormat:@"%@/drive_c/windows/system32/cmd.exe",winePrefix],
                                @"WSS-regedit":     [NSString stringWithFormat:@"%@/drive_c/windows/regedit.exe",winePrefix],
                                @"WSS-taskmgr":     [NSString stringWithFormat:@"%@/drive_c/windows/system32/taskmgr.exe",winePrefix],
                                @"WSS-uninstaller": [NSString stringWithFormat:@"%@/drive_c/windows/system32/uninstaller.exe",winePrefix]};
    
    NSString* path = fileToRunForCommand[wssCommand];
    
    if (path != nil)
    {
        theFileToRun = path;
    }
    else if ([wssCommand isEqualToString:@"WSS-wineprefixcreate"] || [wssCommand isEqualToString:@"WSS-wineprefixcreatenoregs"] ||
             [wssCommand isEqualToString:@"WSS-wineboot"] || [wssCommand isEqualToString:@"WSS-winetricks"] ||
             [wssCommand isEqualToString:@"debug"])
    {
        NSString *errorMsg = [NSString stringWithFormat:@"ERROR, tried to run command %@ when the wrapper was already running.  Please make sure the wrapper is not running in order to do this.", wssCommand];
        CFUserNotificationDisplayNotice(10.0, 0, NULL, NULL, NULL, CFSTR("ERROR!"), (CFStringRef)errorMsg, NULL);
        NSLog(@"%@",errorMsg);
        return;
    }
    else if ([wssCommand isEqualToString:@"CustomEXE"])
    {
        NSDictionary *cexePlistDictionary = [[NSDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/%@/Contents/Info.plist.cexe",appNameWithPath,otherCommands[0]]];
        NSString* programNameAndPath = [NSString stringWithFormat:@"C:%@",cexePlistDictionary[WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH]];
        theFileToRun = [NSPathUtilities getMacPathForWindowsPath:programNameAndPath ofWrapper:self.portManager.path];
    }
    else if ([wssCommand hasPrefix:@"/"])
    {
        NSMutableArray *temp = [[NSMutableArray alloc] initWithObjects:wssCommand, nil];
        [temp addObjectsFromArray:otherCommands];
        theFileToRun = [temp componentsJoinedByString:@"\" \""];
    }
    else
    {
        NSLog(@"ERROR, wrapper was re-run with no recognized command line options while already running.  This is a useless operation and ignored.");
        return;
    }
    [self systemCommand:[NSString stringWithFormat:@"open \"%@\" -a \"%@\"",theFileToRun,appNameWithPath]];
    return;
}

- (void)setGamma:(NSString *)inputValue
{
	if ([inputValue isEqualToString:@"default"])
	{
		CGDisplayRestoreColorSyncSettings();
		return;
	}
    
	double gamma = [inputValue doubleValue];
	CGDirectDisplayID activeDisplays[] = {0,0,0,0,0,0,0,0};
	CGDisplayCount activeDisplaysNum,totalDisplaysNum=8;
	CGDisplayErr error1 = CGGetActiveDisplayList(totalDisplaysNum,activeDisplays,&activeDisplaysNum);
	
    if (error1!=0)
    {
        NSLog(@"setGamma function active display list failed! error = %d",error1);
    }
	
    CGGammaValue gammaMin = 0.0;
	CGGammaValue gammaMax = 1.0;
	CGGammaValue gammaSettingsRED = gamma;
	CGGammaValue gammaSettingsGREEN = gamma;
	CGGammaValue gammaSettingsBLUE = gamma;
    
    CGSetDisplayTransferByFormula(*activeDisplays, gammaMin, gammaMax, gammaSettingsRED, gammaMin,
                                  gammaMax, gammaSettingsGREEN, gammaMin, gammaMax, gammaSettingsBLUE);
}

- (void)setResolution:(NSString *)reso
{
    NSString* xRes = [reso getFragmentAfter:nil andBefore:@" "];
    NSString* yRes = [reso getFragmentAfter:@" " andBefore:nil];
    
    //if XxY doesn't exist, we will ignore for now... in the future maybe add way to find the closest reso that is available.
	//change the resolution using Xrandr
    NSArray* command = @[[NSString stringWithFormat:@"export WINESKIN_LIB_PATH_FOR_FALLBACK=\"%@\";",dyldFallBackLibraryPath],
                         [NSString stringWithFormat:@"export PATH=\"%@/wswine.bundle/bin:%@/bin:$PATH:/opt/local/bin:/opt/local/sbin\";",frameworksFold,frameworksFold],
                         [NSString stringWithFormat:@"export DISPLAY=%@;",theDisplayNumber],
                         [NSString stringWithFormat:@"export WINEPREFIX=\"%@\";",winePrefix],
                         [NSString stringWithFormat:@"cd \"%@/wswine.bundle/bin\";",frameworksFold],
                         [NSString stringWithFormat:@"DYLD_FALLBACK_LIBRARY_PATH=\"%@\"",dyldFallBackLibraryPath],
                         [NSString stringWithFormat:@"xrandr -s %@x%@ > /dev/null 2>&1",xRes,yRes]];
    
	system([[command componentsJoinedByString:@" "] UTF8String]);
}

- (NSString *)getScreenResolution
{
	CGRect screenFrame = CGDisplayBounds(kCGDirectMainDisplay);
	CGSize screenSize  = screenFrame.size;
	return [NSString stringWithFormat:@"%.0f %.0f",screenSize.width,screenSize.height];
}

- (NSArray *)makePIDArray:(NSString *)processToLookFor
{
	NSString *resultString = [NSString stringWithFormat:@"00000\n%@",[self systemCommand:[NSString stringWithFormat:@"ps axc|awk \"{if (\\$5==\\\"%@\\\") print \\$1}\"",processToLookFor]]];
	return [resultString componentsSeparatedByString:@"\n"];
}

- (NSString *)getNewPid:(NSString *)processToLookFor from:(NSArray *)firstPIDlist confirm:(bool)confirm_pid;
{
    //do loop compare to find correct PID, try 8 times, doubling the delay each try ... up to 102.2 secs of total waiting
    int i = 0;
    int sleep_duration = 200000; // start off w/ 0.2 secs and double each iteration
    
    //re-usable array
    NSMutableArray *secondPIDlist = [[NSMutableArray alloc] init];
    for (i = 0; i < 9; ++i)
    {
        // log delay if it will take longer than 1 second
        if (sleep_duration / 1000000 > 1)
        {
            NSLog(@"Wineskin: Waiting %d seconds for %@ to start.", sleep_duration / 1000000, processToLookFor);
        }
        
        // sleep a bit before checking for current pid list
        usleep(sleep_duration);
        sleep_duration = sleep_duration * 2;
        [secondPIDlist removeAllObjects];
        [secondPIDlist addObjectsFromArray:[self makePIDArray:processToLookFor]];
        for (NSString *secondPIDlistItem in secondPIDlist)
        {
            if ([secondPIDlistItem isEqualToString:wrapperBundlePID])
            {
                continue;
            }
            BOOL match = NO;
            for (NSString *firstPIDlistItem in firstPIDlist)
            {
                if ([secondPIDlistItem isEqualToString:firstPIDlistItem])
                {
                    match = YES;
                }
            }
            if (!match)
            {
                if (!confirm_pid)
                {
                    return secondPIDlistItem;
                }
                else
                {
                    // sleep another duration (+ 0.25 secs) to confirm pid is still valid
                    sleep_duration = (sleep_duration / 2) + 250000;
                    
                    // log delay if it will take longer than 1 second
                    if (sleep_duration / 1000000 > 1)
                    {
                        NSLog(@"Wineskin: Waiting %d more seconds to confirm PID (%@) is valid for %@.", sleep_duration / 1000000, secondPIDlistItem, processToLookFor);
                    }
                    
                    // sleep a bit before checking for current pid list
                    usleep(sleep_duration);
                    
                    // return PID if still valid
                    if ([self isPID:secondPIDlistItem named:processToLookFor])
                    {
                        return secondPIDlistItem;
                    }
                }
                
                // pid isn't valid
                NSLog(@"Wineskin: Found invalid %@ pid: %@.", processToLookFor, secondPIDlistItem);
            }
        }
    }
    NSLog(@"Wineskin: Could not find PID for %@", processToLookFor);
    return @"-1";
}

-(NSString*)createWrapperHomeSymlinkFolder:(NSString*)folderName forMacFolder:(NSString*)macFolder
{
    NSMutableString *symlink = [[NSMutableString alloc] init];
    [symlink setString:[[self.portManager plistObjectForKey:[NSString stringWithFormat:@"Symlink %@",folderName]]
                        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
    [symlink replaceOccurrencesOfString:@"$HOME" withString:NSHomeDirectory() options:NSLiteralSearch range:NSMakeRange(0, symlink.length)];
    
    BOOL error = (symlink.length <= 1);
    
    if (!error)
    {
        if (![fm directoryExistsAtPath:symlink]) [fm createDirectoryAtPath:symlink withIntermediateDirectories:YES];
        error = ![fm directoryExistsAtPath:symlink];
    }
    
    if (error)
    {
        NSString *tempOld = [symlink copy];
        [symlink setString:[NSString stringWithFormat:@"%@/%@",NSHomeDirectory(),macFolder]];
        NSLog(@"ERROR: \"%@\" requested to be linked to \"%@\", but folder does not exist and could not be created. Using \"%@\" instead.",tempOld,folderName,symlink);
    }
    
    return symlink;
}
-(void)createWrapperHomeFolder:(NSString*)folderName withSymlinkTo:(NSString*)symlink
{
    NSString* folderPath = [NSString stringWithFormat:@"%@/drive_c/users/Wineskin/%@",winePrefix,folderName];
    
    if (symlink)
    {
        [fm removeItemAtPath:folderPath];
        [fm createSymbolicLinkAtPath:folderPath withDestinationPath:symlink error:nil];
        [self systemCommand:[NSString stringWithFormat:@"chmod -h 777 \"%@\"",folderPath]];
        return;
    }
    
    [fm createDirectoryAtPath:folderPath withIntermediateDirectories:NO];
}
- (void)setUserFolders:(BOOL)doSymlinks
{
    NSString* symlinkMyDocuments = [self createWrapperHomeSymlinkFolder:@"My Documents" forMacFolder:@"Documents"];
    NSString* symlinkDesktop     = [self createWrapperHomeSymlinkFolder:@"Desktop"      forMacFolder:@"Desktop"];
    NSString* symlinkDownloads   = [self createWrapperHomeSymlinkFolder:@"Downloads"    forMacFolder:@"Downloads"];
    NSString* symlinkMyVideos    = [self createWrapperHomeSymlinkFolder:@"My Videos"    forMacFolder:@"Movies"];
    NSString* symlinkMyMusic     = [self createWrapperHomeSymlinkFolder:@"My Music"     forMacFolder:@"Music"];
    NSString* symlinkMyPictures  = [self createWrapperHomeSymlinkFolder:@"My Pictures"  forMacFolder:@"Pictures"];
    
    //set the symlinks
	if ([fm fileExistsAtPath:[NSString stringWithFormat:@"%@/drive_c/users/Wineskin",winePrefix]])
	{
        if (!doSymlinks || symlinkMyDocuments.length == 0) symlinkMyDocuments = nil;
        [self createWrapperHomeFolder:@"My Documents" withSymlinkTo:symlinkMyDocuments];
        
        if (!doSymlinks || symlinkDesktop.length == 0) symlinkDesktop = nil;
        [self createWrapperHomeFolder:@"Desktop" withSymlinkTo:symlinkDesktop];

        if (!doSymlinks || symlinkDownloads.length == 0) symlinkDownloads = nil;
        [self createWrapperHomeFolder:@"Downloads" withSymlinkTo:symlinkDownloads];

        if (!doSymlinks || symlinkMyVideos.length == 0) symlinkMyVideos = nil;
        [self createWrapperHomeFolder:@"My Videos" withSymlinkTo:symlinkMyVideos];
        
        if (!doSymlinks || symlinkMyMusic.length == 0) symlinkMyMusic = nil;
        [self createWrapperHomeFolder:@"My Music" withSymlinkTo:symlinkMyMusic];
        
        if (!doSymlinks || symlinkMyPictures.length == 0) symlinkMyPictures = nil;
        [self createWrapperHomeFolder:@"My Pictures" withSymlinkTo:symlinkMyPictures];
	}
    
    NSString* usersFolder     = [NSString stringWithFormat:@"%@/drive_c/users/%@",winePrefix,NSUserName()];
    NSString* crossoverFolder = [NSString stringWithFormat:@"%@/drive_c/users/crossover",winePrefix];
    
    for (NSString* folder in @[usersFolder, crossoverFolder])
    {
        [fm createSymbolicLinkAtPath:folder withDestinationPath:@"Wineskin" error:nil];
        [self systemCommand:[NSString stringWithFormat:@"chmod -h 777 \"%@\"",folder]];
    }
}

- (void)fixWinePrefixForCurrentUser
{
	// changing owner just fails, need this to work for normal users without admin password on the fly.
	// Needed folders are set to 777, so just make a new resources folder and move items, should always work.
	// NSFileManager changing posix permissions still failing to work right, using chmod as a system command
	//if owner and current user match, exit
	NSDictionary *checkThis = [fm attributesOfItemAtPath:winePrefix error:nil];
	if ([NSUserName() isEqualToString:[checkThis valueForKey:@"NSFileOwnerAccountName"]])
	{
		return;
	}
    
	//make ResoTemp
	[fm createDirectoryAtPath:[NSString stringWithFormat:@"%@/ResoTemp",contentsFold] withIntermediateDirectories:NO];
	
    //move everything from Resources to ResoTemp
	NSArray *tmpy = [fm contentsOfDirectoryAtPath:winePrefix];
	for (NSString *item in tmpy)
    {
		[fm moveItemAtPath:[NSString stringWithFormat:@"%@/Resources/%@",contentsFold,item]
                    toPath:[NSString stringWithFormat:@"%@/ResoTemp/%@",contentsFold,item]];
    }
	
    //delete Resources
	[fm removeItemAtPath:winePrefix];
	
    //rename ResoTemp to Resources
	[fm moveItemAtPath:[NSString stringWithFormat:@"%@/ResoTemp",contentsFold]
                toPath:[NSString stringWithFormat:@"%@/Resources",contentsFold]];
	
    //fix Resources to 777
	[self systemCommand:[NSString stringWithFormat:@"chmod 777 \"%@\"",winePrefix]];
}

- (void)setGpuInfoVendorID:(NSString*)nvendorID deviceID:(NSString*)ndeviceID memorySize:(NSString*)nVRAM
{
    //if user.reg doesn't exist, don't do anything
    if (!([fm fileExistsAtPath:[NSString stringWithFormat:@"%@/user.reg",winePrefix]]))
    {
        return;
    }
    
    NSString* direct3dHeader = @"[Software\\\\Wine\\\\Direct3D]";
    NSMutableString* direct3dReg = [[self.portManager getRegistryEntry:direct3dHeader fromRegistryFileNamed:USER_REG] mutableCopy];
    
    [self.portManager setValue:nVRAM     forKey:@"VideoMemorySize"  atRegistryEntryString:direct3dReg];
    [self.portManager setValue:ndeviceID forKey:@"VideoPciDeviceID" atRegistryEntryString:direct3dReg];
    [self.portManager setValue:nvendorID forKey:@"VideoPciVendorID" atRegistryEntryString:direct3dReg];
    
    [self.portManager deleteRegistry:direct3dHeader fromRegistryFileNamed:USER_REG];
    [self.portManager addRegistry:[NSString stringWithFormat:@"%@\n%@\n",direct3dHeader,direct3dReg] fromRegistryFileNamed:USER_REG];
    
    [self systemCommand:[NSString stringWithFormat:@"chmod 666 \"%@/user.reg\"",winePrefix]];
}
- (void)tryToUseGPUInfo
{
	NSMutableString *deviceID = [[VMMComputerInformation mainVideoCard].deviceID mutableCopy];
    NSMutableString *vendorID = [[VMMComputerInformation mainVideoCard].vendorID mutableCopy];
    NSString *VRAM = [NSString stringWithFormat:@"%d",[VMMComputerInformation mainVideoCard].memorySizeInMegabytes.intValue];
    
    //need to strip 0x off the front of deviceID and vendorID, and pad with 0's in front until its a total of 8 digits long.
    if (vendorID)
    {
        vendorID = [[vendorID substringFromIndex:2] mutableCopy];
        
        while (vendorID.length < 8)
        {
            [vendorID insertString:@"0" atIndex:0];
        }
    }
    if (deviceID)
    {
        deviceID = [[deviceID substringFromIndex:2] mutableCopy];
        
        while ([deviceID length] < 8)
        {
            [deviceID insertString:@"0" atIndex:0];
        }
    }
	
    NSString* nVRAM = VRAM ? [NSString stringWithFormat:@"\"%@\"",VRAM] : nil;
    NSString* ndeviceID = deviceID ? [NSString stringWithFormat:@"dword:%@",deviceID] : nil;
    NSString* nvendorID = vendorID ? [NSString stringWithFormat:@"dword:%@",vendorID] : nil;
    
    [self setGpuInfoVendorID:nvendorID deviceID:ndeviceID memorySize:nVRAM];
}
- (void)removeGPUInfo
{
    [self setGpuInfoVendorID:nil deviceID:nil memorySize:nil];
}

- (NSString *)setWindowManager
{
    //do not run quartz-wm in override->fullscreen
	if (fullScreenOption)
    {
        return @"";
    }
    
	NSMutableString *quartzwmLine = [[NSMutableString alloc] init];

    //look for quartz-wm in all locations, if not found default to backup
	//should be in /usr/bin/quartz-wm or /opt/X11/bin/quartz-wm or /opt/local/bin/quartz-wm
	//find the newest version
	NSMutableArray *pathsToCheck = [[NSMutableArray alloc] init];
    for (NSString* quartzWm in @[@"/usr/bin/quartz-wm", @"/opt/X11/bin/quartz-wm", @"/opt/local/bin/quartz-wm"])
    {
        if ([fm fileExistsAtPath:quartzWm]) [pathsToCheck addObject:quartzWm];
    }
	
	while (pathsToCheck.count > 1) //go through list, remove all but newest version
	{
		NSString *indexZero = [self systemCommand:[NSString stringWithFormat:@"%@ --version",pathsToCheck[0]]];
		NSString *indexOne  = [self systemCommand:[NSString stringWithFormat:@"%@ --version",pathsToCheck[1]]];
        
        VMMVersionCompare result = [VMMVersion compareVersionString:indexZero withVersionString:indexOne];
        if (result == VMMVersionCompareSecondIsNewest) //indexZeroArray is smaller, get rid of it
        {
            [pathsToCheck removeObjectAtIndex:0];
        }
        else //indexOneArray is smaller or they are equal, get rid of it
        {
            [pathsToCheck removeObjectAtIndex:1];
        }
	}
	if (pathsToCheck.count == 1)
    {
		[quartzwmLine setString:[NSString stringWithFormat:@" +extension \"'%@'\"",pathsToCheck.firstObject]];
    }
    
	return [NSString stringWithString:quartzwmLine];
}

- (BOOL)checkToUseMacDriver
{
    return [NSPortDataLoader macDriverIsEnabledAtPort:self.portManager];
}

- (BOOL)checkToUseXQuartz
{
    return [NSPortDataLoader useXQuartzIsEnabledAtPort:self.portManager];
}

- (void)startXQuartz
{
	if (![fm fileExistsAtPath:@"/Applications/Utilities/XQuartz.app/Contents/MacOS/X11.bin"])
	{
		NSLog(@"Error XQuartz not found, please install XQuartz");
		//useXQuartz = NO;
		return;
	}
    
	if (!fullScreenOption)
	{
		[self systemCommand:@"open /Applications/Utilities/XQuartz.app"];
        [theDisplayNumber setString:[self systemCommand:@"echo $DISPLAY"]];
        return;
	}
	
    //make sure XQuartz is not already running
    //this is because it needs to be started with no Quartz-wm for override->fullscreen to function correctly.
    if ([[self systemCommand:@"killall -s X11.bin"] hasPrefix:@"kill"])
    {
        //already running, error and exit
        NSLog(@"Error: XQuartz cannot already be running if using Override Fullscreen option!  Please close XQuartz and try again!");
        CFUserNotificationDisplayNotice(0, 0, NULL, NULL, NULL, CFSTR("ERROR"), CFSTR("Error: XQuartz cannot already be running if using Override Fullscreen option!\n\nPlease close XQuartz and try again!"), NULL);
        [fm removeItemAtPath:lockfile];
        [fm removeItemAtPath:tmpFolder];
        [fm removeItemAtPath:tmpwineFolder];
        [NSApp terminate:nil];
    }
    
    //make first pid array
    NSArray *firstPIDlist = [self makePIDArray:@"X11.bin"];
    
    //start XQuartz
    xQuartzBundlePID = [self systemCommand:[NSString stringWithFormat:@"/Applications/Utilities/XQuartz.app/Contents/MacOS/X11.bin %@ > /dev/null & echo $!",theDisplayNumber]];
    
    // get PID of X11.bin just launched
    [xQuartzX11BinPID setString:[self getNewPid:@"X11.bin" from:firstPIDlist confirm:NO]];
    
    //if no PID found, log problem
    if ([xQuartzX11BinPID isEqualToString:@"-1"])
    {
        NSLog(@"Error! XQuartz X11.Bin PID not found, there may be unexpected errors on shut down!\n");
    }
    
    //if started this way we need extra time or Wine may be gotten too too quickly
    usleep(1500000);
    [self bringToFront:xQuartzBundlePID];
}

- (void)bringToFront:(NSString *)thePid
{
	/*this has been very problematic.  Need to detect front most app, and try to make XQuartz go frontmost
	 *recheck and retry different ways until it is the frontmost, or just fail with a NSLog.
	 *only attempt if XQuartz is still actually running
	 */
    if ([self isPID:thePid named:appNameWithPath] == false) return;
	
    NSWorkspace* workspace = [NSWorkspace sharedWorkspace];
    int i=0;
    for (i = 0; i < 10; ++i)
    {
        //get frontmost application information
        NSDictionary* frontMostAppInfo = [workspace activeApplication];
        
        //get the PSN of the frontmost app
        UInt32 lowLong  = [frontMostAppInfo[@"NSApplicationProcessSerialNumberLow"]  unsignedIntValue];
        UInt32 highLong = [frontMostAppInfo[@"NSApplicationProcessSerialNumberHigh"] unsignedIntValue];
        ProcessSerialNumber currentAppPSN = {highLong,lowLong};
        
        //Get Apple Process PID
        ProcessSerialNumber PSN = {kNoProcess, kNoProcess};
        GetProcessForPID((pid_t)[thePid intValue], &PSN);
        
        //check if we are in the front
        if (PSN.lowLongOfPSN == currentAppPSN.lowLongOfPSN && PSN.highLongOfPSN == currentAppPSN.highLongOfPSN)
        {
            return;
        }
        
        if (i==0)
        {
            [[NSRunningApplication runningApplicationWithProcessIdentifier:[thePid intValue]] activateWithOptions:(NSApplicationActivateAllWindows | NSApplicationActivateIgnoringOtherApps)];
        }
        else if (i==1)
        {
            [workspace launchApplication:appNameWithPath];
        }
        else if (i==2)
        {
            [self systemCommand:[NSString stringWithFormat:@"open \"%@\"",appNameWithPath]];
        }
        else if (i==3)
        {
            NSString *theScript = [NSString stringWithFormat:@"tell Application \"%@\" to activate",appNameWithPath];
            NSAppleScript *bringToFrontScript = [[NSAppleScript alloc] initWithSource:theScript];
            [bringToFrontScript executeAndReturnError:nil];
        }
        else if (i==4)
        {
            [self systemCommand:[NSString stringWithFormat:@"arch -i386 /usr/bin/osascript -e \"tell application \\\"%@\\\" to activate\"",appNameWithPath]];
        }
        else
        {
            //only gets here if app never front most and breaks
            NSLog(@"Application PID %@ may have failed to become front most",thePid);
            break;
        }
    }
}

- (void)installEngine
{
	NSMutableArray *wswineBundleContentsList = [[NSMutableArray alloc] init];
	
    //get directory contents of wswine.bundle
    NSString* wswineBundlePath = [NSString stringWithFormat:@"%@/wswine.bundle",frameworksFold];
	NSArray *files = [fm contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/",wswineBundlePath]];
    if (files.count == 0) [NSApp terminate:nil];
    
	for (NSString *file in files)
    {
		if ([file hasSuffix:@".bundle.tar.7z"])
        {
            [wswineBundleContentsList addObject:[file stringByReplacingOccurrencesOfString:@".tar.7z" withString:@""]];
        }
    }
    
	//if the .tar.7z files exist, continue with this
	if (wswineBundleContentsList.count > 0)
    {
        isIce = YES;
    }
	if (!isIce)
	{
		return;
	}
    [window makeKeyAndOrderFront:self];
    
	//install Wine on the system
	NSMutableString *wineFile = [[NSMutableString alloc] init];
    [wineFile setString:@"OOPS"];
	for (NSString *item in wswineBundleContentsList)
    {
		if ([item hasPrefix:@"WSWine"] && [item hasSuffix:@"ICE.bundle"])
        {
            [wineFile setString:[NSString stringWithFormat:@"%@",item]];
        }
    }
	if ([wineFile isEqualToString:@"OOPS"])
	{
		NSLog(@"Warning! This appears to be Wineskin ICE, but there is a problem in the Engine files in the wrapper.  They are either corrupted or missing.  The program may fail to launch!");
		CFUserNotificationDisplayNotice(10.0, 0, NULL, NULL, NULL, CFSTR("WARNING!"), (CFStringRef)@"Warning! This appears to be Wineskin ICE, but there is a problem in the Engine files in the wrapper.\n\nThey are either corrupted or missing.\n\nThe program may fail to launch!", NULL);
		usleep(3000000);
	}
    
	//get md5
    NSString* wineTar7zFilePath = [NSString stringWithFormat:@"%@/%@.tar.7z",wswineBundlePath,wineFile];
	NSString *wineFileMd5 = [[self systemCommand:[NSString stringWithFormat:@"md5 -r \"%@\"",wineTar7zFilePath]] stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@" %@",wineTar7zFilePath] withString:@""];
	NSString *wineFileInstalledName = [NSString stringWithFormat:@"%@%@.bundle",[wineFile stringByReplacingOccurrencesOfString:@"bundle" withString:@""],wineFileMd5];
    
	//make ICE folder if it doesn't exist
    NSString* iceFolder = [NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/ICE",NSHomeDirectory()];
    if (![fm directoryExistsAtPath:iceFolder])
    {
        [fm createDirectoryAtPath:iceFolder withIntermediateDirectories:YES];
    }
    
	// delete out extra bundles or tars in engine bundle first
	[fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@.tar",wswineBundlePath,wineFile]];
	[fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@",    wswineBundlePath,wineFile]];
    
	NSArray *iceFiles = [fm contentsOfDirectoryAtPath:iceFolder];
    
	//if Wine version is not installed...
	BOOL wineInstalled = NO;
	for (NSString *file in iceFiles)
    {
		if ([file isEqualToString:wineFileInstalledName])
        {
            wineInstalled = YES;
        }
    }
	if (!wineInstalled)
	{
		//if the Wine bundle is not located in the install folder, then uncompress it and move it over there.
		system([[NSString stringWithFormat:@"\"%@/7za\" x \"%@/%@.tar.7z\" \"-o/%@\"",
                 wswineBundlePath,wswineBundlePath,wineFile,wswineBundlePath] UTF8String]);
		system([[NSString stringWithFormat:@"/usr/bin/tar -C \"%@\" -xf \"%@/%@.tar\"",
                 wswineBundlePath,wswineBundlePath,wineFile] UTF8String]);
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@.tar",wswineBundlePath,wineFile]];
		
        //have uncompressed version now, move it to ICE folder.
        [fm moveItemAtPath:[NSString stringWithFormat:@"%@/%@",wswineBundlePath,wineFile]
                    toPath:[NSString stringWithFormat:@"%@/%@",iceFolder,wineFileInstalledName]];
	}
    
	//make/remake the symlink in wswine.bundle to point to the correct location
    for (NSString* folder in @[@"bin", @"lib", @"lib64", @"share", @"version"])
    {
        [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@",wswineBundlePath,folder]];
        [fm createSymbolicLinkAtPath:[NSString stringWithFormat:@"%@/%@",wswineBundlePath,folder]
                 withDestinationPath:[NSString stringWithFormat:@"%@/%@/%@",iceFolder,wineFileInstalledName,folder] error:nil];
        [self systemCommand:[NSString stringWithFormat:@"chmod -h 777 \"%@/%@\"",wswineBundlePath,folder]];
    }
    
    [window orderOut:self];
}

- (void)setToVirtualDesktop:(NSString *)resolution
{
    //if file doesn't exist, don't do anything
    if (!([fm fileExistsAtPath:[NSString stringWithFormat:@"%@/user.reg",winePrefix]]))
    {
        return;
    }
    
    NSString *desktopName = appNameWithPath.lastPathComponent.stringByDeletingPathExtension;
    
    NSString* explorerRegHeader = @"[Software\\\\Wine\\\\Explorer]";
    NSString* desktopsRegHeader = @"[Software\\\\Wine\\\\Explorer\\\\Desktops]";
    
    NSMutableString* explorerReg = [[self.portManager getRegistryEntry:explorerRegHeader fromRegistryFileNamed:USER_REG] mutableCopy];
    NSMutableString* desktopsReg = [[self.portManager getRegistryEntry:desktopsRegHeader fromRegistryFileNamed:USER_REG] mutableCopy];
    
    NSString* quotedDesktopName = [NSString stringWithFormat:@"\"%@\"",desktopName];
    NSString* resolutionX = [resolution stringByReplacingOccurrencesOfString:@" " withString:@"x"];
    resolutionX = [NSString stringWithFormat:@"\"%@\"",resolutionX];
    
    [self.portManager setValue:quotedDesktopName forKey:@"Desktop" atRegistryEntryString:explorerReg];
    [self.portManager setValue:resolutionX forKey:desktopName atRegistryEntryString:desktopsReg];
    
    [self.portManager deleteRegistry:explorerRegHeader fromRegistryFileNamed:USER_REG];
    [self.portManager deleteRegistry:desktopsRegHeader fromRegistryFileNamed:USER_REG];
    
    [self.portManager addRegistry:[NSString stringWithFormat:@"%@\n%@\n",explorerRegHeader,explorerReg] fromRegistryFileNamed:USER_REG];
    [self.portManager addRegistry:[NSString stringWithFormat:@"%@\n%@\n",desktopsRegHeader,desktopsReg] fromRegistryFileNamed:USER_REG];
    
	[self systemCommand:[NSString stringWithFormat:@"chmod 666 \"%@/user.reg\"",winePrefix]];
}

- (void)setToNoVirtualDesktop
{
	//if file doesn't exist, don't do anything
	if (!([fm fileExistsAtPath:[NSString stringWithFormat:@"%@/user.reg",winePrefix]]))
    {
		return;
    }
    
    NSString* explorerRegHeader = @"[Software\\\\Wine\\\\Explorer]";
    NSString* desktopsRegHeader = @"[Software\\\\Wine\\\\Explorer\\\\Desktops]";
    
    [self.portManager deleteRegistry:explorerRegHeader fromRegistryFileNamed:USER_REG];
    [self.portManager deleteRegistry:desktopsRegHeader fromRegistryFileNamed:USER_REG];
    
    [self.portManager addRegistry:[NSString stringWithFormat:@"%@\n",explorerRegHeader] fromRegistryFileNamed:USER_REG];
    [self.portManager addRegistry:[NSString stringWithFormat:@"%@\n",desktopsRegHeader] fromRegistryFileNamed:USER_REG];
    
	[self systemCommand:[NSString stringWithFormat:@"chmod 666 \"%@/user.reg\"",winePrefix]];
}

- (NSArray *)readFileToStringArray:(NSString *)theFile
{
	return [[NSString stringWithContentsOfFile:theFile encoding:NSUTF8StringEncoding] componentsSeparatedByString:@"\n"];
}

- (void)writeStringArray:(NSArray *)theArray toFile:(NSString *)theFile
{
	[fm removeItemAtPath:theFile];
	[[theArray componentsJoinedByString:@"\n"] writeToFile:theFile atomically:YES encoding:NSUTF8StringEncoding];
	[self systemCommand:[NSString stringWithFormat:@"chmod 777 \"%@\"",theFile]];
}

- (BOOL)isPID:(NSString *)pid named:(NSString *)name
{
    if ([pid isEqualToString:@""])
    {
        NSLog(@"INVALID PID SENT TO isPID!!!");
    }
	if ([[self systemCommand:[NSString stringWithFormat:@"ps -p \"%@\" | grep \"%@\"",pid,name]] length] < 1)
    {
        return NO;
    }
	return YES;
}

- (BOOL)isWineserverRunning
{
    return ([[self systemCommand:[NSString stringWithFormat:@"killall -0 \"%@\" 2>&1",wineServerName]] length] < 1);
}

// Checks to see what wine engine is being used
- (void)fixWineExecutableNames
{
    NSString *pathToWineBinFolder = [NSString stringWithFormat:@"%@/wswine.bundle/bin",frameworksFold];
    
    if     ([fm fileExistsAtPath:[NSString stringWithFormat:@"%@/wine64-preloader",pathToWineBinFolder]])
    {
        [self fixWineStaging64ExecutableNames];
    }
    else if     ([fm fileExistsAtPath:[NSString stringWithFormat:@"%@/wine64",pathToWineBinFolder]])
    {
        [self fixWine64ExecutableNames];
    }
    else if     ([fm fileExistsAtPath:[NSString stringWithFormat:@"%@/wine-preloader",pathToWineBinFolder]])
    {
        [self fixWineStagingExecutableNames];
    }
    else
    {
        [self fixWine32ExecutableNames];
    }
    
}

// WINESKIN_LIB_PATH_FOR_FALLBACK removed from bash scripts, it's only needed so WineskinX11 will launch on El Capitan & above (commit 5ac7fa4) and this gets handled by -startWine so it's not needed within the bash scripts
- (void)fixWine32ExecutableNames
{
    BOOL fixWine=YES;
    NSString *oldWineName = nil;
    NSString *oldWineServerName = nil;
    NSString *pathToWineBinFolder = [NSString stringWithFormat:@"%@/wswine.bundle/bin",frameworksFold];
    NSArray *engineBinContents = [fm contentsOfDirectoryAtPath:pathToWineBinFolder];
    for (NSString *item in engineBinContents)
    {
        if ([item hasSuffix:@"Wine"])
        {
            oldWineName = [NSString stringWithFormat:@"%@",item];
        }
        else if ([item hasSuffix:@"Wineserver"])
        {
            oldWineServerName = [NSString stringWithFormat:@"%@",item];
        }
    }
    if (oldWineName == nil)
    {
        oldWineName=@"wine";
    }
    if (oldWineServerName == nil)
    {
        oldWineServerName=@"wineserver";
    }
    if ([oldWineName hasPrefix:appName] && [oldWineServerName hasPrefix:appName])
    {
        fixWine=NO;
        wineName = [NSString stringWithFormat:@"%@",oldWineName];
        wineServerName = [NSString stringWithFormat:@"%@",oldWineServerName];
    }
    
    if (fixWine == false) return;
    
    // set CFBundleID too
    srand((unsigned)time(0));
    bundleRandomInt1 = (int)(rand()%999999999);
    if (bundleRandomInt1 < 0)
    {
        bundleRandomInt1 = bundleRandomInt1*(-1);
    }
    
    //set names for wine and wineserver
    wineServerName = [NSString stringWithFormat:@"%@%dWineserver",appName,bundleRandomInt1];
    wineName = [NSString stringWithFormat:@"%@%dWine",appName,bundleRandomInt1];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineName]];
    [fm moveItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,oldWineName]
                toPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineName]];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineServerName]];
    [fm moveItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,oldWineServerName]
                toPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineServerName]];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/wine",pathToWineBinFolder]];
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/wineserver",pathToWineBinFolder]];
    
    NSString* binBash = @"#!/bin/bash\n";
    
    NSString *wineBash = [NSString stringWithFormat:@"%@\"$(dirname \"$0\")/%@\" \"$@\"",
                          binBash,wineName];
    NSString *wineServerBash = [NSString stringWithFormat:@"%@\"$(dirname \"$0\")/%@\" \"$@\"",
                                binBash,wineServerName];
    
    [wineBash       writeToFile:[NSString stringWithFormat:@"%@/wine",pathToWineBinFolder]       atomically:YES encoding:NSUTF8StringEncoding];
    [wineServerBash writeToFile:[NSString stringWithFormat:@"%@/wineserver",pathToWineBinFolder] atomically:YES encoding:NSUTF8StringEncoding];
    
    [self systemCommand:[NSString stringWithFormat:@"chmod -R 777 \"%@\"",pathToWineBinFolder]];
}

// WINESKIN_LIB_PATH_FOR_FALLBACK removed from bash scripts, it's only needed so WineskinX11 will launch on El Capitan & above (commit 5ac7fa4) and this gets handled by -startWine so it's not needed within the bash scripts
- (void)fixWine64ExecutableNames
{
    BOOL fixWine=YES;
    NSString *oldWineName = nil;
    NSString *oldWine64Name = nil;
    NSString *oldWineServerName = nil;
    NSString *pathToWineBinFolder = [NSString stringWithFormat:@"%@/wswine.bundle/bin",frameworksFold];
    NSArray *engineBinContents = [fm contentsOfDirectoryAtPath:pathToWineBinFolder];
    for (NSString *item in engineBinContents)
    {
        if ([item hasSuffix:@"Wine"])
        {
            oldWineName = [NSString stringWithFormat:@"%@",item];
            
        }
        if ([item hasSuffix:@"Wine64"])
        {
            oldWine64Name = [NSString stringWithFormat:@"%@",item];
            
        }
        else if ([item hasSuffix:@"Wineserver"])
        {
            oldWineServerName = [NSString stringWithFormat:@"%@",item];
        }
    }
    if (oldWineName == nil)
    {
        oldWineName=@"wine";
    }
    if (oldWine64Name == nil)
    {
        oldWine64Name=@"wine64";
    }
    if (oldWineServerName == nil)
    {
        oldWineServerName=@"wineserver";
    }
    if ([oldWineName hasPrefix:appName] && [oldWine64Name hasPrefix:appName] && [oldWineServerName hasPrefix:appName])
    {
        fixWine=NO;
        wineName = [NSString stringWithFormat:@"%@",oldWineName];
        wine64Name = [NSString stringWithFormat:@"%@",oldWine64Name];
        wineServerName = [NSString stringWithFormat:@"%@",oldWineServerName];
    }
    
    if (fixWine == false) return;
    
    // set CFBundleID too
    srand((unsigned)time(0));
    bundleRandomInt1 = (int)(rand()%999999999);
    if (bundleRandomInt1 < 0)
    {
        bundleRandomInt1 = bundleRandomInt1*(-1);
    }
    
    //set names for wine, wine64 and wineserver
    wineServerName = [NSString stringWithFormat:@"%@%dWineserver",appName,bundleRandomInt1];
    wineName = [NSString stringWithFormat:@"%@%dWine",appName,bundleRandomInt1];
    wine64Name = [NSString stringWithFormat:@"%@%dWine64",appName,bundleRandomInt1];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineName]];
    [fm moveItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,oldWineName]
                toPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineName]];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wine64Name]];
    [fm moveItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,oldWine64Name]
                toPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wine64Name]];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineServerName]];
    [fm moveItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,oldWineServerName]
                toPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineServerName]];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/wine",pathToWineBinFolder]];
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/wine64",pathToWineBinFolder]];
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/wineserver",pathToWineBinFolder]];
    
    NSString* binBash = @"#!/bin/bash\n";
    
    NSString *wineBash = [NSString stringWithFormat:@"%@\"$(dirname \"$0\")/%@\" \"$@\"",
                          binBash,wineName];
    NSString *wine64Bash = [NSString stringWithFormat:@"%@\"$(dirname \"$0\")/%@\" \"$@\"",
                            binBash,wine64Name];
    NSString *wineServerBash = [NSString stringWithFormat:@"%@\"$(dirname \"$0\")/%@\" \"$@\"",
                                binBash,wineServerName];
    
    [wineBash       writeToFile:[NSString stringWithFormat:@"%@/wine",pathToWineBinFolder]       atomically:YES encoding:NSUTF8StringEncoding];
    [wine64Bash       writeToFile:[NSString stringWithFormat:@"%@/wine64",pathToWineBinFolder]       atomically:YES encoding:NSUTF8StringEncoding];
    [wineServerBash writeToFile:[NSString stringWithFormat:@"%@/wineserver",pathToWineBinFolder] atomically:YES encoding:NSUTF8StringEncoding];
    
    [self systemCommand:[NSString stringWithFormat:@"chmod -R 777 \"%@\"",pathToWineBinFolder]];
}

// WINESKIN_LIB_PATH_FOR_FALLBACK removed from bash scripts, it's only needed so WineskinX11 will launch on El Capitan & above (commit 5ac7fa4) and this gets handled by -startWine so it's not needed within the bash scripts
// Wine-Staging engines only work correctly on 10.8+ systems according to wine-staging.com
// Renaming can only apply to wine-preloader for staging engines
- (void)fixWineStagingExecutableNames
{
    BOOL fixWine=YES;
    NSString *oldWineStagingName = nil;
    NSString *oldWineServerName = nil;
    NSString *pathToWineBinFolder = [NSString stringWithFormat:@"%@/wswine.bundle/bin",frameworksFold];
    NSArray *engineBinContents = [fm contentsOfDirectoryAtPath:pathToWineBinFolder];
    for (NSString *item in engineBinContents)
    {
        if ([item hasSuffix:@"Wine-preloader"])
        {
            oldWineStagingName = [NSString stringWithFormat:@"%@",item];
        }
        else if ([item hasSuffix:@"Wineserver"])
        {
            oldWineServerName = [NSString stringWithFormat:@"%@",item];
        }
    }
    if (oldWineStagingName == nil)
    {
        oldWineStagingName=@"wine-preloader";
    }
    if (oldWineServerName == nil)
    {
        oldWineServerName=@"wineserver";
    }
    if ([oldWineStagingName hasPrefix:appName] && [oldWineServerName hasPrefix:appName])
    {
        fixWine=NO;
        wineStagingName = [NSString stringWithFormat:@"%@",oldWineStagingName];
        wineServerName = [NSString stringWithFormat:@"%@",oldWineServerName];
    }
    
    if (fixWine == false) return;
    
    // set CFBundleID too
    srand((unsigned)time(0));
    bundleRandomInt1 = (int)(rand()%999999999);
    if (bundleRandomInt1 < 0)
    {
        bundleRandomInt1 = bundleRandomInt1*(-1);
    }
    
    //set names for wine-preloader and wineserver
    wineServerName = [NSString stringWithFormat:@"%@%dWineserver",appName,bundleRandomInt1];
    wineStagingName = [NSString stringWithFormat:@"%@%dWine-preloader",appName,bundleRandomInt1];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineStagingName]];
    [fm moveItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,oldWineStagingName]
                toPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineStagingName]];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineServerName]];
    [fm moveItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,oldWineServerName]
                toPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineServerName]];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/wine-preloader",pathToWineBinFolder]];
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/wineserver",pathToWineBinFolder]];
    
    NSString* binBash = @"#!/bin/bash\n";
    
    NSString *wineStagingBash = [NSString stringWithFormat:@"%@\"$(dirname \"$0\")/%@\" \"$@\"",
                                 binBash,wineStagingName];
    NSString *wineServerBash = [NSString stringWithFormat:@"%@\"$(dirname \"$0\")/%@\" \"$@\"",
                                binBash,wineServerName];
    
    [wineStagingBash       writeToFile:[NSString stringWithFormat:@"%@/wine-preloader",pathToWineBinFolder]       atomically:YES encoding:NSUTF8StringEncoding];
    [wineServerBash writeToFile:[NSString stringWithFormat:@"%@/wineserver",pathToWineBinFolder] atomically:YES encoding:NSUTF8StringEncoding];
    
    [self systemCommand:[NSString stringWithFormat:@"chmod -R 777 \"%@\"",pathToWineBinFolder]];
}

// WINESKIN_LIB_PATH_FOR_FALLBACK removed from bash scripts, it's only needed so WineskinX11 will launch on El Capitan & above (commit 5ac7fa4) and this gets handled by -startWine so it's not needed within the bash scripts
// Wine-Staging engines only work correctly on 10.8+ systems according to wine-staging.com
// Renaming can only apply to wine-preloader/wine64-preloader for staging engines
- (void)fixWineStaging64ExecutableNames
{
    BOOL fixWine=YES;
    NSString *oldWineStagingName = nil;
    NSString *oldWineStaging64Name = nil;
    NSString *oldWineServerName = nil;
    NSString *pathToWineBinFolder = [NSString stringWithFormat:@"%@/wswine.bundle/bin",frameworksFold];
    NSArray *engineBinContents = [fm contentsOfDirectoryAtPath:pathToWineBinFolder];
    for (NSString *item in engineBinContents)
    {
        if ([item hasSuffix:@"Wine-preloader"])
        {
            oldWineStagingName = [NSString stringWithFormat:@"%@",item];
        }
        if ([item hasSuffix:@"Wine64-preloader"])
        {
            oldWineStaging64Name = [NSString stringWithFormat:@"%@",item];
        }
        else if ([item hasSuffix:@"Wineserver"])
        {
            oldWineServerName = [NSString stringWithFormat:@"%@",item];
        }
    }
    if (oldWineStagingName == nil)
    {
        oldWineStagingName=@"wine-preloader";
    }
    if (oldWineStaging64Name == nil)
    {
        oldWineStaging64Name=@"wine64-preloader";
    }
    if (oldWineServerName == nil)
    {
        oldWineServerName=@"wineserver";
    }
    if ([oldWineStagingName hasPrefix:appName] && [oldWineStaging64Name hasPrefix:appName] && [oldWineServerName hasPrefix:appName])
    {
        fixWine=NO;
        wineStagingName = [NSString stringWithFormat:@"%@",oldWineStagingName];
        wineStaging64Name = [NSString stringWithFormat:@"%@",oldWineStaging64Name];
        wineServerName = [NSString stringWithFormat:@"%@",oldWineServerName];
    }
    
    if (fixWine == false) return;
    
    // set CFBundleID too
    srand((unsigned)time(0));
    bundleRandomInt1 = (int)(rand()%999999999);
    if (bundleRandomInt1 < 0)
    {
        bundleRandomInt1 = bundleRandomInt1*(-1);
    }
    
    //set names for wine-preloader, wine64-preloader and wineserver
    wineServerName = [NSString stringWithFormat:@"%@%dWineserver",appName,bundleRandomInt1];
    wineStagingName = [NSString stringWithFormat:@"%@%dWine-preloader",appName,bundleRandomInt1];
    wineStaging64Name = [NSString stringWithFormat:@"%@%dWine64-preloader",appName,bundleRandomInt1];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineStagingName]];
    [fm moveItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,oldWineStagingName]
                toPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineStagingName]];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineStaging64Name]];
    [fm moveItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,oldWineStaging64Name]
                toPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineStaging64Name]];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineServerName]];
    [fm moveItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,oldWineServerName]
                toPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineServerName]];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/wine-preloader",pathToWineBinFolder]];
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/wine64-preloader",pathToWineBinFolder]];
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/wineserver",pathToWineBinFolder]];
    
    NSString* binBash = @"#!/bin/bash\n";
    
    NSString *wineStagingBash = [NSString stringWithFormat:@"%@\"$(dirname \"$0\")/%@\" \"$@\"",
                                 binBash,wineStagingName];
    NSString *wineStaging64Bash = [NSString stringWithFormat:@"%@\"$(dirname \"$0\")/%@\" \"$@\"",
                                   binBash,wineStaging64Name];
    NSString *wineServerBash = [NSString stringWithFormat:@"%@\"$(dirname \"$0\")/%@\" \"$@\"",
                                binBash,wineServerName];
    
    [wineStagingBash       writeToFile:[NSString stringWithFormat:@"%@/wine-preloader",pathToWineBinFolder]       atomically:YES encoding:NSUTF8StringEncoding];
    [wineStaging64Bash       writeToFile:[NSString stringWithFormat:@"%@/wine64-preloader",pathToWineBinFolder]       atomically:YES encoding:NSUTF8StringEncoding];
    [wineServerBash writeToFile:[NSString stringWithFormat:@"%@/wineserver",pathToWineBinFolder] atomically:YES encoding:NSUTF8StringEncoding];
    
    [self systemCommand:[NSString stringWithFormat:@"chmod -R 777 \"%@\"",pathToWineBinFolder]];
}

- (void)wineBootStuckProcess
{
    //kills Wine if a Wine process is stuck with 90%+ usage.  Very hacky work around
    usleep(5000000);
    int loopCount = 30;
    int i;
    int hit = 0;
    for (i=0; i < loopCount; ++i)
    {
        NSArray *resultArray = [[self systemCommand:@"ps -eo pcpu,pid,args | grep \"wineboot.exe --init\""] componentsSeparatedByString:@" "];
        if ([[resultArray objectAtIndex:1] floatValue] > 90.0)
        {
            if (hit > 5)
            {
                usleep(5000000);
                char *tmp;
                kill((pid_t)(strtoimax([[resultArray objectAtIndex:2] UTF8String], &tmp, 10)), 9);
                break;
            }
            else
            {
                ++hit;
            }
        }
        usleep(1000000);
    }
}

- (void)startWine:(WineStart *)wineStartInfo
{
    @autoreleasepool
    {
        NSString *wssCommand = [wineStartInfo getWssCommand];
        //make sure the /tmp/.wine-uid folder and lock file are correct since Wine is buggy about it
        if (primaryRun)
        {
            NSDictionary *info = [fm attributesOfItemAtPath:winePrefix error:nil];
            NSString *uid = [NSString stringWithFormat: @"%d", getuid()];
            NSString *inode = [NSString stringWithFormat:@"%lx", (unsigned long)[info[NSFileSystemFileNumber] unsignedIntegerValue]];
            NSString *deviceId = [NSString stringWithFormat:@"%lx", (unsigned long)[info[NSFileSystemNumber] unsignedIntegerValue]];
            NSString *pathToWineLockFolder = [NSString stringWithFormat:@"/tmp/.wine-%@/server-%@-%@",uid,deviceId,inode];
            if ([fm fileExistsAtPath:pathToWineLockFolder])
            {
                [fm removeItemAtPath:pathToWineLockFolder];
            }
            [fm createDirectoryAtPath:pathToWineLockFolder withIntermediateDirectories:YES];
            [self systemCommand:[NSString stringWithFormat:@"chmod -R 700 \"/tmp/.wine-%@\"",uid]];
        }
        
        if ([wineStartInfo isNonStandardRun])
        {
            [self setToNoVirtualDesktop];
            NSString *wineDebugLine = @"err-all,warn-all,fixme-all,trace-all";
            
            //remove the .update-timestamp file
            [fm removeItemAtPath:[NSString stringWithFormat:@"%@/.update-timestamp",winePrefix]];
            
            //calling wineboot is a simple builtin refresh that needs to NOT prompt for gecko
            NSString *mshtmlLine;
            if ([wssCommand isEqualToString:@"WSS-wineboot"])
            {
                mshtmlLine = @"export WINEDLLOVERRIDES=\"mscoree,mshtml=\";";
            }
            else
            {
                mshtmlLine = @"";
            }
            
            //launch monitor thread for killing stuck wineboots (work-a-round Macdriver bug for 1.5.28)
            [NSThread detachNewThreadSelector:@selector(wineBootStuckProcess) toTarget:self withObject:nil];
            NSArray* command = @[mshtmlLine,
                                 [NSString stringWithFormat:@"export WINESKIN_LIB_PATH_FOR_FALLBACK=\"%@\";",dyldFallBackLibraryPath],
                                 [NSString stringWithFormat:@"export WINEDEBUG=%@;",wineDebugLine],
                                 [NSString stringWithFormat:@"export PATH=\"%@/wswine.bundle/bin:%@/bin:$PATH:/opt/local/bin:/opt/local/sbin\";",frameworksFold,frameworksFold],
                                 [NSString stringWithFormat:@"export DISPLAY=%@;",theDisplayNumber],
                                 [NSString stringWithFormat:@"export WINEPREFIX=\"%@\";",winePrefix],
                                 [NSString stringWithFormat:@"DYLD_FALLBACK_LIBRARY_PATH=\"%@\"",dyldFallBackLibraryPath],
                                 @"wine wineboot"];
            [self systemCommand:[command componentsJoinedByString:@" "]];
            usleep(3000000);
            
            if ([wssCommand isEqualToString:@"WSS-wineprefixcreate"]) //only runs on build new wrapper, and rebuild
            {
                //make sure windows/profiles is using users folder
                NSString* profilesFolderPath = [NSString stringWithFormat:@"%@/drive_c/windows/profiles",winePrefix];
                [fm removeItemAtPath:profilesFolderPath];
                [fm createSymbolicLinkAtPath:profilesFolderPath withDestinationPath:@"../users" error:nil];
                [self systemCommand:[NSString stringWithFormat:@"chmod -h 777 \"%@\"",profilesFolderPath]];
                
                //rename new user folder to Wineskin and make symlinks
                NSString* usersUserFolderPath = [NSString stringWithFormat:@"%@/drive_c/users/%@",winePrefix,NSUserName()];
                NSString* usersWineskinFolderPath = [NSString stringWithFormat:@"%@/drive_c/users/Wineskin",winePrefix];
                NSString* usersCrossOverFolderPath = [NSString stringWithFormat:@"%@/drive_c/users/crossover",winePrefix];
                
                if ([fm fileExistsAtPath:usersUserFolderPath])
                {
                    [fm moveItemAtPath:usersUserFolderPath toPath:usersWineskinFolderPath];
                    [fm createSymbolicLinkAtPath:usersUserFolderPath withDestinationPath:@"Wineskin" error:nil];
                    [self systemCommand:[NSString stringWithFormat:@"chmod -h 777 \"%@\"",usersUserFolderPath]];
                }
                else if ([fm fileExistsAtPath:usersCrossOverFolderPath])
                {
                    [fm moveItemAtPath:usersCrossOverFolderPath toPath:usersWineskinFolderPath];
                    [fm createSymbolicLinkAtPath:usersCrossOverFolderPath withDestinationPath:@"Wineskin" error:nil];
                    [self systemCommand:[NSString stringWithFormat:@"chmod -h 777 \"%@\"",usersCrossOverFolderPath]];
                }
                else //this shouldn't ever happen.. but what the heck
                {
                    [fm createDirectoryAtPath:usersWineskinFolderPath withIntermediateDirectories:YES];
                    [fm createSymbolicLinkAtPath:usersUserFolderPath withDestinationPath:@"Wineskin" error:nil];
                    [self systemCommand:[NSString stringWithFormat:@"chmod -h 777 \"%@\"",usersUserFolderPath]];
                }
                
                //load Wineskin default reg entries
                NSArray* loadRegCommand = @[[NSString stringWithFormat:@"export WINESKIN_LIB_PATH_FOR_FALLBACK=\"%@\";",dyldFallBackLibraryPath],
                                            [NSString stringWithFormat:@"export WINEDEBUG=%@;",wineDebugLine],
                                            [NSString stringWithFormat:@"export PATH=\"%@/wswine.bundle/bin:%@/bin:$PATH:/opt/local/bin:/opt/local/sbin\";",frameworksFold,frameworksFold],
                                            [NSString stringWithFormat:@"export DISPLAY=%@;",theDisplayNumber],
                                            [NSString stringWithFormat:@"export WINEPREFIX=\"%@\";",winePrefix],
                                            [NSString stringWithFormat:@"DYLD_FALLBACK_LIBRARY_PATH=\"%@\"",dyldFallBackLibraryPath],
                                            [NSString stringWithFormat:@"wine regedit \"%@/../Wineskin.app/Contents/Resources/remakedefaults.reg\" > \"/dev/null\" 2>&1", contentsFold]];
                [self systemCommand:[loadRegCommand componentsJoinedByString:@" "]];
                usleep(5000000);
            }
            
            NSString* userFolderWindowsPath = [NSString stringWithFormat:@"C:\\users\\%@",NSUserName()];
            NSString* wineskinUserFolderWindowsPath = @"C:\\users\\Wineskin";
            
            
            //fix user name entires over to Wineskin
            NSString* userRegPath = [NSString stringWithFormat:@"%@/user.reg",winePrefix];
            NSArray *userReg = [self readFileToStringArray:userRegPath];
            NSMutableArray *newUserReg = [NSMutableArray arrayWithCapacity:userReg.count];
            for (NSString *item in userReg)
            {
                [newUserReg addObject:[item stringByReplacingOccurrencesOfString:userFolderWindowsPath
                                                                      withString:wineskinUserFolderWindowsPath]];
            }
            [self writeStringArray:newUserReg toFile:userRegPath];
            [self systemCommand:[NSString stringWithFormat:@"chmod 666 \"%@\"",userRegPath]];
            
            
            NSString* userDefRegPath = [NSString stringWithFormat:@"%@/userdef.reg",winePrefix];
            NSArray *userDefReg = [self readFileToStringArray:userDefRegPath];
            NSMutableArray *newUserDefReg = [NSMutableArray arrayWithCapacity:userDefReg.count];
            for (NSString *item in userDefReg)
            {
                [newUserDefReg addObject:[item stringByReplacingOccurrencesOfString:userFolderWindowsPath
                                                                         withString:wineskinUserFolderWindowsPath]];
            }
            [self writeStringArray:newUserDefReg toFile:userDefRegPath];
            
            
            // need Temp folder in Wineskin folder
            [fm createDirectoryAtPath:[NSString stringWithFormat:@"%@/drive_c/users/Wineskin/Temp",winePrefix] withIntermediateDirectories:YES];
            
            // do a chmod on the whole wrapper to 755... shouldn't break anything but should prevent issues.
            // Task Number 3221715 Fix Wrapper Permissions
            //cocoa command don't seem to be working right, but chmod system command works fine.
            // cannot 755 the whole wrapper and then change to 777s or this can break the wrapper for non-Admin users.
            //[self systemCommand:[NSString stringWithFormat:@"chmod 755 \"%@\"",appNameWithPath]];
            // need to chmod 777 on Contents, Resources, and Resources/* for multiuser fix on same machine
            [self systemCommand:[NSString stringWithFormat:@"chmod 777 \"%@\"",contentsFold]];
            [self systemCommand:[NSString stringWithFormat:@"chmod 777 \"%@\"",winePrefix]];
            [self systemCommand:[NSString stringWithFormat:@"chmod 777 \"%@\"",frameworksFold]];
            [self systemCommand:[NSString stringWithFormat:@"chmod 777 \"%@/wswine.bundle\"",frameworksFold]];//for ICE symlinks
            [self systemCommand:[NSString stringWithFormat:@"chmod -R 777 \"%@/drive_c\"",winePrefix]];
            NSArray *tmpy2 = [fm contentsOfDirectoryAtPath:winePrefix];
            for (NSString *item in tmpy2)
            {
                [self systemCommand:[NSString stringWithFormat:@"chmod 777 \"%@/%@\"",winePrefix,item]];
            }
            NSString* dosdevicesPath = [NSString stringWithFormat:@"%@/dosdevices",winePrefix];
            NSArray *tmpy3 = [fm contentsOfDirectoryAtPath:dosdevicesPath];
            for (NSString *item in tmpy3)
            {
                [self systemCommand:[NSString stringWithFormat:@"chmod -h 777 \"%@/%@\"",dosdevicesPath,item]];
            }
            return;
        }
        
        //Normal Wine Run
        if (primaryRun)
        {
            //edit reg entiries for VD settings
            NSString *vdResolution = [wineStartInfo getVdResolution];
            if ([vdResolution isEqualToString:WINESKIN_WRAPPER_PLIST_VALUE_SCREEN_OPTIONS_NO_VIRTUAL_DESKTOP])
            {
                [self setToNoVirtualDesktop];
            }
            else
            {
                [self setToVirtualDesktop:vdResolution];
            }
        }
        NSString *wineDebugLine;
        NSString *wineLogFileLocal = [NSString stringWithFormat:@"%@",wineLogFile];
        //set log file names, and stuff
        if (debugEnabled && !fullScreenOption) //standard log
        {
            wineDebugLine = [NSString stringWithFormat:@"%@",[wineStartInfo getWineDebugLine]];
        }
        else if (debugEnabled && fullScreenOption) //always need a log with x11settings
        {
            NSString *setWineDebugLine = [wineStartInfo getWineDebugLine];
            if ([setWineDebugLine rangeOfString:@"trace+x11settings"].location == NSNotFound)
            {
                removeX11TraceFromLog = YES;
                wineDebugLine = [NSString stringWithFormat:@"%@,trace+x11settings",setWineDebugLine];
            }
            else
            {
                wineDebugLine = setWineDebugLine;
            }
        }
        else if (!debugEnabled && fullScreenOption) //need log for reso changes
        {
            wineDebugLine = @"err-all,warn-all,fixme-all,trace+x11settings";
        }
        else //this should be rootless with no debug... don't need a log of any type.
        {
            wineLogFileLocal = @"/dev/null";
            wineDebugLine = @"err-all,warn-all,fixme-all,trace-all";
        }
        //fix start.exe line
        NSString *startExeLine = @"";
        if ([wineStartInfo isRunWithStartExe])
        {
            startExeLine = @" start /unix";
        }
        //Wine start section
        NSString *silentMode;
        if ([wssCommand isEqualToString:@"WSS-winetricks"])
        {
            if ([[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_WINETRICKS_NOLOGS] intValue] == 1)
            {
                wineDebugLine = @"err-all,warn-all,fixme-all,trace-all";
            }
            else
            {
                wineDebugLine = @"err+all,warn-all,fixme+all,trace-all";
            }
            
            if ([[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_WINETRICKS_SILENT] intValue] == 1)
            {
                silentMode = @"-q";
            }
            else
            {
                silentMode = @"";
            }
            NSArray *winetricksCommands = [wineStartInfo getWinetricksCommands];
            if ((winetricksCommands.count == 2 &&  [winetricksCommands[1] isEqualToString:@"list"]) ||
                (winetricksCommands.count == 1 && ([winetricksCommands[0] isEqualToString:@"list"]  ||
                                                   [winetricksCommands[0] hasPrefix:@"list-"])))
            {
                //just getting a list of packages... X should NOT be running.
                [self systemCommand:[NSString stringWithFormat:@"export WINESKIN_LIB_PATH_FOR_FALLBACK=\"%@\";export WINEDEBUG=%@;cd \"%@/../Wineskin.app/Contents/Resources\";export PATH=\"$PWD:%@/wswine.bundle/bin:%@/bin:$PATH:/opt/local/bin:/opt/local/sbin\";export DISPLAY=%@;export WINEPREFIX=\"%@\";DYLD_FALLBACK_LIBRARY_PATH=\"%@\" winetricks --no-isolate %@ > \"%@/Logs/WinetricksTemp.log\"",dyldFallBackLibraryPath,wineDebugLine,contentsFold,frameworksFold,frameworksFold,theDisplayNumber,winePrefix,dyldFallBackLibraryPath,[winetricksCommands componentsJoinedByString:@" "],winePrefix]];
            }
            else
            {
                [self systemCommand:[NSString stringWithFormat:@"export WINESKIN_LIB_PATH_FOR_FALLBACK=\"%@\";export WINEDEBUG=%@;cd \"%@/../Wineskin.app/Contents/Resources\";export PATH=\"$PWD:%@/wswine.bundle/bin:%@/bin:$PATH:/opt/local/bin:/opt/local/sbin\";export DISPLAY=%@;export WINEPREFIX=\"%@\";%@DYLD_FALLBACK_LIBRARY_PATH=\"%@\" winetricks %@ --no-isolate \"%@\" > \"%@/Logs/Winetricks.log\" 2>&1",dyldFallBackLibraryPath,wineDebugLine,contentsFold,frameworksFold,frameworksFold,theDisplayNumber,winePrefix,[wineStartInfo getCliCustomCommands],dyldFallBackLibraryPath,silentMode,[winetricksCommands componentsJoinedByString:@"\" \""],winePrefix]];
            }
            usleep(5000000); // sometimes it dumps out slightly too fast... just hold for a few seconds
            return;
        }
        
        if ([wineStartInfo isOpeningFiles])
        {
            for (NSString *item in [wineStartInfo getFilesToRun]) //start wine with files
            {
                //don't try to run things xorg sometimes passes back stupidly...
                BOOL breakOut = NO;
                NSArray *breakStrings = @[@"/opt/X11/share/fonts",@"/usr/X11/share/fonts",@"/opt/local/share/fonts",
                        @"/usr/X11/lib/X11/fonts",@"/usr/X11R6/lib/X11/fonts",[NSString stringWithFormat:@"%@/bin/fonts",frameworksFold]];
                for (NSString *breakItem in breakStrings)
                {
                    if ([item hasPrefix:breakItem])
                    {
                        breakOut = YES;
                        break;
                    }
                }
                if (breakOut)
                {
                    break;
                }
                [self systemCommand:[NSString stringWithFormat:@"export WINESKIN_LIB_PATH_FOR_FALLBACK=\"%@\";export PATH=\"%@/wswine.bundle/bin:%@/bin:$PATH:/opt/local/bin:/opt/local/sbin\";%@export WINEDEBUG=%@;export DISPLAY=%@;export WINEPREFIX=\"%@\";%@cd \"%@/wswine.bundle/bin\";DYLD_FALLBACK_LIBRARY_PATH=\"%@\" wine start /unix \"%@\" > \"%@\" 2>&1 &",dyldFallBackLibraryPath, frameworksFold, frameworksFold, [wineStartInfo getULimitNumber], wineDebugLine, theDisplayNumber, winePrefix, [wineStartInfo getCliCustomCommands], frameworksFold, dyldFallBackLibraryPath, item, wineLogFileLocal]];
            }
        }
        else
        {
            //launch Wine normally
            [self systemCommand:[NSString stringWithFormat:@"export WINESKIN_LIB_PATH_FOR_FALLBACK=\"%@\";export PATH=\"%@/wswine.bundle/bin:%@/bin:$PATH:/opt/local/bin:/opt/local/sbin\";%@export WINEDEBUG=%@;export DISPLAY=%@;export WINEPREFIX=\"%@\";%@cd \"%@\";DYLD_FALLBACK_LIBRARY_PATH=\"%@\" wine%@ \"%@\"%@ > \"%@\" 2>&1 &",dyldFallBackLibraryPath,frameworksFold,frameworksFold,[wineStartInfo getULimitNumber],wineDebugLine,theDisplayNumber,winePrefix,[wineStartInfo getCliCustomCommands],[wineStartInfo getWineRunLocation],dyldFallBackLibraryPath,startExeLine,[wineStartInfo getWineRunFile],[wineStartInfo getProgramFlags],wineLogFileLocal]];
        }
        
        NSMutableString *vdResolution = [[wineStartInfo getVdResolution] mutableCopy];
        [vdResolution replaceOccurrencesOfString:@"x" withString:@" " options:NSLiteralSearch range:NSMakeRange(0, vdResolution.length)];
        [wineStartInfo setVdResolution:vdResolution];
        
        // give wineserver a minute to start up
        for (int s=0; s<480; ++s)
        {
            if ([self isWineserverRunning]) break;
            usleep(125000);
        }
	}
}

- (void)sleepAndMonitor
{
    NSString* logsFolderPath = [NSString stringWithFormat:@"%@/Logs",winePrefix];
    NSString *timeStampFile = [NSString stringWithFormat:@"%@/.timestamp",logsFolderPath];
	if (useGamma)
    {
        [self setGamma:gammaCorrection];
    }
	NSMutableString *newScreenReso = [[NSMutableString alloc] init];
    NSString *xRandRTempFile = @"/tmp/WineskinXrandrTempFile";
    NSString *timestampChecker = [NSString stringWithFormat:@"find \"%@\" -type f -newer \"%@\"",logsFolderPath,timeStampFile];
	BOOL fixGamma = NO;
	int fixGammaCounter = 0;
    if (fullScreenOption)
    {
        [self systemCommand:[NSString stringWithFormat:@"> \"%@\"",timeStampFile]];
        [self systemCommand:[NSString stringWithFormat:@"> \"%@\"",wineTempLogFile]];
    }
    if (useXQuartz || useMacDriver)
    {
        //use most efficent checking for background loop
    }
	while ([self isWineserverRunning])
	{
		//if running in override fullscreen, need to handle resolution changes
		if (fullScreenOption)
		{
			//compare to timestamp, if log is newer, we need to check it out.
            if ([self systemCommand:timestampChecker])
            {
				NSArray *tempArray = [self readFileToStringArray:wineLogFile];
				[self systemCommand:[NSString stringWithFormat:@"> \"%@\"",wineLogFile]];
                [self systemCommand:[NSString stringWithFormat:@"> \"%@\"",timeStampFile]];
				if (debugEnabled)
                {
                    NSArray *oldDataArray = [self readFileToStringArray:wineTempLogFile];
                    NSMutableArray *temp = [NSMutableArray arrayWithCapacity:[oldDataArray count]];
                    [temp addObjectsFromArray:oldDataArray];
                    [temp addObjectsFromArray:tempArray];
                    [self writeStringArray:temp toFile:wineTempLogFile];
                }
				//now find resolution, and change it
				for (NSString *item in tempArray)
				{
					if ([item hasPrefix:@"trace:x11settings:X11DRV_ChangeDisplaySettingsEx width="])
					{
						[newScreenReso setString:[item substringToIndex:[item rangeOfString:@" bpp="].location]];
                        [newScreenReso replaceOccurrencesOfString:@"trace:x11settings:X11DRV_ChangeDisplaySettingsEx width=" withString:@"" options:NSLiteralSearch range:NSMakeRange(0, [newScreenReso length])];
                        [newScreenReso replaceOccurrencesOfString:@"height=" withString:@"" options:NSLiteralSearch range:NSMakeRange(0, [newScreenReso length])];
						[self setResolution:newScreenReso];
					}
				}
			}
		}
        //check for xrandr made file in /tmp to know to do a gamma change
		if (useGamma)
		{
			if ([fm fileExistsAtPath:xRandRTempFile])
			{
                [fm removeItemAtPath:xRandRTempFile];
                
				///tmp/WineskinXrandrTempFile is written by WineskinX11 when there is a resolution change
                //when this happens Gamma is set to default, so we need to fix it, but there could be a delay, so it needs to try a few times over a few moments before giving up.
                //if it doesn't give up, multiple wrappers will fight eachother endlessly
                fixGamma = YES;
				fixGammaCounter = 0;
			}
            if (fixGamma)
            {
                [self setGamma:gammaCorrection];
                ++fixGammaCounter;
                if (fixGammaCounter > 6)
                {
                    fixGamma = NO;
                }
            }
		}
		usleep(1000000); // sleeping in background 1 second
	}
    [fm removeItemAtPath:timeStampFile];
}

- (void)cleanUpAndShutDown
{
    if (!useMacDriver)
    {
        //fix screen resolution back to original if fullscreen
        if (fullScreenOption)
        {
            [self setResolution:currentResolution];
        }
        if (fullScreenOption)
        {
            char *tmp;
            kill((pid_t)(strtoimax([xQuartzBundlePID UTF8String], &tmp, 10)), 9);
            kill((pid_t)(strtoimax([xQuartzX11BinPID UTF8String], &tmp, 10)), 9);
            [fm removeItemAtPath:@"/tmp/.X11-unix"];
            [fm removeItemAtPath:[NSString stringWithFormat:@"/tmp/.X%@-lock",[theDisplayNumber substringFromIndex:1]]];
        }
        else //using XQuartz but not override->Fullscreen. Change back to Rootless resolution so it won't be stuck in a fullscreen.
        {
            int xRes = [[currentResolution substringToIndex:[currentResolution rangeOfString:@" "].location] intValue];
            int yRes = [[currentResolution substringFromIndex:[currentResolution rangeOfString:@" "].location+1] intValue]-22;//if the resolution is the yMax-22 it should be the Rootless resolution
            [self setResolution:[NSString stringWithFormat:@"%d %d",xRes,yRes]];
        }
    }
    
	//fix user folders back
    for (NSString* userFolder in @[@"My Documents", @"Desktop", @"Downloads", @"My Videos", @"My Music", @"My Pictures"])
    {
        NSString* userFolderPath = [NSString stringWithFormat:@"%@/drive_c/users/Wineskin/%@",winePrefix,userFolder];
        if ([[[fm attributesOfItemAtPath:userFolderPath error:nil] fileType] isEqualToString:@"NSFileTypeSymbolicLink"])
        {
            [fm removeItemAtPath:userFolderPath];
        }
    }
    
	//clean up log files
	if (!debugEnabled)
	{
		[fm removeItemAtPath:wineLogFile];
		[fm removeItemAtPath:x11LogFile];
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Logs/Winetricks.log",winePrefix]];
	}
    else if (fullScreenOption)
    {
        NSArray *tempArray = [self readFileToStringArray:wineLogFile];
        NSArray *oldDataArray = [self readFileToStringArray:wineTempLogFile];
        NSMutableArray *temp = [NSMutableArray arrayWithCapacity:[oldDataArray count]];
        if (removeX11TraceFromLog)
        {
            for (NSString *item in oldDataArray)
            {
                if ([item rangeOfString:@"trace:x11settings"].location == NSNotFound)
                {
                    [temp addObject:item];
                }
            }
            for (NSString *item in tempArray)
            {
                if ([item rangeOfString:@"trace:x11settings"].location == NSNotFound)
                {
                    [temp addObject:item];
                }
            }
        }
        else
        {
            [temp addObjectsFromArray:oldDataArray];
            [temp addObjectsFromArray:tempArray];
        }
        [self writeStringArray:temp toFile:wineLogFile];
    }
    
	//fixes for multi-user use
	NSArray *tmpy3 = [fm contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/dosdevices",winePrefix]];
	for (NSString *item in tmpy3)
    {
		[self systemCommand:[NSString stringWithFormat:@"chmod -h 777 \"%@/dosdevices/%@\"",winePrefix,item]];
    }
    
    for (NSString* regFile in @[USERDEF_REG, SYSTEM_REG, USER_REG])
    {
        [self systemCommand:[NSString stringWithFormat:@"chmod 666 \"%@/%@.reg\"",winePrefix,regFile]];
    }
	
    [self systemCommand:[NSString stringWithFormat:@"chmod 666 \"%@/Info.plist\"",contentsFold]];
	[self systemCommand:[NSString stringWithFormat:@"chmod -R 777 \"%@/drive_c\"",winePrefix]];
    
    //get rid of the preference file
    [fm removeItemAtPath:x11PListFile];
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@.lockfile",x11PListFile]];
    [fm removeItemAtPath:lockfile];
    [fm removeItemAtPath:tmpFolder];
    [fm removeItemAtPath:tmpwineFolder];
    
    //kill processes
    [NSThread detachNewThreadSelector:@selector(wineBootStuckProcess) toTarget:self withObject:nil];
    NSArray* command = @[
                         [NSString stringWithFormat:@"export PATH=\"%@/wswine.bundle/bin:%@/bin:$PATH:/opt/local/bin:/opt/local/sbin\";",frameworksFold,frameworksFold],
                         [NSString stringWithFormat:@"export WINEPREFIX=\"%@\";",winePrefix],
                         [NSString stringWithFormat:@"DYLD_FALLBACK_LIBRARY_PATH=\"%@\"",dyldFallBackLibraryPath],
                         @"wineserver -k"];
    [self systemCommand:[command componentsJoinedByString:@" "]];
    usleep(3000000);

    //get rid of OS X saved state file
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Saved Application State/%@%@.wineskin.prefs.savedState",NSHomeDirectory(),[[NSNumber numberWithLong:bundleRandomInt1] stringValue],[[NSNumber numberWithLong:bundleRandomInt2] stringValue]]];
    
    //attempt to clear out any stuck processes in launchd for the wrapper
    //this may prevent -10810 errors on next launch with 10.9, and *shouldn't* hurt anything.
    NSArray *results = [[self systemCommand:[NSString stringWithFormat:@"launchctl list | grep \"%@\"",appName]] componentsSeparatedByString:@"\n"];
    for (NSString *result in results)
    {
        NSString *entryToRemove = [result getFragmentAfter:@"-" andBefore:nil];
        if (entryToRemove != nil)
        {
            // clear in front of - in case launchd has it as anonymous, then clear after first [
            entryToRemove = [entryToRemove stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSRange theBracket = [entryToRemove rangeOfString:@"["];
            if (theBracket.location != NSNotFound) {
                entryToRemove = [entryToRemove substringFromIndex:theBracket.location];
            }
            NSLog(@"launchctl remove \"%@\"",entryToRemove);
            [self systemCommand:[NSString stringWithFormat:@"launchctl remove \"%@\"",entryToRemove]];
        }
    }
    [NSApp terminate:nil];
}
@end
