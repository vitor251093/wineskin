//
//  WineStart.m
//  WineskinLauncher
//
//  Created by doh123 on 3/20/14.
//
//

#import "WineStart.h"

@implementation WineStart

- (NSArray*)getFilesToRun
{
    return [NSArray arrayWithArray:filesToRun];
}

- (void)setFilesToRun:(NSArray*)input
{
    filesToRun = [NSArray arrayWithArray:input];
}
- (NSString*)getWineRunLocation
{
    return [wineRunLocation copy];
}

- (void)setWineRunLocation:(NSString*)input
{
    wineRunLocation = [input copy];
}
- (NSString*)getProgramFlags
{
    return [programFlags copy];
}

- (void)setProgramFlags:(NSString*)input
{
    programFlags = [input copy];
}
- (NSString*)getVdResolution
{
    return [vdResolution copy];
}

- (void)setVdResolution:(NSString*)input
{
    vdResolution = [input copy];
}
- (NSString*)getCliCustomCommands
{
    return [cliCustomCommands copy];
}

- (void)setCliCustomCommands:(NSString*)input
{
    cliCustomCommands = [input copy];
}
- (BOOL)isRunWithStartExe
{
    return runWithStartExe;
}

- (void)setRunWithStartExe:(BOOL)input
{
    runWithStartExe = input;
}
- (BOOL)isNonStandardRun
{
    return nonStandardRun;
}

- (void)setNonStandardRun:(BOOL)input
{
    nonStandardRun = input;
}
- (BOOL)isOpeningFiles
{
    return openingFiles;
}

- (void)setOpeningFiles:(BOOL)input
{
    openingFiles = input;
}
- (NSString*)getWssCommand
{
    return [wssCommand copy];
}

- (void)setWssCommand:(NSString*)input
{
    wssCommand = [input copy];
}
- (NSString*)getULimitNumber
{
    return [uLimitNumber copy];
}

- (void)setULimitNumber:(NSString*)input
{
    uLimitNumber = [input copy];
}
- (NSString*)getWineDebugLine
{
    return [wineDebugLine copy];
}

- (void)setWineDebugLine:(NSString*)input
{
    wineDebugLine = [input copy];
}
- (NSArray*)getWinetricksCommands
{
    return [NSArray arrayWithArray:winetricksCommands];
}

- (void)setWinetricksCommands:(NSArray*)input
{
    winetricksCommands = [NSArray arrayWithArray:input];
}
- (NSString*)getWineRunFile
{
    return [wineRunFile copy];
}

- (void)setWineRunFile:(NSString*)input
{
    wineRunFile = [input copy];
}
@end
