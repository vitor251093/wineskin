//
//  WineskinAppDelegate.h
//  Wineskin
//
//  Copyright 2011 by The Wineskin Project and doh123@doh123.com All rights reserved.
//  Licensed for use under the LGPL <http://www.gnu.org/licenses/lgpl-2.1.txt>
//

#import <Cocoa/Cocoa.h>

@interface WineskinAppDelegate : NSObject //<NSApplicationDelegate>
{
	int disableButtonCounter;
	BOOL disableXButton;
	BOOL winetricksDone;
	
	//main window
    IBOutlet NSWindow *window;
	IBOutlet NSWindow *chooseExeWindow;
	IBOutlet NSPopUpButton *exeChoicePopUp;
	IBOutlet NSWindow *helpWindow;
	IBOutlet NSWindow *aboutWindow;
	IBOutlet NSTextField *aboutWindowVersionNumber;
	
	//Screen Options window
	IBOutlet NSWindow *screenOptionsWindow;
	IBOutlet NSMatrix *automaticOverrideToggle;
	IBOutlet NSButtonCell *automaticOverrideToggleOverrideButton;
	IBOutlet NSButtonCell *fullscreenRootlessToggleFullscreenButton;
	IBOutlet NSButtonCell *normalWindowsVirtualDesktopToggleVirtualDesktopButton;
	IBOutlet NSButtonCell *forceNormalWindowsUseTheseSettingsToggleUseTheseSettingsButton;
	IBOutlet NSButtonCell *automaticOverrideToggleAutomaticButton;
	IBOutlet NSMatrix *fullscreenRootlessToggle;
	IBOutlet NSTabView *fullscreenRootlesToggleTabView;
	IBOutlet NSButtonCell *fullscreenRootlessToggleRootlessButton;
	IBOutlet NSMatrix *normalWindowsVirtualDesktopToggle;
	IBOutlet NSButtonCell *normalWindowsVirtualDesktopToggleNormalWindowsButton;
	IBOutlet NSMatrix *forceNormalWindowsUseTheseSettingsToggle;
	IBOutlet NSButtonCell *forceNormalWindowsUseTheseSettingsToggleForceButton;
	IBOutlet NSPopUpButton *virtualDesktopResolution;
	IBOutlet NSPopUpButton *fullscreenResolution;
	IBOutlet NSPopUpButton *colorDepth;
	IBOutlet NSPopUpButton *switchPause;
	IBOutlet NSSlider *gammaSlider;
	IBOutlet NSButton *windowManagerCheckBoxButton;
	IBOutlet NSButton *autoDetectGPUInfoCheckBoxButton;
	
	//advanced menu
	IBOutlet NSWindow *advancedWindow;
	IBOutlet NSWindow *configHelpWindow;
	IBOutlet NSWindow *toolsHelpWindow;
	IBOutlet NSButton *testRunButton;
	IBOutlet NSButton *advancedDoneButton;
	IBOutlet NSProgressIndicator *toolRunningPI;
	IBOutlet NSTextField *toolRunningPIText;
	IBOutlet NSTabView *tab;
	
	//advanced menu - Configuration Tab
	IBOutlet NSTextField *windowsExeTextField;
	IBOutlet NSTextField *exeFlagsTextField;
	IBOutlet NSTextField *menubarNameTextField;
	IBOutlet NSTextField *versionTextField;
	IBOutlet NSTextField *wineDebugTextField;
	IBOutlet NSTextField *customCommandsTextField;
	IBOutlet NSButton *useStartExeCheckmark;
	IBOutlet NSImageView *iconImageView;
	IBOutlet NSButton *exeBrowseButton;
	IBOutlet NSButton *iconBrowseButton;
	IBOutlet NSPopUpButton *extPopUpButton;
	IBOutlet NSButton *extEditButton;
	
	//advanced menu - Tools Tab
	IBOutlet NSButton *winecfgButton;
	IBOutlet NSButton *regeditButton;
	IBOutlet NSButton *taskmgrButton;
	IBOutlet NSButton *uninstallerButton;
	IBOutlet NSButton *rebuildWrapperButton;
	IBOutlet NSButton *refreshWrapperButton;
	IBOutlet NSButton *winetricksButton;
	IBOutlet NSButton *customExeButton;
	IBOutlet NSButton *changeEngineButton;
	IBOutlet NSTextField *currentVersionTextField;
	IBOutlet NSButton *updateWrapperButton;
	
	//advanced menu - Options Tab
	IBOutlet NSButton *optSendsAltCheckBoxButton;
	IBOutlet NSButton *mapUserFoldersCheckBoxButton;
	IBOutlet NSButton *confirmQuitCheckBoxButton;
	
	//change engine window
	IBOutlet NSWindow *changeEngineWindow;
	IBOutlet NSPopUpButton *changeEngineWindowPopUpButton;
	IBOutlet NSButton *engineWindowOkButton;
	
	//busy window
	IBOutlet NSWindow *busyWindow;
	IBOutlet NSProgressIndicator *waitWheel;
	
	//cexe window
	IBOutlet NSWindow *cEXEWindow;
	IBOutlet NSTextField *cEXENameToUseTextField;
	IBOutlet NSTextField *cEXEWindowsExeTextField;
	IBOutlet NSTextField *cEXEFlagsTextField;
	IBOutlet NSButton *cEXEUseStartExeCheckmark;
	IBOutlet NSImageView *cEXEIconImageView;
	IBOutlet NSButton *cEXEBrowseButton;
	IBOutlet NSButton *cEXEIconBrowseButton;
	IBOutlet NSMatrix *cEXEautoOrOvverrideDesktopToggle;
	IBOutlet NSButtonCell *cEXEautoOrOvverrideDesktopToggleAutomaticButton;
	IBOutlet NSMatrix *cEXEFullscreenRootlessToggle;
	IBOutlet NSButtonCell *cEXEFullscreenRootlessToggleRootlessButton;
	IBOutlet NSTabView *cEXEFullscreenRootlesToggleTabView;
	IBOutlet NSMatrix *cEXENormalWindowsVirtualDesktopToggle;
	IBOutlet NSButtonCell *cEXENormalWindowsVirtualDesktopToggleNormalWindowsButton;
	IBOutlet NSPopUpButton *cEXEVirtualDesktopResolution;
	IBOutlet NSPopUpButton *cEXEFullscreenResolution;
	IBOutlet NSPopUpButton *cEXEColorDepth;
	IBOutlet NSPopUpButton *cEXESwitchPause;
	IBOutlet NSSlider *cEXEGammaSlider;
	
	//Winetricks window
	IBOutlet NSWindow *winetricksWindow;
	IBOutlet NSPopUpButton *winetricksCommandList;
	IBOutlet NSButton *winetricksRunButton;
	IBOutlet NSButton *winetricksCancelButton;
	IBOutlet NSButton *winetricksUpdateButton;
	IBOutlet NSButton *winetricksShowPackageListButton;
	IBOutlet NSButton *winetricksDoneButton;
	IBOutlet NSProgressIndicator *winetricksWaitWheel;
	IBOutlet NSTextView *winetricksOutputText;
	IBOutlet NSScrollView *winetricksOutputTextScrollView;
	NSMutableArray *shPIDs;
	BOOL winetricksCanceled;
	
	//extensions window
	IBOutlet NSWindow *extAddEditWindow;
	IBOutlet NSTextField *extExtensionTextField;
	IBOutlet NSTextField *extCommandTextField;
	
	//ICE
	BOOL isIce;
}

@property (assign) IBOutlet NSWindow *window;

- (void)enableButtons;
- (void)disableButtons;
- (void)systemCommand:(NSString *)commandToRun withArgs:(NSArray *)args;
- (NSString *)systemCommandWithOutputReturned:(NSString *)command;
- (IBAction)topMenuHelpSelected:(id)sender;
- (IBAction)aboutWindow:(id)sender;
/* Functions deactivated, not currently being used
- (NSString *)OSVersion;
- (BOOL)theOSVersionIs105;
- (BOOL)theOSVersionIs106;
- (BOOL)theOSVersionIs107;
- (BOOL)theOSVersionIs108;
*/

//main menu methods
- (IBAction)wineskinWebsiteButtonPressed:(id)sender;
- (IBAction)installWindowsSoftwareButtonPressed:(id)sender;
- (IBAction)chooseExeOKButtonPressed:(id)sender;
- (IBAction)setScreenOptionsPressed:(id)sender;
- (IBAction)advancedButtonPressed:(id)sender;

//Screen Options window methods
- (void)saveScreenOptionsData;
- (void)loadScreenOptionsData;
- (IBAction)doneButtonPressed:(id)sender;
- (IBAction)automaticClicked:(id)sender;
- (IBAction)overrideClicked:(id)sender;
- (IBAction)rootlessClicked:(id)sender;
- (IBAction)fullscreenClicked:(id)sender;
- (IBAction)normalWindowsClicked:(id)sender;
- (IBAction)virtualDesktopClicked:(id)sender;
- (IBAction)gammaChanged:(id)sender;
- (IBAction)windowManagerCheckBoxClicked:(id)sender;

//advanced menu
- (IBAction)advancedMenuDoneButtonPressed:(id)sender;
- (IBAction)testRunButtonPressed:(id)sender;
- (void)runATestRun;
- (IBAction)killWineskinProcessesButtonPressed:(id)sender;
- (IBAction)advancedHelpButtonPressed:(id)sender;

//advanced menu - Configuration Tab
- (void)saveAllData;
- (void)loadAllData;
- (IBAction)windowsExeBrowseButtonPressed:(id)sender;
- (IBAction)iconToUseBrowseButtonPressed:(id)sender;
- (IBAction)extPlusButtonPressed:(id)sender;
- (IBAction)extMinusButtonPressed:(id)sender;
- (IBAction)extEditButtonPressed:(id)sender;

//advanced menu - Tools Tab
- (IBAction)winecfgButtonPressed:(id)sender;
- (void)runWinecfg;
- (IBAction)uninstallerButtonPressed:(id)sender;
- (void)runUninstaller;
- (IBAction)regeditButtonPressed:(id)sender;
- (void)runRegedit;
- (IBAction)taskmgrButtonPressed:(id)sender;
- (void)runTaskmgr;
- (IBAction)rebuildWrapperButtonPressed:(id)sender;
- (IBAction)refreshWrapperButtonPressed:(id)sender;
- (IBAction)changeEngineUsedButtonPressed:(id)sender;
- (IBAction)changeEngineUsedOkButtonPressed:(id)sender;
- (IBAction)changeEngineUsedCancelButtonPressed:(id)sender;
- (IBAction)updateWrapperButtonPressed:(id)sender;
- (IBAction)logsButtonPressed:(id)sender;

//advanced menu - Options Tab
- (IBAction)optSendsAltCheckBoxButtonPressed:(id)sender;
- (IBAction)mapUserFoldersCheckBoxButtonPressed:(id)sender;
- (IBAction)confirmQuitCheckBoxButtonPressed:(id)sender;

//Winetricks
- (IBAction)winetricksButtonPressed:(id)sender;
- (IBAction)winetricksDoneButtonPressed:(id)sender;
- (IBAction)winetricksShowPackageListButtonPressed:(id)sender;
- (IBAction)winetricksUpdateButtonPressed:(id)sender;
- (IBAction)winetricksRunButtonPressed:(id)sender;
- (IBAction)winetricksCancelButtonPressed:(id)sender;
- (void)runWinetrick;
- (void)doTheDangUpdate;
- (void)winetricksWriteFinished;
- (void)updateWinetrickOutput;
- (NSArray *)makePIDArray:(NSString *)processToLookFor;
// cexe maker
- (IBAction)createCustomExeLauncherButtonPressed:(id)sender;
- (IBAction)cEXESaveButtonPressed:(id)sender;
- (IBAction)cEXECancelButtonPressed:(id)sender;
- (IBAction)cEXEBrowseButtonPressed:(id)sender;
- (IBAction)cEXEIconBrowseButtonPressed:(id)sender;
- (IBAction)cEXEAutomaticButtonPressed:(id)sender;
- (IBAction)cEXEOverrideButtonPressed:(id)sender;
- (IBAction)cEXERootlessButtonPressed:(id)sender;
- (IBAction)cEXEFullscreenButtonPressed:(id)sender;
- (IBAction)cEXEGammaChanged:(id)sender;
//extensions window
- (IBAction)extSaveButtonPressed:(id)sender;
- (IBAction)extCancelButtonPressed:(id)sender;
//ICE
- (void)installEngine;
// TESTS
- (void)ds:(NSString *)input;

@end
