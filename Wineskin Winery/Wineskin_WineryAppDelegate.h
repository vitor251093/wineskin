//
//  Wineskin_WineryAppDelegate.h
//  Wineskin Winery
//
//  Copyright 2011-2013 by The Wineskin Project and Urge Software LLC All rights reserved.
//  Licensed for use under the LGPL <http://www.gnu.org/licenses/lgpl-2.1.txt>
//

#import <Cocoa/Cocoa.h>

#import "NSWineskinEngine.h"

@interface Wineskin_WineryAppDelegate : NSObject <NSApplicationDelegate>
{
	//main window
    IBOutlet NSWindow *__unsafe_unretained window;
	IBOutlet NSWindow *aboutWindow;
	IBOutlet NSTextField *aboutWindowVersionNumber;
	IBOutlet NSWindow *helpWindow;
	IBOutlet NSMenuItem *aboutWindowMenuItem;
	IBOutlet NSTextField *wrapperVersion;
	IBOutlet NSTableView *installedEngines;
	IBOutlet NSTextField *engineAvailableLabel;
	IBOutlet NSTextField *updateAvailableLabel;
    IBOutlet NSButton *hideXQuartzEnginesCheckBox;
    IBOutlet NSButton *compressEngineCheckBox;
	IBOutlet NSButton *updateButton;
	IBOutlet NSButton *createWrapperButton;
	
	//downloading window
	IBOutlet NSWindow *downloadingWindow;
	IBOutlet NSTextField *urlInput;
	IBOutlet NSTextField *urlOutput;
	IBOutlet NSTextField *fileName;
    IBOutlet NSTextField *fileOutputName;
	IBOutlet NSTextField *fileNameDestination;
	IBOutlet NSProgressIndicator *progressBar;
	IBOutlet NSButton *cancelButton;
	IBOutlet NSButton *downloadButton;
	NSURLConnection *connection;
	NSURLRequest *request;
	NSMutableData *payload;
	
	//add engine window
	IBOutlet NSWindow *addEngineWindow;
	IBOutlet NSButton *engineWindowDownloadAndInstallButton;
	IBOutlet NSButton *engineWindowViewWineReleaseNotesButton;
	IBOutlet NSButton *engineWindowDontPromptAsNewButton;
	IBOutlet NSPopUpButton *engineWindowEngineList;
	
	//engine build window
	IBOutlet NSWindow *wineskinEngineBuilderWindow;
	IBOutlet NSTextField *engineBuildWineSource;
	IBOutlet NSTextField *engineBuildConfigurationOptions;
	IBOutlet NSTextField *engineBuildEngineName;
	IBOutlet NSPopUpButton *engineBuildOSVersionToBuildEngineFor;
	IBOutlet NSTextField *engineBuildCurrentEngineBase;
	IBOutlet NSTextField *engineBuildUpdateAvailable;
	IBOutlet NSButton *engineBuildChooseButton;
	IBOutlet NSButton *engineBuildBuildButton;
	IBOutlet NSButton *engineBuildUpdateButton;
	
	//create wrapper window
	IBOutlet NSWindow *createWrapperWindow;
	IBOutlet NSTextField *createWrapperEngine;
	IBOutlet NSTextField *createWrapperName;
	
	//busy window
	IBOutlet NSWindow *busyWindow;
	IBOutlet NSProgressIndicator *waitWheel;
	
}
@property (unsafe_unretained) IBOutlet NSWindow *window;
@property (nonatomic) NSMutableArray<NSWineskinEngine*>* installedEnginesList;
@property (nonatomic) NSMutableArray<NSWineskinEngine*>* installedMacDriverEnginesList;

//main stuff
- (IBAction)aboutWindow:(id)sender;
- (IBAction)helpWindow:(id)sender;
- (void)makeFoldersAndFiles;
- (void)checkForUpdates;
- (IBAction)createNewBlankWrapperButtonPressed:(id)sender;
- (IBAction)refreshButtonPressed:(id)sender;
- (IBAction)downloadPackagesManuallyButtonPressed:(id)sender;
- (IBAction)plusButtonPressed:(id)sender;
- (void)showAvailableEngines:(NSString *)theFilter;
- (IBAction)minusButtonPressed:(id)sender;
- (IBAction)updateButtonPressed:(id)sender;
- (IBAction)wineskinWebsiteButtonPressed:(id)sender;
- (void)getInstalledEngines:(NSString *)theFilter;
- (NSArray *)getEnginesToIgnore;
- (NSMutableArray *)getAvailableEngines;
- (NSString *)getCurrentWrapperVersion;
- (void)setEnginesAvailablePrompt;
- (void)setWrapperAvailablePrompt;
- (IBAction)engineSearchFilter:(id)sender;
- (IBAction)availEngineSearchFilter:(id)sender;

//engine build window
- (IBAction)engineBuildChooseButtonPressed:(id)sender;
- (IBAction)engineBuildBuildButtonPressed:(id)sender;
- (IBAction)engineBuildUpdateButtonPressed:(id)sender;
- (IBAction)engineBuildCancelButtonPressed:(id)sender;
- (NSString *)currentEngineBuildVersion;
- (NSString *)availableEngineBuildVersion;

//Engine Window (+ button) methods
- (IBAction)engineWindowDownloadAndInstallButtonPressed:(id)sender;
- (IBAction)engineWindowViewWineReleaseNotesButtonPressed:(id)sender;
- (IBAction)engineWindowEngineListChanged:(id)sender;
- (IBAction)engineWindowDontPromptAsNewButtonPressed:(id)sender;
- (IBAction)engineWindowDontPromptAllEnginesAsNewButtonPressed:(id)sender;
- (IBAction)engineWindowCustomBuildAnEngineButtonPressed:(id)sender;
- (IBAction)engineWindowCancelButtonPressed:(id)sender;

//Downloader methods
- (IBAction) startDownload:(NSButton *)sender;
- (IBAction) stopDownloading:(NSButton *)sender;
- (void)downloadToggle:(BOOL)toggle;
- (void)connection:(NSURLConnection *)conn didReceiveResponse:(NSURLResponse *)response;
- (void)connection:(NSURLConnection *)conn didReceiveData:(NSData *)data;
- (void)connectionDidFinishLoading:(NSURLConnection *)conn;
- (void)connection:(NSURLConnection *)conn didFailWithError:(NSError *)error;

//create wrapper window methods
- (IBAction) createWrapperOkButtonPressed:(id)sender;
- (IBAction) createWrapperCancelButtonPressed:(id)sender;

//pass in a string to see it in a pop up, for devel testing string values.
- (void)ds:(NSString *)input;

@end
