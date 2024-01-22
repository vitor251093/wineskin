//
//  WineskinAppDelegate.h
//  Wineskin
//
//  Copyright 2014 by The Wineskin Project and Urge Software LLC All rights reserved.
//  Licensed for use under the LGPL <http://www.gnu.org/licenses/lgpl-2.1.txt>
//

#import <Cocoa/Cocoa.h>
#import "WineStart.h"
#import "NSPortManager.h"

@interface WineskinLauncherAppDelegate : NSObject <NSApplicationDelegate>
{
    NSPortManager* portManager;
    
    BOOL primaryRun;
    BOOL wrapperRunning;
	IBOutlet NSWindow *window;
	IBOutlet NSProgressIndicator *waitWheel;
    NSFileManager *fm;
    NSMutableArray *globalFilesToOpen;
    NSString *contentsFold;                         //Contents folder in the wrapper
    NSString *resourcesFold;                        //Resources folder in the wrapper
	NSString *frameworksFold;                       //Frameworks folder in the wrapper
    NSString *gstreamerFold;                        //
    NSString *sharedsupportFold;                    //SharedSupport folder in the wrapper
	NSString *appNameWithPath;                      //full path to and including the app name
    NSString *appName;                              //name of our app/wrapper
    NSString *pathGstreamer;                        //
	NSString *lockfile;                             //lockfile being used to know if the app is already in use
    NSString *tmpFolder;                            //where tmp files can be made and used to be specific to just this wrapper
    NSString *tmpwineFolder;                        //wine makes its own tmp & wineserver uses it for each wine process
	NSString *winePrefix;                           //The $WINEPREFIX
    NSString *pathToWineFolder;                     //
    NSString *pathToWineBinFolder;                  //
    NSString *wineLogFile;                          //location of wine log file
    NSString *wineTempLogFile;                      //location of wine temp log file
    NSString *x11LogFile;                           //location of x11 log file
	BOOL fullScreenOption;                          //wether running fullscreen or rootless (RandR is rootless)
	NSMutableString *fullScreenResolutionBitDepth;	//fullscreen bit depth for X server
	NSString *currentResolution;                    //the resolution that was running when the wrapper was started
	NSString *wrapperBundlePID;                     //PID of running wrapper bundle
	BOOL debugEnabled;                              //set if debug mode is being run, to make logs
	BOOL isIce;                                     //YES if ICE engine being used
    BOOL removeX11TraceFromLog;                     //YES if Wineskin added the X11 trace to winedebug to remove them from the output log
	NSString *dyldFallBackLibraryPath;              //the path for DYLD_FALLBACK_LIBRARY_PATH
    NSString *gstPluginPath;                        //GStreamer will scan these paths for GStreamer plug-ins
    NSString *FASTMATH;                             //
    NSString *FENCES;                               //Required by DXVK for Apple/NVidia GPUs (better FPS than CPU Emulation)
    NSString *RESUME;                               //Required by DXVK (wine doesn't handle VK_ERROR_DEVICE_LOST correctly)
    // (https://github.com/KhronosGroup/MoltenVK/commit/14de07b6f4ba7fb02dbfafd2693d15c557edf0ef)
    NSString *SEMAPHORE;                            //Required by DXVK to restore prior behaviour
    NSString *SWIZZLE;                              //Required by DXVK for AMD500/Intel GPUs
    NSString *HIDEBOOT;
    NSString *wineExecutable;                       //the wine executable that will be used for all launches
    NSString *fontFix;                              //force freetype into using rendering mode from pre 2.7
    BOOL useMacDriver;                              //YES if using Mac Driver over X11
    NSString *wineServerName;                       //the name of the Wineserver we'll be launching
	int bundleRandomInt1;
    int bundleRandomInt2;
}

//run system command with output returned
- (NSString *)systemCommand:(NSString *)command;

//the main running of the program...
- (void)mainRun:(NSArray*)filesToOpen;

//Any time its re-ran after its already running, for like opening extra files or Custom EXEs
- (void)secondaryRun:(NSArray*)filesToOpen;

//used to change the global screen resolution for overriding randr
- (void)setResolution:(NSString *)reso;

//returns the current screen resolution
- (NSString *)getScreenResolution;

//Makes an Array with a list of PIDs that match the process name
- (NSArray *)makePIDArray:(NSString *)processToLookFor;

//returns PID of new process (after it appears)
- (NSString *)getNewPid:(NSString *)processToLookFor from:(NSArray *)firstPIDlist confirm:(bool)confirm_pid;

//sets the drive_c/user/Wineskin folder correctly for a run
- (void)setUserFolders:(BOOL)doSymlinks;

//Makes sure the current user owns the winepeefix, or Wine will not run
- (void)fixWinePrefixForCurrentUser;

//Tries to get the GPU info and enter it in the Wine Registry, use before starting Wine
- (void)tryToUseGPUInfo;

//remove GPU info from Registry
- (void)removeGPUInfo;

//checks if Mac is set in Wine
- (BOOL)checkToUseMacDriver;

//reads a file and passes back contents as an array of strings
- (NSArray *)readFileToStringArray:(NSString *)theFile;

//writes an array to a normal text file, each entry on a line.
- (void)writeStringArray:(NSArray *)theArray toFile:(NSString *)theFile;

//returns true if running PID has the specified name
- (BOOL)isPID:(NSString *)pid named:(NSString *)name;

//returns true if Wineserver for this wrapper is running
- (BOOL)isWineserverRunning;

//start wine
- (void)startWine:(WineStart *)wineStart;

//background monitoring while Wine is running
- (void)sleepAndMonitor;

//run when shutting down
- (void)cleanUpAndShutDown;

@end
