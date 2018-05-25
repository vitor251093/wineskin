//
//  WineskinAppDelegate.m
//  Wineskin
//
//  Copyright 2011-2013 by The Wineskin Project and Urge Software LLC All rights reserved.
//  Licensed for use under the LGPL <http://www.gnu.org/licenses/lgpl-2.1.txt>
//

#import "WineskinAppDelegate.h"

#import "NSData+Extension.h"
#import "NSAlert+Extension.h"
#import "NSImage+Extension.h"
#import "NSString+Extension.h"
#import "NSSavePanel+Extension.h"
#import "NSFileManager+Extension.h"
#import "NSMutableDictionary+Extension.h"

#import "NSPathUtilities.h"
#import "NSExeSelection.h"
#import "NSPortDataLoader.h"
#import "NSWineskinEngine.h"
#import "NSWineskinPortDataWriter.h"
#import "NSComputerInformation.h"

#define WINETRICK_NAME        @"WS-Name"
#define WINETRICK_DESCRIPTION @"WS-Description"
#define WINETRICK_INSTALLED   @"WS-Installed"
#define WINETRICK_CACHED      @"WS-Cached"

NSFileManager *fm;
@implementation WineskinAppDelegate

@synthesize window;
@synthesize winetricksList, winetricksFilteredList, winetricksSelectedList, winetricksInstalledList, winetricksCachedList;

-(NSString*)wrapperPath
{
    return [[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent];
}
-(NSString*)cDrivePathForWrapper
{
    return [NSPathUtilities getMacPathForWindowsDrive:'c' ofWrapper:self.wrapperPath];
}
-(NSString*)wswineBundlePath
{
    return [NSString stringWithFormat:@"%@/Contents/Frameworks/wswine.bundle",self.wrapperPath];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    fm = [NSFileManager defaultManager];
    portManager = [NSPortManager managerWithPath:self.wrapperPath];
    if (!portManager)
    {
        [NSApp terminate:nil];
    }
    
	[self setWinetricksCachedList:[NSArray array]];
	[self setWinetricksInstalledList:[NSArray array]];
	[self setWinetricksSelectedList:[NSMutableDictionary dictionary]];
	[self setWinetricksList:[NSDictionary dictionary]];
	[self setWinetricksFilteredList:[self winetricksList]];
    
	[waitWheel startAnimation:self];
	[busyWindow makeKeyAndOrderFront:self];
	shPIDs = [[NSMutableArray alloc] init];
	[winetricksCancelButton setEnabled:NO];
	[winetricksCancelButton setHidden:YES];
	disableButtonCounter=0;
	disableXButton=NO;
	usingAdvancedWindow=NO;
    
	//clear out cells in Screen Options, They need to be blank but IB likes putting them back to defaults by just opening it and resaving
	[self installEngine];
	[self loadAllData];
	[self loadScreenOptionsData];
    
	NSImage *theImage = [[NSImage alloc] initByReferencingFile:[NSString stringWithFormat:@"%@/Contents/Resources/Wineskin.icns",self.wrapperPath]];
	[iconImageView setImage:theImage];
    
	[window makeKeyAndOrderFront:self];
	[busyWindow orderOut:self];
    
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"]]];
}
- (void)sleepWithRunLoopForSeconds:(NSInteger)seconds
{
	// Sleep while still running the run loop
	if (![[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:seconds]])
		sleep(seconds); // Fallback, should never happen
}
- (void)setButtonsState:(BOOL)state
{
    [windowsExeTextField setEnabled:state];
    [exeBrowseButton setEnabled:state];
    [customCommandsTextField setEnabled:state];
    [menubarNameTextField setEnabled:state];
    [versionTextField setEnabled:state];
    [wineDebugTextField setEnabled:state];
    [extPopUpButton setEnabled:state];
    [extEditButton setEnabled:state];
    [extPlusButton setEnabled:state];
    [extMinusButton setEnabled:state];
    [iconImageView setEditable:state];
    [iconBrowseButton setEnabled:state];
    [advancedInstallSoftwareButton setEnabled:state];
    [advancedSetScreenOptionsButton setEnabled:state];
    [testRunButton setEnabled:state];
    [winetricksButton setEnabled:state];
    [customExeButton setEnabled:state];
    [refreshWrapperButton setEnabled:state];
    [rebuildWrapperButton setEnabled:state];
    [updateWrapperButton setEnabled:state];
    [changeEngineButton setEnabled:state];
    [alwaysMakeLogFilesCheckBoxButton setEnabled:state];
    [setMaxFilesCheckBoxButton setEnabled:state];
    [optSendsAltCheckBoxButton setEnabled:state];
    [emulateThreeButtonMouseCheckBoxButton setEnabled:state];
    [mapUserFoldersCheckBoxButton setEnabled:state];
    [modifyMappingsButton setEnabled:state];
    [confirmQuitCheckBoxButton setEnabled:state];
    [focusFollowsMouseCheckBoxButton setEnabled:state];
    [WinetricksNoLogsButton setEnabled:state];
    [disableCPUsCheckBoxButton setEnabled:state];

    //Use System XQuartz and ForceQuartzWM disabled unless XQuartz is installed
    if ([NSComputerInformation isSystemMacOsEqualOrSuperiorTo:@"10.8"] && ![fm fileExistsAtPath:@"/Applications/Utilities/XQuartz.app/Contents/MacOS/X11.bin"])
    {
        [forceSystemXQuartzButton setEnabled:NO];
        [forceWrapperQuartzWMButton setEnabled:NO];
    }
    else
    {
        [forceSystemXQuartzButton setEnabled:state];
        [forceWrapperQuartzWMButton setEnabled:state];
    }
    
    // TODO: The code below seems to be causing a crash sometimes. Remove?
    if (state) {
        [toolRunningPI stopAnimation:self];
    }
    else {
        [toolRunningPI startAnimation:self];
    }
    
    [toolRunningPIText setHidden:state];
    disableXButton = !state;
}
- (void)enableButtons
{
	disableButtonCounter--;
    if (disableButtonCounter >= 1) return;
    [self setButtonsState:YES];
}
- (void)disableButtons
{
	[self setButtonsState:NO];
	disableButtonCounter++;
}
- (void)systemCommand:(NSString *)commandToRun withArgs:(NSArray *)args
{
	[[NSTask launchedTaskWithLaunchPath:commandToRun arguments:args] waitUntilExit];
}
- (NSString *)systemCommandWithOutputReturned:(NSString *)command
{
	FILE *fp;
	char buff[512];
	NSString *returnString = @"";
	fp = popen([command cStringUsingEncoding:NSUTF8StringEncoding], "r");
	while (fgets( buff, sizeof buff, fp))
		returnString = [NSString stringWithFormat:@"%@%@",returnString,[NSString stringWithCString:buff encoding:NSUTF8StringEncoding]];
	pclose(fp);
	//cut out trailing new line
	if ([returnString hasSuffix:@"\n"])
		returnString = [returnString substringToIndex:[returnString rangeOfString:@"\n" options:NSBackwardsSearch].location];
	return returnString;
}
- (IBAction)topMenuHelpSelected:(id)sender
{
	[helpWindow makeKeyAndOrderFront:self];
}
- (IBAction)aboutWindow:(id)sender
{
	[aboutWindowVersionNumber setStringValue:WINESKIN_VERSION];
	[aboutWindow makeKeyAndOrderFront:self];
}

//*************************************************************
//******************** Main Menu Methods **********************
//*************************************************************
- (NSArray*)runnableSubpathsInWrapperCDrive
{
    NSArray *filesTEMP1 = [fm subpathsOfDirectoryAtPath:self.cDrivePathForWrapper error:nil];
    NSMutableArray *files1 = [[NSMutableArray alloc] init];
    for (NSString *item in filesTEMP1)
    {
        if ([[item lowercaseString] hasSuffix:@".exe"] || [[item lowercaseString] hasSuffix:@".bat"] ||
            [[item lowercaseString] hasSuffix:@".msi"])
        {
            [files1 addObject:item];
        }
    }
    
    return files1;
}
- (IBAction)wineskinWebsiteButtonPressed:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://wineskin.urgesoftware.com/"]];
}
- (IBAction)installWindowsSoftwareButtonPressed:(id)sender
{
	[window orderOut:self];
	[advancedWindow orderOut:self];
	[installerWindow makeKeyAndOrderFront:self];
}
- (IBAction)chooseSetupExecutableButtonPressed:(id)sender
{
	// have user choose install program
	//NSOpenPanel *panel = [NSOpenPanel openPanel];
	NSOpenPanel *panel = [[NSOpenPanel alloc] init];
	[panel setWindowTitle:NSLocalizedString(@"Please choose the install program",nil)];
	[panel setPrompt:NSLocalizedString(@"Choose",nil)];
	[panel setCanChooseDirectories:NO];
	[panel setCanChooseFiles:YES];
	[panel setAllowsMultipleSelection:NO];
    [panel setInitialDirectory:@"/"];
    [panel setAllowedFileTypes:EXTENSIONS_COMPATIBLE_WITH_WINESKIN_WRAPPER];
	
	if ([panel runModal] == 0)
	{
		return;
	}
    
    NSString* selectedInstaller = [[[panel URLs] objectAtIndex:0] path];
    
	//show busy window
	[busyWindow makeKeyAndOrderFront:self];
	// get rid of main window
	[installerWindow orderOut:self];
	[advancedWindow orderOut:self];
    
	NSString* wrapperPath = self.wrapperPath;
    
    //make 1st array of .exe, .msi, and .bat files
    NSArray *files1 = self.runnableSubpathsInWrapperCDrive;
    
	//run install in Wine
	[self systemCommand:[NSPathUtilities wineskinLauncherBinForPortAtPath:wrapperPath] withArgs:@[@"WSS-installer",selectedInstaller]];
    
	//make 2nd array of .exe, .msi, and .bat files
	NSArray *files2 = self.runnableSubpathsInWrapperCDrive;
    
	NSMutableArray *finalList = [[NSMutableArray alloc] init];
	//fill new array of new .exe, .msi, and .bat files
	for (NSString *item2 in files2)
	{
        if (![files1 containsObject:item2])
        {
			if (![item2 hasPrefix:@"users/Wineskin"] && ![item2 hasPrefix:@"windows/Installer"] && ![item2 isEqualToString:@"nothing.exe"])
            {
                [finalList addObject:[NSString stringWithFormat:@"\"C:/%@\"",item2]];
            }
        }
	}
	
	//display warning if final array is 0 length and exit method
	if (finalList.count == 0)
	{
        [NSAlert showAlertOfType:NSAlertTypeWarning withMessage:@"No new executables found!\n\nMaybe the installer failed...?\n\nIf you tried to install somewhere other than C: drive (drive_c in the wrapper) then you will get this message too.  All software must be installed in C: drive."];
        
		[installerWindow makeKeyAndOrderFront:self];
		return;
	}
    
	// populate choose exe list
	[exeChoicePopUp removeAllItems];
	for (NSString *item in finalList)
    {
		[exeChoicePopUp addItemWithTitle:item];
    }
	//if set EXE is not located inside of the wrapper,show choose exe window
    NSString* mainExeWindowsPath = [NSString stringWithFormat:@"C:%@",[portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH]];
    NSString* mainExePath = [NSPathUtilities getMacPathForWindowsPath:mainExeWindowsPath ofWrapper:wrapperPath];
    
	if ([fm fileExistsAtPath:mainExePath])
	{
		if (usingAdvancedWindow)
        {
			[advancedWindow makeKeyAndOrderFront:self];
        }
		else
        {
			[window makeKeyAndOrderFront:self];
        }
	}
	else
    {
		[chooseExeWindow makeKeyAndOrderFront:self];
    }
    
	//close busy window
	[busyWindow orderOut:self];
}
- (IBAction)copyAFolderInsideButtonPressed:(id)sender
{
	[self copyFolderRemovingOriginal:NO];
}
- (IBAction)moveAFolderInsideButtonPressed:(id)sender
{
	[self copyFolderRemovingOriginal:YES];
}
- (void)copyFolderRemovingOriginal:(BOOL)removeOriginal
{
	NSOpenPanel *panel = [[NSOpenPanel alloc] init];
	if (removeOriginal)
		[panel setWindowTitle:NSLocalizedString(@"Please choose the Folder to MOVE in",nil)];
	else
        [panel setWindowTitle:NSLocalizedString(@"Please choose the Folder to COPY in",nil)];
	[panel setPrompt:NSLocalizedString(@"Choose",nil)];
	[panel setCanChooseDirectories:YES];
	[panel setCanChooseFiles:NO];
	[panel setAllowsMultipleSelection:NO];
    [panel setInitialDirectory:@"/"];
	
	if ([panel runModal] == 0)
	{
		return;
	}
    
	//show busy window
	[busyWindow makeKeyAndOrderFront:self];
	// get rid of installer window
	[installerWindow orderOut:self];
    
	//make 1st array of .exe, .msi, and .bat files
    NSArray *files1 = self.runnableSubpathsInWrapperCDrive;
	
	//copy or move the folder to Program Files
	NSString *theFileNamePath = [[[panel URLs] objectAtIndex:0] path];
	NSString *theFileName = [theFileNamePath substringFromIndex:[theFileNamePath rangeOfString:@"/" options:NSBackwardsSearch].location];
	BOOL success;
	if (removeOriginal)
    {
        success = [fm moveItemAtPath:theFileNamePath
                              toPath:[NSString stringWithFormat:@"%@Program Files%@",self.cDrivePathForWrapper,theFileName]];
    }
	else
    {
        success = [fm copyItemAtPath:theFileNamePath
                              toPath:[NSString stringWithFormat:@"%@Program Files%@",self.cDrivePathForWrapper,theFileName]];
    }
    
	if (!success)
	{
		[installerWindow makeKeyAndOrderFront:self];
		[busyWindow orderOut:self];
		return;
	}
    
	//make 2nd array of .exe, .msi, and .bat files
	NSArray *files2 = self.runnableSubpathsInWrapperCDrive;
	
    NSMutableArray *finalList = [[NSMutableArray alloc] init];
	//fill new array of new .exe, .msi, and .bat files
    for (NSString *item2 in files2)
    {
        if (![files1 containsObject:item2])
        {
            if (![item2 hasPrefix:@"users/Wineskin"] && ![item2 hasPrefix:@"windows/Installer"] && ![item2 isEqualToString:@"nothing.exe"])
            {
                [finalList addObject:[NSString stringWithFormat:@"\"C:/%@\"",item2]];
            }
        }
    }
    
	//display warning if final array is 0 length and exit method
	if (finalList.count == 0)
	{
		if (removeOriginal)
        {
            [NSAlert showAlertOfType:NSAlertTypeWarning
                         withMessage:@"No new executables found after moving the selected folder inside the wrapper!"];
        }
		else
        {
            [NSAlert showAlertOfType:NSAlertTypeWarning
                         withMessage:@"No new executables found after copying the selected folder inside the wrapper!"];
        }
		
		if (usingAdvancedWindow)
			[advancedWindow makeKeyAndOrderFront:self];
		else
			[window makeKeyAndOrderFront:self];
		[busyWindow orderOut:self];
		return;
	}
	// populate choose exe list
	[exeChoicePopUp removeAllItems];
	for (NSString *item in finalList)
		[exeChoicePopUp addItemWithTitle:item];
    
    NSString* mainExeWindowsPath = [NSString stringWithFormat:@"C:%@",[portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH]];
    NSString* mainExePath = [NSPathUtilities getMacPathForWindowsPath:mainExeWindowsPath ofWrapper:self.wrapperPath];
    
    if ([fm fileExistsAtPath:mainExePath])
	{
		if (usingAdvancedWindow)
			[advancedWindow makeKeyAndOrderFront:self];
		else
			[window makeKeyAndOrderFront:self];
	}
	else
		[chooseExeWindow makeKeyAndOrderFront:self];
	[busyWindow orderOut:self];
}
- (IBAction)installerCancelButtonPressed:(id)sender
{
	if (usingAdvancedWindow)
		[advancedWindow makeKeyAndOrderFront:self];
	else
		[window makeKeyAndOrderFront:self];
	[installerWindow orderOut:self];
}
- (IBAction)chooseExeOKButtonPressed:(id)sender
{
	//use standard entry from Config tab automatically.
	[self loadAllData];
	[windowsExeTextField setStringValue:[[exeChoicePopUp selectedItem] title]];
	[self saveAllData];
	//show main menu
	if (usingAdvancedWindow)
		[advancedWindow makeKeyAndOrderFront:self];
	else
		[window makeKeyAndOrderFront:self];
	[chooseExeWindow orderOut:self];
}
- (IBAction)setScreenOptionsPressed:(id)sender
{
	[self loadScreenOptionsData];
	[screenOptionsWindow makeKeyAndOrderFront:self];
	[window orderOut:self];
	[advancedWindow orderOut:self];
}
- (IBAction)advancedButtonPressed:(id)sender
{
	[self loadAllData];
	[advancedWindow makeKeyAndOrderFront:self];
	usingAdvancedWindow=YES;
	[window orderOut:self];
}


//*************************************************************
//************* Screen Options window methods *****************
//*************************************************************
-(NSString*)getResolutionStringWithValuesVirtualDesktop:(BOOL)virtualDesktop resolution:(NSString*)resolution
                                                 colors:(int)colors sleep:(int)sleep
{
    NSString* resolutionString = WINESKIN_WRAPPER_PLIST_VALUE_SCREEN_OPTIONS_NO_VIRTUAL_DESKTOP;
    
    if (virtualDesktop)
    {
        resolutionString = resolution;
    }
    
    return [NSString stringWithFormat:@"%@x%dsleep%d",resolutionString,colors,sleep];
}
- (void)saveScreenOptionsData
{
    if ([useX11RadioButton state])
    {
        int colorInt = [[[[colorDepth selectedItem] title] stringByReplacingOccurrencesOfString:@" bit" withString:@""] intValue];
        NSString* sleep = @"0";
        
        BOOL vd = ([windowModeVirtualDesktopRadioButton isEnabled] && [windowModeVirtualDesktopRadioButton state]);
        BOOL fullscreen = [virtualDesktopFullscreenRadioButton isEnabled] && [virtualDesktopFullscreenRadioButton intValue];
        NSString* resolution = [[virtualDesktopResolution selectedItem] title];
        
        [NSWineskinPortDataWriter setAutomaticScreenOptions:([defaultSettingsAutomaticRadioButton intValue] == 1)
                                                 fullscreen:fullscreen virtualDesktop:vd resolution:resolution colors:colorInt
                                                      sleep:sleep atPort:portManager];
        
        if ([defaultSettingsAutomaticRadioButton intValue] == 1)
        {
            //set to automatic
            [portManager setPlistObject:@FALSE forKey:WINESKIN_WRAPPER_PLIST_KEY_INSTALLER_WITH_NORMAL_WINDOWS];
        }
        else
        {
            //set to override
            [portManager setPlistObject:@([installerSettingsAutomaticRadioButton intValue])
                                 forKey:WINESKIN_WRAPPER_PLIST_KEY_INSTALLER_WITH_NORMAL_WINDOWS];
        }
        
        [NSWineskinPortDataWriter saveDecorateWindow:windowManagerCheckBoxButton.state atPort:portManager];
    }
    else
    {
        NSString* engine = [NSPortDataLoader engineOfPortAtPath:self.wrapperPath];
        [NSWineskinPortDataWriter saveRetinaMode:[retinaModeCheckBoxButton state] withEngine:engine atPort:portManager];
    }
    
    
    // Gamma
	if ([gammaSlider doubleValue] == 60.0)
    {
        [portManager setPlistObject:@"default" forKey:WINESKIN_WRAPPER_PLIST_KEY_GAMMA_CORRECTION];
    }
	else
    {
		[portManager setPlistObject:[NSString stringWithFormat:@"%1.2f",(100.0-([gammaSlider doubleValue]-60))/100]
                             forKey:WINESKIN_WRAPPER_PLIST_KEY_GAMMA_CORRECTION];
    }
}
- (void)loadScreenOptionsData
{
    NSString* engine = [NSPortDataLoader engineOfPortAtPath:self.wrapperPath];
    
    BOOL retinaMode = [NSPortDataLoader retinaModeIsEnabledAtPort:self.wrapperPath withEngine:engine];
    [retinaModeCheckBoxButton setState:retinaMode];
    
    BOOL macDriver = [NSPortDataLoader macDriverIsEnabledAtPort:self.wrapperPath withEngine:engine];
    [useMacDriverRadioButton setState: macDriver];
    [useX11RadioButton       setState:!macDriver];
    [macDriverX11TabView selectTabViewItemAtIndex:macDriver ? 0 : 1];
    
    [useD3DBoostIfAvailableCheckBoxButton setEnabled:[NSWineskinEngine isCsmtCompatibleWithEngine:engine]];
    [useD3DBoostIfAvailableCheckBoxButton setState:[NSPortDataLoader direct3DBoostIsEnabledAtPort:self.wrapperPath]];
    
    [windowManagerCheckBoxButton setState:[NSPortDataLoader decorateWindowIsEnabledAtPort:self.wrapperPath]];
    
    BOOL autoDetectGPUEnabled = [[portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_AUTOMATICALLY_DETECT_GPU] boolValue];
    [autoDetectGPUInfoCheckBoxButton setState:autoDetectGPUEnabled];
	
    if ([[portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_GAMMA_CORRECTION] isEqualToString:@"default"]) {
        [gammaSlider setDoubleValue:60.0];
    }
    else {
        [gammaSlider setDoubleValue:(-100*[[portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_GAMMA_CORRECTION] doubleValue])+160];
    }
    
    BOOL automatic = [[portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_SCREEN_OPTIONS_ARE_AUTOMATIC] boolValue];
    [defaultSettingsOverrideRadioButton  setState:!automatic];
    [defaultSettingsAutomaticRadioButton setState: automatic];
    
    BOOL forceInstallerNormalWindows = [[portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_INSTALLER_WITH_NORMAL_WINDOWS] boolValue];
    [installerSettingsOverrideRadioButton  setState:!forceInstallerNormalWindows];
    [installerSettingsAutomaticRadioButton setState: forceInstallerNormalWindows];
    
    
	if (automatic)
    {
        // Automatic
        [installerSettingsOverrideRadioButton  setEnabled:NO];
        [installerSettingsAutomaticRadioButton setEnabled:NO];
        
        [windowModeNormalWindowsRadioButton  setEnabled:NO];
        [windowModeVirtualDesktopRadioButton setEnabled:NO];
        
        [virtualDesktopFullscreenRadioButton setEnabled:NO];
        [virtualDesktopWindowedRadioButton   setEnabled:NO];
        [virtualDesktopResolution            setEnabled:NO];
        
        [colorDepth setEnabled:NO];
        [windowManagerCheckBoxButton setEnabled:YES];
    }
    else
    {
        // Override
        [installerSettingsOverrideRadioButton  setEnabled:YES];
        [installerSettingsAutomaticRadioButton setEnabled:YES];
        
        [windowModeNormalWindowsRadioButton  setEnabled:YES];
        [windowModeVirtualDesktopRadioButton setEnabled:YES];
        
        [colorDepth setEnabled:YES];
    }
    
    //on override, need to load all options
    BOOL fullscreen = [[portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_SCREEN_OPTIONS_IS_FULLSCREEN] boolValue];
    [virtualDesktopFullscreenRadioButton setState: fullscreen];
    [virtualDesktopWindowedRadioButton   setState:!fullscreen];
    
    NSString* screenConfigurations = [portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_SCREEN_OPTIONS_CONFIGURATIONS];
    [NSPortDataLoader getValuesFromResolutionString:screenConfigurations inBlock:
     ^(BOOL virtualDesktop, NSString *resolution, int colors, int sleep)
    {
        [windowModeNormalWindowsRadioButton  setState:!virtualDesktop];
        [windowModeVirtualDesktopRadioButton setState: virtualDesktop];
        
        BOOL enabledVDOptions = !automatic && virtualDesktop;
        [virtualDesktopFullscreenRadioButton setEnabled:enabledVDOptions];
        [virtualDesktopWindowedRadioButton   setEnabled:enabledVDOptions];
        [virtualDesktopResolution            setEnabled:enabledVDOptions];
        [windowManagerCheckBoxButton         setEnabled:automatic || (!automatic && !virtualDesktop)];
        
        if (resolution != nil) {
            [virtualDesktopResolution selectItemWithTitle:resolution];
        } else {
            [virtualDesktopResolution selectItemWithTitle:WINESKIN_WRAPPER_PLIST_VALUE_SCREEN_OPTIONS_CURRENT_RESOLUTION];
        }
        
        [colorDepth selectItemWithTitle:[NSString stringWithFormat:@"%d bit",colors]];
    }];
}
- (IBAction)automaticClicked:(id)sender
{
    [defaultSettingsOverrideRadioButton setState:false];
    
    [installerSettingsOverrideRadioButton  setEnabled:NO];
    [installerSettingsAutomaticRadioButton setEnabled:NO];
    
    [windowModeNormalWindowsRadioButton  setEnabled:NO];
    [windowModeVirtualDesktopRadioButton setEnabled:NO];
    
    [virtualDesktopFullscreenRadioButton setEnabled:NO];
    [virtualDesktopWindowedRadioButton   setEnabled:NO];
    [virtualDesktopResolution            setEnabled:NO];
    
    [colorDepth setEnabled:NO];
    [windowManagerCheckBoxButton setEnabled:YES];
}

- (IBAction)overrideClicked:(id)sender
{
    [defaultSettingsAutomaticRadioButton setState:false];
    
    [installerSettingsOverrideRadioButton  setEnabled:YES];
    [installerSettingsAutomaticRadioButton setEnabled:YES];
    
    [windowModeNormalWindowsRadioButton  setEnabled:YES];
    [windowModeVirtualDesktopRadioButton setEnabled:YES];
    
    BOOL vd = windowModeVirtualDesktopRadioButton.state;
    [virtualDesktopFullscreenRadioButton setEnabled:vd];
    [virtualDesktopWindowedRadioButton   setEnabled:vd];
    [virtualDesktopResolution            setEnabled:vd];
    
    [colorDepth setEnabled:YES];
    [windowManagerCheckBoxButton setEnabled:!vd];
}
- (IBAction)installerAutomaticClicked:(id)sender
{
    [installerSettingsOverrideRadioButton setState:false];
}
- (IBAction)installerOverrideClicked:(id)sender
{
    [installerSettingsAutomaticRadioButton setState:false];
}

- (IBAction)normalWindowsClicked:(id)sender
{
    [windowModeVirtualDesktopRadioButton setState:false];
    
    [virtualDesktopWindowedRadioButton   setEnabled:NO];
    [virtualDesktopFullscreenRadioButton setEnabled:NO];
    [virtualDesktopResolution            setEnabled:NO];
    
    [windowManagerCheckBoxButton setEnabled:YES];
}

- (IBAction)virtualDesktopClicked:(id)sender
{
    [windowModeNormalWindowsRadioButton setState:false];
    
    [virtualDesktopWindowedRadioButton   setEnabled:YES];
    [virtualDesktopFullscreenRadioButton setEnabled:YES];
    [virtualDesktopResolution            setEnabled:YES];
    
    [windowManagerCheckBoxButton setEnabled:NO];
}

- (IBAction)fullscreenClicked:(id)sender
{
    [virtualDesktopWindowedRadioButton setState:false];
}
- (IBAction)windowedClicked:(id)sender
{
    [virtualDesktopFullscreenRadioButton setState:false];
}

- (IBAction)gammaChanged:(id)sender
{
	if ([gammaSlider doubleValue] != 60.0)
		[self systemCommand:[NSString stringWithFormat:@"%@/Contents/Resources/WSGamma",[[NSBundle mainBundle] bundlePath]]
                   withArgs:@[[NSString stringWithFormat:@"%1.2f",(100.0-([gammaSlider doubleValue]-60))/100]]];
}

- (IBAction)useMacDriverCheckBoxClicked:(id)sender
{
    [useX11RadioButton setState:false];
    [macDriverX11TabView selectTabViewItemAtIndex:0];
    
    [NSWineskinPortDataWriter saveMacDriver:true atPort:portManager];
}
- (IBAction)useX11CheckBoxClicked:(id)sender
{
    [useMacDriverRadioButton setState:false];
    [macDriverX11TabView selectTabViewItemAtIndex:1];
    
    [NSWineskinPortDataWriter saveMacDriver:false atPort:portManager];
}

- (IBAction)retinaModeCheckBoxClicked:(id)sender
{
    NSString* engine = [NSPortDataLoader engineOfPortAtPath:self.wrapperPath];
    [NSWineskinPortDataWriter saveRetinaMode:[retinaModeCheckBoxButton state] withEngine:engine atPort:portManager];
}
- (IBAction)direct3dBoostCheckBoxClicked:(id)sender
{
    NSString* engine = [NSPortDataLoader engineOfPortAtPath:self.wrapperPath];
    [NSWineskinPortDataWriter saveDirect3DBoost:useD3DBoostIfAvailableCheckBoxButton.state withEngine:engine atPort:portManager];
}
- (IBAction)autoDetectGpuCheckBoxClicked:(id)sender
{
    [portManager setPlistObject:@([autoDetectGPUInfoCheckBoxButton state]) forKey:WINESKIN_WRAPPER_PLIST_KEY_AUTOMATICALLY_DETECT_GPU];
    [portManager synchronizePlist];
}


//*************************************************************
//********************* Advanced Menu *************************
//*************************************************************
- (IBAction)testRunButtonPressed:(id)sender
{
	[self saveAllData];
	[NSThread detachNewThreadSelector:@selector(runATestRun) toTarget:self withObject:nil];
}
- (void)runATestRun
{
	@autoreleasepool
    {
		[self disableButtons];
		[self systemCommand:[NSPathUtilities wineskinLauncherBinForPortAtPath:self.wrapperPath] withArgs:@[@"debug"]];
		[self enableButtons];
		
        if ([NSAlert showBooleanAlertOfType:NSAlertTypeSuccess withMessage:@"Do you wish to view the Test Run Logs?" withDefault:YES])
        {
            NSString* logsFolderPath = [NSString stringWithFormat:@"%@/Contents/Resources/Logs",self.wrapperPath];
            [self systemCommand:@"/usr/bin/open" withArgs:@[@"-e",[NSString stringWithFormat:@"%@/LastRunX11.log",logsFolderPath]]];
            [self systemCommand:@"/usr/bin/open" withArgs:@[@"-e",[NSString stringWithFormat:@"%@/LastRunWine.log",logsFolderPath]]];
        }
	}
}

- (IBAction)commandLineWineTestButtonPressed:(id)sender
{
	[self saveAllData];
	[NSThread detachNewThreadSelector:@selector(runACommandLineTestRun) toTarget:self withObject:nil];
}

- (void)runACommandLineTestRun
{
	@autoreleasepool
    {
		system([[NSString stringWithFormat: @"export PATH=\"%@/bin:$PATH\";open -a Terminal.app \"%@/Contents/Resources/Command Line Wine Test\"",self.wswineBundlePath,[[NSBundle mainBundle] bundlePath]] UTF8String]);
	}
}

- (IBAction)killWineskinProcessesButtonPressed:(id)sender
{
    //give warning message
    if ([NSAlert showBooleanAlertOfType:NSAlertTypeWarning withMessage:[NSString stringWithFormat:@"This will kill all processes from this wrapper...\nAre you sure that you want to continue?"] withDefault:NO])
    {
        //sends kill command to winesever, this then cause winesever to kill everything without causing registry corruption
        [self runWineskinLauncherWithDisabledButtonsWithFlag:@"WSS-wineserverkill"];
        
        //kill WineskinLauncher WineskinX11
        NSMutableArray *pidsToKill = [[NSMutableArray alloc] init];
        [pidsToKill addObjectsFromArray:[[self systemCommand:[NSString stringWithFormat:@"ps ax | grep \"%@\" | grep WineskinX11 | awk \"{print \\$1}\"",self.wrapperPath]] componentsSeparatedByString:@"\n"]];
        [pidsToKill addObjectsFromArray:[[self systemCommand:[NSString stringWithFormat:@"ps ax | grep \"%@\" | grep WineskinLauncher | awk \"{print \\$1}\"",self.wrapperPath]] componentsSeparatedByString:@"\n"]];
        
        for (NSString *pid in pidsToKill)
        {
            [self systemCommand:[NSString stringWithFormat:@"kill -9 %@",pid]];
        }
    }
    //clear launchd entries that may be stuck
    NSString *wrapperPath = self.wrapperPath;
    NSString *wrapperName = [[wrapperPath substringFromIndex:[wrapperPath rangeOfString:@"/" options:NSBackwardsSearch].location+1] stringByDeletingPathExtension];
    NSString *results = [self systemCommand:[NSString stringWithFormat:@"launchctl list | grep \"%@\"",wrapperName]];
    NSArray *resultArray = [results componentsSeparatedByString:@"\n"];
    for (NSString *result in resultArray)
    {
        NSRange theDash = [result rangeOfString:@"-"];
        if (theDash.location != NSNotFound)
        {
            // clear in front of - in case launchd has it as anonymous, then clear after first [
            NSString *entryToRemove = [[result substringFromIndex:theDash.location+1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSRange theBracket = [entryToRemove rangeOfString:@"["];
            if (theBracket.location != NSNotFound) {
                entryToRemove = [entryToRemove substringFromIndex:theBracket.location];
            }
            NSLog(@"launchctl remove \"%@\"",entryToRemove);
            [self systemCommand:[NSString stringWithFormat:@"launchctl remove \"%@\"",entryToRemove]];
        }
    }
    //delete lockfile
    NSString *tmpFolder=[NSString stringWithFormat:@"/tmp/%@",[self.wrapperPath stringByReplacingOccurrencesOfString:@"/" withString:@"xWSx"]];
    NSString *lockfile=[NSString stringWithFormat:@"%@/lockfile",tmpFolder];
    NSString *tempwineFolder=[NSString stringWithFormat:@"/tmp/.wine-501/"];
    [fm removeItemAtPath:lockfile];
    [fm removeItemAtPath:tmpFolder];
    [fm removeItemAtPath:tempwineFolder];
}

//*************************************************************
//*********** Advanced Menu - Configuration Tab ***************
//*************************************************************
- (void)saveAllData
{
    [NSWineskinPortDataWriter setMainExeName:menubarNameTextField.stringValue
                                     version:versionTextField.stringValue
                                        icon:nil
                                        path:windowsExeTextField.stringValue
                                      atPort:portManager];
    
    [portManager setPlistObject:customCommandsTextField.stringValue forKey:@"CLI Custom Commands"];
    [portManager setPlistObject:wineDebugTextField.stringValue      forKey:@"WINEDEBUG="];
    [portManager synchronizePlist];
}

- (void)loadAllData
{
	//get wrapper version and put on Advanced Page wrapperVersionText
	[wrapperVersionText setStringValue:[NSString stringWithFormat:@"Wineskin %@",WINESKIN_VERSION]];
    
	//get current engine and put it on Advanced Page engineVersionText
    [engineVersionText setStringValue:[NSPortDataLoader engineOfPortAtPath:self.wrapperPath]];
    
	//set info from Info.plist
    [windowsExeTextField setStringValue:[NSPortDataLoader pathForMainExeAtPort:self.wrapperPath]];
    [versionTextField setStringValue:[portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_VERSION]];
    [menubarNameTextField setStringValue:[portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_NAME]];
    
    if ([[portManager plistObjectForKey:@"CLI Custom Commands"] length] > 0)
    {
		[customCommandsTextField setStringValue:[portManager plistObjectForKey:@"CLI Custom Commands"]];
    }
    
	[wineDebugTextField setStringValue:[portManager plistObjectForKey:@"WINEDEBUG="]];
	NSArray *assArray = [[portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_ASSOCIATIONS] componentsSeparatedByString:@" "];
	[extPopUpButton removeAllItems];
    
	for (NSString *item in assArray)
    {
		[extPopUpButton addItemWithTitle:item];
    }
    
    BOOL validExtension = ![[[extPopUpButton selectedItem] title] isEqualToString:@""];
    [extMinusButton setEnabled:validExtension];
    [extEditButton  setEnabled:validExtension];
    
	[mapUserFoldersCheckBoxButton setState:[[portManager plistObjectForKey:@"Symlinks In User Folder"] intValue]];
    [modifyMappingsButton         setEnabled:[mapUserFoldersCheckBoxButton state]];
    [enableWinetricksSilentButton       setState:[[portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_WINETRICKS_SILENT] intValue]];
    [WinetricksNoLogsButton       setState:[[portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_WINETRICKS_NOLOGS] intValue]];

    //Use System XQuartz and ForceQuartzWM disabled unless XQuartz is installed
    if ([NSComputerInformation isSystemMacOsEqualOrSuperiorTo:@"10.8"] && ![fm fileExistsAtPath:@"/Applications/Utilities/XQuartz.app/Contents/MacOS/X11.bin"])
    {
        [forceSystemXQuartzButton setEnabled:NO];
        [forceSystemXQuartzButton setState:0];
        [portManager setPlistObject:@([forceSystemXQuartzButton state]) forKey:WINESKIN_WRAPPER_PLIST_KEY_USE_XQUARTZ];
        [forceWrapperQuartzWMButton setEnabled:NO];
        [forceWrapperQuartzWMButton setState:0];
        [portManager setPlistObject:@([forceWrapperQuartzWMButton state]) forKey:WINESKIN_WRAPPER_PLIST_KEY_DECORATE_WINDOW];
        [portManager synchronizePlist];
    }
    else
    {
        [forceSystemXQuartzButton setEnabled:YES];
        [forceSystemXQuartzButton         setState:[[portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_USE_XQUARTZ] intValue]];
        [forceWrapperQuartzWMButton setEnabled:YES];
        [forceWrapperQuartzWMButton       setState:[[portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_DECORATE_WINDOW] intValue]];
    }
    
    [disableCPUsCheckBoxButton        setState:[[portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_SINGLE_CPU] intValue]];
	[alwaysMakeLogFilesCheckBoxButton setState:[[portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_DEBUG_MODE] intValue]];
    [setMaxFilesCheckBoxButton        setState:[[portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_MAX_OF_10240_FILES] intValue]];
    
	[optSendsAltCheckBoxButton             setState:[[portManager x11PlistObjectForKey:WINESKIN_WRAPPER_X11_PLIST_KEY_OPTION_WORKS_LIKE_ALT] intValue]];
	[emulateThreeButtonMouseCheckBoxButton setState:[[portManager x11PlistObjectForKey:WINESKIN_WRAPPER_X11_PLIST_KEY_EMULATE_THREE_BUTTONS] intValue]];
	[focusFollowsMouseCheckBoxButton       setState:[[portManager x11PlistObjectForKey:@"wm_ffm"] intValue]];
    
    [confirmQuitCheckBoxButton setState:[NSPortDataLoader isCloseNicelyEnabledAtPort:portManager]];
}
- (IBAction)windowsExeBrowseButtonPressed:(id)sender
{
    NSString* cDrivePath = self.cDrivePathForWrapper;
    
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setWindowTitle:NSLocalizedString(@"Please choose the file that should run",nil)];
	[panel setPrompt:NSLocalizedString(@"Choose",nil)];
	[panel setCanChooseDirectories:NO];
	[panel setCanChooseFiles:YES];
	[panel setAllowsMultipleSelection:NO];
	[panel setExtensionHidden:NO];
	[panel setTreatsFilePackagesAsDirectories:YES];
    [panel setAllowedFileTypes:EXTENSIONS_COMPATIBLE_WITH_RUN_PATH];
    [panel setInitialDirectory:cDrivePath];
	
    //open browse window to get .exe choice
    if ([panel runModal] == 0)
    {
        return;
    }
    
    NSString* selectedMainExe = [[[panel URLs] objectAtIndex:0] path];
    NSString* windowsPath = [NSExeSelection selectAsMainExe:selectedMainExe forPort:self.wrapperPath];
	[windowsExeTextField setStringValue:windowsPath];
}
- (IBAction)extPlusButtonPressed:(id)sender
{
	[self saveAllData];
	[extExtensionTextField setStringValue:@""];
	[extCommandTextField setStringValue:[NSString stringWithFormat:@"%@ \"%%1\"",[[windowsExeTextField stringValue] stringByReplacingOccurrencesOfString:@"/" withString:@"\\"]]];
	[extAddEditWindow makeKeyAndOrderFront:self];
	[advancedWindow orderOut:self];
}
- (IBAction)extMinusButtonPressed:(id)sender
{
    if ([NSAlert showBooleanAlertOfType:NSAlertTypeWarning withMessage:@"Are you sure that you want to remove that entry? This will remove the file association." withDefault:NO] == false)
    {
		return;
	}
    
    NSString* extension = [[extPopUpButton selectedItem] title];
    if (!extension) return;
    
	[self saveAllData];
	[busyWindow makeKeyAndOrderFront:self];
	[advancedWindow orderOut:self];
    
    NSString* regSoftwareClassesExtension = [NSString stringWithFormat:@"[Software\\\\Classes\\\\.%@]",extension];
    NSString* regSoftwareClassesExtensionShellOpenCommand = [NSString stringWithFormat:@"[Software\\\\Classes\\\\%@file\\\\shell\\\\open\\\\command]",extension];
    
    [portManager deleteRegistry:regSoftwareClassesExtension                 fromRegistryFileNamed:SYSTEM_REG];
    [portManager deleteRegistry:regSoftwareClassesExtensionShellOpenCommand fromRegistryFileNamed:SYSTEM_REG];
    
    
	//remove entry from Info.plist
	NSMutableArray *assArray = [[[portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_ASSOCIATIONS]
                                 componentsSeparatedByString:@" "] mutableCopy];
	[assArray removeObject:extension];
	[portManager setPlistObject:[assArray componentsJoinedByString:@" "] forKey:WINESKIN_WRAPPER_PLIST_KEY_ASSOCIATIONS];
    [portManager synchronizePlist];
	
	[self loadAllData];
	[advancedWindow makeKeyAndOrderFront:self];
	[busyWindow orderOut:self];	
}
- (IBAction)extEditButtonPressed:(id)sender
{
	[self saveAllData];
    
	// get selected extension
    NSString* extension = [[extPopUpButton selectedItem] title];
	[extExtensionTextField setStringValue:extension];
    
    NSString* regSoftwareClassesExtensionShellOpenCommand = [NSString stringWithFormat:@"[Software\\\\Classes\\\\%@file\\\\shell\\\\open\\\\command]",extension];
    
    // read system.reg and find command line for that extension
    NSString* commandReg = [portManager getRegistryEntry:regSoftwareClassesExtensionShellOpenCommand fromRegistryFileNamed:SYSTEM_REG];
    if (!commandReg) return;
    
    NSString* atValue = [NSPortManager getStringValueForKey:nil fromRegistryString:commandReg];
    if (!atValue) return;
    
    [extCommandTextField setStringValue:atValue];
    
    
	[extAddEditWindow makeKeyAndOrderFront:self];
	[advancedWindow orderOut:self];
}
- (IBAction)iconToUseBrowseButtonPressed:(id)sender
{
    NSOpenPanel *panel = [[NSOpenPanel alloc] init];
    [panel setWindowTitle:NSLocalizedString(@"Please choose the image file to use in the wrapper",nil)];
    [panel setPrompt:NSLocalizedString(@"Choose",nil)];
    [panel setCanChooseDirectories:NO];
    [panel setCanChooseFiles:YES];
    [panel setAllowsMultipleSelection:NO];
    [panel setExtensionHidden:NO];
    [panel setTreatsFilePackagesAsDirectories:YES];
    [panel setInitialDirectory:@"/"];
    
    if ([panel runModal] == 0)
    {
        return;
    }
    
    NSString* newIconPath = [[[panel URLs] objectAtIndex:0] path];
    [iconImageView loadIconFromFile:newIconPath];
    
    NSString* wrapperRealPath = self.wrapperPath;
    NSString* wrapperIconPath = [NSString stringWithFormat:@"%@/Contents/Resources/Wineskin.icns",wrapperRealPath];
    NSString* wrapperTemporaryPath = [NSString stringWithFormat:@"%@WineskinTempRenamer",wrapperRealPath];
    
    [[NSFileManager defaultManager] removeItemAtPath:wrapperIconPath];
    [iconImageView.image saveAsIcnsAtPath:wrapperIconPath];
    [[NSFileManager defaultManager] moveItemAtPath:wrapperRealPath toPath:wrapperTemporaryPath];
    [[NSFileManager defaultManager] moveItemAtPath:wrapperTemporaryPath toPath:wrapperRealPath];
}
//*************************************************************
//*************** Advanced Menu - Options Tab *****************
//*************************************************************
- (IBAction)alwaysMakeLogFilesCheckBoxButtonPressed:(id)sender
{
    [portManager setPlistObject:@([alwaysMakeLogFilesCheckBoxButton state]) forKey:WINESKIN_WRAPPER_PLIST_KEY_DEBUG_MODE];
    [portManager synchronizePlist];
}
- (IBAction)setMaxFilesCheckBoxButtonPressed:(id)sender
{
    [portManager setPlistObject:@([setMaxFilesCheckBoxButton state]) forKey:WINESKIN_WRAPPER_PLIST_KEY_MAX_OF_10240_FILES];
    [portManager synchronizePlist];
}
- (IBAction)optSendsAltCheckBoxButtonPressed:(id)sender;
{
    [portManager setX11PlistObject:@([optSendsAltCheckBoxButton state]) forKey:WINESKIN_WRAPPER_X11_PLIST_KEY_OPTION_WORKS_LIKE_ALT];
    [portManager synchronizeX11Plist];
}
- (IBAction)emulateThreeButtonMouseCheckBoxButtonPressed:(id)sender
{
    [portManager setX11PlistObject:@([emulateThreeButtonMouseCheckBoxButton state])
                            forKey:WINESKIN_WRAPPER_X11_PLIST_KEY_EMULATE_THREE_BUTTONS];
    [portManager synchronizeX11Plist];
}
- (IBAction)mapUserFoldersCheckBoxButtonPressed:(id)sender
{
    BOOL symlinksInUserFolder = [mapUserFoldersCheckBoxButton state];
    [modifyMappingsButton setEnabled:symlinksInUserFolder];
    
    [portManager setPlistObject:[NSNumber numberWithBool:symlinksInUserFolder] forKey:@"Symlinks In User Folder"];
    [portManager synchronizePlist];
}
- (IBAction)confirmQuitCheckBoxButtonPressed:(id)sender
{
    [NSWineskinPortDataWriter saveCloseSafely:@(confirmQuitCheckBoxButton.state) atPort:portManager];
}
- (IBAction)focusFollowsMouseCheckBoxButtonPressed:(id)sender
{
    [portManager setX11PlistObject:[NSNumber numberWithBool:[focusFollowsMouseCheckBoxButton state]] forKey:@"wm_ffm"];
    [portManager synchronizeX11Plist];
}
- (IBAction)modifyMappingsButtonPressed:(id)sender
{
	[modifyMappingsMyDocumentsTextField setStringValue:[portManager plistObjectForKey:@"Symlink My Documents"]];
	[modifyMappingsDesktopTextField     setStringValue:[portManager plistObjectForKey:@"Symlink Desktop"]];
	[modifyMappingsMyVideosTextField    setStringValue:[portManager plistObjectForKey:@"Symlink My Videos"]];
	[modifyMappingsMyMusicTextField     setStringValue:[portManager plistObjectForKey:@"Symlink My Music"]];
	[modifyMappingsMyPicturesTextField  setStringValue:[portManager plistObjectForKey:@"Symlink My Pictures"]];
    [modifyMappingsDownloadsTextField  setStringValue:[portManager plistObjectForKey:@"Symlink Downloads"]];
	[modifyMappingsWindow makeKeyAndOrderFront:self];
	[advancedWindow orderOut:self];
}
- (IBAction)disableCPUsButtonPressed:(id)sender
{
    [portManager setPlistObject:@([disableCPUsCheckBoxButton state]) forKey:WINESKIN_WRAPPER_PLIST_KEY_SINGLE_CPU];
    [portManager synchronizePlist];
}
- (IBAction)forceWrapperQuartzWMButtonPressed:(id)sender
{
    [portManager setPlistObject:@([forceWrapperQuartzWMButton state]) forKey:WINESKIN_WRAPPER_PLIST_KEY_DECORATE_WINDOW];
    [portManager synchronizePlist];
}
- (IBAction)forceSystemXQuartzButtonPressed:(id)sender
{
    [portManager setPlistObject:@([forceSystemXQuartzButton state]) forKey:WINESKIN_WRAPPER_PLIST_KEY_USE_XQUARTZ];
    [portManager synchronizePlist];
}
- (IBAction)enableWinetricksSilentButtonPressed:(id)sender
{
    [portManager setPlistObject:@([enableWinetricksSilentButton state]) forKey:WINESKIN_WRAPPER_PLIST_KEY_WINETRICKS_SILENT];
    [portManager synchronizePlist];
}
- (IBAction)WinetricksNoLogsButtonPressed:(id)sender
{
    [portManager setPlistObject:@([WinetricksNoLogsButton state]) forKey:WINESKIN_WRAPPER_PLIST_KEY_WINETRICKS_NOLOGS];
    [portManager synchronizePlist];
}
//*************************************************************
//**************** Advanced Menu - Tools Tab ******************
//*************************************************************
- (IBAction)winecfgButtonPressed:(id)sender
{
	[NSThread detachNewThreadSelector:@selector(runWinecfg) toTarget:self withObject:nil];
}
- (void)runWineskinLauncherWithDisabledButtonsWithFlag:(NSString*)flag
{
    @autoreleasepool
    {
        [self disableButtons];
        [self systemCommand:[NSPathUtilities wineskinLauncherBinForPortAtPath:self.wrapperPath] withArgs:@[flag]];
        [self enableButtons];
    }
}
- (void)runWinecfg
{
    [self runWineskinLauncherWithDisabledButtonsWithFlag:@"WSS-winecfg"];
}
- (IBAction)uninstallerButtonPressed:(id)sender
{
	[NSThread detachNewThreadSelector:@selector(runUninstaller) toTarget:self withObject:nil];
}
- (void)runUninstaller
{
    [self runWineskinLauncherWithDisabledButtonsWithFlag:@"WSS-uninstaller"];
}
- (IBAction)regeditButtonPressed:(id)sender
{
	[NSThread detachNewThreadSelector:@selector(runRegedit) toTarget:self withObject:nil];
}
- (void)runRegedit
{
    [self runWineskinLauncherWithDisabledButtonsWithFlag:@"WSS-regedit"];
}
- (IBAction)taskmgrButtonPressed:(id)sender
{
	[NSThread detachNewThreadSelector:@selector(runTaskmgr) toTarget:self withObject:nil];
}
- (void)runTaskmgr
{
    [self runWineskinLauncherWithDisabledButtonsWithFlag:@"WSS-taskmgr"];
}
- (IBAction)rebuildWrapperButtonPressed:(id)sender
{
	//issue warning
    if ([NSAlert showBooleanAlertOfType:NSAlertTypeWarning withMessage:@"This will remove all contents, including anything installed in drive_c, and registry files, and rebuild them from scratch! You will lose anything you have installed in the wrapper!\n\nThis data is NOT recoverable!!\n\nAre you sure you want to do this?" withDefault:NO])
    {
		//delete files
		[busyWindow makeKeyAndOrderFront:self];
		[advancedWindow orderOut:self];
        
        for (NSString* fileToRemove in @[@".update-timestamp", @"drive_c", @"dosdevices", @"harddiskvolume0",
                                         @"system.reg", @"user.reg", @"userdef.reg", @"winetricksInstalled.plist", @"winetricks.log"])
        {
            NSString* filePath = [NSString stringWithFormat:@"%@/Contents/Resources/%@",self.wrapperPath,fileToRemove];
            if ([fm fileExistsAtPath:filePath]) [fm removeItemAtPath:filePath];
        }
        
		//refresh
		[self systemCommand:[NSPathUtilities wineskinLauncherBinForPortAtPath:self.wrapperPath] withArgs:@[@"WSS-wineprefixcreate"]];
        
		[advancedWindow makeKeyAndOrderFront:self];
		[busyWindow orderOut:self];
	}
}
- (IBAction)refreshWrapperButtonPressed:(id)sender
{
	[busyWindow makeKeyAndOrderFront:self];
	[advancedWindow orderOut:self];
    
	[self systemCommand:[NSPathUtilities wineskinLauncherBinForPortAtPath:self.wrapperPath] withArgs:@[@"WSS-wineprefixcreatenoregs"]];
    
	[advancedWindow makeKeyAndOrderFront:self];
	[busyWindow orderOut:self];
}
- (IBAction)winetricksButtonPressed:(id)sender
{
    //Warning User if Winetricks No Logs Mode is enabled, Custom Title instead of Warning?
    if (([WinetricksNoLogsButton intValue] == 1) && [NSAlert showBooleanAlertOfType:NSAlertTypeWinetricks withMessage:[NSString stringWithFormat:@"\nDisable winetricks logs only if you know exactly what you're doing\nAre you sure that you want to proceed?"] withDefault:NO] == false)
    {
        //Disables "Wineskin No Logs mode" if user picks No, then continues
        [WinetricksNoLogsButton setState:0];
        [portManager setPlistObject:@([WinetricksNoLogsButton state]) forKey:WINESKIN_WRAPPER_PLIST_KEY_WINETRICKS_NOLOGS];
        [portManager synchronizePlist];
        [self winetricksRefreshButtonPressed:self];
    }
    [self winetricksRefreshButtonPressed:self];
}
- (IBAction)winetricksDoneButtonPressed:(id)sender
{
	[advancedWindow makeKeyAndOrderFront:self];
	[winetricksWindow orderOut:self];
}
- (IBAction)winetricksRefreshButtonPressed:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	winetricksDone = NO;
	[winetricksWindow makeKeyAndOrderFront:self];
	[advancedWindow orderOut:self];
	[busyWindow orderOut:self];
	[winetricksCustomLine setStringValue:@""];
	[winetricksCustomCheckbox setState:NO];
	[self winetricksCustomCommandToggled:winetricksCustomCheckbox];
//	[[self winetricksSelectedList] removeAllObjects];

	[winetricksTableColumnInstalled setHidden:![defaults boolForKey:@"InstalledColumnShown"]];
	[winetricksTableColumnDownloaded setHidden:![defaults boolForKey:@"DownloadedColumnShown"]];
	[winetricksShowDownloadedColumn setState:([defaults boolForKey:@"DownloadedColumnShown"] ? NSOnState : NSOffState)];
	[winetricksShowInstalledColumn setState:([defaults boolForKey:@"InstalledColumnShown"] ? NSOnState : NSOffState)];
	[winetricksOutlineView setOutlineTableColumn:winetricksTableColumnName];
	
	[self setWinetricksBusy:YES];

	// Run the possibly lenghty operation in a separate thread so that it won't beachball
	NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(winetricksLoadPackageLists) object:nil];
	[thread start];
	while (![thread isFinished]) // Wait in a non-locking mode until the thread finishes running
    {
		[self sleepWithRunLoopForSeconds:1];
	}
	winetricksDone = YES;
	[self setWinetricksBusy:NO];
	[winetricksOutlineView reloadData];
}
- (IBAction)winetricksUpdateButtonPressed:(id)sender
{
	//Get the URL where winetricks is located
	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://wineskin.urgesoftware.com/WineskinWinetricks/Location.txt?%@",[[NSNumber numberWithLong:rand()] stringValue]]];
    NSString *urlWhereWinetricksIs = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding timeoutInterval:5];
    
	urlWhereWinetricksIs = [urlWhereWinetricksIs stringByReplacingOccurrencesOfString:@"\n" withString:@""]; //remove \n
	//confirm update
    
    if ([NSAlert showBooleanAlertOfType:NSAlertTypeWarning withMessage:[NSString stringWithFormat:@"Are you sure you want to update to the latest version of Winetricks?\n\nThe latest version from...\n\t%@\nwill be downloaded and installed for this wrapper.",urlWhereWinetricksIs] withDefault:NO] == false)
    {
		return;
	}
    
    //random added to force recheck
	urlWhereWinetricksIs = [NSString stringWithFormat:@"%@?%@",urlWhereWinetricksIs,[[NSNumber numberWithLong:rand()] stringValue]];
	
    //show busy window
	[busyWindow makeKeyAndOrderFront:self];
	//hide Winetricks window
	[winetricksWindow orderOut:self];
	
    //Use downloader to download
	NSData *newVersion = [NSData dataWithContentsOfURL:[NSURL URLWithString:urlWhereWinetricksIs] timeoutInterval:5];
	//if new version looks messed up, prompt the download failed, and exit.
	if (newVersion.length < 50)
	{
        [NSAlert showAlertOfType:NSAlertTypeError withMessage:@"Connection to the website failed. The site is either down currently, or there is a problem with your internet connection."];
        
		[winetricksWindow makeKeyAndOrderFront:self];
		[busyWindow orderOut:self];
		return;
	}
    
    NSString* winetricksFilePath = [NSString stringWithFormat:@"%@/Contents/Resources/winetricks",[[NSBundle mainBundle] bundlePath]];
	[fm removeItemAtPath:winetricksFilePath];
	[newVersion writeToFile:winetricksFilePath atomically:YES];
	[self systemCommand:@"/bin/chmod" withArgs:[NSArray arrayWithObjects:@"777",winetricksFilePath,nil]];
    
	//remove old list of packages and descriptions (it'll be rebuilt when refreshing the list)
	[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Contents/Resources/winetricksHelpList.plist",[[NSBundle mainBundle] bundlePath]]];

	//refresh window
	[self winetricksRefreshButtonPressed:self];
}
- (IBAction)winetricksRunButtonPressed:(id)sender
{
	// Clean list from unselected entries
	for (NSString *eachPackage in [[self winetricksSelectedList] allKeys])
	{
        NSNumber* winetrickWasSelected = [[self winetricksSelectedList] objectForKey:eachPackage];
		if (!winetrickWasSelected || ![winetrickWasSelected boolValue]) // Cleanup
			[[self winetricksSelectedList] removeObjectForKey:eachPackage];
	}
    
    NSString* winetricks;
	if ([winetricksCustomCheckbox state]) // Don't run if there are no selected packages to install
	{
        winetricks = [[winetricksCustomLine stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if (winetricks.length == 0) return;
	}
	else
	{
        winetricks = [[[self winetricksSelectedList] allKeys] componentsJoinedByString:@" "];
        if ([[self winetricksSelectedList] count] == 0) return;
	}
    
    if ([NSAlert showBooleanAlertOfType:NSAlertTypeSuccess withMessage:[NSString stringWithFormat:@"Do you wish to run the following command?\nwinetricks %@", winetricks] withDefault:YES] == false)
    {
        return;
    }
    
	winetricksDone = NO;
	winetricksCanceled = NO;
	[self setWinetricksBusy:YES];
	// switch to the log tab
	//[winetricksTabView selectTabViewItem:winetricksTabLog];
	// delete log file
	[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Contents/Resources/Logs/Winetricks.log",self.wrapperPath]];
	//killing sh processes from Winetricks will cancel out Winetricks correctly
	//get first list of running "sh" processes
	NSArray *firstPIDlist = [self makePIDArray:@"sh"];
	// call runWinetrick in new thread
	[NSThread detachNewThreadSelector:@selector(runWinetrick) toTarget:self withObject:nil];
	[NSThread detachNewThreadSelector:@selector(updateWinetrickOutput) toTarget:self withObject:nil];
	//clear out shPIDs
	[shPIDs removeAllObjects];
	//loop though a second list and matching pids several times to try and get all the correct "sh" processes.  Sadly this may get stray other processes on the system if people are multitasking a lot... not sure how else to handle it.
	int i;
	for (i=0;i<3;i++)
	{
		//get second list of running "sh" processes
		NSArray *secondPIDlist = [self makePIDArray:@"sh"];
		//compare first and second list, and ones in second list are the Winetricks ones, if cancel button pressed these are the ones to kill
		BOOL match = YES;
		for (NSString *secondPIDlistItem in secondPIDlist)
		{
			match = NO;
			for (NSString *firstPIDlistItem in firstPIDlist)
				if ([secondPIDlistItem isEqualToString:firstPIDlistItem]) match = YES;
			if (!match) [shPIDs addObject:secondPIDlistItem];
		}
		usleep(1000000);
	}
}
- (IBAction)winetricksCancelButtonPressed:(id)sender
{
	//confirm to kill with big warning window
    if ([NSAlert showBooleanAlertOfType:NSAlertTypeWarning withMessage:@"Are you sure you want to cancel Winetricks?\n\nThis will kill the running Winetricks process, but has a chance to accidently leave \"sh\" processes running until you manually end them or reboot\n\nIt could also mess up the wrapper where you may need to do a full rebuild to get it working right again (this will not usually be a problem)." withDefault:NO] == false)
    {
        return;
    }
    
	[winetricksCancelButton setHidden:YES];
	[winetricksCancelButton setEnabled:NO];
    
	//kill shPIDs
	winetricksCanceled = YES;
	char *tmp;
	for (NSString *item in shPIDs)
    {
		kill((pid_t)(strtoimax([item UTF8String], &tmp, 10)), 9);
    }
}
- (IBAction)winetricksSelectAllButtonPressed:(id)sender
{
	for (NSDictionary *eachCategoryList in [[self winetricksFilteredList] allValues])
		for (NSString *eachPackage in eachCategoryList)
			[[self winetricksSelectedList] setValue:[NSNumber numberWithBool:YES] forKey:eachPackage];
	[winetricksOutlineView setNeedsDisplay];
}
- (IBAction)winetricksSelectNoneButtonPressed:(id)sender
{
	[[self winetricksSelectedList] removeAllObjects];
	[winetricksOutlineView setNeedsDisplay];
}
- (IBAction)winetricksSearchFilter:(id)sender
{
	NSString *searchString = [[sender stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if ([searchString length] == 0)
		[self setWinetricksFilteredList:[self winetricksList]];
	else
	{
		NSMutableDictionary *list = [[NSMutableDictionary alloc] init];
		for (NSString *eachCategory in [self winetricksList])
		{
			NSDictionary *thisCategoryListOriginal = [[self winetricksList] valueForKey:eachCategory];
			NSMutableDictionary *thisCategoryList = [thisCategoryListOriginal mutableCopy];
			for (NSString *eachPackage in thisCategoryListOriginal) // Can't iterate on the copy being modified
			{
				if ([eachPackage rangeOfString:searchString options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch].location != NSNotFound) // Found in package name
					continue;
				if ([[[thisCategoryListOriginal valueForKey:eachPackage] valueForKey:WINETRICK_DESCRIPTION] rangeOfString:searchString options:NSCaseInsensitiveSearch|NSDiacriticInsensitiveSearch].location != NSNotFound) // Found in package description
					continue;
				// Not found.  Remove the item from the dictionary
				[thisCategoryList removeObjectForKey:eachPackage];
			}
			if ([thisCategoryList count] > 0)
				[list setValue:thisCategoryList forKey:eachCategory];
		}
		[self setWinetricksFilteredList:list];
	}
	[winetricksOutlineView reloadData];
}
- (IBAction)winetricksCustomCommandToggled:(id)sender
{
    BOOL useCustomLine = [sender state];
    BOOL hideCustomLine = !useCustomLine;
    
    [enableWinetricksSilentButton setHidden:useCustomLine];
    [winetricksCustomLine setEnabled:useCustomLine];
    [winetricksCustomLine setHidden:hideCustomLine];
    [winetricksCustomLineLabel setHidden:hideCustomLine];
    [winetricksOutlineView setEnabled:hideCustomLine];
    [winetricksSearchField setEnabled:hideCustomLine];
    
	if (useCustomLine)
	{
		[winetricksCustomLine becomeFirstResponder];
	}
	else
	{
		[winetricksRunButton becomeFirstResponder];
	}
}
- (IBAction)winetricksToggleColumn:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL newState = !([sender state] == NSOnState);
	if (sender == winetricksShowInstalledColumn)
	{
		[sender setState:(newState ? NSOnState : NSOffState)];
		[defaults setBool:newState forKey:@"InstalledColumnShown"];
	}
	else if (sender == winetricksShowDownloadedColumn)
	{
		[sender setState:(newState ? NSOnState : NSOffState)];
		[defaults setBool:newState forKey:@"DownloadedColumnShown"];
	}
	[defaults synchronize];
	[self winetricksRefreshButtonPressed:self];
}
- (void)winetricksLoadPackageLists
{
	@autoreleasepool
    {
		NSDictionary *list = nil;
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
		// List of all winetricks
		list = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/Contents/Resources/winetricksHelpList.plist",[[NSBundle mainBundle] bundlePath]]];
		BOOL needsListRebuild = NO;
		if (list == nil)
        {
            // This only happens in case of a winetricks update
			needsListRebuild = YES;
        }
		else
		{
			for (NSString *eachCategory in [list allKeys])
			{
				if ([list valueForKey:eachCategory] == nil || ![[list valueForKey:eachCategory] isKindOfClass:[NSDictionary class]])
				{
					needsListRebuild = YES;
					break;
				}
				NSDictionary *thisCategory = list[eachCategory];
				for (NSString *eachPackage in [thisCategory allKeys])
				{
					if ([thisCategory valueForKey:eachPackage] == nil || ![[thisCategory valueForKey:eachPackage] isKindOfClass:[NSDictionary class]])
					{
						needsListRebuild = YES;
						break;
					}
					NSDictionary *thisPackage = [thisCategory valueForKey:eachPackage];
					if (!thisPackage[WINETRICK_NAME]        || ![thisPackage[WINETRICK_NAME]        isKindOfClass:[NSString class]] ||
                        !thisPackage[WINETRICK_DESCRIPTION] || ![thisPackage[WINETRICK_DESCRIPTION] isKindOfClass:[NSString class]])
					{
						needsListRebuild = YES;
						break;
					}
				}
			}
		}
		if (needsListRebuild)
		{ // Invalid or missing list.  Rebuild it
            NSArray *winetricksFile = [[NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@/Contents/Resources/winetricks",[[NSBundle mainBundle] bundlePath]] encoding:NSUTF8StringEncoding] componentsSeparatedByString:@"\n"];
            NSMutableArray *linesToCheck = [[NSMutableArray alloc] init];
            NSArray *winetricksCategories;
            int i;
            for (i=0; i < [winetricksFile count]; ++i)
            {
                NSMutableString *fixedLine = [[NSMutableString alloc] init];
                [fixedLine setString:[[winetricksFile objectAtIndex:i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
                if ([fixedLine hasPrefix:@"WINETRICKS_CATEGORIES="])
                {
                    [fixedLine replaceOccurrencesOfString:@"WINETRICKS_CATEGORIES=" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [fixedLine length])];
                    [fixedLine replaceOccurrencesOfString:@"\"" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [fixedLine length])];
                    winetricksCategories = [fixedLine componentsSeparatedByString:@" "];
                }
                else if ([fixedLine hasPrefix:@"w_metadata"])
                {
                    [fixedLine replaceOccurrencesOfString:@"\\" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [fixedLine length])];
                    [fixedLine replaceOccurrencesOfString:@"w_metadata" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [fixedLine length])];
                    [fixedLine appendString:@" "];
                    NSMutableString *descriptionLine = [[NSMutableString alloc] initWithString:@"No Description Found"];
                    //check next few lines for title
                    int counter = 1;
                    for (counter = 1; counter < 10; ++counter)
                    {
                        if ([[winetricksFile objectAtIndex:i+counter] rangeOfString:@"title="].location != NSNotFound)
                        {
                            //this is the title!
                            [descriptionLine setString:[winetricksFile objectAtIndex:i+counter]];
                            break;
                        }
                    }
                    [descriptionLine replaceOccurrencesOfString:@"\\" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [descriptionLine length])];
                    [descriptionLine replaceOccurrencesOfString:@"\"" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [descriptionLine length])];
                    [descriptionLine replaceOccurrencesOfString:@"title=" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [descriptionLine length])];
                    [fixedLine appendString:[descriptionLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
                    [linesToCheck addObject:[fixedLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
                }
            }
			list = [[NSMutableDictionary alloc] init];
			for (NSString *category in winetricksCategories)
			{
                NSMutableArray *winetricksTempList = [[NSMutableArray alloc] init];
                for (NSString *line in linesToCheck)
                {
                    NSMutableString *fixedLine = [[NSMutableString alloc] init];
                    [fixedLine setString:line]; //fix multiple space issue
                    while ([fixedLine rangeOfString:@"  "].location != NSNotFound)
                    {
                        [fixedLine replaceOccurrencesOfString:@"  " withString:@" " options:NSCaseInsensitiveSearch range:NSMakeRange(0, [fixedLine length])];
                    }
                    NSArray *splitLine = [fixedLine componentsSeparatedByString:@" "];
                    if ([[splitLine objectAtIndex:1] isEqualToString:category])
                    {
                        //[fixedLine replaceOccurrencesOfString:category withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [fixedLine length])];
                        while ([fixedLine rangeOfString:@"  "].location != NSNotFound)
                        {
                            [fixedLine replaceOccurrencesOfString:@"  " withString:@" " options:NSCaseInsensitiveSearch range:NSMakeRange(0, [fixedLine length])];
                        }
                        [winetricksTempList addObject:[fixedLine stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
                    }
                }
                [winetricksTempList sortUsingSelector:(@selector(caseInsensitiveCompare:))];
				NSMutableDictionary *winetricksThisCategoryList = [[NSMutableDictionary alloc] init];
				for (NSString *eachPackage in winetricksTempList)
				{
					NSRange position = [eachPackage rangeOfString:@" "];
					if (position.location == NSNotFound) continue;// Skip invalid entries
					NSString *packageName = [eachPackage substringToIndex:position.location];
                NSMutableString *packageDescription = [[NSMutableString alloc] init];
					[packageDescription appendString:[[eachPackage substringFromIndex:position.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
                NSRange position2 = [packageDescription rangeOfString:[NSString stringWithFormat:@"%@ ",category]];
                [packageDescription deleteCharactersInRange:position2];
					// Yes, we're inserting the name twice (as a key and as a value) on purpose, so that we won't have to do a nasty, slow allObjectsForKey when drawing the UI.
                    [winetricksThisCategoryList setObject:@{WINETRICK_NAME: packageName, WINETRICK_DESCRIPTION: packageDescription}
                                                   forKey:packageName];
				}
				if ([winetricksThisCategoryList count] == 0) continue;
				[list setValue:winetricksThisCategoryList forKey:category];
			}
			[list writeToFile:[NSString stringWithFormat:@"%@/Contents/Resources/winetricksHelpList.plist",[[NSBundle mainBundle] bundlePath]] atomically:YES];
		}
		[self setWinetricksList:list];
		[self setWinetricksFilteredList:list];
		
		if ([defaults boolForKey:@"InstalledColumnShown"])
		{
			// List of installed winetricks
			list = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/Contents/Resources/winetricksInstalled.plist",self.wrapperPath]];
			if (!list[WINETRICK_INSTALLED] || ![list[WINETRICK_INSTALLED] isKindOfClass:[NSArray class]])
			{
                // Invalid or missing list.  Rebuild it (it only happens on a newly created wrapper or after a wrapper rebuild
				[self systemCommand:[NSPathUtilities wineskinLauncherBinForPortAtPath:self.wrapperPath] withArgs:[NSArray arrayWithObjects:@"WSS-winetricks", @"list-installed", nil]];
                
				NSArray *tempList = [[[NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@/Contents/Resources/Logs/WinetricksTemp.log", self.wrapperPath] encoding:NSUTF8StringEncoding] componentsSeparatedByString:@"\n"] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
                list = @{WINETRICK_INSTALLED: tempList};
				[list writeToFile:[NSString stringWithFormat:@"%@/Contents/Resources/winetricksInstalled.plist",self.wrapperPath] atomically:YES];
			}
			[self setWinetricksInstalledList:list[WINETRICK_INSTALLED]];
		}
		else
        {
			[self setWinetricksInstalledList:[NSArray array]];
		}
		if ([defaults boolForKey:@"DownloadedColumnShown"])
		{
			// List of downloaded winetricks
			list = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/winetricks/winetricksCached.plist", [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0]]];
			if (!list[WINETRICK_CACHED] || ![list[WINETRICK_CACHED] isKindOfClass:[NSArray class]])
			{
                // Invalid or missing list.  Rebuild it (it only happens when the user first runs wineetricks on their system (from any wrapper) or after wiping ~/Caches/winetricks
				[self systemCommand:[NSPathUtilities wineskinLauncherBinForPortAtPath:self.wrapperPath] withArgs:[NSArray arrayWithObjects:@"WSS-winetricks",@"list-cached",nil]];
				NSArray *tempList = [[[NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@/Contents/Resources/Logs/WinetricksTemp.log", self.wrapperPath] encoding:NSUTF8StringEncoding] componentsSeparatedByString:@"\n"] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
                list = @{WINETRICK_CACHED: tempList};
				[list writeToFile:[NSString stringWithFormat:@"%@/winetricks/winetricksCached.plist", [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0]] atomically:YES];
			}
			[self setWinetricksCachedList:list[WINETRICK_CACHED]];
		}
		else
        {
			[self setWinetricksCachedList:[NSArray array]];
        }
	}
}
- (void)setWinetricksBusy:(BOOL)isBusy;
{
	// disable X button
	disableXButton = isBusy;
    
	// disable all buttons on Winetricks window
	[winetricksRunButton setEnabled:!isBusy];
	[winetricksUpdateButton setEnabled:!isBusy];
	[winetricksRefreshButton setEnabled:!isBusy];
	[winetricksDoneButton setEnabled:!isBusy];
	[winetricksSearchField setEnabled:!isBusy];
    [enableWinetricksSilentButton setEnabled:!isBusy];
	[winetricksCustomCheckbox setEnabled:!isBusy];
	[winetricksActionPopup setEnabled:!isBusy];
	
    //enable cancel button
	[winetricksCancelButton setHidden:!isBusy];
	[winetricksCancelButton setEnabled:isBusy];
    
	if (isBusy)
	{
		[winetricksWaitWheel startAnimation:self];
		[winetricksOutlineView setEnabled:NO];
		[winetricksCustomLine setEnabled:NO];
	}
	else
	{
		[winetricksWaitWheel stopAnimation:self];
        
		// Set the correct state for elements that depend on the Custom checkbox
		[self winetricksCustomCommandToggled:winetricksCustomCheckbox];
	}
}
- (void)runWinetrick
{
	@autoreleasepool
    {
        NSString* wineskinLauncherPath = [NSPathUtilities wineskinLauncherBinForPortAtPath:self.wrapperPath];
        
		winetricksDone = NO;
		// loop while winetricksDone is NO
        NSMutableArray* winetricksArgs = [@[@"WSS-winetricks"] mutableCopy];
		if ([winetricksCustomCheckbox state])
        {
            NSCharacterSet* separators = [NSCharacterSet whitespaceAndNewlineCharacterSet];
            NSArray* winetricksCommands = [[winetricksCustomLine stringValue] componentsSeparatedByCharactersInSet:separators];
            [winetricksArgs addObjectsFromArray:winetricksCommands];
            [winetricksArgs removeObject:@""];
        }
		else
        {
			[winetricksArgs addObjectsFromArray:[[self winetricksSelectedList] allKeys]];
        }
        [self systemCommand:wineskinLauncherPath withArgs:winetricksArgs];
		winetricksDone = YES;
        
		// Remove installed and cached packages lists since they need to be rebuilt
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Contents/Resources/winetricksInstalled.plist",self.wrapperPath]];
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/winetricks/winetricksCached.plist", [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0]]];
		usleep(500000); // Wait just a little, to make sure logs aren't overwritten before updateWinetrickOutput is done
		[self winetricksRefreshButtonPressed:self];
		[self winetricksSelectNoneButtonPressed:self];
		return;
	}
}
- (void)doTheDangUpdate
{
	@autoreleasepool
    {
	// update text area with Winetricks log
		NSArray *winetricksOutput = [[NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@/Contents/Resources/Logs/Winetricks.log",self.wrapperPath] encoding:NSUTF8StringEncoding] componentsSeparatedByString:@"\n"];
		[winetricksOutputText setEditable:YES];
		[winetricksOutputText setString:@""];
		for (NSString *item in winetricksOutput)
			if (!([item hasPrefix:@"XIO:"]) && !([item hasPrefix:@"      after"]))
				[winetricksOutputText insertText:[NSString stringWithFormat:@"%@\n",item]];
		[winetricksOutputText setEditable:NO];
	}
}
- (void)winetricksWriteFinished
{
	@autoreleasepool
    {
		[winetricksOutputText setEditable:YES];
		if (winetricksCanceled)
        {
            [winetricksOutputText insertText:@"\n\n Winetricks CANCELED!!\nIt is possible that there are now problems with the wrapper, or other shell processes may have accidently been affected as well.  Usually its best to not cancel Winetricks, but in many cases it will not hurt.  You may need to refresh the wrapper, or in bad cases do a rebuild.\n\n"];
        }
		[winetricksOutputText insertText:@"\n\n Winetricks Commands Finished!!\n\n"];
		[winetricksOutputText setEditable:NO];
	}
}
- (void)updateWinetrickOutput
{
	@autoreleasepool
    {
		while (!winetricksDone)
		{
			//need the main thread to do the window update
			[self performSelectorOnMainThread:@selector(doTheDangUpdate) withObject:self waitUntilDone:YES]; 
			sleep(1);
		}
		// update text area with Winetricks log for last time, to make sure everything is there.
		[self performSelectorOnMainThread:@selector(doTheDangUpdate) withObject:self waitUntilDone:YES];
		// Write a finished statement since Winetricks doesn't seem to want to
		[self performSelectorOnMainThread:@selector(winetricksWriteFinished) withObject:self waitUntilDone:YES];
		[self setWinetricksBusy:NO];
	}
}
- (NSArray *)makePIDArray:(NSString *)processToLookFor
{
	NSString *resultString = [NSString stringWithFormat:@"00000\n%@",[self systemCommandWithOutputReturned:[NSString stringWithFormat:@"ps axc|awk \"{if (\\$5==\\\"%@\\\") print \\$1}\"",processToLookFor]]];
	return [resultString componentsSeparatedByString:@"\n"];
}

//*********** CEXE
- (IBAction)createCustomExeLauncherButtonPressed:(id)sender
{
    NSString* portIconPath = [NSString stringWithFormat:@"%@/Contents/Resources/Wineskin.icns",self.wrapperPath];
	NSImage *theImage = [[NSImage alloc] initByReferencingFile:portIconPath];
	[cEXEIconImageView setImage:theImage];
	[cEXEWindow makeKeyAndOrderFront:self];
	[advancedWindow orderOut:self];
}
- (IBAction)cEXESaveButtonPressed:(id)sender
{
	//make sure name and exe fields are not blank
	//replace common symbols...
    NSString* filename = cEXENameToUseTextField.stringValue;
    filename = [filename stringByReplacingOccurrencesOfString:@"&" withString:@"and"];
    filename = [filename stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"!#$%%^*()+=|\\?<>;:@"]];
    
	if (filename.length == 0)
	{
        if (cEXENameToUseTextField.stringValue.length > 0)
        {
            [NSAlert showAlertOfType:NSAlertTypeError withMessage:@"Your name contains only invalid characters!"];
        }
        else
        {
            [NSAlert showAlertOfType:NSAlertTypeError withMessage:@"You must type in a name to use!"];
        }
        
		return;
	}
    
    [cEXENameToUseTextField setStringValue:filename];
    
	
    if ([[cEXEWindowsExeTextField stringValue] isEqualToString:@""])
	{
        [NSAlert showAlertOfType:NSAlertTypeError withMessage:@"You must choose an executable to run!"];
        return;
	}
    
	//make sure file doesn't exist, if it does, error and return
	if ([fm fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.app",self.wrapperPath,[cEXENameToUseTextField stringValue]]])
	{
        [NSAlert showAlertOfType:NSAlertTypeError withMessage:@"That name is already in use, please choose a different name."];
		return;
	}
	
	//show busy window
	[busyWindow makeKeyAndOrderFront:self];
	//hide cEXE window
	[cEXEWindow orderOut:self];
	
    NSString* customExeName = cEXENameToUseTextField.stringValue;
    [NSWineskinPortDataWriter addCustomExeWithName:customExeName version:@"1.0"
                                              icon:cEXEIconImageView.image
                                              path:cEXEWindowsExeTextField.stringValue
                                      atPortAtPath:self.wrapperPath];
    
    NSString* customExePath = [NSString stringWithFormat:@"%@/%@.app",self.wrapperPath,customExeName];
    NSPortManager* customExePortManager = [NSPortManager managerWithCustomExePath:customExePath];
    
    //fix gamma entry
	if ([gammaSlider doubleValue] == 60.0)
    {
        [customExePortManager setPlistObject:@"default" forKey:@"Gamma Correction"];
    }
	else
    {
		NSString* gamma = [NSString stringWithFormat:@"%1.2f",(100.0-([gammaSlider doubleValue]-60))/100];
        [customExePortManager setPlistObject:gamma forKey:@"Gamma Correction"];
    }
    
    int colorInt = [[[[cEXEColorDepth selectedItem] title] stringByReplacingOccurrencesOfString:@" bit" withString:@""] intValue];
    NSString* sleep = [[[cEXESwitchPause selectedItem] title] stringByReplacingOccurrencesOfString:@" sec." withString:@""];
    
    BOOL vd = !([cEXEFullscreenRootlessToggleRootlessButton intValue] && [cEXENormalWindowsVirtualDesktopToggleNormalWindowsButton intValue]);
    NSString* resolution = [cEXEFullscreenRootlessToggleRootlessButton intValue] ? [[cEXEVirtualDesktopResolution selectedItem] title] :
                                                                                   [[cEXEFullscreenResolution     selectedItem] title];
    
    [NSWineskinPortDataWriter setAutomaticScreenOptions:([cEXEautoOrOvverrideDesktopToggleAutomaticButton intValue] == 1)
                                             fullscreen:[cEXEFullscreenRootlessToggleRootlessButton intValue]
                                         virtualDesktop:vd resolution:resolution colors:colorInt sleep:sleep atPort:portManager];
    
    [customExePortManager synchronizePlist];
    
	//give done message
    [NSAlert showAlertOfType:NSAlertTypeSuccess withMessage:@"The Custom Exe Launcher has been made and can be found just inside the wrapper along with Wineskin.app.\n\nIf you want to be able to access it from outside of the app, just make and use an alias to it."];
    
	//show advanced window
	[advancedWindow makeKeyAndOrderFront:self];
	//hide busy window
	[busyWindow orderOut:self];
}
- (IBAction)cEXECancelButtonPressed:(id)sender
{
	[advancedWindow makeKeyAndOrderFront:self];
	[cEXEWindow orderOut:self];
}
- (IBAction)cEXEBrowseButtonPressed:(id)sender
{
	//NSOpenPanel *panel = [NSOpenPanel openPanel];
	NSOpenPanel *panel = [[NSOpenPanel alloc] init];
	[panel setWindowTitle:NSLocalizedString(@"Please choose the file that should run",nil)];
	[panel setPrompt:NSLocalizedString(@"Choose",nil)];
	[panel setCanChooseDirectories:NO];
	[panel setCanChooseFiles:YES];
	[panel setAllowsMultipleSelection:NO];
	[panel setExtensionHidden:NO];
	[panel setTreatsFilePackagesAsDirectories:YES];
    [panel setAllowedFileTypes:EXTENSIONS_COMPATIBLE_WITH_WINESKIN_WRAPPER];
    [panel setInitialDirectory:self.cDrivePathForWrapper];
    
    //open browse window to get .exe choice
    if ([panel runModal] == 0)
    {
        return;
    }
    
    NSString* selectedMainExe = [[[panel URLs] objectAtIndex:0] path];
    NSString* windowsPath = [NSExeSelection selectAsMainExe:selectedMainExe forPort:self.wrapperPath];
    [cEXEWindowsExeTextField setStringValue:windowsPath];
}
- (IBAction)cEXEIconBrowseButtonPressed:(id)sender
{
	//NSOpenPanel *panel = [NSOpenPanel openPanel];
	NSOpenPanel *panel = [[NSOpenPanel alloc] init];
	[panel setWindowTitle:NSLocalizedString(@"Please choose the .icns file to use in the wrapper",nil)];
	[panel setPrompt:NSLocalizedString(@"Choose",nil)];
	[panel setCanChooseDirectories:NO];
	[panel setCanChooseFiles:YES];
	[panel setAllowsMultipleSelection:NO];
	[panel setExtensionHidden:NO];
	[panel setTreatsFilePackagesAsDirectories:YES];
    [panel setInitialDirectory:@"/"];
	
	if ([panel runModal] == 0)
	{
		return;
	}
    
    NSString* newIconPath = [[[panel URLs] objectAtIndex:0] path];
    [cEXEIconImageView loadIconFromFile:newIconPath];
}
- (IBAction)cEXEAutomaticButtonPressed:(id)sender
{
	[cEXEFullscreenRootlessToggle setEnabled:NO];
	[cEXENormalWindowsVirtualDesktopToggle setEnabled:NO];
	[cEXEVirtualDesktopResolution setEnabled:NO];
	[cEXEFullscreenResolution setEnabled:NO];
	[cEXEColorDepth setEnabled:NO];
	[cEXESwitchPause setEnabled:NO];
}
- (IBAction)cEXEOverrideButtonPressed:(id)sender
{
	[cEXEFullscreenRootlessToggle setEnabled:YES];
	[cEXENormalWindowsVirtualDesktopToggle setEnabled:YES];
	[cEXEVirtualDesktopResolution setEnabled:YES];
	[cEXEFullscreenResolution setEnabled:YES];
	[cEXEColorDepth setEnabled:YES];
	[cEXESwitchPause setEnabled:YES];
}
- (IBAction)cEXERootlessButtonPressed:(id)sender
{
	[cEXEFullscreenRootlesToggleTabView selectFirstTabViewItem:self];
}
- (IBAction)cEXEFullscreenButtonPressed:(id)sender
{
	[cEXEFullscreenRootlesToggleTabView selectLastTabViewItem:self];
}
- (IBAction)cEXEGammaChanged:(id)sender
{
	if ([cEXEGammaSlider doubleValue] != 60.0)
		[self systemCommand:[NSString stringWithFormat:@"%@/Contents/Resources/WSGamma",[[NSBundle mainBundle] bundlePath]] withArgs:[NSArray arrayWithObjects:[NSString stringWithFormat:@"%1.2f",(100.0-([cEXEGammaSlider doubleValue]-60))/100],nil]];
}
- (IBAction)changeEngineUsedButtonPressed:(id)sender
{
	//set the list of engines
	[self setEngineList:@""];
	//show Change Engine Window
	[changeEngineWindow makeKeyAndOrderFront:self];
	//order out advanced window
	[advancedWindow orderOut:self];
}
- (void)setEngineList:(NSString *)theFilter
{
	//get installed engines
	NSMutableArray *installedEnginesList = [NSWineskinEngine getListOfLocalEngines];
	
    //update engine list in change engine window
	[changeEngineWindowPopUpButton removeAllItems];
    [changeEngineWindowPopUpButton addItemsWithTitles:installedEnginesList];
	
    //disable/enable OK button depending if any engines in the list
    [engineWindowOkButton setEnabled:installedEnginesList.count > 0];
    
	//** Show current installed engine version
	// read in current engine name from first line of version file in wswine.bundle
    NSString* versionFilePath = [NSString stringWithFormat:@"%@/version",self.wswineBundlePath];
	if ([fm fileExistsAtPath:versionFilePath])
	{
		NSString *currentEngineVersion = [NSString stringWithContentsOfFile:versionFilePath encoding:NSUTF8StringEncoding];
        
        //change currentVersionTextField to engine name
		[currentVersionTextField setStringValue:[currentEngineVersion getFragmentAfter:nil andBefore:@"\n"]];
	}
}
- (IBAction)changeEngineUsedOkButtonPressed:(id)sender
{
	//make sure 7za exists,if not prompt error and exit...
	if (!([fm fileExistsAtPath:BINARY_7ZA]))
	{
        [NSAlert showAlertOfType:NSAlertTypeError withMessage:@"Cannot continue... files missing. Please try reinstalling an engine manually, or running Wineskin Winery. Either should attempt to fix the problem."];
        
		//order in advanced window
		[advancedWindow makeKeyAndOrderFront:self];
		//order out change engine window
		[changeEngineWindow orderOut:self];
		return;
	}
    
	//show busy window
	[busyWindow makeKeyAndOrderFront:self];
	//hide change engine window
	[changeEngineWindow orderOut:self];
	
    //uncompress engine
    NSString* newEngineName = [[changeEngineWindowPopUpButton selectedItem] title];
    NSString* wswineBundlePath = self.wswineBundlePath;
    
	system([[NSString stringWithFormat:@"\"%@\" x \"%@/%@.tar.7z\" \"-o/%@\"", BINARY_7ZA,WINESKIN_LIBRARY_ENGINES_FOLDER,newEngineName,WINESKIN_LIBRARY_ENGINES_FOLDER] UTF8String]);
	system([[NSString stringWithFormat:@"/usr/bin/tar -C \"%@\" -xf \"%@/%@.tar\"",WINESKIN_LIBRARY_ENGINES_FOLDER,WINESKIN_LIBRARY_ENGINES_FOLDER,newEngineName] UTF8String]);
	//remove tar
	[fm removeItemAtPath:[NSString stringWithFormat:@"%@/%@.tar",WINESKIN_LIBRARY_ENGINES_FOLDER,newEngineName]];
	//delete old engine
	[fm removeItemAtPath:wswineBundlePath];
	//put engine in wrapper
	[fm moveItemAtPath:[NSString stringWithFormat:@"%@/wswine.bundle",WINESKIN_LIBRARY_ENGINES_FOLDER] toPath:wswineBundlePath];
	[self systemCommand:@"/bin/chmod" withArgs:@[@"777",wswineBundlePath]];
	[self installEngine];
	//refresh wrapper
	[self systemCommand:[NSPathUtilities wineskinLauncherBinForPortAtPath:self.wrapperPath] withArgs:@[@"WSS-wineboot"]];
	[self loadAllData];
    
	//order in advanced window
	[advancedWindow makeKeyAndOrderFront:self];
	//hide busy window
	[busyWindow orderOut:self];
}
- (IBAction)changeEngineUsedCancelButtonPressed:(id)sender
{
	//order in advanced window
	[advancedWindow makeKeyAndOrderFront:self];
	//order out change engine window
	[changeEngineWindow orderOut:self];
}
- (IBAction)changeEngineSearchFilter:(id)sender
{
	[self setEngineList:[[sender stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
}
-(void)replaceFile:(NSString*)filePath withVersionFromMasterWrapper:(NSString*)masterWrapperName
{
    NSString* copyFrom = [NSString stringWithFormat:@"%@/%@%@",WINESKIN_LIBRARY_WRAPPER_FOLDER,masterWrapperName,filePath];
    NSString* copyTo = [NSString stringWithFormat:@"%@%@",self.wrapperPath,filePath];
    if ([fm fileExistsAtPath:copyTo]) [fm removeItemAtPath:copyTo];
    [fm copyItemAtPath:copyFrom toPath:copyTo];
}
- (IBAction)updateWrapperButtonPressed:(id)sender
{
	//get current version from Info.plist, change spaces to - to it matches master wrapper naming
	NSString *currentWrapperVersion = [portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_WINESKIN_VERSION];
	currentWrapperVersion = [currentWrapperVersion stringByReplacingOccurrencesOfString:@" " withString:@"-"];
	currentWrapperVersion = [NSString stringWithFormat:@"%@.app",currentWrapperVersion];
    
	//get new master wrapper name
	NSArray *files = [fm contentsOfDirectoryAtPath:WINESKIN_LIBRARY_WRAPPER_FOLDER];
	
	if (files.count != 1)
	{
        [NSAlert showAlertOfType:NSAlertTypeError withMessage:@"There is an error with the installation of your Master Wrapper. Please update your Wrapper in Wineskin Winery (a manual install of a wrapper for Wineskin Winery will work too)."];
		return;
	}
	
	//if master wrapper and current wrapper have same versions, prompt its already updated and return
    NSString *masterWrapperName = [files firstObject];
    if ([currentWrapperVersion isEqualToString:masterWrapperName])
	{
        if ([NSAlert showBooleanAlertOfType:NSAlertTypeWarning withMessage:@"Your wrapper version matches the master wrapper version... no update needed. Do you want to force an update?" withDefault:NO] == false)
        {
            return;
        }
	}
    
	//confirm wrapper change
    if ([NSAlert showBooleanAlertOfType:NSAlertTypeWarning withMessage:@"Are you sure you want to do this update? It will change out the wrappers main Wineskin files with newer copies from whatever Master Wrapper you have installed with Wineskin Winery. The following files/folders will be replaced in the wrapper:\nWineskin.app\nContents/MacOS\nContents/Frameworks\nContents/Resources/English.lproj/MainMenu.nib\nContents/Resources/English.lproj/main.nib" withDefault:NO] == false)
    {
        return;
    }
    
	//show busy window
	[busyWindow makeKeyAndOrderFront:self];
	//hide advanced window
	[advancedWindow orderOut:self];
	
    //if WineskinEngine.bundle exists, convert it to WS8 and update wrapper
    NSString* wineskinEngineBundlePath = [NSString stringWithFormat:@"%@/Contents/Resources/WineskinEngine.bundle",self.wrapperPath];
    NSString* wswineBundlePath = self.wswineBundlePath;
	if ([fm fileExistsAtPath:wineskinEngineBundlePath])
	{
		//if ICE give warning message that you'll need to install an engine yourself
        NSString* wineskinEngineBundleX11Path = [NSString stringWithFormat:@"%@/X11",wineskinEngineBundlePath];
		if (![fm fileExistsAtPath:wineskinEngineBundleX11Path] ||
           [[[fm attributesOfItemAtPath:wineskinEngineBundleX11Path error:nil] fileType] isEqualToString:@"NSFileTypeSymbolicLink"])
		{
			//delete WineskinEngine.bundle
            [NSAlert showAlertOfType:NSAlertTypeWarning withMessage:@"Warning, ICE engine detected. Engine will not be converted, you must choose a new WS8+ engine manually later (Change Engine in Wineskin.app)."];
			[fm removeItemAtPath:wineskinEngineBundlePath];
		}
        
		//if wswine.bundle already exists, just remove WineskinEngine.bundle
		if ([fm fileExistsAtPath:wswineBundlePath])
		{
			[fm removeItemAtPath:wineskinEngineBundlePath];
		}
		else
		{
            NSString* wsConfigPath = [NSString stringWithFormat:@"%@/WSConfig.txt",wineskinEngineBundleX11Path];
			NSString *currentEngineVersion = [NSString stringWithContentsOfFile:wsConfigPath encoding:NSUTF8StringEncoding];
            currentEngineVersion = [currentEngineVersion getFragmentAfter:nil andBefore:@"\n"];
            
            [fm removeItemAtPath:wineskinEngineBundleX11Path];
			[self systemCommand:@"/bin/chmod" withArgs:@[@"777",[NSString stringWithFormat:@"%@/Wine",wineskinEngineBundlePath]]];
            
			//put version in version file
			if ([currentEngineVersion matchesWithRegex:REGEX_WINESKIN_CONVERTABLE_OLD_WINE_ENGINE])
				currentEngineVersion = [currentEngineVersion substringFromIndex:3];
			
            currentEngineVersion = [NSString stringWithFormat:@"WS8%@",currentEngineVersion];
            [currentEngineVersion writeToFile:[NSString stringWithFormat:@"%@/Wine/version",wineskinEngineBundlePath]
                                   atomically:YES encoding:NSUTF8StringEncoding];
            
            [fm createDirectoryAtPath:[NSString stringWithFormat:@"%@/Contents/Frameworks",self.wrapperPath] withIntermediateDirectories:YES];
			[fm moveItemAtPath:[NSString stringWithFormat:@"%@/Wine",wineskinEngineBundlePath] toPath:wswineBundlePath];
			[fm removeItemAtPath:wineskinEngineBundlePath];
		}
	}
    
	//delete old MacOS, and copy in new
    [self replaceFile:@"/Contents/MacOS" withVersionFromMasterWrapper:masterWrapperName];
	
	//delete old WineskinLauncher.nib
    NSString* oldNibPath = [NSString stringWithFormat:@"%@/Contents/Resources/WineskinLauncher.nib",self.wrapperPath];
    if ([fm fileExistsAtPath:oldNibPath]) [fm removeItemAtPath:oldNibPath];
    
    //copy new MainMenu.nib
    [self replaceFile:@"/Contents/Resources/English.lproj/MainMenu.nib" withVersionFromMasterWrapper:masterWrapperName];
	
    //edit Info.plist to new wrapper version, replace - with spaces, and dump .app
	[portManager setPlistObject:[[masterWrapperName stringByReplacingOccurrencesOfString:@".app" withString:@""] stringByReplacingOccurrencesOfString:@"-" withString:@" "] forKey:WINESKIN_WRAPPER_PLIST_KEY_WINESKIN_VERSION];
	
    //Make sure new keys are added to the old Info.plist
	NSMutableDictionary *newPlistDictionary = [NSMutableDictionary mutableDictionaryWithContentsOfFile:[NSString stringWithFormat:@"%@/%@/Contents/Info.plist",WINESKIN_LIBRARY_WRAPPER_FOLDER,masterWrapperName]];
	[newPlistDictionary addEntriesFromDictionary:portManager.plist];
    [portManager setPlist:newPlistDictionary];
    [portManager synchronizePlist];
	[self systemCommand:@"/bin/chmod" withArgs:@[@"777",[NSString stringWithFormat:@"%@/Contents/Info.plist",self.wrapperPath]]];
	
    //force delete Wineskin.app and copy in new
    [self replaceFile:@"/Wineskin.app" withVersionFromMasterWrapper:masterWrapperName];
	
	//move wswine.bundle out of Frameworks
    NSString* wswineBundleOriginalPath = self.wswineBundlePath;
    NSString* wswineBundleTempPath = @"/tmp/wswineWSTEMP.bundle";
	[fm moveItemAtPath:wswineBundleOriginalPath toPath:wswineBundleTempPath];
    
	//replace Frameworks
    [self replaceFile:@"/Contents/Frameworks" withVersionFromMasterWrapper:masterWrapperName];
    
	//move wswine.bundle back into Frameworks
	[fm moveItemAtPath:wswineBundleTempPath toPath:wswineBundleOriginalPath];
    
	//change out main.nib
    [self replaceFile:@"/Contents/Resources/English.lproj/main.nib" withVersionFromMasterWrapper:masterWrapperName];
    
	//open new Wineskin.app
	[self systemCommand:@"/usr/bin/open" withArgs:@[[NSString stringWithFormat:@"%@/Wineskin.app",self.wrapperPath]]];
    
	//close program
	[NSApp terminate:sender];
}
- (IBAction)logsButtonPressed:(id)sender
{
    NSString* logsFolder = [NSString stringWithFormat:@"%@/Contents/Resources/Logs",self.wrapperPath];
	[self systemCommand:@"/usr/bin/open" withArgs:@[@"-e",[NSString stringWithFormat:@"%@/LastRunX11.log",logsFolder]]];
	[self systemCommand:@"/usr/bin/open" withArgs:@[@"-e",[NSString stringWithFormat:@"%@/LastRunWine.log",logsFolder]]];
}
- (IBAction)commandLineShellButtonPressed:(id)sender
{
	[NSThread detachNewThreadSelector:@selector(runCmd) toTarget:self withObject:nil];
}
- (void)runCmd
{
	@autoreleasepool
    {
		[self disableButtons];
		[self systemCommand:[NSPathUtilities wineskinLauncherBinForPortAtPath:self.wrapperPath] withArgs:@[@"WSS-cmd"]];
		[self enableButtons];
	}
}
//*************************************************************
//*********************** OVERRIDES ***************************
//*************************************************************
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return YES;
}
- (BOOL)windowShouldClose:(id)sender
{
	if (disableXButton)
	{
		return NO;
	}
	else if (sender==window)
	{
		//don't do anything... yet
	}
	else if (sender==advancedWindow)
	{
		[self saveAllData];
	}
	else if (sender==screenOptionsWindow)
	{
		[self saveScreenOptionsData];
		if (usingAdvancedWindow)
			[advancedWindow makeKeyAndOrderFront:self];
		else
			[window makeKeyAndOrderFront:self];
	}
	else if (sender==winetricksWindow)
	{
		[self winetricksDoneButtonPressed:sender];
		return NO;
	}
	else if (sender==installerWindow)
	{
		if (usingAdvancedWindow)
			[advancedWindow makeKeyAndOrderFront:self];
		else
			[window makeKeyAndOrderFront:self];
	}
	[sender orderOut:self];
	return NO;
}
- (NSApplicationTerminateReply)applicationShouldTerminate:(id)sender
{
	[self saveAllData];
	[self saveScreenOptionsData];
	return YES;
}
- (void)tabView:(NSTabView *)tabView didSelectTabViewItem:(NSTabViewItem *)tabViewItem
{
	[self saveAllData];
}
//*************************************************************
//******************* Extensions Window ***********************
//*************************************************************
- (IBAction)extSaveButtonPressed:(id)sender
{
	if ([[extExtensionTextField stringValue] isEqualToString:@""] || [[extCommandTextField stringValue] isEqualToString:@""])
	{
        [NSAlert showAlertOfType:NSAlertTypeError withMessage:@"You left an entry field blank..."];
		return;
	}
	
    [busyWindow makeKeyAndOrderFront:self];
	[extAddEditWindow orderOut:self];
    
	//edit the system.reg to make sure Associations exist correctly, and add them if they do not.
	//make sure the extension doesn't have dots
    NSString* extension = [[extExtensionTextField stringValue] stringByReplacingOccurrencesOfString:@"." withString:@""];
	
    //fix stringToWrite to escape quotes and backslashes before writing
    NSString *stringToWrite = [extCommandTextField stringValue];
    stringToWrite = [stringToWrite stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    stringToWrite = [stringToWrite stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
    
    NSString* regSoftwareClassesExtension = [NSString stringWithFormat:@"[Software\\\\Classes\\\\.%@]",extension];
    NSString* regSoftwareClassesExtensionShellOpenCommand = [NSString stringWithFormat:@"[Software\\\\Classes\\\\%@file\\\\shell\\\\open\\\\command]",extension];
    
    NSMutableString* registry1 = [[portManager getRegistryEntry:regSoftwareClassesExtension fromRegistryFileNamed:SYSTEM_REG] mutableCopy];
    NSMutableString* registry2 = [[portManager getRegistryEntry:regSoftwareClassesExtensionShellOpenCommand
                                          fromRegistryFileNamed:SYSTEM_REG] mutableCopy];
    
    [portManager setValue:[NSString stringWithFormat:@"\"%@file\"",extension] forKey:nil atRegistryEntryString:registry1];
    [portManager setValue:[NSString stringWithFormat:@"\"%@\"",stringToWrite] forKey:nil atRegistryEntryString:registry2];
    
    [portManager deleteRegistry:regSoftwareClassesExtension fromRegistryFileNamed:SYSTEM_REG];
    [portManager deleteRegistry:regSoftwareClassesExtensionShellOpenCommand fromRegistryFileNamed:SYSTEM_REG];
    
    [portManager addRegistry:[NSString stringWithFormat:@"%@\n%@\n",regSoftwareClassesExtension,registry1] fromRegistryFileNamed:SYSTEM_REG];
    [portManager addRegistry:[NSString stringWithFormat:@"%@\n%@\n",regSoftwareClassesExtensionShellOpenCommand,registry2] fromRegistryFileNamed:SYSTEM_REG];
    
	//add to Info.plist
	NSMutableArray *assArray = [[[portManager plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_ASSOCIATIONS] componentsSeparatedByString:@" "] mutableCopy];
    if (![assArray containsObject:extension]) [assArray addObject:extension];
	NSString *newExtString = [assArray componentsJoinedByString:@" "];
	[portManager setPlistObject:newExtString forKey:WINESKIN_WRAPPER_PLIST_KEY_ASSOCIATIONS];
    [portManager synchronizePlist];
	
	[self loadAllData];
	[advancedWindow makeKeyAndOrderFront:self];
	[busyWindow orderOut:self];
}
- (IBAction)extCancelButtonPressed:(id)sender
{
	[self loadAllData];
	[advancedWindow makeKeyAndOrderFront:self];
	[extAddEditWindow orderOut:self];
}

//*************************************************************
//************** Modify Mappings window ***********************
//*************************************************************
- (IBAction)modifyMappingsSaveButtonPressed:(id)sender
{
	[portManager setPlistObject:[modifyMappingsMyDocumentsTextField stringValue] forKey:@"Symlink My Documents"];
	[portManager setPlistObject:[modifyMappingsDesktopTextField stringValue]     forKey:@"Symlink Desktop"];
	[portManager setPlistObject:[modifyMappingsMyVideosTextField stringValue]    forKey:@"Symlink My Videos"];
	[portManager setPlistObject:[modifyMappingsMyMusicTextField stringValue]     forKey:@"Symlink My Music"];
	[portManager setPlistObject:[modifyMappingsMyPicturesTextField stringValue]  forKey:@"Symlink My Pictures"];
    [portManager setPlistObject:[modifyMappingsDownloadsTextField stringValue]  forKey:@"Symlink Downloads"];
    [portManager synchronizePlist];
	
	[advancedWindow makeKeyAndOrderFront:self];
	[modifyMappingsWindow orderOut:self];
}

- (IBAction)modifyMappingsCancelButtonPressed:(id)sender
{
	[advancedWindow makeKeyAndOrderFront:self];
	[modifyMappingsWindow orderOut:self];
}

- (IBAction)modifyMappingsResetButtonPressed:(id)sender
{
	[modifyMappingsMyDocumentsTextField setStringValue:@"$HOME/Documents"];
	[modifyMappingsDesktopTextField     setStringValue:@"$HOME/Desktop"];
	[modifyMappingsMyVideosTextField    setStringValue:@"$HOME/Movies"];
	[modifyMappingsMyMusicTextField     setStringValue:@"$HOME/Music"];
	[modifyMappingsMyPicturesTextField  setStringValue:@"$HOME/Pictures"];
    [modifyMappingsDownloadsTextField  setStringValue:@"$HOME/Downloads"];

}

-(NSString*)newPathForMappingOfFolder:(NSString*)folder
{
    NSOpenPanel *panel = [[NSOpenPanel alloc] init];
    [panel setWindowTitle:[NSString stringWithFormat:NSLocalizedString(@"Please choose the Folder \"%@\" should map to",nil),folder]];
    [panel setPrompt:NSLocalizedString(@"Choose",nil)];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setTreatsFilePackagesAsDirectories:YES];
    [panel setShowsHiddenFiles:YES];
    [panel setInitialDirectory:@"/"];
    
    if ([panel runModal] == 0)
    {
        return nil;
    }
    
    return [[[[panel URLs] objectAtIndex:0] path] stringByReplacingOccurrencesOfString:NSHomeDirectory() withString:@"$HOME"];
}
- (IBAction)modifyMappingsMyDocumentsBrowseButtonPressed:(id)sender
{
    NSString* newPath = [self newPathForMappingOfFolder:@"My Documents"];
	
    if (newPath)
    {
        [modifyMappingsMyDocumentsTextField setStringValue:newPath];
    }
}

- (IBAction)modifyMappingsMyDesktopBrowseButtonPressed:(id)sender
{
    NSString* newPath = [self newPathForMappingOfFolder:@"Desktop"];
    
    if (newPath)
    {
        [modifyMappingsDesktopTextField setStringValue:newPath];
    }
}

- (IBAction)modifyMappingsMyVideosBrowseButtonPressed:(id)sender
{
    NSString* newPath = [self newPathForMappingOfFolder:@"My Videos"];
    
    if (newPath)
    {
        [modifyMappingsMyVideosTextField setStringValue:newPath];
    }
}

- (IBAction)modifyMappingsMyMusicBrowseButtonPressed:(id)sender
{
    NSString* newPath = [self newPathForMappingOfFolder:@"My Music"];
    
    if (newPath)
    {
        [modifyMappingsMyMusicTextField setStringValue:newPath];
    }
}

- (IBAction)modifyMappingsMyPicturesBrowseButtonPressed:(id)sender
{
    NSString* newPath = [self newPathForMappingOfFolder:@"My Pictures"];
    
    if (newPath)
    {
        [modifyMappingsMyPicturesTextField setStringValue:newPath];
    }
}
- (IBAction)modifyMappingsDownloadsBrowseButtonPressed:(id)sender
{
    NSString* newPath = [self newPathForMappingOfFolder:@"Downloads"];
    
    if (newPath)
    {
        [modifyMappingsDownloadsTextField setStringValue:newPath];
    }
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

//*************************************************************
//**************************** ICE ****************************
//*************************************************************
- (void)installEngine
{
	NSString *theSystemCommand = [NSString stringWithFormat: @"\"%@\" WSS-InstallICE",
                                  [NSPathUtilities wineskinLauncherBinForPortAtPath:self.wrapperPath]];
	system([theSystemCommand UTF8String]);
}
//*************************************************************
//***** NSOutlineViewDataSource (winetricks) ******************
//*************************************************************
/* Required methods */
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)childIndex ofItem:(id)item
{
	if (!winetricksDone)
		return nil;
	if (outlineView != winetricksOutlineView)
		return nil;
	if (!item)
		item = winetricksFilteredList;
	NSUInteger count = ([item valueForKey:WINETRICK_NAME] == nil ? [item count] : 0); // Set count to zero if the item is a package
	if (count <= childIndex)
		return nil;
	return [item objectForKey:[[[item allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] objectAtIndex:childIndex]];
}
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	if (!winetricksDone)
		return NO;
	if (outlineView != winetricksOutlineView)
		return NO;
	if ([item valueForKey:WINETRICK_NAME] != nil)
		return NO;
	return YES;
}
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if (!winetricksDone)
		return 0;
	if (outlineView != winetricksOutlineView)
		return 0;
	if ([item valueForKey:WINETRICK_NAME] != nil)
		return 0;
	return [(item ? item : [self winetricksFilteredList]) count];
}
- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if (!winetricksDone)
		return nil;
	if (outlineView != winetricksOutlineView)
		return nil;
	if ((tableColumn == winetricksTableColumnRun
	     || tableColumn == winetricksTableColumnInstalled
	     || tableColumn == winetricksTableColumnDownloaded)
	    && [item valueForKey:WINETRICK_NAME] == nil)
		return @"";

	if (tableColumn == winetricksTableColumnRun)
	{
		NSNumber *thisEntry = [[self winetricksSelectedList] valueForKey:[item valueForKey:WINETRICK_NAME]];
		if (thisEntry == nil)
			return [NSNumber numberWithBool:NO];
		return thisEntry;
	}
	else if (tableColumn == winetricksTableColumnInstalled)
	{
		for (NSString *eachEntry in [self winetricksInstalledList])
			if ([eachEntry isEqualToString:[item valueForKey:WINETRICK_NAME]])
				return @"\u2713"; // Check mark character
		return @"";
	}
	else if (tableColumn == winetricksTableColumnDownloaded)
	{
		for (NSString *eachEntry in [self winetricksCachedList])
			if ([eachEntry isEqualToString:[item valueForKey:WINETRICK_NAME]])
				return @"\u2713"; // Check mark character
		return @"";
	}
	else if (tableColumn == winetricksTableColumnName)
	{
		if ([item valueForKey:WINETRICK_NAME] != nil)
			return [item valueForKey:WINETRICK_NAME];
		NSDictionary *parentDict = [outlineView parentForItem:item];
		return [[(parentDict ? parentDict : [self winetricksFilteredList]) allKeysForObject:item] objectAtIndex:0];
	}
	else if (tableColumn == winetricksTableColumnDescription)
	{
		if ([item valueForKey:WINETRICK_DESCRIPTION] != nil)
			return [item valueForKey:WINETRICK_DESCRIPTION];
		return @"";
	}
	return nil;
}
/* Optional Methods */
- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if (!winetricksDone)
		return;
	if (outlineView != winetricksOutlineView)
		return;
	if (tableColumn != winetricksTableColumnRun)
		return;
	if ([item valueForKey:WINETRICK_NAME] == nil)
		return;
	[[self winetricksSelectedList] setValue:object forKey:[item valueForKey:WINETRICK_NAME]];
}
/* Delegate */
- (NSCell *)outlineView:(NSOutlineView *)outlineView dataCellForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if (!winetricksDone)
		return nil;
	if (tableColumn == winetricksTableColumnRun && [item valueForKey:WINETRICK_NAME] == nil)
		return [[NSTextFieldCell alloc] init];
	return [tableColumn dataCellForRow:[outlineView rowForItem:item]];
}
@end
