//
//  WineskinLauncherAppDelegate.h
//  WineskinLauncher
//
//  Copyright 2011 by The Wineskin Project and doh123@doh123.com All rights reserved.
//  Licensed for use under the LGPL <http://www.gnu.org/licenses/lgpl-2.1.txt>
//

#import <Cocoa/Cocoa.h>

///*
#if (MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_5)
@interface WineskinLauncherAppDelegate : NSObject
#else
@interface WineskinLauncherAppDelegate : NSObject <NSApplicationDelegate>
#endif
//*/
//@interface WineskinLauncherAppDelegate : NSObject <NSApplicationDelegate>
{
	BOOL openedByFile;
	BOOL doFileStart;
	NSString *joinedString;
	IBOutlet NSWindow *window;
	IBOutlet NSProgressIndicator *waitWheel;
}

- (void) doSpecialStartup; // if Fn or Alt held on run
- (void)installEngine; // checks if ICE, and if engine is installed... installs what is needed.
- (NSString *)systemCommand:(NSString *)command; //run system command with output returned
- (void)ds:(NSString *)input; // display string for troubleshooting
@end
