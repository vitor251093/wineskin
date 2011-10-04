//
//  WineskinLauncherAppDelegate.m
//  WineskinLauncher
//
//  Copyright 2011 by The Wineskin Project and doh123@doh123.com All rights reserved.
//  Licensed for use under the LGPL <http://www.gnu.org/licenses/lgpl-2.1.txt>
//

#import "WineskinLauncherAppDelegate.h"

@implementation WineskinLauncherAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	[window setLevel:NSStatusWindowLevel];
	[waitWheel startAnimation:self];
	[self installEngine];
	// Normal run
	if(openedByFile)
	{
		NSString *theSystemCommand = [NSString stringWithFormat: @"\"%@/Contents/Frameworks/bin/Wineskin\" &", [[NSBundle mainBundle] bundlePath]];
		if (doFileStart) theSystemCommand = [NSString stringWithFormat: @"\"%@/Contents/Frameworks/bin/Wineskin\" \"%@\" &", [[NSBundle mainBundle] bundlePath], joinedString];
		system([theSystemCommand UTF8String]);
	}
	[NSApp terminate: nil];
}

- (void)applicationWillFinishLaunching:(NSNotification*)aNotification
{
	doFileStart = NO;
	openedByFile = YES;
/*	SInt32 versionMinor;
	Gestalt(gestaltSystemVersionMinor, &versionMinor);
	if( versionMinor > 5 )
	{
		if (([NSEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) == NSAlternateKeyMask || ([NSEvent modifierFlags] & NSDeviceIndependentModifierFlagsMask) == kCGEventFlagMaskSecondaryFn)
			[self doSpecialStartup];
	}
	else
	{
*/
		CGEventRef event = CGEventCreate(NULL);
		CGEventFlags modifiers = CGEventGetFlags(event);
		CFRelease(event);
		if ((modifiers & kCGEventFlagMaskAlternate) == kCGEventFlagMaskAlternate || (modifiers & kCGEventFlagMaskSecondaryFn) == kCGEventFlagMaskSecondaryFn)
			[self doSpecialStartup];
//	}
}

- (void)doSpecialStartup
{
	//when holding modifier key
	openedByFile = NO;
	NSString* theSystemCommand = [NSString stringWithFormat: @"open \"%@/Wineskin.app\"", [[NSBundle mainBundle] bundlePath]];
	system([theSystemCommand UTF8String]);
}

- (void)installEngine
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSMutableArray *wswineBundleContentsList = [NSMutableArray arrayWithCapacity:2];
	//get directory contents of WineskinEngine.bundle
	NSArray *files = [fm contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/Contents/Frameworks/wswine.bundle/",[[NSBundle mainBundle] bundlePath]] error:nil];
	for (NSString *file in files)
		if ([file hasSuffix:@".bundle.tar.7z"]) [wswineBundleContentsList addObject:[file stringByReplacingOccurrencesOfString:@".tar.7z" withString:@""]];
	
	//exit if not ICE. if Wine or X11 folders are a symlink, need to do ICE.
	BOOL isIce = NO;
	if ([wswineBundleContentsList count] > 0) isIce = YES;
	if (!isIce)
	{
		[fm release];
		return;
	}
	//install Wine on the system
	NSString *wineFile = @"OOPS";
	for (NSString *item in wswineBundleContentsList)
		if ([item hasPrefix:@"WSWine"] && [item hasSuffix:@"ICE.bundle"]) wineFile = [NSString stringWithFormat:@"%@",item];
	//get md5 of wineFile and x11File
	NSString *wineFileMd5 = [[self systemCommand:[NSString stringWithFormat:@"md5 -r \"%@/Contents/Frameworks/wswine.bundle/%@.tar.7z\"",[[NSBundle mainBundle] bundlePath],wineFile]] stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@" %@/Contents/Frameworks/wswine.bundle/%@.tar.7z",[[NSBundle mainBundle] bundlePath],wineFile] withString:@""];
	NSString *wineFileInstalledName = [NSString stringWithFormat:@"%@%@.bundle",[wineFile stringByReplacingOccurrencesOfString:@"bundle" withString:@""],wineFileMd5];
	NSArray *iceFiles = [fm contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/Library/Application Support/Wineskin/Engines/ICE",NSHomeDirectory()] error:nil];
	//if either Wine or X11 version is not installed...
	BOOL wineInstalled = NO;
	for (NSString *file in iceFiles)
		if ([file isEqualToString:wineFileInstalledName]) wineInstalled = YES;
	if (!wineInstalled)
	{
		[window makeKeyAndOrderFront:self];
		NSString *theSystemCommand = [NSString stringWithFormat: @"\"%@/Contents/Frameworks/bin/Wineskin\" WSS-InstallICE", [[NSBundle mainBundle] bundlePath]];
		system([theSystemCommand UTF8String]);
		[window orderOut:self];
	}
	[fm release];
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

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
	if(openedByFile)
	{
		//openedByFile = NO;
		joinedString = [filenames componentsJoinedByString:@"\" \""];
		doFileStart = YES;
	}
}
- (void)ds:(NSString *)input
{
	if (input == nil) input=@"nil";
	NSAlert *TESTER = [[NSAlert alloc] init];
	[TESTER addButtonWithTitle:@"close"];
	[TESTER setMessageText:@"Contents of string"];
	[TESTER setInformativeText:input];
	[TESTER setAlertStyle:NSInformationalAlertStyle];
	[TESTER runModal];
	[TESTER release];
}
@end
