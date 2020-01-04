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
#import "WineskinLauncher_Prefix.pch"
#import "NSWineskinEngine.h"

@implementation WineskinLauncherAppDelegate

-(NSString*)wrapperPath
{
    return [[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent];
}

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

- (void)application:(NSApplication *)application openURLs:(NSArray<NSURL *> *)urls;
{
    for (NSURL *url in urls) {
        NSString *urlString = [url absoluteString];

        NSRange replaceRange = [urlString rangeOfString:@"file://"];
        if (replaceRange.location == 0)
        {
            urlString = [urlString stringByReplacingCharactersInRange:replaceRange withString:@""];
        }

        [globalFilesToOpen addObject:urlString];
    }
    if (wrapperRunning)
    {
        [NSThread detachNewThreadSelector:@selector(secondaryRun:) toTarget:self withObject:[globalFilesToOpen copy]];
        [globalFilesToOpen removeAllObjects];
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
    NSString *uid = [NSString stringWithFormat: @"%d", getuid()];
    appNameWithPath = self.portManager.path;
    contentsFold = [NSString stringWithFormat:@"%@/Contents",appNameWithPath];
    frameworksFold = [NSString stringWithFormat:@"%@/Frameworks",contentsFold];
    winePrefix = [NSString stringWithFormat:@"%@/Resources",contentsFold];
    
    appName = appNameWithPath.lastPathComponent.stringByDeletingPathExtension;
    tmpFolder = [NSString stringWithFormat:@"/tmp/%@",[appNameWithPath stringByReplacingOccurrencesOfString:@"/" withString:@"xWSx"]];
    tmpwineFolder = [NSString stringWithFormat:@"/tmp/.wine-%@",uid];
    
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
	NSString* wineskinAppPath = [NSString stringWithFormat: @"%@/Wineskin.app", [[NSBundle mainBundle] bundlePath]];
    [[NSWorkspace sharedWorkspace] launchApplication:wineskinAppPath];
    [NSApp terminate:nil];
}

- (NSString *)system:(NSString *)command
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
        
        //TODO: Seems this is not used for bundle name on created but recreation works?
        // set CFBundleID too
        srand((unsigned)time(0));
        bundleRandomInt1 = (int)(rand()%999999999);
        if (bundleRandomInt1 < 0)
        {
            bundleRandomInt1 = bundleRandomInt1*(-1);
        }
    
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
        [NSTask runProgram:@"chmod" withFlags:@[@"-R",@"777",tmpFolder]];
        
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
            [NSTask runProgram:@"chmod" withFlags:@[@"-R",@"777",tmpFolder]];
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
        //TODO: Need to remove spaces to give a valid bundleID
        [self.portManager setPlistObject:[NSString stringWithFormat:@"com.%@%d.wineskin",appName,bundleRandomInt1]
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
        }
        
        debugEnabled = [[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_DEBUG_MODE] intValue];
        
        //set correct dyldFallBackLibraryPath
        //TODO: Maybe move Runtime inside Application Support?
        if (useXQuartz)
        {
            dyldFallBackLibraryPath = [NSString stringWithFormat:@"/opt/X11/lib:/opt/local/lib:%@/Wineskin/lib:%@:%@/wstools.bundle/lib:%@/wswine.bundle/lib:%@/wswine.bundle/lib64:/usr/lib:/usr/libexec:/usr/lib/system",NSHomeDirectory(),frameworksFold,frameworksFold,frameworksFold,frameworksFold];
        }
        
        NSString* engineString = [NSPortDataLoader engineOfPortAtPath:self.wrapperPath];
        NSWineskinEngine* engine = [NSWineskinEngine wineskinEngineWithString:engineString];
        
        if (engine.isCompatibleWithLatestFreeType)
        {
            //Use latest avalible dylib versions before the legacy versions within wstools.bundle
            dyldFallBackLibraryPath = [NSString stringWithFormat:@"/opt/local/lib:%@/Wineskin/lib:%@:%@/wswine.bundle/lib:%@/wswine.bundle/lib64:%@/wstools.bundle/lib:/usr/lib:/usr/libexec:/usr/lib/system:/opt/X11/lib",NSHomeDirectory(),frameworksFold,frameworksFold,frameworksFold,frameworksFold];
        }
        else
        {
            //Wine-2.17 and below can't use FreeType 2.8.1 so fallback to an older version
            dyldFallBackLibraryPath = [NSString stringWithFormat:@"%@/wstools.bundle/lib:%@:%@/wswine.bundle/lib:%@/wswine.bundle/lib64:%@/Wineskin/lib:/usr/lib:/usr/libexec:/usr/lib/system:/opt/X11/lib:/opt/local/lib",frameworksFold,frameworksFold,frameworksFold,frameworksFold,NSHomeDirectory()];
        }
        
        //TODO: check if we already map the /bin folder
        NSString *pathToWineBinFolder = [NSString stringWithFormat:@"%@/wswine.bundle/bin",frameworksFold];
        
        //set the wine executable to be used.
        //can't trust the Engine is named correctly so check the actual binary files
        if     ([fm fileExistsAtPath:[NSString stringWithFormat:@"%@/wine64",pathToWineBinFolder]] && ![fm fileExistsAtPath:[NSString stringWithFormat:@"%@/wine32on64",pathToWineBinFolder]] && IS_SYSTEM_MAC_OS_10_15_OR_SUPERIOR)
        {
            wineExecutable = @"wine64";
        }
        else if      ([fm fileExistsAtPath:[NSString stringWithFormat:@"%@/wine32on64",pathToWineBinFolder]] && IS_SYSTEM_MAC_OS_10_15_OR_SUPERIOR)
        {
            wineExecutable = @"wine32on64";
        }
        else
        {
            wineExecutable = @"wine";
        }
        
        [gammaCorrection setString:[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_GAMMA_CORRECTION]];
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
            if ([wssCommand hasPrefix:@"/"] || //if wssCommand starts with a / its file(s) passed in to open
                [wssCommand rangeOfString:@"[A-Za-z][A-Za-z0-9\\.\\+-]+:" options:NSRegularExpressionSearch].location == 0) //url schema
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
                    
                    if ([wssCommand isEqualToString:@"WSS-wineserverkill"])
                    {
                        NSString* pathEnv = [NSString stringWithFormat:@"%@/wswine.bundle/bin:$PATH:/opt/local/bin:/opt/local/sbin",frameworksFold];
                        [NSTask runProgram:[NSString stringWithFormat:@"%@/wswine.bundle/bin/wineserver",frameworksFold] withFlags:@[@"-k"] withEnvironment:@{@"PATH":pathEnv, @"WINEPREFIX":winePrefix}];
                        
                        //****** if "IsFnToggleEnabled" is enabled
                        if ([[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_ENABLE_FNTOGGLE] intValue] == 1)
                        {
                            [NSTask runProgram:[NSString stringWithFormat:@"%@/../Wineskin.app/Contents/Resources/fntoggle",contentsFold]
                                     withFlags:@[@"off"]];
                        }
                    }
                    
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
            NSString* wineskinAppPath = [NSString stringWithFormat: @"%@/Wineskin.app", appNameWithPath];
            [[NSWorkspace sharedWorkspace] launchApplication:wineskinAppPath];
            [fm removeItemAtPath:lockfile];
            [fm removeItemAtPath:tmpFolder];
            [fm removeItemAtPath:tmpwineFolder];
            exit(0);
        }
        //********** Wineskin Customizer start up script
        [NSTask runProgram:[NSString stringWithFormat:@"%@/Scripts/WineskinStartupScript",winePrefix]];
        
        //****** if "IsFnToggleEnabled" is enabled
        if ([[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_ENABLE_FNTOGGLE] intValue] == 1)
        {
            [NSTask runProgram:[NSString stringWithFormat:@"%@/../Wineskin.app/Contents/Resources/fntoggle",contentsFold]
                     withFlags:@[@"on"]];
        }
        
        //TODO: CPU Disabled does not work on current macOS versions, still need a replacement
        //****** if CPUs Disabled, disable all but 1 CPU
        NSString *cpuCountInput;
        if ([[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_SINGLE_CPU] intValue] == 1)
        {
            cpuCountInput = [self system:@"hwprefs cpu_count 2>/dev/null"];
            int i, cpuCount = [cpuCountInput intValue];
            for (i = 2; i <= cpuCount; ++i)
            {
                [self system:[NSString stringWithFormat:@"hwprefs cpu_disable %d",i]];
            }
        }
        
        if (lockFileAlreadyExisted)
        {
            //if lockfile already existed, then this instance was launched when another is the main one.
            //We need to pass the parameters given to WineskinLauncher over to the correct run of this program
            WineStart *wineStartInfo = [[WineStart alloc] init];
            [wineStartInfo setWssCommand:wssCommand];
            [wineStartInfo setWinetricksCommands:winetricksCommands];
            [self secondaryRun:filesToOpen];
            BOOL killWineskin = YES;
            
            // check if X11 is even running
            if (!useMacDriver && [self system:@"killall -0 X11.bin 2>&1"].length > 0)
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
                    // Needed for wrapper creation when using Engines that don't support Mac Driver
                    if (self.isXQuartzInstalled)
                    {
                        useXQuartz = YES;
                        [self startXQuartz];
                    }
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
        
        //********** Write system info to end X11 log file
        if (debugEnabled)
        {
            if (useXQuartz)
            {
                [self system:[NSString stringWithFormat:@"echo \"No X11 Log info when using XQuartz!\n\" > \"%@\"",x11LogFile]];
            }
            NSString *versionFile = [NSString stringWithFormat:@"%@/wswine.bundle/version",frameworksFold];
            if ([fm fileExistsAtPath:versionFile])
            {
                NSArray *tempArray = [self readFileToStringArray:versionFile];
                [self system:[NSString stringWithFormat:@"echo \"Engine Used: %@\" >> \"%@\"",[tempArray objectAtIndex:0],x11LogFile]];
            }
            //use mini detail level so no personal information can be displayed
            [self system:[NSString stringWithFormat:@"system_profiler -detailLevel mini SPHardwareDataType SPDisplaysDataType >> \"%@\"",x11LogFile]];
        }
        
        //**********sleep and monitor in background while app is running
        [self sleepAndMonitor];
        
        //****** if "IsFnToggleEnabled" is enabled, revert
        if ([[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_ENABLE_FNTOGGLE] intValue] == 1)
        {
            [NSTask runProgram:[NSString stringWithFormat:@"%@/../Wineskin.app/Contents/Resources/fntoggle",contentsFold]
                     withFlags:@[@"off"]];
        }
        
        //****** if CPUs Disabled, re-enable them
        if ([[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_SINGLE_CPU] intValue] == 1)
        {
            int i, cpuCount = [cpuCountInput intValue];
            for ( i = 2; i <= cpuCount; ++i)
            {
                [self system:[NSString stringWithFormat:@"hwprefs cpu_enable %d",i]];
            }
        }
            
        //********** Wineskin Customizer shut down script
        [NSTask runProgram:[NSString stringWithFormat:@"%@/Scripts/WineskinShutdownScript",winePrefix]];
        
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
            if ([wssCommand hasPrefix:@"/"] ||  //if wssCommand starts with a / its file(s) passed in to open
                [wssCommand rangeOfString:@"[A-Za-z][A-Za-z0-9\\.\\+-]+:" options:NSRegularExpressionSearch].location == 0) //url schema
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
                    //this will stop wineserverkill.exe from showing in "LastRunWine.log"
                    else if ([wssCommand isEqualToString:@"WSS-wineserverkill"])
                    {
                        return;
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
    NSArray* command = @[[NSString stringWithFormat:@"export PATH=\"%@/wswine.bundle/bin:%@/wstools.bundle/bin:$PATH:/opt/local/bin:/opt/local/sbin\";",frameworksFold,frameworksFold],
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
	NSString *resultString = [NSString stringWithFormat:@"00000\n%@",[self system:[NSString stringWithFormat:@"ps axc|awk \"{if (\\$5==\\\"%@\\\") print \\$1}\"",processToLookFor]]];
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
        [NSTask runProgram:@"chmod" withFlags:@[@"-h",@"777",folderPath]];
    }
    else
    {
        [fm createDirectoryAtPath:folderPath withIntermediateDirectories:NO];
    }
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
        [NSTask runProgram:@"chmod" withFlags:@[@"-h",@"777",folder]];
    }
}

- (void)fixWinePrefixForCurrentUser
{
	// changing owner just fails, need this to work for normal users without admin password on the fly.
	// Needed folders are set to 777, so just make a new resources folder and move items, should always work.
	// NSFileManager changing posix permissions still failing to work right, using chmod as a system command
    
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
	[NSTask runProgram:@"chmod" withFlags:@[@"-R",@"777",winePrefix]];
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
    
    [NSTask runProgram:@"chmod" withFlags:@[@"666",[NSString stringWithFormat:@"%@/user.reg",winePrefix]]];
}
- (void)tryToUseGPUInfo
{
    VMMVideoCard* vc = [VMMVideoCardManager bestInternalVideoCard];
    
    NSMutableString *deviceID = [vc.deviceID mutableCopy];
    NSMutableString *vendorID = [vc.vendorID mutableCopy];
    NSString *VRAM = [NSString stringWithFormat:@"%d",vc.memorySizeInMegabytes.intValue];
    
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
		NSString *indexZero = [self system:[NSString stringWithFormat:@"%@ --version",pathsToCheck[0]]];
		NSString *indexOne  = [self system:[NSString stringWithFormat:@"%@ --version",pathsToCheck[1]]];
        
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

-(BOOL)isXQuartzInstalled
{
    return [[NSFileManager defaultManager] fileExistsAtPath:@"/opt/X11/bin/Xquartz"];
}

- (BOOL)checkToUseXQuartz
{
    return [NSPortDataLoader useXQuartzIsEnabledAtPort:self.portManager];
}

- (void)startXQuartz
{
	if (!self.isXQuartzInstalled)
	{
        NSLog(@"Error XQuartz not found, please install XQuartz");
		//useXQuartz = NO;
		//return;
        [NSApp terminate:nil];
	}
    
	if (!fullScreenOption)
	{
        [theDisplayNumber setString:[self system:@"echo $DISPLAY"]];
        return;
	}
	
    //make sure XQuartz is not already running
    //this is because it needs to be started with no Quartz-wm for override->fullscreen to function correctly.
    if ([[self system:@"killall -s X11.bin"] hasPrefix:@"kill"])
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
    xQuartzBundlePID = [self system:[NSString stringWithFormat:@"/opt/X11/bin/Xquartz %@ > /dev/null & echo $!",theDisplayNumber]];
    
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
            [self system:[NSString stringWithFormat:@"open \"%@\"",appNameWithPath]];
        }
        else if (i==3)
        {
            NSString *theScript = [NSString stringWithFormat:@"tell Application \"%@\" to activate",appNameWithPath];
            NSAppleScript *bringToFrontScript = [[NSAppleScript alloc] initWithSource:theScript];
            [bringToFrontScript executeAndReturnError:nil];
        }
        else if (i==4)
        {
            [self system:[NSString stringWithFormat:@"arch -i386 /usr/bin/osascript -e \"tell application \\\"%@\\\" to activate\"",appNameWithPath]];
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
	NSString *wineFileMd5 = [[self system:[NSString stringWithFormat:@"md5 -r \"%@\"",wineTar7zFilePath]] stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@" %@",wineTar7zFilePath] withString:@""];
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
        [NSTask runProgram:@"chmod" withFlags:@[@"-h",@"777",[NSString stringWithFormat:@"%@/%@",wswineBundlePath,folder]]];
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
    
    [NSTask runProgram:@"chmod" withFlags:@[@"666",[NSString stringWithFormat:@"%@/user.reg",winePrefix]]];
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
    
    [NSTask runProgram:@"chmod" withFlags:@[@"666",[NSString stringWithFormat:@"%@/user.reg",winePrefix]]];
}

- (NSArray *)readFileToStringArray:(NSString *)theFile
{
	return [[NSString stringWithContentsOfFile:theFile encoding:NSUTF8StringEncoding] componentsSeparatedByString:@"\n"];
}

- (void)writeStringArray:(NSArray *)theArray toFile:(NSString *)theFile
{
	[fm removeItemAtPath:theFile];
	[[theArray componentsJoinedByString:@"\n"] writeToFile:theFile atomically:YES encoding:NSUTF8StringEncoding];
    [NSTask runProgram:@"chmod" withFlags:@[@"777",theFile]];
}

- (BOOL)isPID:(NSString *)pid named:(NSString *)name
{
    if ([pid isEqualToString:@""])
    {
        NSLog(@"INVALID PID SENT TO isPID!!!");
    }
	if ([[self system:[NSString stringWithFormat:@"ps -p \"%@\" | grep \"%@\"",pid,name]] length] < 1)
    {
        return NO;
    }
	return YES;
}

- (BOOL)isWineserverRunning
{
    return ([[self system:[NSString stringWithFormat:@"killall -0 \"%@\" 2>&1",wineServerName]] length] < 1);
}

// Checks to see what wine engine is being used
- (void)fixWineExecutableNames
{
    NSString *pathToWineBinFolder = [NSString stringWithFormat:@"%@/wswine.bundle/bin",frameworksFold];
    
    
    //wine32on64 without wine64
    if     ([fm fileExistsAtPath:[NSString stringWithFormat:@"%@/wine32on64-preloader",pathToWineBinFolder]] &&
            ![fm fileExistsAtPath:[NSString stringWithFormat:@"%@/wine64-preloader",pathToWineBinFolder]])
    {
        [self fixWine32on64ExecutableNames];
    }
    
    //wine32on64 with wine64
    else if     ([fm fileExistsAtPath:[NSString stringWithFormat:@"%@/wine32on64-preloader",pathToWineBinFolder]] &&
               [fm fileExistsAtPath:[NSString stringWithFormat:@"%@/wine64-preloader",pathToWineBinFolder]])
    {
        [self fixWine32on64_64BitExecutableNames];
    }
    
    
    else if     ([fm fileExistsAtPath:[NSString stringWithFormat:@"%@/wine64-preloader",pathToWineBinFolder]])
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
    NSString* dyldFallbackLibraryPath = @"DYLD_FALLBACK_LIBRARY_PATH=\"${WINESKIN_LIB_PATH_FOR_FALLBACK}\"";
    
    NSString *wineBash = [NSString stringWithFormat:@"%@ %@ \"%@\" \"$@\"",
                          binBash,dyldFallbackLibraryPath,wineName];
    NSString *wineServerBash = [NSString stringWithFormat:@"%@ %@ \"%@\" \"$@\"",
                                binBash,dyldFallbackLibraryPath,wineServerName];
    
    [wineBash       writeToFile:[NSString stringWithFormat:@"%@/wine",pathToWineBinFolder]       atomically:YES encoding:NSUTF8StringEncoding];
    [wineServerBash writeToFile:[NSString stringWithFormat:@"%@/wineserver",pathToWineBinFolder] atomically:YES encoding:NSUTF8StringEncoding];
    
    [NSTask runProgram:@"chmod" withFlags:@[@"-R",@"777",pathToWineBinFolder]];
}

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
    NSString* dyldFallbackLibraryPath = @"DYLD_FALLBACK_LIBRARY_PATH=\"${WINESKIN_LIB_PATH_FOR_FALLBACK}\"";
    
    NSString *wineBash = [NSString stringWithFormat:@"%@ %@ \"%@\" \"$@\"",
                          binBash,dyldFallbackLibraryPath,wineName];
    NSString *wine64Bash = [NSString stringWithFormat:@"%@ %@ \"%@\" \"$@\"",
                            binBash,dyldFallbackLibraryPath,wine64Name];
    NSString *wineServerBash = [NSString stringWithFormat:@"%@ %@ \"%@\" \"$@\"",
                                binBash,dyldFallbackLibraryPath,wineServerName];
    
    [wineBash       writeToFile:[NSString stringWithFormat:@"%@/wine",pathToWineBinFolder]       atomically:YES encoding:NSUTF8StringEncoding];
    [wine64Bash       writeToFile:[NSString stringWithFormat:@"%@/wine64",pathToWineBinFolder]       atomically:YES encoding:NSUTF8StringEncoding];
    [wineServerBash writeToFile:[NSString stringWithFormat:@"%@/wineserver",pathToWineBinFolder] atomically:YES encoding:NSUTF8StringEncoding];
    
    [NSTask runProgram:@"chmod" withFlags:@[@"-R",@"777",pathToWineBinFolder]];
}

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
    NSString* dyldFallbackLibraryPath = @"DYLD_FALLBACK_LIBRARY_PATH=\"${WINESKIN_LIB_PATH_FOR_FALLBACK}\"";
    
    NSString *wineStagingBash = [NSString stringWithFormat:@"%@ %@ \"%@\" \"$@\"",
                          binBash,dyldFallbackLibraryPath,wineStagingName];
    NSString *wineServerBash = [NSString stringWithFormat:@"%@ %@ \"%@\" \"$@\"",
                                binBash,dyldFallbackLibraryPath,wineServerName];

    //write out bash scripts to launch wine
    [wineStagingBash       writeToFile:[NSString stringWithFormat:@"%@/wine-preloader",pathToWineBinFolder]       atomically:YES encoding:NSUTF8StringEncoding];
    [wineServerBash writeToFile:[NSString stringWithFormat:@"%@/wineserver",pathToWineBinFolder] atomically:YES encoding:NSUTF8StringEncoding];
    
    [NSTask runProgram:@"chmod" withFlags:@[@"-R",@"777",pathToWineBinFolder]];
}

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
    NSString* dyldFallbackLibraryPath = @"DYLD_FALLBACK_LIBRARY_PATH=\"${WINESKIN_LIB_PATH_FOR_FALLBACK}\"";
    
    NSString *wineStagingBash = [NSString stringWithFormat:@"%@ %@ \"%@\" \"$@\"",
                                 binBash,dyldFallbackLibraryPath,wineStagingName];
    NSString *wineStaging64Bash = [NSString stringWithFormat:@"%@ %@ \"%@\" \"$@\"",
                                 binBash,dyldFallbackLibraryPath,wineStaging64Name];
    NSString *wineServerBash = [NSString stringWithFormat:@"%@ %@ \"%@\" \"$@\"",
                                binBash,dyldFallbackLibraryPath,wineServerName];
    
    
    [wineStagingBash       writeToFile:[NSString stringWithFormat:@"%@/wine-preloader",pathToWineBinFolder]       atomically:YES encoding:NSUTF8StringEncoding];
    [wineStaging64Bash       writeToFile:[NSString stringWithFormat:@"%@/wine64-preloader",pathToWineBinFolder]       atomically:YES encoding:NSUTF8StringEncoding];
    [wineServerBash writeToFile:[NSString stringWithFormat:@"%@/wineserver",pathToWineBinFolder] atomically:YES encoding:NSUTF8StringEncoding];
    
    [NSTask runProgram:@"chmod" withFlags:@[@"-R",@"777",pathToWineBinFolder]];
}

// Renaming can only apply to wine-preloader/wine64-preloader
- (void)fixWine32on64ExecutableNames
{
    BOOL fixWine=YES;
    NSString *oldWineStagingName = nil;
    NSString *oldWine32on64Name = nil;
    NSString *oldWineServerName = nil;
    NSString *pathToWineBinFolder = [NSString stringWithFormat:@"%@/wswine.bundle/bin",frameworksFold];
    NSArray *engineBinContents = [fm contentsOfDirectoryAtPath:pathToWineBinFolder];
    for (NSString *item in engineBinContents)
    {
        if ([item hasSuffix:@"Wine-preloader"])
        {
            oldWineStagingName = [NSString stringWithFormat:@"%@",item];
        }
        if ([item hasSuffix:@"Wine32on64-preloader"])
        {
            oldWine32on64Name = [NSString stringWithFormat:@"%@",item];
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
    if (oldWine32on64Name == nil)
    {
        oldWine32on64Name=@"wine32on64-preloader";
    }
    if (oldWineServerName == nil)
    {
        oldWineServerName=@"wineserver";
    }
    if ([oldWineStagingName hasPrefix:appName] && [oldWine32on64Name hasPrefix:appName] && [oldWineServerName hasPrefix:appName])
    {
        fixWine=NO;
        wineStagingName = [NSString stringWithFormat:@"%@",oldWineStagingName];
        wine32on64Name = [NSString stringWithFormat:@"%@",oldWine32on64Name];
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
    wine32on64Name = [NSString stringWithFormat:@"%@%dWine32on64-preloader",appName,bundleRandomInt1];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineStagingName]];
    [fm moveItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,oldWineStagingName]
                toPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineStagingName]];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wine32on64Name]];
    [fm moveItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,oldWine32on64Name]
                toPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wine32on64Name]];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineServerName]];
    [fm moveItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,oldWineServerName]
                toPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineServerName]];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/wine-preloader",pathToWineBinFolder]];
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/wine32on64-preloader",pathToWineBinFolder]];
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/wineserver",pathToWineBinFolder]];
    
    NSString* binBash = @"#!/bin/bash\n";
    NSString* dyldFallbackLibraryPath = @"DYLD_FALLBACK_LIBRARY_PATH=\"${WINESKIN_LIB_PATH_FOR_FALLBACK}\"";
    
    NSString *wineStagingBash = [NSString stringWithFormat:@"%@ %@ \"%@\" \"$@\"",
                                 binBash,dyldFallbackLibraryPath,wineStagingName];
    NSString *wine32on64Bash = [NSString stringWithFormat:@"%@ %@ \"%@\" \"$@\"",
                                 binBash,dyldFallbackLibraryPath,wine32on64Name];
    
    NSString *wineServerBash = [NSString stringWithFormat:@"%@ %@ \"%@\" \"$@\"",
                                binBash,dyldFallbackLibraryPath,wineServerName];
    
    
    [wineStagingBash       writeToFile:[NSString stringWithFormat:@"%@/wine-preloader",pathToWineBinFolder]       atomically:YES encoding:NSUTF8StringEncoding];
    [wine32on64Bash       writeToFile:[NSString stringWithFormat:@"%@/wine32on64-preloader",pathToWineBinFolder]       atomically:YES encoding:NSUTF8StringEncoding];
    [wineServerBash writeToFile:[NSString stringWithFormat:@"%@/wineserver",pathToWineBinFolder] atomically:YES encoding:NSUTF8StringEncoding];
    
    [NSTask runProgram:@"chmod" withFlags:@[@"-R",@"777",pathToWineBinFolder]];
}

// Renaming can only apply to wine-preloader/wine64-preloader
- (void)fixWine32on64_64BitExecutableNames
{
    BOOL fixWine=YES;
    NSString *oldWineStagingName = nil;
    NSString *oldWine32on64Name = nil;
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
        if ([item hasSuffix:@"Wine32on64-preloader"])
        {
            oldWine32on64Name = [NSString stringWithFormat:@"%@",item];
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
    if (oldWine32on64Name == nil)
    {
        oldWine32on64Name=@"wine32on64-preloader";
    }
    if (oldWineStaging64Name == nil)
    {
        oldWineStaging64Name=@"wine64-preloader";
    }
    if (oldWineServerName == nil)
    {
        oldWineServerName=@"wineserver";
    }
    if ([oldWineStagingName hasPrefix:appName] && [oldWine32on64Name hasPrefix:appName] && [oldWineStaging64Name hasPrefix:appName] && [oldWineServerName hasPrefix:appName])
    {
        fixWine=NO;
        wineStagingName = [NSString stringWithFormat:@"%@",oldWineStagingName];
        wine32on64Name = [NSString stringWithFormat:@"%@",oldWine32on64Name];
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
    wine32on64Name = [NSString stringWithFormat:@"%@%dWine32on64-preloader",appName,bundleRandomInt1];
    wineStaging64Name = [NSString stringWithFormat:@"%@%dWine64-preloader",appName,bundleRandomInt1];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineStagingName]];
    [fm moveItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,oldWineStagingName]
                toPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineStagingName]];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wine32on64Name]];
    [fm moveItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,oldWine32on64Name]
                toPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wine32on64Name]];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineStaging64Name]];
    [fm moveItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,oldWineStaging64Name]
                toPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineStaging64Name]];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineServerName]];
    [fm moveItemAtPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,oldWineServerName]
                toPath:[NSString stringWithFormat:@"%@/%@",pathToWineBinFolder,wineServerName]];
    
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/wine-preloader",pathToWineBinFolder]];
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/wine32on64-preloader",pathToWineBinFolder]];
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/wine64-preloader",pathToWineBinFolder]];
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/wineserver",pathToWineBinFolder]];
    
    NSString* binBash = @"#!/bin/bash\n";
    NSString* dyldFallbackLibraryPath = @"DYLD_FALLBACK_LIBRARY_PATH=\"${WINESKIN_LIB_PATH_FOR_FALLBACK}\"";
    
    NSString *wineStagingBash = [NSString stringWithFormat:@"%@ %@ \"%@\" \"$@\"",
                                 binBash,dyldFallbackLibraryPath,wineStagingName];
    NSString *wine32on64Bash = [NSString stringWithFormat:@"%@ %@ \"%@\" \"$@\"",
                                 binBash,dyldFallbackLibraryPath,wine32on64Name];
    NSString *wineStaging64Bash = [NSString stringWithFormat:@"%@ %@ \"%@\" \"$@\"",
                                 binBash,dyldFallbackLibraryPath,wineStaging64Name];
    NSString *wineServerBash = [NSString stringWithFormat:@"%@ %@ \"%@\" \"$@\"",
                                binBash,dyldFallbackLibraryPath,wineServerName];
    
    
    [wineStagingBash       writeToFile:[NSString stringWithFormat:@"%@/wine-preloader",pathToWineBinFolder]       atomically:YES encoding:NSUTF8StringEncoding];
    [wine32on64Bash       writeToFile:[NSString stringWithFormat:@"%@/wine32on64-preloader",pathToWineBinFolder]       atomically:YES encoding:NSUTF8StringEncoding];
    [wineStaging64Bash       writeToFile:[NSString stringWithFormat:@"%@/wine64-preloader",pathToWineBinFolder]       atomically:YES encoding:NSUTF8StringEncoding];
    [wineServerBash writeToFile:[NSString stringWithFormat:@"%@/wineserver",pathToWineBinFolder] atomically:YES encoding:NSUTF8StringEncoding];
    
    [NSTask runProgram:@"chmod" withFlags:@[@"-R",@"777",pathToWineBinFolder]];
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
        NSArray *resultArray = [[self system:@"ps -eo pcpu,pid,args | grep \"wineboot.exe --init\""] componentsSeparatedByString:@" "];
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
            [NSTask runProgram:@"chmod" withFlags:@[@"-R",@"700",[NSString stringWithFormat:@"/tmp/.wine-%@",uid]]];
        }
        
        if ([wineStartInfo isNonStandardRun])
        {
            [self setToNoVirtualDesktop];
            NSString *wineDebugLine = @"err-all,warn-all,fixme-all,trace-all";
            
            //remove the .update-timestamp file
            [fm removeItemAtPath:[NSString stringWithFormat:@"%@/.update-timestamp",winePrefix]];
            
            //calling wineboot is a simple builtin refresh that needs to NOT prompt for gecko
            NSString *mshtmlValue;
            if ([wssCommand isEqualToString:@"WSS-wineboot"] || [[self.portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_DISABLE_MONO_GECKO] intValue] == 1 )
            {
                mshtmlValue = @"mscoree,mshtml=";
            }
            else
            {
                //disable mono since its useless anyway
                mshtmlValue = @"mscoree=";
            }
            
            //launch monitor thread for killing stuck wineboots (work-a-round Macdriver bug for 1.5.28)
            [NSThread detachNewThreadSelector:@selector(wineBootStuckProcess) toTarget:self withObject:nil];
            [NSTask runAsynchronousProgram:[NSString stringWithFormat:@"%@/wswine.bundle/bin/%@",frameworksFold,wineExecutable]
                                 withFlags:@[@"wineboot"]
                           withEnvironment:@{@"WINEDLLOVERRIDES":mshtmlValue,
                                             @"WINESKIN_LIB_PATH_FOR_FALLBACK":dyldFallBackLibraryPath,
                                             @"WINEDEBUG":wineDebugLine,
                                             @"PATH":[NSString stringWithFormat:@"%@/wswine.bundle/bin:%@/wstools.bundle/bin:$PATH:/opt/local/bin:/opt/local/sbin",frameworksFold,frameworksFold],
                                             @"DISPLAY":theDisplayNumber,
                                             @"WINEPREFIX":winePrefix,
                                             @"FREETYPE_PROPERTIES":@"truetype:interpreter-version=35",
                                             @"DYLD_FALLBACK_LIBRARY_PATH":dyldFallBackLibraryPath
                                             }];
            usleep(3000000);
            
            if ([wssCommand isEqualToString:@"WSS-wineprefixcreate"]) //only runs on build new wrapper, and rebuild
            {
                //make sure windows/profiles is using users folder
                NSString* profilesFolderPath = [NSString stringWithFormat:@"%@/drive_c/windows/profiles",winePrefix];
                [fm removeItemAtPath:profilesFolderPath];
                [fm createSymbolicLinkAtPath:profilesFolderPath withDestinationPath:@"../users" error:nil];
                [NSTask runProgram:@"chmod" withFlags:@[@"-h",@"777",profilesFolderPath]];
                
                //rename new user folder to Wineskin and make symlinks
                NSString* usersUserFolderPath = [NSString stringWithFormat:@"%@/drive_c/users/%@",winePrefix,NSUserName()];
                NSString* usersWineskinFolderPath = [NSString stringWithFormat:@"%@/drive_c/users/Wineskin",winePrefix];
                NSString* usersCrossOverFolderPath = [NSString stringWithFormat:@"%@/drive_c/users/crossover",winePrefix];
                
                if ([fm fileExistsAtPath:usersUserFolderPath])
                {
                    [fm moveItemAtPath:usersUserFolderPath toPath:usersWineskinFolderPath];
                    [fm createSymbolicLinkAtPath:usersUserFolderPath withDestinationPath:@"Wineskin" error:nil];
                    [NSTask runProgram:@"chmod" withFlags:@[@"-h",@"777",usersUserFolderPath]];
                }
                else if ([fm fileExistsAtPath:usersCrossOverFolderPath])
                {
                    [fm moveItemAtPath:usersCrossOverFolderPath toPath:usersWineskinFolderPath];
                    [fm createSymbolicLinkAtPath:usersCrossOverFolderPath withDestinationPath:@"Wineskin" error:nil];
                    [NSTask runProgram:@"chmod" withFlags:@[@"-h",@"777",usersCrossOverFolderPath]];
                }
                else //this shouldn't ever happen.. but what the heck
                {
                    [fm createDirectoryAtPath:usersWineskinFolderPath withIntermediateDirectories:YES];
                    [fm createSymbolicLinkAtPath:usersUserFolderPath withDestinationPath:@"Wineskin" error:nil];
                    [NSTask runProgram:@"chmod" withFlags:@[@"-h",@"777",usersUserFolderPath]];
                }

                //load Wineskin default reg entries
                NSString* pathEnv = [@[[NSString stringWithFormat:@"%@/wswine.bundle/bin",frameworksFold],
                                       [NSString stringWithFormat:@"%@/wstools.bundle/bin",frameworksFold],
                                       @"$PATH",@"/opt/local/bin",@"/opt/local/sbin"] componentsJoinedByString:@":"];
                NSString* remakedefaultsReg = [NSString stringWithFormat:@"%@/../Wineskin.app/Contents/Resources/remakedefaults.reg",contentsFold];
                [NSTask runAsynchronousProgram:[NSString stringWithFormat:@"%@/wswine.bundle/bin/%@",frameworksFold,wineExecutable]
                                     withFlags:@[@"regedit",remakedefaultsReg]
                               withEnvironment:@{@"WINESKIN_LIB_PATH_FOR_FALLBACK":dyldFallBackLibraryPath,
                                                 @"WINEDEBUG":wineDebugLine,
                                                 @"PATH":pathEnv,
                                                 @"DISPLAY":theDisplayNumber,
                                                 @"WINEPREFIX":winePrefix,
                                                 @"DYLD_FALLBACK_LIBRARY_PATH":dyldFallBackLibraryPath
                                                 }];
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
            [NSTask runProgram:@"chmod" withFlags:@[@"666",userRegPath]];
            
            
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
            [NSTask runProgram:@"chmod" withFlags:@[@"777",contentsFold]];
            [NSTask runProgram:@"chmod" withFlags:@[@"777",winePrefix]];
            [NSTask runProgram:@"chmod" withFlags:@[@"777",frameworksFold]];
            [NSTask runProgram:@"chmod" withFlags:@[@"777",[NSString stringWithFormat:@"%@/wswine.bundle",frameworksFold]]];
            [NSTask runProgram:@"chmod" withFlags:@[@"-R",@"777",[NSString stringWithFormat:@"%@/drive_c",winePrefix]]];
            NSArray *tmpy2 = [fm contentsOfDirectoryAtPath:winePrefix];
            for (NSString *item in tmpy2)
            {
                [NSTask runProgram:@"chmod" withFlags:@[@"777",[NSString stringWithFormat:@"%@/%@",winePrefix,item]]];
            }
            NSString* dosdevicesPath = [NSString stringWithFormat:@"%@/dosdevices",winePrefix];
            NSArray *tmpy3 = [fm contentsOfDirectoryAtPath:dosdevicesPath];
            for (NSString *item in tmpy3)
            {
                [NSTask runProgram:@"chmod" withFlags:@[@"-h",@"777",[NSString stringWithFormat:@"%@/%@",dosdevicesPath,item]]];
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
                wineDebugLine = @"err+all,warn-all,fixme+all,trace-all,fixme-esync";
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
                //TODO: change to using NSTask check runProgram in ObjectiveC_Extension.framework
                [self system:[NSString stringWithFormat:@"export WINESKIN_LIB_PATH_FOR_FALLBACK=\"%@\";export WINEDEBUG=%@;cd \"%@/\";export PATH=\"$PWD:%@/wswine.bundle/bin:$PATH:%@/wstools.bundle/bin:/opt/local/bin:/opt/local/sbin\";export DISPLAY=%@;export WINEPREFIX=\"%@\";export FREETYPE_PROPERTIES=\"truetype:interpreter-version=35\";DYLD_FALLBACK_LIBRARY_PATH=\"%@\" winetricks --no-isolate %@ > \"%@/Logs/WinetricksTemp.log\"",dyldFallBackLibraryPath,wineDebugLine,winePrefix,frameworksFold,frameworksFold,theDisplayNumber,winePrefix,dyldFallBackLibraryPath,[winetricksCommands componentsJoinedByString:@" "],winePrefix]];
            }
            else
            {
                //TODO: change to using NSTask check runProgram in ObjectiveC_Extension.framework
                [self system:[NSString stringWithFormat:@"export WINESKIN_LIB_PATH_FOR_FALLBACK=\"%@\";export WINEDEBUG=%@;cd \"%@/\";export PATH=\"$PWD:%@/wswine.bundle/bin:$PATH:%@/wstools.bundle/bin:/opt/local/bin:/opt/local/sbin\";export DISPLAY=%@;export WINEPREFIX=\"%@\";export FREETYPE_PROPERTIES=\"truetype:interpreter-version=35\";%@DYLD_FALLBACK_LIBRARY_PATH=\"%@\" winetricks %@ --no-isolate \"%@\" > \"%@/Logs/Winetricks.log\" 2>&1",dyldFallBackLibraryPath,wineDebugLine,winePrefix,frameworksFold,frameworksFold,theDisplayNumber,winePrefix,[wineStartInfo getCliCustomCommands],dyldFallBackLibraryPath,silentMode,[winetricksCommands componentsJoinedByString:@"\" \""],winePrefix]];
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
                        @"/usr/X11/lib/X11/fonts",@"/usr/X11R6/lib/X11/fonts"];
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

                if ([item hasPrefix:@"/"])
                {
                    // TODO: [wineStartInfo getULimitNumber]
                    // TODO: [wineStartInfo getCliCustomCommands] being ignored
                    // TODO: wineLogFileLocal being ignored
                    [NSTask runAsynchronousProgram:[NSString stringWithFormat:@"%@/wswine.bundle/bin/%@",frameworksFold,wineExecutable]
                                         withFlags:@[@"start",@"/unix",item]
                                         atRunPath:[NSString stringWithFormat:@"%@/wswine.bundle/bin",frameworksFold]
                                   withEnvironment:@{@"WINESKIN_LIB_PATH_FOR_FALLBACK":dyldFallBackLibraryPath,
                                                     @"WINEDEBUG":wineDebugLine,
                                                     @"PATH":[NSString stringWithFormat:@"%@/wswine.bundle/bin:%@/wstools.bundle/bin:$PATH:/opt/local/bin:/opt/local/sbin",frameworksFold,frameworksFold],
                                                     @"DISPLAY":theDisplayNumber,
                                                     @"WINEPREFIX":winePrefix,
                                                     @"FREETYPE_PROPERTIES":@"truetype:interpreter-version=35",
                                                     @"DYLD_FALLBACK_LIBRARY_PATH":dyldFallBackLibraryPath
                                                     }];
                }
                else
                {
                    // TODO: [wineStartInfo getULimitNumber]
                    // TODO: [wineStartInfo getCliCustomCommands] being ignored
                    // TODO: wineLogFileLocal being ignored
                    [NSTask runAsynchronousProgram:[NSString stringWithFormat:@"%@/wswine.bundle/bin/%@",frameworksFold,wineExecutable]
                                         withFlags:@[@"start",item] atRunPath:[wineStartInfo getWineRunLocation]
                                   withEnvironment:@{@"WINESKIN_LIB_PATH_FOR_FALLBACK":dyldFallBackLibraryPath,
                                                     @"WINEDEBUG":wineDebugLine,
                                                     @"PATH":[NSString stringWithFormat:@"%@/wswine.bundle/bin:%@/wstools.bundle/bin:$PATH:/opt/local/bin:/opt/local/sbin",frameworksFold,frameworksFold],
                                                     @"DISPLAY":theDisplayNumber,
                                                     @"WINEPREFIX":winePrefix,
                                                     @"FREETYPE_PROPERTIES":@"truetype:interpreter-version=35",
                                                     @"DYLD_FALLBACK_LIBRARY_PATH":dyldFallBackLibraryPath
                                                     }];
                }
            }
        }
        else
        {
            //launch Wine normally
            // TODO: [wineStartInfo getCliCustomCommands] being ignored
            // TODO: wineLogFileLocal being ignored
            NSMutableArray* flags = [[startExeLine.trim componentsSeparatedByString:@" "] mutableCopy];
            [flags addObject:[wineStartInfo getWineRunFile]];
            [flags addObject:[wineStartInfo getProgramFlags]];
            [NSTask runAsynchronousProgram:[NSString stringWithFormat:@"%@/wswine.bundle/bin/%@",frameworksFold,wineExecutable]
                                 withFlags:flags atRunPath:[wineStartInfo getWineRunLocation]
                           withEnvironment:@{@"WINESKIN_LIB_PATH_FOR_FALLBACK":dyldFallBackLibraryPath,
                                             @"WINEDEBUG":wineDebugLine,
                                             @"PATH":[NSString stringWithFormat:@"%@/wswine.bundle/bin:%@/wstools.bundle/bin:$PATH:/opt/local/bin:/opt/local/sbin",frameworksFold,frameworksFold],
                                             @"DISPLAY":theDisplayNumber,
                                             @"WINEPREFIX":winePrefix,
                                             @"FREETYPE_PROPERTIES":@"truetype:interpreter-version=35",
                                             @"DYLD_FALLBACK_LIBRARY_PATH":dyldFallBackLibraryPath
                                             }];
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
        [self system:[NSString stringWithFormat:@"> \"%@\"",timeStampFile]];
        [self system:[NSString stringWithFormat:@"> \"%@\"",wineTempLogFile]];
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
            if ([self system:timestampChecker])
            {
				NSArray *tempArray = [self readFileToStringArray:wineLogFile];
				[self system:[NSString stringWithFormat:@"> \"%@\"",wineLogFile]];
                [self system:[NSString stringWithFormat:@"> \"%@\"",timeStampFile]];
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
        [fm removeItemAtPath:[NSString stringWithFormat:@"%@/Winetricks.log",winePrefix]];
        [fm removeItemAtPath:[NSString stringWithFormat:@"%@/Logs/Winetricks.log",winePrefix]];
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Logs/WinetricksTemp.log",winePrefix]];
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
		[NSTask runProgram:@"chmod" withFlags:@[@"-h",@"777",[NSString stringWithFormat:@"%@/dosdevices/%@",winePrefix,item]]];
    }
    
    for (NSString* regFile in @[USERDEF_REG, SYSTEM_REG, USER_REG])
    {
        [NSTask runProgram:@"chmod" withFlags:@[@"666",[NSString stringWithFormat:@"%@/%@.reg",winePrefix,regFile]]];
    }
	
    [NSTask runProgram:@"chmod" withFlags:@[@"666",[NSString stringWithFormat:@"%@/Info.plist",contentsFold]]];
    [NSTask runProgram:@"chmod" withFlags:@[@"-R",@"777",[NSString stringWithFormat:@"%@/drive_c",winePrefix]]];
    
    //get rid of the preference file
    [fm removeItemAtPath:lockfile];
    [fm removeItemAtPath:tmpFolder];
    
    //kill wine processes
    NSArray* command = @[
                         [NSString stringWithFormat:@"export PATH=\"%@/wswine.bundle/bin:$PATH:/opt/local/bin:/opt/local/sbin\";",frameworksFold],
                         [NSString stringWithFormat:@"export WINEPREFIX=\"%@\";",winePrefix],@"wineserver -k"];
    [self system:[command componentsJoinedByString:@" "]];
    usleep(3000000);
    
    //kill XQuartz processes
    [self system:[NSString stringWithFormat:@"killall -9 \"XQuartz\" > /dev/null 2>&1"]];
    [self system:[NSString stringWithFormat:@"killall -9 \"Xquartz\" > /dev/null 2>&1"]];
    [self system:[NSString stringWithFormat:@"killall -9 \"xinit\" > /dev/null 2>&1"]];

    //get rid of OS X saved state file
    [fm removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Saved Application State/com.%@%@.wineskin.savedState",NSHomeDirectory(),[[NSNumber numberWithLong:bundleRandomInt1] stringValue],[[NSNumber numberWithLong:bundleRandomInt2] stringValue]]];
    
    //attempt to clear out any stuck processes in launchd for the wrapper
    //this may prevent -10810 errors on next launch with 10.9, and *shouldn't* hurt anything.
    NSArray *results = [[self system:[NSString stringWithFormat:@"launchctl list | grep \"%@\"",appName]] componentsSeparatedByString:@"\n"];
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
            [self system:[NSString stringWithFormat:@"launchctl remove \"%@\"",entryToRemove]];
        }
    }
    //fix permissions before closing
    [self fixWinePrefixForCurrentUser];
    [fm removeItemAtPath:tmpwineFolder];
    [NSApp terminate:nil];
}
@end
