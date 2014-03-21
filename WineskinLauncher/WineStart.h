//
//  WineStart.h
//  WineskinLauncher
//  Data for starting Wine
//  Created by doh123 on 3/20/14.
//
//

#import <Foundation/Foundation.h>

@interface WineStart : NSObject
{
    NSArray *filesToRun;
    NSString *wineRunLocation;
    NSString *programFlags;
    NSString *vdResolution;
    NSString *cliCustomCommands;
    BOOL runWithStartExe;
    BOOL nonStandardRun;
    BOOL openingFiles;
    NSString *wssCommand;
    NSString *uLimitNumber;
    NSString *wineDebugLine;
    NSArray *winetricksCommands;
    NSString *wineRunFile;
}
- (NSArray*)getFilesToRun;
- (void)setFilesToRun:(NSArray*)input;
- (NSString*)getWineRunLocation;
- (void)setWineRunLocation:(NSString*)input;
- (NSString*)getProgramFlags;
- (void)setProgramFlags:(NSString*)input;
- (NSString*)getVdResolution;
- (void)setVdResolution:(NSString*)input;
- (NSString*)getCliCustomCommands;
- (void)setCliCustomCommands:(NSString*)input;
- (BOOL)isRunWithStartExe;
- (void)setRunWithStartExe:(BOOL)input;
- (BOOL)isNonStandardRun;
- (void)setNonStandardRun:(BOOL)input;
- (BOOL)isOpeningFiles;
- (void)setOpeningFiles:(BOOL)input;
- (NSString*)getWssCommand;
- (void)setWssCommand:(NSString*)input;
- (NSString*)getULimitNumber;
- (void)setULimitNumber:(NSString*)input;
- (NSString*)getWineDebugLine;
- (void)setWineDebugLine:(NSString*)input;
- (NSArray*)getWinetricksCommands;
- (void)setWinetricksCommands:(NSArray*)input;
- (NSString*)getWineRunFile;
- (void)setWineRunFile:(NSString*)input;
@end
