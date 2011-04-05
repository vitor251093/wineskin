//  Wineskin.m
//  Copyright 2011 by The Wineskin Project and doh123@doh123.com All rights reserved.
//  Licensed for use under the LGPL <http://www.gnu.org/licenses/lgpl-2.1.txt>

#import <Cocoa/Cocoa.h>
//#include <signal.h>
//#include <inttypes.h>
#include <sys/stat.h>
//#include <ApplicationServices/ApplicationServices.h>

@interface Wineskin : NSObject
{
	NSString *contentsFold;					//contents folder in the wrapper
	NSString *appNameWithPath;				//full path to and including the app name
	NSString *firstPIDFile;					//pid file used to find wineserver pid
	NSString *secondPIDFile;				//pid file used to find wineserver pid
	NSString *wineserverPIDFile;			//pid files holding wineserver of current/last run
	NSString *displayNumberFile;			//pid file holding display number of current/last run
	NSString *infoPlistFile;				//the Info.plist file in the wrapper
	NSString *winePrefix;					//the $WINEPREFIX
	NSString *theDisplayNumber;				//the Display Number to use
	NSString *x11PrefFileName;				//the name of the X11 plist file
	NSString *wineRunLocation;				//path to exe for wine
	NSString *wineRunFile;					//exe file name for wine to run
	NSString *programFlags;					//command line argments to windows exectuable
	BOOL runWithStartExe;					//wether start.exe is being used
	BOOL fullScreenOption;					//wether running fullscreen or rootless (RandR is rootless)
	BOOL useRandR;							//if "Autoamatic" is set in Wineskin.app
	BOOL useGamma;							//wether or not gamma correction will be checked for
	NSString *vdResolution; 				//virtual desktop resolution to be used for rootless or fullscreen
	NSString *gammaCorrection;				//added in gamma correction
	NSString *fullScreenResolutionBitDepth;	//fullscreen bit depth for X server
	NSString *currentResolution; 			//the resolution that was running when the wrapper was started
	int sleepNumber;						//fullscreen resolution switch pause number in seconds
	NSString *wineserverPIDToCheck;			//wineserver PID of last run
	NSString *wineServerPID; 				//wineserver PID of current run
	NSString *x11PID;						//PID of running X server
	NSMutableArray *filesToRun;				//list of files passed in to open
	BOOL debugEnabled;						//set if debug mode is being run, to make logs
	BOOL cexeRun;							//set if runnin from a custom exe launcher
	BOOL nonStandardRun;					//set if a special wine run
	BOOL openingFiles;						//set if we are opening files instead of a program
	NSString *wssCommand;					//should be argv[1], if a special command
	NSString *winetricksCommand;			//should be argv[2] if wssCommand is WSS-winetricks
	NSString *winetricksCommand2;			//should be argv[3] if wssCommand is WSS-winetricks
	NSString *winetrickCommandsList;		//string of commnads for "list" command
	NSString *programNameAndPath;			//directly from the info.plist
	NSString *uLimitNumber;					//read from "max open files" in Info.plist
	NSString *wineDebugLineFromPlist;		//read from "WINEDEBUG=" in Info.plist
	NSString *randrXres;					//holds X res for keyboard shortcut to toggle back to fullscreen mode
	NSString *randrYres;					//holds Y res for keyboard shortcut to toggle back to fullscreen mode
	BOOL killWineskin;						//sets to true if opening files and wineserver was already running, kills extra wineskin
	NSString *cliCustomCommands;			//from CLI Variables entry in info.plist
}
//the main running of the program...
- (void)mainRun:(NSArray *)argv;

//used to change the gamma setting since Xquartz cannot yet
- (void)setGamma:(NSString *)inputValue;

//used to change the global screen resolution for overriding randr
- (void)setResolution:(NSString *)reso;

//returns the current screen resolution
- (NSString *)getResolution;

//use to run a system() call but have the text returned as string
- (NSString *)systemCommand:(NSString *)command;

//Makes an Array with a list of PIDs that match the process name
- (NSArray *)makePIDArray:(NSString *)processToLookFor;

//sets the drive_c/user/Wineskin folder correctly for a run
- (void)setUserFolders:(BOOL)doSymlinks;

//Makes sure the current user owns the winepeefix, or Wine will not run
- (void)fixWinePrefixForCurrentUser;

//Tries to get the GPU info and enter it in the Wine Registry, use before starting Wine
- (void)tryToUseGPUInfo;

//remove GPU info from Registry
- (void)removeGPUInfo;

//starts up WineskinX11 and passes its PID back
- (NSString *)startX11;

//installs ICE files
- (void)installEngine;

//Changes VD Desktop user.reg entries to a given virtual desktop
- (void)setToVirtualDesktop:(NSString *)resolution named:(NSString *)desktopName;

//Changes VD Desktop user.reg entires to not have a virtual desktop
- (void)setToNoVirtualDesktop;

//reads a file and passes back contents as an array of strings
- (NSArray *)readFileToStringArray:(NSString *)theFile;

//writes an array to a normal text file, each entry on a line.
- (void)writeStringArray:(NSArray *)theArray toFile:(NSString *)theFile;

//returns true if pid is running
- (BOOL)pidRunning:(NSString *)pid;

//start wine, return wineserver PID;
- (NSString *)startWine;

//background monitoring while Wine is running
- (void)sleepAndMonitor;

//run when shutting down
- (void)cleanUpAndShutDown:(BOOL)removeSymlinks;

//test display string in pop up
- (void)ds:(NSString *)input;
@end

@implementation Wineskin
- (void)mainRun:(NSArray *)argv
{
	runWithStartExe = NO;
	fullScreenOption = NO;
	useRandR = NO;
	useGamma = YES;
	gammaCorrection = @"default";
	wineserverPIDToCheck = @"-1";
	debugEnabled = NO;
	cexeRun = NO;
	nonStandardRun = NO;
	openingFiles = NO;
	wssCommand = @"nothing";
	randrXres = @"0";
	randrYres = @"0";
	killWineskin = NO;
	if ([argv count]>0) wssCommand = [argv objectAtIndex:0];
	if ([wssCommand isEqualToString:@"CustomEXE"]) cexeRun = YES;
	//if wssCommand is WSS-InstallICE, then just run ICE install and quit!
	contentsFold=[NSString stringWithFormat:@"%@/Contents",[[NSBundle mainBundle] bundlePath]];
	appNameWithPath=[[NSBundle mainBundle] bundlePath];
	firstPIDFile = [NSString stringWithFormat:@"%@/.firstpidfile",contentsFold];
	secondPIDFile = [NSString stringWithFormat:@"%@/.secondpidfile",contentsFold];
	wineserverPIDFile = [NSString stringWithFormat:@"%@/.wineserverpidfile",contentsFold];
	displayNumberFile = [NSString stringWithFormat:@"%@/.currentuseddisplay",contentsFold];
	infoPlistFile = [NSString stringWithFormat:@"%@/Info.plist",contentsFold];
	winePrefix=[NSString stringWithFormat:@"%@/Resources",contentsFold];
	[self installEngine];
	if ([wssCommand isEqualToString:@"WSS-InstallICE"]) return; //just called for ICE install, dont run.
	wineserverPIDToCheck = [[self readFileToStringArray:wineserverPIDFile] objectAtIndex:0];
	NSLog(@"Starting up...");
	NSLog(@"reading all configuration information...");
	//open Info.plist to read all needed info
	NSDictionary *plistDictionary = [[NSDictionary alloc] initWithContentsOfFile:infoPlistFile];
	NSDictionary *cexePlistDictionary;
	NSString *resolutionTemp = @"";
	if (!cexeRun)
	{
		programNameAndPath = [plistDictionary valueForKey:@"Program Name and Path"];
		programFlags = [plistDictionary valueForKey:@"Program Flags"];
		fullScreenOption = [[plistDictionary valueForKey:@"Fullscreen"] intValue];
		resolutionTemp = [plistDictionary valueForKey:@"Resolution"];
		runWithStartExe = [[plistDictionary valueForKey:@"use start.exe"] intValue];
		useRandR = [[plistDictionary valueForKey:@"Use RandR"] intValue];
	}
	else
	{
		cexePlistDictionary = [[NSDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/%@/Contents/Info.plist.cexe",appNameWithPath,[argv objectAtIndex:1]]];
		programNameAndPath = [cexePlistDictionary valueForKey:@"Program Name and Path"];
		programFlags = [cexePlistDictionary valueForKey:@"Program Flags"];
		fullScreenOption = [[cexePlistDictionary valueForKey:@"Fullscreen"] intValue];
		resolutionTemp = [cexePlistDictionary valueForKey:@"Resolution"];
		runWithStartExe = [[cexePlistDictionary valueForKey:@"use start.exe"] intValue];
		useGamma = [[cexePlistDictionary valueForKey:@"Use Gamma"] intValue];
		useRandR = [[cexePlistDictionary valueForKey:@"Use RandR"] intValue];
	}
	gammaCorrection = [plistDictionary valueForKey:@"Gamma Correction"];
	x11PrefFileName = [plistDictionary valueForKey:@"CFBundleIdentifier"];
	uLimitNumber=@"10000"; // run as 10000 for now.. I don't think this needs to be edited.  If peoples launchctl limit report less than 10000, they need to fix their machine, or reboot
	wineDebugLineFromPlist = [plistDictionary valueForKey:@"WINEDEBUG="];
	//if any program flags, need to add a space to the front of them
	if (!([programFlags isEqualToString:@""]))
		programFlags = [NSString stringWithFormat:@" %@",programFlags];
	//resolutionTemp needs to be stripped for resolution info, bit depth, and switch pause
	//vdreso
	vdResolution = [NSString stringWithFormat:@"%@",resolutionTemp];
	vdResolution = [vdResolution substringToIndex:[vdResolution rangeOfString:@"x" options:NSBackwardsSearch].location];
	//bitdepth
	fullScreenResolutionBitDepth = [NSString stringWithFormat:@"%@",resolutionTemp];
	fullScreenResolutionBitDepth = [fullScreenResolutionBitDepth stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@x",vdResolution] withString:@""];
	fullScreenResolutionBitDepth = [fullScreenResolutionBitDepth substringToIndex:[fullScreenResolutionBitDepth rangeOfString:@"sleep"].location];
	//sleep number
	NSString *sleepNumberTemp = [NSString stringWithFormat:@"%@",resolutionTemp];
	sleepNumberTemp = [sleepNumberTemp stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@x%@sleep",vdResolution,fullScreenResolutionBitDepth] withString:@""];
	sleepNumber = [sleepNumberTemp intValue];
	//make sure vdReso has a space, not an x
	vdResolution = [vdResolution stringByReplacingOccurrencesOfString:@"x" withString:@" "];
	currentResolution = [self getResolution];
	if ([vdResolution isEqualToString:@"Current Resolution"])
		vdResolution = [NSString stringWithFormat:@"%@",currentResolution];
	// get cliCustomCommands
	cliCustomCommands = [plistDictionary valueForKey:@"CLI Custom Commands"];
	// strip off trailing ; on cliCustomCommands if it exists
	if (!([cliCustomCommands hasSuffix:@";"]) && ([cliCustomCommands length] > 0))
		cliCustomCommands = [NSString stringWithFormat:@"%@;",cliCustomCommands];
	//******* fix all data correctly
	//list of possile options
	//WSS-installer {path/file}	- Installer is calling the program
	//WSS-winecfg 				- need to run winecfg
	//WSS-regedit 				- need to run regedit
	//WSS-taskmgr 				- need to run taskmgr
	//WSS-uninstall				- run uninstaller
	//WSS-wineprefixcreate		- need to run wineboot, refresh wrapper
	//WSS-wineprefixcreatenoregs- same as above, doesn't load default regs
	//WSS-wineboot				- run simple wineboot, no deletions or loading regs. mshtml=disabled
	//WSS-winetricks {command}	- winetricks is being run
	//debug 					- run in debug mode, keep logs
	//CustomEXE {appname}		- running a custom EXE with appname
	//starts with a"/" 			- will be 1+ path/filename to open
	//no command line args		- normal run
	if ([argv count] > 1) winetricksCommand = [argv objectAtIndex:1];
	if ([argv count] > 2)
	{
		winetricksCommand2 = [argv objectAtIndex:2];
		winetrickCommandsList = [argv objectAtIndex:1];
		int i = 3;
		for (NSString *item in argv)
		{
			if ([item isEqualToString:winetricksCommand]
				|| [item isEqualToString:wssCommand])
				continue;
			winetrickCommandsList = [NSString stringWithFormat:@"%@ %@",winetrickCommandsList,item];
		}		
	}
	if ([argv count] > 0)
	{
		if ([wssCommand hasPrefix:@"/"]) //if wssCommand starts with a / its file(s) passed in to open
		{
			for (NSString *item in argv)
				[filesToRun addObject:item];
			NSLog(@"files passed in to open, will open with associated app");
			openingFiles=YES;
		}
		else if ([wssCommand hasPrefix:@"WSS-"]) //if wssCommand starts with WSS- its a special command
		{
			debugEnabled=YES; //need logs in special commands
			useGamma=NO;
			if ([wssCommand isEqualToString:@"WSS-installer"]) //if its in the installer, need to know if normal windows are forced
			{
				if ([[plistDictionary valueForKey:@"force Installer to normal windows"] intValue] == 1)
				{
					fullScreenResolutionBitDepth = @"24";
					vdResolution = @"novd";
					fullScreenOption = NO;
					sleepNumber = 0;
				}
				programNameAndPath = [argv objectAtIndex:1]; // second argument full path and file name to run
				runWithStartExe = YES; //installer always uses start.exe
			}
			else //any WSS that isn't the installer
			{
				fullScreenResolutionBitDepth = @"24"; // all should force normal windows
				vdResolution = @"novd";
				fullScreenOption = NO;
				sleepNumber = 0;
				//should only use this line for winecfg regedit and taskmgr, other 2 do nonstandard runs and wont use this line
				programNameAndPath = [NSString stringWithFormat:@"/../WineskinEngine.bundle/Wine/lib/wine/%@.exe.so",[wssCommand stringByReplacingOccurrencesOfString:@"WSS-" withString:@""]];
				programFlags = @""; // just in case there were some flags... don't use on these.
				if ([wssCommand isEqualToString:@"WSS-wineboot"] || [wssCommand isEqualToString:@"WSS-wineprefixcreate"] || [wssCommand isEqualToString:@"WSS-wineprefixcreatenoregs"] || [wssCommand isEqualToString:@"WSS-winetricks"])
					nonStandardRun=YES; // handle Wine differently if its one of these 2
			}			
		}
		else if ([wssCommand isEqualToString:@"debug"]) //if wssCommand is debug, run in debug mode
		{
			debugEnabled=YES;
			NSLog(@"Debug Mode enabled");
		}
	}
	//if vdResolution is bigger than currentResolution, need to downsize it
	if (!([vdResolution isEqualToString:@"novd"]))
	{
		NSString *xRes = [vdResolution substringToIndex:[vdResolution rangeOfString:@" "].location];
		NSString *yRes = [vdResolution stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@ ",xRes] withString:@""];
		NSString *xResMax = [currentResolution substringToIndex:[currentResolution rangeOfString:@" "].location];
		NSString *yResMax = [currentResolution stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@ ",xResMax] withString:@""];
		if ([xRes intValue] > [xResMax intValue] || [yRes intValue] > [yResMax intValue])
			vdResolution = [NSString stringWithFormat:@"%@",currentResolution];
		
	}
	//fix wine run paths
	if (![programNameAndPath hasPrefix:@"/"])
		programNameAndPath = [NSString stringWithFormat:@"/%@",programNameAndPath];
	wineRunLocation = [programNameAndPath substringToIndex:[programNameAndPath rangeOfString:@"/" options:NSBackwardsSearch].location];
	wineRunFile = [programNameAndPath stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@/",wineRunLocation] withString:@""];
	//add path to drive C if its not an installer
	if (!([wssCommand isEqualToString:@"WSS-installer"]))
		wineRunLocation = [NSString stringWithFormat:@"%@/Resources/drive_c%@",contentsFold,wineRunLocation];
	
	//**********make sure that the set executable is found if normal run
	if (!openingFiles && !([wssCommand hasPrefix:@"WSS-"]) && !([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@",wineRunLocation,wineRunFile]]))
	{
		//error, file doesn't exist, and its not a special command
		NSLog(@"Error! Set executable not found.  Wineskin.app running instead.");
		system([[NSString stringWithFormat:@"open \"%@/Wineskin.app\"",appNameWithPath] UTF8String]);
		return;
	}
	//********** Wineskin Customizer start up script
	system([[NSString stringWithFormat:@"\"%@/WineskinStartupScript\"",winePrefix] UTF8String]);
	
	//**********set the display number
	srand((unsigned)time(0));
	int randomint = 5+(int)(rand()%9994);
	if (randomint<0){randomint=randomint*(-1);}
	theDisplayNumber = [NSString stringWithFormat:@":%@",[[NSNumber numberWithLong:randomint] stringValue]];
	
	//**********start the X server
	NSLog(@"Starting up WineskinX11");
	x11PID = [self startX11];
	NSLog(@"WineskinX11 running on PID %@",x11PID);
	//**********set user folders
	NSLog(@"Fixing user folders in Drive C to current user");
	if ([[plistDictionary valueForKey:@"Symlinks In User Folder"] intValue] == 1)
		[self setUserFolders:YES];
	else
		[self setUserFolders:NO];
	
	//********** fix wineprefix
	[self fixWinePrefixForCurrentUser];
	
	//********** If setting GPU info, do it
	if ([[plistDictionary valueForKey:@"Try To Use GPU Info"] intValue] == 1) [self tryToUseGPUInfo];
	
	//**********start wine
	NSLog(@"Starting specified executable in Wine");
	wineServerPID = [self startWine];
	NSLog(@"Wineserver running on PID %@",wineServerPID);
	//********** exit if already running and just opening new file
	//if wineserver pid was already running in startWine and openFiles was true, then exit, we already have a Wineskin monitoring the wrapper
	if (killWineskin) return;
	
	//change fullscreen reso if needed
	if (fullScreenOption)
	{
		NSLog(@"Changing to requested starting resolution of %@...",vdResolution);
		[self setResolution:vdResolution];
	}
	
	//**********sleep and monitor in background while app is running
	NSLog(@"Sleeping and monitoring from the background while app runs...");
	[self sleepAndMonitor];
	
	//********** Wineskin Customizer shut down script
	system([[NSString stringWithFormat:@"\"%@/WineskinShutdownScript\"",winePrefix] UTF8String]);
	
	//********** app finished, time to clean up and shut down
	NSLog(@"Application finished, cleaning up and shut down...\n");
	if ([[plistDictionary valueForKey:@"Symlinks In User Folder"] intValue] == 1)
		[self cleanUpAndShutDown:YES];
	else
		[self cleanUpAndShutDown:NO];
	if ([[plistDictionary valueForKey:@"Try To Use GPU Info"] intValue] == 1) [self removeGPUInfo];
	NSLog(@"Finished!\n");
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
	if (error1!=0) NSLog(@"setGamma function active display list failed! error = %d",error1);
	CGGammaValue gammaMin = 0.0;
	CGGammaValue gammaMax = 1.0;
	CGGammaValue gammaSettingsRED = gamma;
	CGGammaValue gammaSettingsGREEN = gamma;
	CGGammaValue gammaSettingsBLUE = gamma;
	CGSetDisplayTransferByFormula(*activeDisplays,gammaMin,gammaMax,gammaSettingsRED,gammaMin,gammaMax,gammaSettingsGREEN,gammaMin,gammaMax,gammaSettingsBLUE);
}

- (void)setResolution:(NSString *)reso
{
	NSString *xRes = [reso substringToIndex:[reso rangeOfString:@" "].location];
	NSString *yRes = [reso stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%@ ",xRes] withString:@""];
	//if XxY doesn't exist, we will ignore for now... in the future maybe add way to find the closest reso that is available.
	//change the resolution using Xrandr
	system([[NSString stringWithFormat:@"export PATH=\"%@/Resources/WineskinEngine.bundle/Wine/bin:%@/Resources/WineskinEngine.bundle/X11/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin\";export DISPLAY=%@;export WINEPREFIX=\"%@\";cd \"%@/Resources/WineskinEngine.bundle/Wine/bin\";DYLD_FALLBACK_LIBRARY_PATH=\"%@/Resources/WineskinEngine.bundle/X11/lib:%@/Resources/WineskinEngine.bundle/Wine/lib:/usr/lib:/usr/libexec:/usr/lib/system:/usr/X11/lib:/usr/X11R6/lib\" xrandr -s %@x%@ > /dev/null 2>&1",contentsFold,contentsFold,theDisplayNumber,winePrefix,contentsFold,contentsFold,contentsFold,xRes,yRes] UTF8String]);
}

- (NSString *)getResolution
{
	CGRect screenFrame = CGDisplayBounds(kCGDirectMainDisplay);
	CGSize screenSize  = screenFrame.size;
	return [NSString stringWithFormat:@"%.0f %.0f",screenSize.width,screenSize.height];
}

- (NSString *)systemCommand:(NSString *)command
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

- (NSArray *)makePIDArray:(NSString *)processToLookFor
{
	NSString *resultString = [NSString stringWithFormat:@"00000\n%@",[self systemCommand:[NSString stringWithFormat:@"ps axc|awk \"{if (\\$5==\\\"%@\\\") print \\$1}\"",processToLookFor]]];
	return [resultString componentsSeparatedByString:@"\n"];
}

- (void)setUserFolders:(BOOL)doSymlinks
{
	NSFileManager *fm = [NSFileManager defaultManager];
	if ([fm fileExistsAtPath:[NSString stringWithFormat:@"%@/drive_c/users/Wineskin",winePrefix]])
	{
		[fm moveItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/Wineskin",winePrefix] toPath:[NSString stringWithFormat:@"%@/drive_c/users/%@",winePrefix,NSUserName()] error:nil];
		if (doSymlinks)
		{
			[fm removeItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/%@/My Documents",winePrefix,NSUserName()] error:nil];
			[fm removeItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/%@/Desktop",winePrefix,NSUserName()] error:nil];
			[fm removeItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/%@/My Videos",winePrefix,NSUserName()] error:nil];
			[fm removeItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/%@/My Music",winePrefix,NSUserName()] error:nil];
			[fm removeItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/%@/My Pictures",winePrefix,NSUserName()] error:nil];
			[fm createSymbolicLinkAtPath:[NSString stringWithFormat:@"%@/drive_c/users/%@/My Documents",winePrefix,NSUserName()] withDestinationPath:[NSString stringWithFormat:@"%@/Documents",NSHomeDirectory()] error:nil];
			[fm createSymbolicLinkAtPath:[NSString stringWithFormat:@"%@/drive_c/users/%@/Desktop",winePrefix,NSUserName()] withDestinationPath:[NSString stringWithFormat:@"%@/Desktop",NSHomeDirectory()] error:nil];
			[fm createSymbolicLinkAtPath:[NSString stringWithFormat:@"%@/drive_c/users/%@/My Videos",winePrefix,NSUserName()] withDestinationPath:[NSString stringWithFormat:@"%@/Movies",NSHomeDirectory()] error:nil];
			[fm createSymbolicLinkAtPath:[NSString stringWithFormat:@"%@/drive_c/users/%@/My Music",winePrefix,NSUserName()] withDestinationPath:[NSString stringWithFormat:@"%@/Music",NSHomeDirectory()] error:nil];
			[fm createSymbolicLinkAtPath:[NSString stringWithFormat:@"%@/drive_c/users/%@/My Pictures",winePrefix,NSUserName()] withDestinationPath:[NSString stringWithFormat:@"%@/Pictures",NSHomeDirectory()] error:nil];
		}
		else
		{
			[fm createDirectoryAtPath:[NSString stringWithFormat:@"%@/drive_c/users/%@/My Documents",winePrefix,NSUserName()] withIntermediateDirectories:NO attributes:nil error:nil];
			[fm createDirectoryAtPath:[NSString stringWithFormat:@"%@/drive_c/users/%@/Desktop",winePrefix,NSUserName()] withIntermediateDirectories:NO attributes:nil error:nil];
			[fm createDirectoryAtPath:[NSString stringWithFormat:@"%@/drive_c/users/%@/My Videos",winePrefix,NSUserName()] withIntermediateDirectories:NO attributes:nil error:nil];
			[fm createDirectoryAtPath:[NSString stringWithFormat:@"%@/drive_c/users/%@/My Music",winePrefix,NSUserName()] withIntermediateDirectories:NO attributes:nil error:nil];
			[fm createDirectoryAtPath:[NSString stringWithFormat:@"%@/drive_c/users/%@/My Pictures",winePrefix,NSUserName()] withIntermediateDirectories:NO attributes:nil error:nil];
		}
	}
	if ([fm fileExistsAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover",winePrefix]])
	{
		if (doSymlinks)
		{
			[fm removeItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover/My Documents",winePrefix] error:nil];
			[fm removeItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover/Desktop",winePrefix] error:nil];
			[fm removeItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover/My Videos",winePrefix] error:nil];
			[fm removeItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover/My Music",winePrefix] error:nil];
			[fm removeItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover/My Pictures",winePrefix] error:nil];
			[fm createSymbolicLinkAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover/My Documents",winePrefix] withDestinationPath:[NSString stringWithFormat:@"%@/Documents",NSHomeDirectory()] error:nil];
			[fm createSymbolicLinkAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover/Desktop",winePrefix] withDestinationPath:[NSString stringWithFormat:@"%@/Desktop",NSHomeDirectory()] error:nil];
			[fm createSymbolicLinkAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover/My Videos",winePrefix] withDestinationPath:[NSString stringWithFormat:@"%@/Movies",NSHomeDirectory()] error:nil];
			[fm createSymbolicLinkAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover/My Music",winePrefix] withDestinationPath:[NSString stringWithFormat:@"%@/Music",NSHomeDirectory()] error:nil];
			[fm createSymbolicLinkAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover/My Pictures",winePrefix] withDestinationPath:[NSString stringWithFormat:@"%@/Pictures",NSHomeDirectory()] error:nil];
		}
		else
		{
			[fm createDirectoryAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover/My Documents",winePrefix] withIntermediateDirectories:NO attributes:nil error:nil];
			[fm createDirectoryAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover/Desktop",winePrefix] withIntermediateDirectories:NO attributes:nil error:nil];
			[fm createDirectoryAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover/My Videos",winePrefix] withIntermediateDirectories:NO attributes:nil error:nil];
			[fm createDirectoryAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover/My Music",winePrefix] withIntermediateDirectories:NO attributes:nil error:nil];
			[fm createDirectoryAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover/My Pictures",winePrefix] withIntermediateDirectories:NO attributes:nil error:nil];			
		}
	}
	[fm release];
}

- (void)fixWinePrefixForCurrentUser
{
	// changing owner just fails, need this to work for normal users without admin password on the fly.
	// Needed folders are set to 777, so just make a new resources folder and move items, should always work.
	// NSFileManager changing posix permissions still failing to work right, using chmod as a system command
	NSFileManager *fm = [NSFileManager defaultManager];
	//if owner and current user match, exit
	NSDictionary *checkThis = [fm attributesOfItemAtPath:winePrefix error:nil];
	if ([NSUserName() isEqualToString:[checkThis valueForKey:@"NSFileOwnerAccountName"]])
	{
		[fm release];
		return;
	}
	//make ResoTemp
	[fm createDirectoryAtPath:[NSString stringWithFormat:@"%@/ResoTemp",contentsFold] withIntermediateDirectories:NO attributes:nil error:nil];
	//move everything from Resources to ResoTemp
	NSArray *tmpy = [fm contentsOfDirectoryAtPath:winePrefix error:nil];
	for (NSString *item in tmpy)
		[fm moveItemAtPath:[NSString stringWithFormat:@"%@/Resources/%@",contentsFold,item] toPath:[NSString stringWithFormat:@"%@/ResoTemp/%@",contentsFold,item] error:nil];
	//delete Resources
	[fm removeItemAtPath:winePrefix error:nil];
	//rename ResoTemp to Resources
	[fm moveItemAtPath:[NSString stringWithFormat:@"%@/ResoTemp",contentsFold] toPath:[NSString stringWithFormat:@"%@/Resources",contentsFold] error:nil];
	//fix Reosurces to 777
	[self systemCommand:[NSString stringWithFormat:@"chmod 777 \"%@\"",winePrefix]];
	[fm release];
}

- (void)tryToUseGPUInfo
{
	//if user.reg doesn't exist, don't do anything
	if (!([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/user.reg",winePrefix]])) return;
	NSString *deviceID = @"error";
	NSString *vendorID = @"error";
	NSString *VRAM = @"error";
	NSArray *results = [[self systemCommand:@"system_profiler SPDisplaysDataType"] componentsSeparatedByString:@"\n"];
	int i;
	int findCounter = 0;
	int displaysLineCounter = 0;
	BOOL doTesting = NO;
	//need to go through backwards.  After finding a suffix "Online: Yes" then next VRAM Device ID and Vendor is the correct ones, exit after finding all 3
	// if we hit a prefix of "Displays:" a second time after start testing, we have gone too far.
	for (i = [results count] - 1; i >= 0; i--)
	{
		NSString *temp = [[results objectAtIndex:i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if ([temp hasSuffix:@"Online: Yes"])
		{
			doTesting = YES;
			continue;
		}
		if (doTesting)
		{
			if ([temp hasPrefix:@"Displays:"]) displaysLineCounter++;  // make sure somehting missing on some GPU will not pull info from 2 GPUs.
			if (displaysLineCounter > 1) findCounter=3;
			else if ([temp hasPrefix:@"Device ID:"])
			{
				deviceID = [[temp stringByReplacingOccurrencesOfString:@"Device ID:" withString:@""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
				findCounter++;
			}
			else if ([temp hasPrefix:@"Vendor:"])
			{
				vendorID = [temp substringFromIndex:[temp rangeOfString:@"("].location+1];
				vendorID = [[vendorID stringByReplacingOccurrencesOfString:@")" withString:@""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
				findCounter++;
			}
			else if ([temp hasPrefix:@"VRAM (Total):"])
			{
				VRAM = [temp stringByReplacingOccurrencesOfString:@"VRAM (Total): " withString:@""];
				VRAM = [[VRAM stringByReplacingOccurrencesOfString:@" MB" withString:@""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
				findCounter++;
			}
			
		}
		if (findCounter > 2) break;
	}
	//need to strip 0x off the front of deviceID and vendorID, and pad with 0's in front until its a total of 8 digits long.
	vendorID = [vendorID stringByReplacingOccurrencesOfString:@"0x" withString:@""];
	deviceID = [deviceID stringByReplacingOccurrencesOfString:@"0x" withString:@""];
	while ([vendorID length] < 8)
		vendorID = [NSString stringWithFormat:@"0%@",vendorID];
	while ([deviceID length] < 8)
		deviceID = [NSString stringWithFormat:@"0%@",deviceID];
	
	// write each of the 3 in the Registry if not = "error"
	//read in user.reg to an array
	NSArray *userRegContents = [self readFileToStringArray:[NSString stringWithFormat:@"%@/user.reg",winePrefix]];
	NSMutableArray *newUserRegContents = [NSMutableArray arrayWithCapacity:[userRegContents count]];
	BOOL deviceIDFound = NO;
	BOOL vendorIDFound = NO;
	BOOL VRAMFound = NO;
	BOOL startTesting = NO;
	for (NSString *item in userRegContents)
	{
		if ([item hasPrefix:@"[Software\\\\Wine\\\\Direct3D]"])
		{
			[newUserRegContents addObject:item];
			startTesting = YES;
			continue;
		}
		if (startTesting)
		{
			if ([item hasPrefix:@"\"VideoMemorySize\""] && !([VRAM isEqualToString:@"error"]))
			{
				[newUserRegContents addObject:[NSString stringWithFormat:@"\"VideoMemorySize\"=\"%@\"",VRAM]];
				VRAMFound = YES;
				continue;
			}
			else if ([item hasPrefix:@"\"VideoPciDeviceID\""] && !([deviceID isEqualToString:@"error"]))
			{
				[newUserRegContents addObject:[NSString stringWithFormat:@"\"VideoPciDeviceID\"=dword:%@",deviceID]];
				deviceIDFound = YES;
				continue;
			}
			else if ([item hasPrefix:@"\"VideoPciVendorID\""] && !([vendorID isEqualToString:@"error"]))
			{
				[newUserRegContents addObject:[NSString stringWithFormat:@"\"VideoPciVendorID\"=dword:%@",vendorID]];
				vendorIDFound = YES;
				continue;
			}
		}
		if (startTesting && [item hasPrefix:@"["])
		{
			// its out of the Direct3D section, write in any items still needed
			startTesting = NO;
			if ([[newUserRegContents lastObject] length] < 1) // just in case someone editing manually and didn't leave a space
				[newUserRegContents removeLastObject];
			if (!VRAMFound && !([VRAM isEqualToString:@"error"]))
				[newUserRegContents addObject:[NSString stringWithFormat:@"\"VideoMemorySize\"=\"%@\"",VRAM]];
			if (!deviceIDFound && !([deviceID isEqualToString:@"error"]))
				[newUserRegContents addObject:[NSString stringWithFormat:@"\"VideoPciDeviceID\"=dword:%@",deviceID]];
			if (!vendorIDFound && !([vendorID isEqualToString:@"error"]))
				[newUserRegContents addObject:[NSString stringWithFormat:@"\"VideoPciVendorID\"=dword:%@",vendorID]];
			[newUserRegContents addObject:@""];
		}
		//if it makes it through everything, then its a normal line that is needed as is.
		[newUserRegContents addObject:item];
	}
	//write array back to file
	[self writeStringArray:[NSArray arrayWithArray:newUserRegContents] toFile:[NSString stringWithFormat:@"%@/user.reg",winePrefix]];
}

- (void)removeGPUInfo
{
	NSArray *userRegContents = [self readFileToStringArray:[NSString stringWithFormat:@"%@/user.reg",winePrefix]];
	NSMutableArray *newUserRegContents = [NSMutableArray arrayWithCapacity:[userRegContents count]];
	BOOL deviceIDFound = NO;
	BOOL vendorIDFound = NO;
	BOOL VRAMFound = NO;
	BOOL startTesting = NO;
	for (NSString *item in userRegContents)
	{
		if ([item hasPrefix:@"[Software\\\\Wine\\\\Direct3D]"]) //make sure we are in the same place
		{
			[newUserRegContents addObject:item];
			startTesting = YES;
			continue;
		}
		if (startTesting)
		{
			if ([item hasPrefix:@"\"VideoMemorySize\""])
			{
				VRAMFound = YES;
				continue;
			}
			else if ([item hasPrefix:@"\"VideoPciDeviceID\""])
			{
				deviceIDFound = YES;
				continue;
			}
			else if ([item hasPrefix:@"\"VideoPciVendorID\""])
			{
				vendorIDFound = YES;
				continue;
			}
		}
		if ([item hasPrefix:@"["]) startTesting = NO;
		//if it makes it through everything, then its a normal line that is needed as is.
		[newUserRegContents addObject:item];
	}
	//write array back to file
	[self writeStringArray:[NSArray arrayWithArray:newUserRegContents] toFile:[NSString stringWithFormat:@"%@/user.reg",winePrefix]];
}

- (NSString *)startX11
{
	// do not start X server for Winetricks listings.. its a waste of time.
	if ([wssCommand isEqualToString:@"WSS-winetricks"] && ([winetricksCommand isEqualToString:@"list"] || [winetricksCommand2 isEqualToString:@"list"]))
		return @"Winetricks Listing, no X server needed";
	//copying X11plist file over to /tmp to use... was needed in C++ for copy problems from /Volumes, may not be needed now... trying directly
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *wsX11PlistFile = [NSString stringWithFormat:@"%@/WineskinEngine.bundle/X11/WSX11Prefs.plist",winePrefix];
	NSArray *tempArray = [self readFileToStringArray:[NSString stringWithFormat:@"%@/WineskinEngine.bundle/X11/WSConfig.txt",winePrefix]];
	NSString *engineVersion = [tempArray objectAtIndex:0];
	NSString *x11InstallPath = [tempArray objectAtIndex:1];
	NSString *x11Version = [engineVersion substringToIndex:[engineVersion rangeOfString:@"Wine"].location];
	//list error if using an old incompatible engine
	if ([x11Version isEqualToString:@"WS1"] || [x11Version isEqualToString:@"WS2"] || [x11Version isEqualToString:@"WS3"] || [x11Version isEqualToString:@"WS4"])
	{
		NSLog(@"Error! old engine in use! Old WS1 through WS4 engines will not run in Wineskin 2.0+ correctly! There may be major problems!");
		CFUserNotificationDisplayNotice(5.0, 0, NULL, NULL, NULL, CFSTR("WARNING!"), (CFStringRef)@"Warning! Old engine in use! Old WS1 through WS4 engines will not run in Wineskin 2.0+ correctly! There may be major problems!", NULL);
		usleep(5000000);
	}
	//set up quartz-wm launch correctly
	NSString *quartzwmLine = [NSString stringWithFormat:@" +extension \"%@/bin/quartz-wm\"",x11InstallPath];
	//copy the plist over
	[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Library/Preferences/%@.plist",NSHomeDirectory(),x11PrefFileName] error:nil];
	[fm copyItemAtPath:wsX11PlistFile toPath:[NSString stringWithFormat:@"%@/Library/Preferences/%@.plist",NSHomeDirectory(),x11PrefFileName] error:nil];
	//make proper files and symlinks in x11InstallPath
	//remove for files just in case some other version had made symlinks here, will cause a failure
	[fm removeItemAtPath:x11InstallPath error:nil];
	//symlink X11 straight to x11InstallPath
	[fm createSymbolicLinkAtPath:[NSString stringWithFormat:@"%@",x11InstallPath] withDestinationPath:[NSString stringWithFormat:@"%@/WineskinEngine.bundle/X11",winePrefix] error:nil];
	NSArray *winePidCheck = [self readFileToStringArray:wineserverPIDFile];
	if ([self pidRunning:[winePidCheck objectAtIndex:0]])
	{
		[fm release];
		return [winePidCheck objectAtIndex:0];
	}
	//change Info.plist to use main.nib (xquartz's nib) instead of MainMenu.nib (WineskinLauncher's nib)
	NSMutableDictionary* quickEdit1 = [[NSDictionary alloc] initWithContentsOfFile:infoPlistFile];
	[quickEdit1 setValue:@"X11Application" forKey:@"NSPrincipalClass"];
	[quickEdit1 setValue:@"main.nib" forKey:@"NSMainNibFile"];
	[quickEdit1 writeToFile:infoPlistFile atomically:YES];
	[quickEdit1 release];
	//set up fontpath variable for server depending where X11 fonts are on the system
	NSString *wineskinX11FontPathPrefix = @"/usr/X11/lib/X11/fonts";
	if (![fm fileExistsAtPath:wineskinX11FontPathPrefix])
	{
		if ([fm fileExistsAtPath:@"/usr/X11/share/fonts"])
			wineskinX11FontPathPrefix=@"/usr/X11/share/fonts";
		else if ([fm fileExistsAtPath:@"/opt/X11/share/fonts"])
			wineskinX11FontPathPrefix=@"/opt/X11/share/fonts";
		else if ([fm fileExistsAtPath:@"/opt/local/share/fonts"])
			wineskinX11FontPathPrefix=@"/opt/local/share/fonts";
		else if ([fm fileExistsAtPath:@"/usr/X11R6/lib/X11/fonts"])
			wineskinX11FontPathPrefix=@"/usr/X11R6/lib/X11/fonts";
	}
	NSString *wineskinX11FontPath = [NSString stringWithFormat:@"-fp %@/75dpi,%@/100dpi,%@/cyrillic,%@/encodings,%@/misc,%@/OTF,%@/Speedo,%@/TTF,%@/Type1,%@/util",wineskinX11FontPathPrefix,wineskinX11FontPathPrefix,wineskinX11FontPathPrefix,wineskinX11FontPathPrefix,wineskinX11FontPathPrefix,wineskinX11FontPathPrefix,wineskinX11FontPathPrefix,wineskinX11FontPathPrefix,wineskinX11FontPathPrefix,wineskinX11FontPathPrefix];
	// set log variable
	NSString *logFileLocation;
	if (debugEnabled)
		logFileLocation=[NSString stringWithFormat:@"%@/Logs/LastRunX11.log",winePrefix];
	else
		logFileLocation = @"/dev/null";
	//Start WineskinX11
	NSString *thePidToReturn = [self systemCommand:[NSString stringWithFormat:@"export DISPLAY=%@;DYLD_FALLBACK_LIBRARY_PATH=\"%@/WineskinEngine.bundle/X11/lib:%@/WineskinEngine.bundle/Wine/lib:/usr/lib:/usr/libexec:/usr/lib/system:/usr/X11/lib:/usr/X11R6/lib\" \"%@/MacOS/WineskinX11\" %@ -depth %@ +xinerama -br %@ -xkbdir \"%@/WineskinEngine.bundle/X11/share/X11/xkb\"%@ > \"%@\" 2>&1 & echo \"$!\"",theDisplayNumber,winePrefix,winePrefix,contentsFold,theDisplayNumber,fullScreenResolutionBitDepth,wineskinX11FontPath,winePrefix,quartzwmLine,logFileLocation]];
	//fix Info.plist back
	usleep(500000);
	[self systemCommand:[NSString stringWithFormat:@"/usr/bin/arch -i386 /usr/bin/osascript -e \"tell application \\\"%@\\\" to activate\"",appNameWithPath]];
	NSMutableDictionary* quickEdit2 = [[NSDictionary alloc] initWithContentsOfFile:infoPlistFile];
	[quickEdit2 setValue:@"NSApplication" forKey:@"NSPrincipalClass"];
	[quickEdit2 setValue:@"MainMenu.nib" forKey:@"NSMainNibFile"];
	[quickEdit2 writeToFile:infoPlistFile atomically:YES];
	[quickEdit2 release];
	[fm release];
	return thePidToReturn;
}

- (void)installEngine
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableArray *wineskinEngineBundleContentsList = [NSMutableArray arrayWithCapacity:2];
	//get directory contents of WineskinEngine.bundle
	NSArray *files = [fm contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/WineskinEngine.bundle/",winePrefix] error:nil];
	for (NSString *file in files)
		if ([file hasSuffix:@".bundle.tar.7z"]) [wineskinEngineBundleContentsList addObject:[file stringByReplacingOccurrencesOfString:@".tar.7z" withString:@""]];
	//if the .tar.7z files exist, continue with this
	BOOL isIce = NO;
	BOOL doError = NO;
	//test if Wine and X11 are symlinks or folders, if symlink isIce is YES
	NSString *testResults1 = [fm destinationOfSymbolicLinkAtPath:[NSString stringWithFormat:@"%@/WineskinEngine.bundle/X11",winePrefix] error:nil];
	NSString *testResults2 = [fm destinationOfSymbolicLinkAtPath:[NSString stringWithFormat:@"%@/WineskinEngine.bundle/Wine",winePrefix] error:nil];
	if ([testResults1 length] > 0 || [testResults2 length] > 0) isIce = YES;
	if ([wineskinEngineBundleContentsList count] > 0) isIce = YES;
	if (!isIce)
	{
		[fm release];
		return;
	}
	if ([wineskinEngineBundleContentsList count] != 2) doError = YES;
	NSString *wineFile = @"OOPS";
	NSString *x11File = @"OOPS";
	for (NSString *item in wineskinEngineBundleContentsList)
	{
		if ([item hasPrefix:@"WSWine"] && [item hasSuffix:@"ICE.bundle"]) wineFile = [NSString stringWithFormat:@"%@",item];
		if ([item hasPrefix:@"WS"] && [item hasSuffix:@"X11ICE.bundle"]) x11File = [NSString stringWithFormat:@"%@",item];
	}
	if (wineFile == @"OOPS" || x11File == @"OOPS") doError = YES;
	if (doError)
	{
		NSLog(@"Warning! This appears to be Wineskin ICE, but there is a problem in the Engine files in the wrapper.  They are either corrupted or missing.  The program may fail to launch!");
		CFUserNotificationDisplayNotice(10.0, 0, NULL, NULL, NULL, CFSTR("WARNING!"), (CFStringRef)@"Warning! This appears to be Wineskin ICE, but there is a problem in the Engine files in the wrapper.\n\nThey are either corrupted or missing.\n\nThe program may fail to launch!", NULL);
		usleep(3000000);
	}
	//get md5 of wineFile and x11File
	NSString *wineFileMd5 = [[self systemCommand:[NSString stringWithFormat:@"md5 -r \"%@/WineskinEngine.bundle/%@.tar.7z\"",winePrefix,wineFile]] stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@" %@/WineskinEngine.bundle/%@.tar.7z",winePrefix,wineFile] withString:@""];
	NSString *x11FileMd5 = [[self systemCommand:[NSString stringWithFormat:@"md5 -r \"%@/WineskinEngine.bundle/%@.tar.7z\"",winePrefix,x11File]] stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@" %@/WineskinEngine.bundle/%@.tar.7z",winePrefix,x11File] withString:@""];
	NSString *wineFileInstalledName = [NSString stringWithFormat:@"%@%@.bundle",[wineFile stringByReplacingOccurrencesOfString:@"bundle" withString:@""],wineFileMd5];
	NSString *x11FileInstalledName = [NSString stringWithFormat:@"%@%@.bundle",[x11File stringByReplacingOccurrencesOfString:@"bundle" withString:@""],x11FileMd5];
	//make ICE folder if it doesn't exist
	[fm createDirectoryAtPath:[NSHomeDirectory() stringByAppendingString:@"/Library/Application Support/Wineskin/Engines/ICE"] withIntermediateDirectories:YES attributes:nil error:nil];
	// delete out extra bundles or tars in engine bundle first
	[fm removeItemAtPath:[NSString stringWithFormat:@"%@/WineskinEngine.bundle/%@.tar",winePrefix,wineFile] error:nil];
	[fm removeItemAtPath:[NSString stringWithFormat:@"%@/WineskinEngine.bundle/%@.tar",winePrefix,x11File] error:nil];
	[fm removeItemAtPath:[NSString stringWithFormat:@"%@/WineskinEngine.bundle/%@",winePrefix,wineFile] error:nil];
	[fm removeItemAtPath:[NSString stringWithFormat:@"%@/WineskinEngine.bundle/%@",winePrefix,x11File] error:nil];	
	//get directory contents of NSHomeDirectory()/Library/Application Support/Wineskin/Engines/ICE
	NSArray *iceFiles = [fm contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/ICE",NSHomeDirectory()] error:nil];
	//if either Wine or X11 version is not installed...
	BOOL wineInstalled = NO;
	BOOL x11Installed = NO;
	for (NSString *file in iceFiles)
	{
		if ([file isEqualToString:wineFileInstalledName]) wineInstalled = YES;
		if ([file isEqualToString:x11FileInstalledName]) x11Installed = YES;
	}
	if (!wineInstalled || !x11Installed)
	{
		//if the Wine bundle is not located in the install folder, then uncompress it and move it over there.
		if (!wineInstalled)
		{
			system([[NSString stringWithFormat:@"\"%@/WineskinEngine.bundle/7za\" x \"%@/WineskinEngine.bundle/%@.tar.7z\" \"-o/%@/WineskinEngine.bundle\"",winePrefix,winePrefix,wineFile,winePrefix] UTF8String]);
			system([[NSString stringWithFormat:@"/usr/bin/tar -C \"%@/WineskinEngine.bundle\" -xf \"%@/WineskinEngine.bundle/%@.tar\"",winePrefix,winePrefix,wineFile] UTF8String]);
			[fm removeItemAtPath:[NSString stringWithFormat:@"%@/WineskinEngine.bundle/%@.tar",winePrefix,wineFile] error:nil];
			//have uncompressed version now, move it to ICE folder.
			[fm moveItemAtPath:[NSString stringWithFormat:@"%@/WineskinEngine.bundle/%@",winePrefix,wineFile] toPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/ICE/%@",NSHomeDirectory(),wineFileInstalledName] error:nil];
		}
		//if the X11 bundle is not located in the install folder, then uncompress it and move it over there.
		if (!x11Installed)
		{
			system([[NSString stringWithFormat:@"\"%@/WineskinEngine.bundle/7za\" x \"%@/WineskinEngine.bundle/%@.tar.7z\" \"-o/%@/WineskinEngine.bundle\"",winePrefix,winePrefix,x11File,winePrefix] UTF8String]);
			system([[NSString stringWithFormat:@"/usr/bin/tar -C \"%@/WineskinEngine.bundle\" -xf \"%@/WineskinEngine.bundle/%@.tar\"",winePrefix,winePrefix,x11File] UTF8String]);
			[fm removeItemAtPath:[NSString stringWithFormat:@"%@/WineskinEngine.bundle/%@.tar",winePrefix,x11File] error:nil];
			//have uncompressed version now, move it to ICE folder.
			[fm moveItemAtPath:[NSString stringWithFormat:@"%@/WineskinEngine.bundle/%@",winePrefix,x11File] toPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/ICE/%@",NSHomeDirectory(),x11FileInstalledName] error:nil];
		}
	}
	//make/remake the symlinks in WineskinEngine.bundle to point to the correct locations
	[fm removeItemAtPath:[NSString stringWithFormat:@"%@/WineskinEngine.bundle/Wine",winePrefix] error:nil];
	[fm removeItemAtPath:[NSString stringWithFormat:@"%@/WineskinEngine.bundle/X11",winePrefix] error:nil];
	[fm createSymbolicLinkAtPath:[NSString stringWithFormat:@"%@/WineskinEngine.bundle/Wine",winePrefix] withDestinationPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/ICE/%@",NSHomeDirectory(),wineFileInstalledName] error:nil];
	[fm createSymbolicLinkAtPath:[NSString stringWithFormat:@"%@/WineskinEngine.bundle/X11",winePrefix] withDestinationPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/ICE/%@",NSHomeDirectory(),x11FileInstalledName] error:nil];
	[fm release];
}

- (void)setToVirtualDesktop:(NSString *)resolution named:(NSString *)desktopName
{
	//read in user.reg to an array
	NSArray *userRegContents = [self readFileToStringArray:[NSString stringWithFormat:@"%@/user.reg",winePrefix]];
	NSMutableArray *newUserRegContents = [NSMutableArray arrayWithCapacity:[userRegContents count]];
	BOOL eFound = NO;
	BOOL eDFound = NO;
	BOOL eFixMade = NO;
	BOOL eDFixMade = NO;
	for (NSString *item in userRegContents)
	{
		//if it finds "[Software\\Wine\\Explorer]" add it and make sure next line is set right
		if ([item hasPrefix:@"[Software\\\\Wine\\\\Explorer]"])
		{
			[newUserRegContents addObject:item];
			[newUserRegContents addObject:[NSString stringWithFormat:@"\"Desktop\"=\"%@\"",desktopName]];
			[newUserRegContents addObject:@""];
			eFixMade = YES;
			eFound = YES;
			continue;
		}
		if ([item hasPrefix:@"[Software\\\\Wine\\\\Explorer\\\\Desktops]"])
		{
			[newUserRegContents addObject:item];
			[newUserRegContents addObject:[NSString stringWithFormat:@"\"%@\"=\"%@\"",desktopName,[resolution stringByReplacingOccurrencesOfString:@" " withString:@"x"]]];
			[newUserRegContents addObject:@""];
			eDFixMade = YES;
			eDFound = YES;
			continue;
		}
		if (eFound && !([item hasPrefix:@"["])) continue;
		else eFound = NO;
		if (eDFound && !([item hasPrefix:@"["])) continue;
		else eDFound = NO;
		//if it makes it thorugh everything, then its a normal line that is needed.
		[newUserRegContents addObject:item];
	}
	//if either of the lines were never found, add them at the end with correct entries
	if (!eFixMade)
	{
		[newUserRegContents addObject:@""];
		[newUserRegContents addObject:@"[Software\\\\Wine\\\\Explorer]"];
		[newUserRegContents addObject:[NSString stringWithFormat:@"\"Desktop\"=\"%@\"",desktopName]];
	}
	if (!eDFixMade)
	{
		[newUserRegContents addObject:@""];
		[newUserRegContents addObject:@"[Software\\\\Wine\\\\Explorer\\\\Desktops]"];
		[newUserRegContents addObject:[NSString stringWithFormat:@"\"%@\"=\"%@\"",desktopName,[resolution stringByReplacingOccurrencesOfString:@" " withString:@"x"]]];
	}
	//write array back to file
	[self writeStringArray:[NSArray arrayWithArray:newUserRegContents] toFile:[NSString stringWithFormat:@"%@/user.reg",winePrefix]];
}

- (void)setToNoVirtualDesktop
{
	//if file doesn't exist, don't do anything
	if (!([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/user.reg",winePrefix]]))
		return;
	//read in user.reg to an array
	NSArray *userRegContents = [self readFileToStringArray:[NSString stringWithFormat:@"%@/user.reg",winePrefix]];
	NSMutableArray *newUserRegContents = [NSMutableArray arrayWithCapacity:[userRegContents count]];
	BOOL eFound = NO;
	BOOL eDFound = NO;
	for (NSString *item in userRegContents)
	{
		//if it finds "[Software\\Wine\\Explorer]" add it and make sure next line is set right
		if ([item hasPrefix:@"[Software\\\\Wine\\\\Explorer]"])
		{
			[newUserRegContents addObject:item];
			[newUserRegContents addObject:@""];
			eFound = YES;
			continue;
		}
		if ([item hasPrefix:@"[Software\\\\Wine\\\\Explorer\\\\Desktops]"])
		{
			[newUserRegContents addObject:item];
			[newUserRegContents addObject:@""];
			eDFound = YES;
			continue;
		}
		if (eFound && !([item hasPrefix:@"["])) continue;
		else eFound = NO;
		if (eDFound && !([item hasPrefix:@"["])) continue;
		else eDFound = NO;
		//if it makes it thorugh everything, then its a normal line that is needed.
		[newUserRegContents addObject:item];
	}
	//write array back to file
	[self writeStringArray:[NSArray arrayWithArray:newUserRegContents] toFile:[NSString stringWithFormat:@"%@/user.reg",winePrefix]];
}

- (NSArray *)readFileToStringArray:(NSString *)theFile
{
	return [[NSString stringWithContentsOfFile:theFile encoding:NSUTF8StringEncoding error:nil] componentsSeparatedByString:@"\n"];
}

- (void)writeStringArray:(NSArray *)theArray toFile:(NSString *)theFile
{
	[[NSFileManager defaultManager] removeItemAtPath:theFile error:nil];
	[[theArray componentsJoinedByString:@"\n"] writeToFile:theFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (BOOL)pidRunning:(NSString *)pid
{
	if ([pid isEqualToString:@"-1"]) return NO;
	char *tmp;
	BOOL answer = NO;
	intmax_t xmax = strtoimax([pid UTF8String], &tmp, 10);
	if (kill((pid_t)xmax, 0) == 0) answer = YES;
	return answer;
}

- (NSString *)startWine
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *returnPID=@"-1";
	if (nonStandardRun)
	{
		[self setToNoVirtualDesktop];
		if ([wssCommand isEqualToString:@"WSS-wineboot"])
		{
			NSString *wineDebugLine = @"err-all,warn-all,fixme-all,trace-all";
			NSString *wineLogFile = @"/dev/null";
			[self systemCommand:[NSString stringWithFormat:@"export WINEDLLOVERRIDES=\"mshtml=\";export WINEDEBUG=%@;export PATH=\"%@/WineskinEngine.bundle/Wine/bin:%@/WineskinEngine.bundle/X11/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin\";export DISPLAY=%@;export WINEPREFIX=\"%@\";DYLD_FALLBACK_LIBRARY_PATH=\"%@/WineskinEngine.bundle/X11/lib:%@/WineskinEngine.bundle/Wine/lib:/usr/lib:/usr/libexec:/usr/lib/system:/usr/X11/lib:/usr/X11R6/lib\" wine wineboot > \"%@\" 2>&1",wineDebugLine,winePrefix,winePrefix,theDisplayNumber,winePrefix,winePrefix,winePrefix,wineLogFile]];
			usleep(3000000);
			//fix user name entires over to public
			NSArray *userReg = [self readFileToStringArray:[NSString stringWithFormat:@"%@/user.reg",winePrefix]];
			NSMutableArray *newUserReg = [NSMutableArray arrayWithCapacity:[userReg count]];
			for (NSString *item in userReg)
				[newUserReg addObject:[item stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"C:\\users\\%@",NSUserName()] withString:@"C:\\users\\Public"]];
			[self writeStringArray:[NSArray arrayWithArray:newUserReg] toFile:[NSString stringWithFormat:@"%@/user.reg",winePrefix]];
			NSArray *userDefReg = [self readFileToStringArray:[NSString stringWithFormat:@"%@/userdef.reg",winePrefix]];
			NSMutableArray *newUserDefReg = [NSMutableArray arrayWithCapacity:[userDefReg count]];
			for (NSString *item in userDefReg)
				[newUserDefReg addObject:[item stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"C:\\users\\%@",NSUserName()] withString:@"C:\\users\\Public"]];
			[self writeStringArray:[NSArray arrayWithArray:newUserDefReg] toFile:[NSString stringWithFormat:@"%@/userdef.reg",winePrefix]];
			// need Temp folder in Public folder
			[fm createDirectoryAtPath:[NSString stringWithFormat:@"%@/drive_c/users/Public/Temp",winePrefix] withIntermediateDirectories:YES attributes:nil error:nil];
		}
		else if ([wssCommand isEqualToString:@"WSS-wineprefixcreate"] || [wssCommand isEqualToString:@"WSS-wineprefixcreatenoregs"])
		{
			NSString *wineDebugLine = @"err-all,warn-all,fixme-all,trace-all";
			NSString *wineLogFile = @"/dev/null";
			//remove the .update-timestamp file... so we will get Gecko prompt with a refresh.
			[fm removeItemAtPath:[NSString stringWithFormat:@"%@/.update-timestamp",winePrefix] error:nil];
			[self systemCommand:[NSString stringWithFormat:@"export WINEDEBUG=%@;export PATH=\"%@/WineskinEngine.bundle/Wine/bin:%@/WineskinEngine.bundle/X11/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin\";export DISPLAY=%@;export WINEPREFIX=\"%@\";DYLD_FALLBACK_LIBRARY_PATH=\"%@/WineskinEngine.bundle/X11/lib:%@/WineskinEngine.bundle/Wine/lib:/usr/lib:/usr/libexec:/usr/lib/system:/usr/X11/lib:/usr/X11R6/lib\" wine wineboot > \"%@\" 2>&1",wineDebugLine,winePrefix,winePrefix,theDisplayNumber,winePrefix,winePrefix,winePrefix,wineLogFile]];
			usleep(3000000);
			if ([wssCommand isEqualToString:@"WSS-wineprefixcreate"])
			{
				//load Wineskin default reg entries
				[self systemCommand:[NSString stringWithFormat:@"export WINEDEBUG=%@;export PATH=\"%@/WineskinEngine.bundle/Wine/bin:%@/WineskinEngine.bundle/X11/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin\";export DISPLAY=%@;export WINEPREFIX=\"%@\";DYLD_FALLBACK_LIBRARY_PATH=\"%@/WineskinEngine.bundle/X11/lib:%@/WineskinEngine.bundle/Wine/lib:/usr/lib:/usr/libexec:/usr/lib/system:/usr/X11/lib:/usr/X11R6/lib\" wine regedit \"%@/../Wineskin.app/Contents/Resources/remakedefaults.reg\" > \"%@\" 2>&1",wineDebugLine,winePrefix,winePrefix,theDisplayNumber,winePrefix,winePrefix,winePrefix,contentsFold,wineLogFile]];
				usleep(5000000);
			}
			//fix user name entires over to public
			NSArray *userReg = [self readFileToStringArray:[NSString stringWithFormat:@"%@/user.reg",winePrefix]];
			NSMutableArray *newUserReg = [NSMutableArray arrayWithCapacity:[userReg count]];
			for (NSString *item in userReg)
				[newUserReg addObject:[item stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"C:\\users\\%@",NSUserName()] withString:@"C:\\users\\Public"]];
			[self writeStringArray:[NSArray arrayWithArray:newUserReg] toFile:[NSString stringWithFormat:@"%@/user.reg",winePrefix]];
			NSArray *userDefReg = [self readFileToStringArray:[NSString stringWithFormat:@"%@/userdef.reg",winePrefix]];
			NSMutableArray *newUserDefReg = [NSMutableArray arrayWithCapacity:[userDefReg count]];
			for (NSString *item in userDefReg)
				[newUserDefReg addObject:[item stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"C:\\users\\%@",NSUserName()] withString:@"C:\\users\\Public"]];
			[self writeStringArray:[NSArray arrayWithArray:newUserDefReg] toFile:[NSString stringWithFormat:@"%@/userdef.reg",winePrefix]];
			// need Temp folder in Public folder
			[fm createDirectoryAtPath:[NSString stringWithFormat:@"%@/drive_c/users/Public/Temp",winePrefix] withIntermediateDirectories:YES attributes:nil error:nil];
			// do a chmod on the whole wrapper to 755... shouldn't breka anything but should prevent issues.
			// Task Number 3221715 Fix Wrapper Permissions
			//cocoa command don't seem to be working right, but chmod system command works fine.
			[self systemCommand:[NSString stringWithFormat:@"chmod -R 755 \"%@\"",appNameWithPath]];
			// need to chmod 777 on Contents, Resources, and Resources/* for multiuser fix on same machine
			[self systemCommand:[NSString stringWithFormat:@"chmod 777 \"%@\"",contentsFold]];
			[self systemCommand:[NSString stringWithFormat:@"chmod 777 \"%@\"",winePrefix]];
			NSArray *tmpy2 = [fm contentsOfDirectoryAtPath:winePrefix error:nil];
			for (NSString *item in tmpy2)
				[self systemCommand:[NSString stringWithFormat:@"chmod 777 \"%@/%@\"",winePrefix,item]];
		}
		else if ([wssCommand isEqualToString:@"WSS-winetricks"])
		{
			NSString *wineDebugLine = @"err+all,warn-all,fixme+all,trace-all";
			NSString *wineLogFile = [NSString stringWithFormat:@"%@/Logs/Winetricks.log",winePrefix];
			if ([winetricksCommand2 isEqualToString:@"list"]) //just getting a list of packages... X should NOT be running.
				[self systemCommand:[NSString stringWithFormat:@"export WINEDEBUG=%@;cd \"%@/../Wineskin.app/Contents/Resources\";export PATH=\"$PWD:%@/WineskinEngine.bundle/Wine/bin:%@/WineskinEngine.bundle/X11/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin\";export DISPLAY=%@;export WINEPREFIX=\"%@\";DYLD_FALLBACK_LIBRARY_PATH=\"%@/WineskinEngine.bundle/X11/lib:%@/WineskinEngine.bundle/Wine/lib:/usr/lib:/usr/libexec:/usr/lib/system:/usr/X11/lib:/usr/X11R6/lib\" winetricks --no-isolate %@ > \"%@\"",wineDebugLine,contentsFold,winePrefix,winePrefix,theDisplayNumber,winePrefix,winePrefix,winePrefix,winetrickCommandsList,wineLogFile]];
			else if ([winetricksCommand isEqualToString:@"list"])
				[self systemCommand:[NSString stringWithFormat:@"export WINEDEBUG=%@;cd \"%@/../Wineskin.app/Contents/Resources\";export PATH=\"$PWD:%@/WineskinEngine.bundle/Wine/bin:%@/WineskinEngine.bundle/X11/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin\";export DISPLAY=%@;export WINEPREFIX=\"%@\";DYLD_FALLBACK_LIBRARY_PATH=\"%@/WineskinEngine.bundle/X11/lib:%@/WineskinEngine.bundle/Wine/lib:/usr/lib:/usr/libexec:/usr/lib/system:/usr/X11/lib:/usr/X11R6/lib\" winetricks --no-isolate \"%@\" > \"%@\"",wineDebugLine,contentsFold,winePrefix,winePrefix,theDisplayNumber,winePrefix,winePrefix,winePrefix,winetricksCommand,wineLogFile]];
			else
				[self systemCommand:[NSString stringWithFormat:@"export WINEDEBUG=%@;cd \"%@/../Wineskin.app/Contents/Resources\";export PATH=\"$PWD:%@/WineskinEngine.bundle/Wine/bin:%@/WineskinEngine.bundle/X11/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin\";export DISPLAY=%@;export WINEPREFIX=\"%@\";DYLD_FALLBACK_LIBRARY_PATH=\"%@/WineskinEngine.bundle/X11/lib:%@/WineskinEngine.bundle/Wine/lib:/usr/lib:/usr/libexec:/usr/lib/system:/usr/X11/lib:/usr/X11R6/lib\" winetricks --no-isolate \"%@\" > \"%@\" 2>&1",wineDebugLine,contentsFold,winePrefix,winePrefix,theDisplayNumber,winePrefix,winePrefix,winePrefix,winetricksCommand,wineLogFile]];
			usleep(5000000); // sometimes it dumps out slightly too fast... just hold for a few seconds
		}
	}
	else //Normal Wine Run
	{	
		//set desktop name for VD
		NSString *virtualDesktopName = [x11PrefFileName stringByReplacingOccurrencesOfString:@".Wineskin.prefs" withString:@""];
		//edit reg entiries for VD settings
		if ([vdResolution isEqualToString:@"novd"]) [self setToNoVirtualDesktop];
		else [self setToVirtualDesktop:vdResolution named:virtualDesktopName];
		// wineserver check to see if this is a multirun customexe
		NSArray *wineserverPIDCheckArray = [self readFileToStringArray:wineserverPIDFile];
		if ([self pidRunning:[wineserverPIDCheckArray objectAtIndex:0]]) returnPID = [wineserverPIDCheckArray objectAtIndex:0];
		//do not run if wineserver already running.
		if ([returnPID isEqualToString:@"-1"])
		{
			//make first pid array
			NSArray *firstPIDlist = [self makePIDArray:@"wineserver"];
			//start wineserver
			[self systemCommand:[NSString stringWithFormat:@"%@export PATH=\"%@/WineskinEngine.bundle/Wine/bin:%@/WineskinEngine.bundle/X11/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin\";launchctl limit maxfiles %@ %@;ulimit -n %@ > /dev/null 2>&1;export DISPLAY=%@;export WINEPREFIX=\"%@\";cd \"%@/WineskinEngine.bundle/Wine/bin\";DYLD_FALLBACK_LIBRARY_PATH=\"%@/WineskinEngine.bundle/X11/lib:%@/WineskinEngine.bundle/Wine/lib:/usr/lib:/usr/libexec:/usr/lib/system:/usr/X11/lib:/usr/X11R6/lib\" wineserver > /dev/null 2>&1",cliCustomCommands,winePrefix,winePrefix,uLimitNumber,uLimitNumber,uLimitNumber,theDisplayNumber,winePrefix,winePrefix,winePrefix,winePrefix]];
			//do loop compare to find correct PID, only try 3 times, then fail
			BOOL match = YES;
			int i = 0;
			for (i=0;i<3;i++)
			{
				NSArray *secondPIDlist = [self makePIDArray:@"wineserver"];
				for(NSString *secondPIDlistItem in secondPIDlist)
				{
					match = NO;
					for(NSString *firstPIDlistItem in firstPIDlist)
						if ([secondPIDlistItem isEqualToString:firstPIDlistItem]) match = YES;
					if (!match)
					{
						returnPID = secondPIDlistItem;
						break;
					}
				}
				if (!match) break;
			}
			//if no PID found, do error
			if ([returnPID isEqualToString:@"-1"])
			{
				NSLog(@"Error! launching wineserver failed! no new wineserver PID found!\n");
				CFUserNotificationDisplayNotice(0, 0, NULL, NULL, NULL, CFSTR("Wineskin Error"), (CFStringRef)@"ERROR! Launching wineserver failed! No new wineserver PID found!", NULL);
				[fm release];
				return @"-1";
			}
			//write out new pid file
			[self writeStringArray:[NSArray arrayWithObjects:[NSString stringWithFormat:@"%@\n",returnPID],nil] toFile:wineserverPIDFile];
		}
		else //wineserver was already running, use old display setting
		{
			if (openingFiles) killWineskin = YES;
			NSArray *displayArray = [self readFileToStringArray:displayNumberFile];
			theDisplayNumber = [displayArray objectAtIndex:0];
		}
		//write out new display file
		[self writeStringArray:[NSArray arrayWithObjects:[NSString stringWithFormat:@"%@\n",theDisplayNumber],nil] toFile:displayNumberFile];
		NSString *wineDebugLine;
		NSString *wineLogFile;
		//set log file names, and stuff
		wineLogFile = [NSString stringWithFormat:@"%@/Logs/LastRunWine.log",winePrefix];
		if (debugEnabled && !fullScreenOption) //standard log
			wineDebugLine = [NSString stringWithFormat:@"%@",wineDebugLineFromPlist];
		else if (debugEnabled && fullScreenOption) //always need a log with x11settings
			wineDebugLine = [NSString stringWithFormat:@"%@,trace+x11settings",wineDebugLineFromPlist];
		else if (!debugEnabled && fullScreenOption) //need log for reso changes
			wineDebugLine = @"err-all,warn-all,fixme-all,trace+x11settings";
		else //this should be rootless with no debug... don't need a log of any type.
		{
			wineLogFile = @"/dev/null";
			wineDebugLine = @"err-all,warn-all,fixme-all,trace-all";
		}
		//fix start.exe line
		NSString *startExeLine = @"";
		if (runWithStartExe) startExeLine = @" start /unix";		
		//make sure correct wineserver is still running
		if (![self pidRunning:returnPID])
		{
			[fm release];
			return @"-1";
		}
		//Wine start section... if opening files handle differently.
		if (openingFiles)
			for (NSString *item in filesToRun) //start wine with files
				[self systemCommand:[NSString stringWithFormat:@"%@export PATH=\"%@/WineskinEngine.bundle/Wine/bin:%@/WineskinEngine.bundle/X11/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin\";launchctl limit maxfiles %@ %@;ulimit -n %@ > /dev/null 2>&1;export WINEDEBUG=%@;export DISPLAY=%@;export WINEPREFIX=\"%@\";cd \"%@/WineskinEngine.bundle/Wine/bin\";DYLD_FALLBACK_LIBRARY_PATH=\"%@/WineskinEngine.bundle/X11/lib:%@/WineskinEngine.bundle/Wine/lib:/usr/lib:/usr/libexec:/usr/lib/system:/usr/X11/lib:/usr/X11R6/lib\" wine start /unix \"%@\" > \"%@\" 2>&1 &",cliCustomCommands,winePrefix,winePrefix,uLimitNumber,uLimitNumber,uLimitNumber,wineDebugLine,theDisplayNumber,winePrefix,winePrefix,winePrefix,winePrefix,item,wineLogFile]];
		else  //launch Wine normally
			[self systemCommand:[NSString stringWithFormat:@"%@export PATH=\"%@/WineskinEngine.bundle/Wine/bin:%@/WineskinEngine.bundle/X11/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin\";launchctl limit maxfiles %@ %@;ulimit -n %@ > /dev/null 2>&1;export WINEDEBUG=%@;export DISPLAY=%@;export WINEPREFIX=\"%@\";cd \"%@\";DYLD_FALLBACK_LIBRARY_PATH=\"%@/WineskinEngine.bundle/X11/lib:%@/WineskinEngine.bundle/Wine/lib:/usr/lib:/usr/libexec:/usr/lib/system:/usr/X11/lib:/usr/X11R6/lib\" wine%@ \"%@\"%@ > \"%@\" 2>&1 &",cliCustomCommands,winePrefix,winePrefix,uLimitNumber,uLimitNumber,uLimitNumber,wineDebugLine,theDisplayNumber,winePrefix,wineRunLocation,winePrefix,winePrefix,startExeLine,wineRunFile,programFlags,wineLogFile]];
		vdResolution = [vdResolution stringByReplacingOccurrencesOfString:@"x" withString:@" "];
	}
	[fm release];
	return returnPID;
}

- (void)sleepAndMonitor
{
	NSFileManager *fm = [NSFileManager defaultManager];
	int oldTimeStamp=0;
	int oldInfoPlistTimeStamp=0;
	struct stat stat_p;
	if (useGamma) [self setGamma:gammaCorrection];
	NSString *newScreenReso;
	BOOL fixGamma = NO;
	int fixGammaCounter = 0;
	while ([self pidRunning:wineServerPID])
	{
		//check for xrandr made files in /tmp
		// /tmp/WineskinXrandrTempFile line 1 will be fullscreen X res, and line 2 is fullscreen y res.
		// /tmp/WineskinXrandrTempFileSwitch file existence means need to toggle back to fullscreen with xrandr to above X,Y gotten earlier
		if ([fm fileExistsAtPath:@"/tmp/WineskinXrandrTempFile"])
		{
			//new fullscreen resolution to remember.  read in new X and Y
			NSArray *tempArray = [self readFileToStringArray:@"/tmp/WineskinXrandrTempFile"];
			[fm removeItemAtPath:@"/tmp/WineskinXrandrTempFile" error:nil];
			randrXres = [tempArray objectAtIndex:0];
			randrYres = [tempArray objectAtIndex:1];
			if (useGamma)
			{
				// OSX sets gamma back to default on a resolution change, but not right away.. it can take a few seconds
				// nned to make a way it'll try a few times over the next few loops to fix the gamma
				fixGamma = YES;
				fixGammaCounter = 0;
			}
		}
		if ([fm fileExistsAtPath:@"/tmp/WineskinXrandrTempFileSwitch"])
		{
			//need to call xrandr for the last fullscreen res
			[fm removeItemAtPath:@"/tmp/WineskinXrandrTempFileSwitch" error:nil];
			if (!([randrXres isEqualToString:@"0"]) && !([randrYres isEqualToString:@"0"]))
				[self setResolution:[NSString stringWithFormat:@"%@ %@",randrXres,randrYres]];
		}
		//if WineskinX11 is not longer running, tell wineserver to close
		if (![self pidRunning:x11PID])
			[self systemCommand:[NSString stringWithFormat:@"export PATH=\"%@/WineskinEngine.bundle/Wine/bin:%@/WineskinEngine.bundle/X11/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin\";export DISPLAY=%@;export WINEPREFIX=\"%@\";cd \"%@/WineskinEngine.bundle/Wine/bin\";DYLD_FALLBACK_LIBRARY_PATH=\"%@/WineskinEngine.bundle/X11/lib:%@/WineskinEngine.bundle/Wine/lib:/usr/lib:/usr/libexec:/usr/lib/system:/usr/X11/lib:/usr/X11R6/lib\" wineserver -k > /dev/null 2>&1",winePrefix,winePrefix,theDisplayNumber,winePrefix,winePrefix,winePrefix,winePrefix]];
		//if running in override fullscreen, need to handle resolution changes
		if(fullScreenOption)
		{
			//get timestamp for wine log to see if it has changed
			stat([[NSString stringWithFormat:@"%@/Logs/LastRunWine.log",winePrefix] UTF8String], &stat_p);
			//if changed, read to get resolution to change to
			if (stat_p.st_mtime > oldTimeStamp)
			{
				//get previous wineserver
				NSArray *tempArray = [self readFileToStringArray:[NSString stringWithFormat:@"%@/Logs/LastRunWine.log",winePrefix]];
				for (NSString *item in tempArray)
				{
					if ([item hasPrefix:@"trace:x11settings:X11DRV_ChangeDisplaySettingsEx width="])
					{
						newScreenReso = [item stringByReplacingOccurrencesOfString:@"trace:x11settings:X11DRV_ChangeDisplaySettingsEx width=" withString:@""];
						newScreenReso = [newScreenReso stringByReplacingOccurrencesOfString:@"height=" withString:@""];
						newScreenReso = [newScreenReso substringToIndex:[newScreenReso rangeOfString:@" bpp="].location];
						//change resolution
						[self setResolution:newScreenReso];
						NSLog(@"Changing resolution to request: %@",newScreenReso);
						break;
					}
				}
			}
			//if not in debug mode blank the log
			if (!debugEnabled)
			{
				//remaking the file causes problems... need to open and blank it without re-writing it.
				FILE *file; 
				file = fopen([[NSString stringWithFormat:@"%@/Logs/LastRunWine.log",winePrefix] UTF8String],"w");
				fclose(file);
			}
			//set new time stamp
			stat ([[NSString stringWithFormat:@"%@/Logs/LastRunWine.log",winePrefix] UTF8String], &stat_p);
			oldTimeStamp = stat_p.st_mtime;
		}
		if (fixGamma)
		{
			[self setGamma:gammaCorrection];
			fixGammaCounter++;
		}
		if (fixGammaCounter > 6) fixGamma = NO;
		usleep(1250000); // sleeping in background 1.25 seconds
	}
	[fm release];
}

- (void)cleanUpAndShutDown:(BOOL)removeSymlinks
{
	//fix screen resolution back to original if fullscreen
	if (fullScreenOption)
	{
		NSLog(@"Changing the resolution back to %@...",currentResolution);
		[self setResolution:currentResolution];
	}
	//kill the X server
	char *tmp;
	kill((pid_t)(strtoimax([x11PID UTF8String], &tmp, 10)), 9);
	//fix user folders back
	NSFileManager *fm = [NSFileManager defaultManager];
	if ([fm fileExistsAtPath:[NSString stringWithFormat:@"%@/drive_c/users/%@",winePrefix,NSUserName()]])
	{
		[fm moveItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/%@",winePrefix,NSUserName()] toPath:[NSString stringWithFormat:@"%@/drive_c/users/Wineskin",winePrefix] error:nil];
		if (removeSymlinks)
		{
			[fm removeItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/Wineskin/My Documents",winePrefix] error:nil];
			[fm removeItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/Wineskin/Desktop",winePrefix] error:nil];
			[fm removeItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/Wineskin/My Videos",winePrefix] error:nil];
			[fm removeItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/Wineskin/My Music",winePrefix] error:nil];
			[fm removeItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/Wineskin/My Pictures",winePrefix] error:nil];
		}
	}
	if (removeSymlinks && [fm fileExistsAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover",winePrefix]])
	{
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover/My Documents",winePrefix] error:nil];
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover/Desktop",winePrefix] error:nil];
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover/My Videos",winePrefix] error:nil];
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover/My Music",winePrefix] error:nil];
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/drive_c/users/crossover/My Pictures",winePrefix] error:nil];
		
	}
	//if not in debug mode, remove last wine log
	if (!debugEnabled)
	{
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Logs/LastRunWine.log",winePrefix] error:nil];
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Logs/LastRunX11.log",winePrefix] error:nil];
		[fm removeItemAtPath:[NSString stringWithFormat:@"%@/Logs/Winetricks.log",winePrefix] error:nil];
	}
	[fm release];
}
- (void)ds:(NSString *)input
{
	CFUserNotificationDisplayNotice(0, 0, NULL, NULL, NULL, CFSTR("Contents of String"), (CFStringRef)input, NULL);
}
@end

int main(int argc, char *argv[])
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	//get argv to pass on to mainRun
	NSMutableArray *temp = [NSMutableArray arrayWithCapacity:10];
	int i;
	for (i=1;i<argc;i++) [temp addObject:[NSString stringWithUTF8String:argv[i]]];
	id WineskinRun;
	WineskinRun=[Wineskin new];
	[WineskinRun mainRun:temp];
	[WineskinRun release];
	[pool release];
	return 0;
}
