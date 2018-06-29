//
//  NSPortManager.m
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 01/09/16.
//  Copyright © 2016 Vitor Marques de Miranda. All rights reserved.
//

#import "NSPortManager.h"

#import <ObjectiveC_Extension/ObjectiveC_Extension.h>

#import "NSExeSelection.h"
#import "NSPathUtilities.h"

#import "NSPortDataLoader.h"

#define SMALLER_ICONSET_NEEDED_SIZE 16
#define BIGGEST_ICONSET_NEEDED_SIZE 1024

#define TIFF2ICNS_ICON_SIZE 512

#define DESKTOP_FOLDER   [NSString stringWithFormat:@"%@/Desktop/",NSHomeDirectory()]
#define NOTHING_EXE_PATH @"C:/nothing.exe"

@implementation NSMutableString (PKMutableString)

- (void)replaceOccurrencesOfString:(NSString *)target withString:(NSString *)replacement
{
    [self replaceOccurrencesOfString:target withString:replacement options:0 range:NSMakeRange(0, self.length)];
}

@end

@implementation NSPortManager

+(NSPortManager*)managerForWrapperAtPath:(NSString*)path
{
    if (!path) return nil;
    
    NSPortManager* portManager = [[NSPortManager alloc] init];
    portManager.path = path;
    portManager.type = NSPortManagerTypeWrapper;
    
    @autoreleasepool
    {
        NSString* plistPath = [NSString stringWithFormat:@"%@%@",path,PLIST_PATH_WINESKIN_WRAPPER];
        if ([[NSFileManager defaultManager] regularFileExistsAtPath:plistPath])
        {
            portManager.plist = [NSMutableDictionary mutableDictionaryWithContentsOfFile:plistPath];
        }
        
        NSString* x11plistPath = [NSString stringWithFormat:@"%@/Contents/Resources/WSX11Prefs.plist",path];
        if ([[NSFileManager defaultManager] regularFileExistsAtPath:x11plistPath])
        {
            portManager.x11Plist = [NSMutableDictionary mutableDictionaryWithContentsOfFile:x11plistPath];
        }
        else
        {
            x11plistPath = [NSString stringWithFormat:@"%@/Contents/Resources/WineskinEngine.bundle/X11/WSX11Prefs.plist",path];
            if (![[NSFileManager defaultManager] regularFileExistsAtPath:x11plistPath])
            {
                portManager.x11Plist = [NSMutableDictionary mutableDictionaryWithContentsOfFile:x11plistPath];
            }
        }
    }
    
    return portManager;
}
+(NSPortManager*)managerForCustomExeAtPath:(NSString*)path
{
    if (!path) return nil;
    
    NSPortManager* portManager = [[NSPortManager alloc] init];
    portManager.path = path;
    portManager.type = NSPortManagerTypeCustomExe;
    
    @autoreleasepool
    {
        NSString* plistPath = [NSString stringWithFormat:@"%@%@",path, PLIST_PATH_WINESKIN_CUSTOM_EXE];
        if ([[NSFileManager defaultManager] regularFileExistsAtPath:plistPath])
            portManager.plist = [NSMutableDictionary mutableDictionaryWithContentsOfFile:plistPath];
    }
    
    return portManager;
}

+(NSPortManager*)managerForPortAtPath:(NSString*)path
{
    NSString* customExePlistPath = [NSString stringWithFormat:@"%@%@",path,PLIST_PATH_WINESKIN_CUSTOM_EXE];
    if ([[NSFileManager defaultManager] regularFileExistsAtPath:customExePlistPath])
    {
        return [self managerForCustomExeAtPath:path];
    }
    
    return [self managerForWrapperAtPath:path];
}

-(BOOL)isWrapper
{
    return self.type == NSPortManagerTypeWrapper;
}
-(BOOL)isCustomEXE
{
    return self.type == NSPortManagerTypeCustomExe;
}

-(NSString*)path
{
    char pathbuf[1000];
    
    if (portTrackerFileHandle)
    {
        if (fcntl([portTrackerFileHandle fileDescriptor], F_GETPATH, pathbuf) != -1)
        {
            NSString *path = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:pathbuf length:strlen(pathbuf)];
            path = [path stringByDeletingLastPathComponent];
            return path;
        }
    }
    
    return portPathBackup;
}
-(void)setPath:(NSString*)newPath
{
    if (newPath && [newPath hasSuffix:@".app"])
    {
        NSString* tempFileLocator = [newPath stringByAppendingString:@"/.wineskin_manager"];
        
        if (![[NSFileManager defaultManager] regularFileExistsAtPath:tempFileLocator])
        {
            [[NSFileManager defaultManager] createEmptyFileAtPath:tempFileLocator];
        }
        
        portTrackerFileHandle = [NSFileHandle fileHandleForReadingAtPath:tempFileLocator];
        portPathBackup = newPath;
    }
    else
    {
        portTrackerFileHandle = nil;
        portPathBackup = nil;
    }
}

-(id)plistObjectForKey:(NSString*)item
{
    return _plist ? _plist[item] : nil;
}
-(void)setPlistObject:(id)object forKey:(NSString*)item
{
    if (!_plist) return;
    
    if (object)
        [_plist setObject:object forKey:item];
    else [_plist removeObjectForKey:item];
}
-(BOOL)synchronizePlist
{
    if (!_plist) return false;
    
    return [_plist writeToFile:[NSString stringWithFormat:@"%@%@",self.path,PLIST_PATH_WINESKIN_WRAPPER] atomically:YES];
}

-(id)x11PlistObjectForKey:(NSString*)item
{
    return _x11Plist ? _x11Plist[item] : nil;
}
-(void)setX11PlistObject:(id)object forKey:(NSString*)item
{
    if (!_x11Plist) return;
    
    if (object)
        [_x11Plist setObject:object forKey:item];
    else [_x11Plist removeObjectForKey:item];
}
-(BOOL)synchronizeX11Plist
{
    if (!_x11Plist) return false;
    
    return [_x11Plist writeToFile:[NSString stringWithFormat:@"%@/Contents/Resources/WSX11Prefs.plist",self.path] atomically:YES];
}

-(BOOL)mainExeHasInvalidPath
{
    NSString* mainExePath = [self plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_RUN_PATH];
    if (!mainExePath) return YES;
    
    mainExePath = [NSString stringWithFormat:@"C:/%@",mainExePath];
    mainExePath = [mainExePath stringByReplacingOccurrencesOfString:@"//" withString:@"/"];
    
    return [mainExePath isEqualToString:NOTHING_EXE_PATH];
}

-(void)setIconWithImage:(NSImage*)sourceImage
{
    if (!sourceImage) return;
    
    NSString* icnsFileName = [self plistObjectForKey:WINESKIN_WRAPPER_PLIST_KEY_ICON_PATH];
    if (!icnsFileName) return;
    
    NSString* icnsPath = [NSString stringWithFormat:@"%@/Contents/Resources/%@",self.path,icnsFileName];
    BOOL result = [sourceImage saveAsIcnsAtPath:icnsPath];
    
    if (result)
    {
        [[NSWorkspace sharedWorkspace] setIcon:nil forFile:self.path options:NSExcludeQuickDrawElementsIconCreationOption];
    }
    else
    {
        [[NSWorkspace sharedWorkspace] setIcon:sourceImage forFile:self.path options:NSExcludeQuickDrawElementsIconCreationOption];
    }
}

-(NSString*)runWithArguments:(NSArray*)args forcingLogReturn:(BOOL)returnLog
{
    if (returnLog)
    {
        [self setPlistObject:@TRUE forKey:WINESKIN_WRAPPER_PLIST_KEY_DEBUG_MODE];
        [self synchronizePlist];
    }
    
    NSString* appPath = [NSPathUtilities wineskinLauncherBinForPortAtPath:self.path];
    NSString* wineLog = [NSTask runProgram:appPath withFlags:args];
    
    if (returnLog)
    {
        [self setPlistObject:nil forKey:WINESKIN_WRAPPER_PLIST_KEY_DEBUG_MODE];
        [self synchronizePlist];
        
        if (!wineLog || wineLog.length < 10)
        {
            NSString* logPath = [NSString stringWithFormat:@"%@/Contents/Resources/Logs/LastRunWine.log",self.path];
            
            if ([[NSFileManager defaultManager] regularFileExistsAtPath:logPath])
                wineLog = [NSString stringWithContentsOfFile:logPath encoding:NSASCIIStringEncoding];
        }
    }
    
    return wineLog;
}
-(NSString*)installWinetrick:(NSString*)winetrick
{
    if (!winetrick) return false;
    
    [self runWithArguments:@[@"WSS-winetricks",winetrick] forcingLogReturn:NO];
    
    NSString* logPath = [NSString stringWithFormat:@"%@/Contents/Resources/Logs/Winetricks.log",self.path];
    NSString* log = [NSString stringWithContentsOfFile:logPath encoding:NSASCIIStringEncoding];
    return log;
}

-(NSArray*)desktopFolderBeforeExtraction
{
    return [[NSFileManager defaultManager] contentsOfDirectoryAtPath:DESKTOP_FOLDER];
}
-(NSArray*)removeUselessFilesFromDesktopFolderReturningTheirPathsExcept:(NSArray*)exceptions forPortAtPath:(NSString*)portPath
{
    BOOL returnFilesPaths = (portPath != nil);
    NSMutableArray* uselessFilesPaths = returnFilesPaths ? [[NSMutableArray alloc] init] : nil;
    NSMutableArray* folderAfterExtraction = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:DESKTOP_FOLDER] mutableCopy];
    [folderAfterExtraction removeObjectsInArray:exceptions];
    
    for (NSString* item in folderAfterExtraction)
    {
        if ([item hasSuffix:@".desktop"] || [item hasSuffix:@".lnk"] || [item hasSuffix:@".appref-ms"])
        {
            NSString* itemPath = [NSString stringWithFormat:@"%@%@",DESKTOP_FOLDER,item];
            
            if (returnFilesPaths)
            {
                NSString* itemFilePath = [NSExeSelection selectAsMainExe:itemPath forPort:portPath];
                if (itemFilePath) [uselessFilesPaths addObject:itemFilePath];
            }
            
            [[NSFileManager defaultManager] removeItemAtPath:itemPath];
        }
    }
    
    return uselessFilesPaths;
}
-(NSArray*)removeUselessDesktopFilesCreatedOnBlock:(void (^)(void))block returningTheirPathsForPortAtPath:(NSString*)portPath
{
    NSArray* folderBeforeExtraction = [self desktopFolderBeforeExtraction];
    block();
    NSArray* paths = [self removeUselessFilesFromDesktopFolderReturningTheirPathsExcept:folderBeforeExtraction forPortAtPath:portPath];
    return paths ? [paths arrayByRemovingRepetitions] : nil;
}

-(NSString*)runEXE:(NSString*)installerFile withFlags:(NSString*)flags
{
    NSString* fileToRun;
    NSString* installerFileWindowsPath;
    
    if ([installerFile hasPrefix:@"/"])
    {
        installerFileWindowsPath = [NSPathUtilities getWindowsPathForMacPath:installerFile ofWrapper:self.path];
    }
    else
    {
        installerFileWindowsPath = installerFile;
    }
    
    installerFileWindowsPath = [installerFileWindowsPath stringByReplacingOccurrencesOfString:@"/" withString:@"\\"];
    
    if (flags)
    {
        // Using the 'start' application will make the cmd window disappear
        NSString* batFileContent = [NSString stringWithFormat:@"start \"%@\" %@",installerFileWindowsPath,flags];
        
        // Choosing bat path and saving
        NSString* batFileLocation;
        for (int x = 0; batFileLocation == nil; x++)
        {
            batFileLocation = [NSPathUtilities getMacPathForWindowsPath:[NSString stringWithFormat:@"C:/wineskinTemp%d.bat",x]
                                                              ofWrapper:self.path];
            if ([[NSFileManager defaultManager] regularFileExistsAtPath:batFileLocation]) batFileLocation = nil;
        }
        
        [batFileContent writeToFile:batFileLocation atomically:YES encoding:NSASCIIStringEncoding];
        
        fileToRun = batFileLocation;
    }
    else
    {
        fileToRun = [NSPathUtilities getMacPathForWindowsPath:installerFileWindowsPath ofWrapper:self.path];
    }
    
    NSString* log = [self runWithArguments:@[fileToRun] forcingLogReturn:NO];
    
    if (flags)
    {
        // Removing bat file
        [[NSFileManager defaultManager] removeItemAtPath:fileToRun];
    }
    
    return log;
}

// Get available Winetricks list
-(NSString*)getFieldValue:(NSString*)field fromDescription:(NSString*)description
{
    field = [NSString stringWithFormat:@"%@=\"",field];
    return [description getFragmentAfter:field andBefore:@"\""];
}
-(NSMutableDictionary*)getFunctionFromDescription:(NSString*)description
{
    NSMutableDictionary* newFunction = [[NSMutableDictionary alloc] init];
    
    while ([description hasPrefix:@" "]) description = [description substringFromIndex:1];
    NSString* base = [description getFragmentAfter:@" " andBefore:@"\\\n"];
    newFunction[@"Type"] = base ? base : @"";
    
    description = [NSString stringWithFormat:@" %@",description];
    base = [description getFragmentAfter:@" " andBefore:@"\\\n"];
    newFunction[@"Name"] = base ? base : @"";
    
    return newFunction;
}
-(NSArray*)getAvailableWinetricksList
{
    NSString* winetricksPath = [NSString stringWithFormat:@"%@/Wineskin.app/Contents/Resources/winetricks",self.path];
    NSString* winetricksRaw = [[NSString alloc] initWithContentsOfFile:winetricksPath encoding:NSASCIIStringEncoding error:nil];
    
    NSMutableArray* newList = [[NSMutableArray alloc] init];
    NSMutableArray* winetricksItems = [[winetricksRaw componentsSeparatedByString:@"\nw_metadata "] mutableCopy];
    [winetricksItems removeObjectAtIndex:0];
    
    for (__strong NSString* winetrickItem in winetricksItems)
    {
        NSMutableDictionary* newFunction = [self getFunctionFromDescription:winetrickItem];
        
        NSString* dllsList = [winetrickItem getFragmentAfter:@"w_override_dlls native,builtin " andBefore:@"\n"];
        if (!dllsList) dllsList = [winetrickItem getFragmentAfter:@"w_override_dlls native " andBefore:@"\n"];
        if (dllsList)  newFunction[@"DLLs"] = dllsList;
        
        winetrickItem = [winetrickItem getFragmentAfter:nil andBefore:@"\nload_"];
        NSString* titleField     = [self getFieldValue:@"title"     fromDescription:winetrickItem];
        NSString* yearField      = [self getFieldValue:@"year"      fromDescription:winetrickItem];
        NSString* publisherField = [self getFieldValue:@"publisher" fromDescription:winetrickItem];
        
        NSString* description = titleField;
        if (yearField && publisherField)
        {
            description = [NSString stringWithFormat:@"%@ (Copyright © %@ %@. All rights reserved.)",
                           titleField, yearField, publisherField];
        }
        
        newFunction[@"Description"] = description ? description : @"";
        
        [newList addObject:newFunction];
    }
    
    NSSortDescriptor *descript = [[NSSortDescriptor alloc] initWithKey:@"Name" ascending:YES];
    [newList sortUsingDescriptors:@[descript]];
    
    descript = [[NSSortDescriptor alloc] initWithKey:@"Type" ascending:YES];
    [newList sortUsingDescriptors:@[descript]];
    
    return newList;
}
-(BOOL)isWinetrickAvailableForInstalling:(NSString*)winetrickName
{
    for (NSDictionary* winetrick in [self getAvailableWinetricksList])
    {
        if ([[winetrick[@"Name"] lowercaseString] isEqualToString:winetrickName.lowercaseString]) return YES;
    }
    
    return NO;
}

// Path utilities
-(NSString*)completeWindowsPath:(NSString*)windowsPath
{
    NSString* macPath = [[windowsPath substringFromIndex:3] stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
    NSString* driveC = [NSPathUtilities getMacPathForWindowsDrive:'C' ofWrapper:self.path];
    
    NSArray* arquivos = [NSPathUtilities filesCompatibleWithStructure:macPath insideFolder:driveC];
    macPath = arquivos.count == 0 ? nil : arquivos[0];
    
    return macPath ? [NSPathUtilities getWindowsPathForMacPath:macPath ofWrapper:self.path] : nil;
}
-(NSString*)programFilesPathFor64bitsApplication:(BOOL)is64bits
{
    NSString* reg = [self getRegistryEntry:@"[Software\\\\Microsoft\\\\Windows\\\\CurrentVersion]" fromRegistryFileNamed:SYSTEM_REG];
    NSString* value = nil;
    
    if (!is64bits)
    {
        value = [NSPortManager getStringValueForKey:@"ProgramFilesDir (x86)" fromRegistryString:reg];
        if (value) value = [value stringByReplacingOccurrencesOfString:@"\\\\" withString:@"/"];
    }
    
    if (!value)
    {
        value = [NSPortManager getStringValueForKey:@"ProgramFilesDir" fromRegistryString:reg];
        if (value) value = [value stringByReplacingOccurrencesOfString:@"\\\\" withString:@"/"];
    }
    
    if (!value) value = @"C:/Program Files";
    return value;
}

//Add, delete and get registry entries
-(NSString*)getPathForRegistryFile:(NSString*)reg
{
    return [NSString stringWithFormat:@"%@/Contents/Resources/%@.reg",self.path,reg];
}
-(void)addRegistry:(NSString*)lines fromRegistryFileNamed:(NSString*)reg
{
    NSString* regFile = [self getPathForRegistryFile:reg];
    NSString* text = [NSString stringWithContentsOfFile:regFile encoding:NSASCIIStringEncoding];
    
    text = [NSString stringWithFormat:@"%@\n\n\n%@",text,lines];
    [text writeToFile:regFile atomically:NO encoding:NSASCIIStringEncoding];
}
-(void)deleteRegistry:(NSString*)line fromRegistryFileNamed:(NSString*)reg
{
    NSString* regFile = [self getPathForRegistryFile:reg];
    NSString* text = [NSString stringWithContentsOfFile:regFile encoding:NSASCIIStringEncoding];
    if (!text) return;
    
    NSString* registryContents = [text getFragmentAfter:line andBefore:@"\n\n"];
    if (!registryContents) return;
    
    registryContents = [NSString stringWithFormat:@"%@%@",line,registryContents];
    text = [text stringByReplacingOccurrencesOfString:registryContents withString:@""];
    while ([text contains:@"\n\n\n"]) text = [text stringByReplacingOccurrencesOfString:@"\n\n\n" withString:@"\n\n"];
    
    [text writeToFile:regFile atomically:NO encoding:NSASCIIStringEncoding];
}
-(NSArray*)getRegistriesWithGramar:(NSString*)gramar fromRegistryFileNamed:(NSString*)reg
{
    //A gramática mencionada é apenas uma entrada de registro com um * no lugar de um dos campos
    NSString* regFile = [self getPathForRegistryFile:reg];
    NSString* text = [NSString stringWithContentsOfFile:regFile encoding:NSASCIIStringEncoding];
    
    NSMutableArray* objects = [NSMutableArray new];
    NSArray* gramarParts = [gramar componentsSeparatedByString:@"*"];
    
    NSArray* registriesParts = [text componentsSeparatedByString:gramarParts[0]];
    NSString* registry;
    int x;
    
    for (int y = 1; y < registriesParts.count; y ++)
    {
        registry = [registriesParts[y] getFragmentAfter:nil andBefore:@"\n\n"];
        NSArray* registryParts = [registry componentsSeparatedByString:@"\n"];
        
        if (registryParts.count > 1)
        {
            NSString* text2 = [NSString stringWithFormat:@"%@%@",gramarParts[0],registryParts[0]];
            
            if ([text2 contains:gramarParts[1]])
            {
                for (x = 1; x < registryParts.count; x++) text2 = [NSString stringWithFormat:@"%@\n%@",text2,registryParts[x]];
                [objects addObject:text2];
            }
        }
    }
    
    return objects;
}
-(NSString*)getRegistryEntry:(NSString*)line fromRegistryFileNamed:(NSString*)reg
{
    NSString* regFile = [self getPathForRegistryFile:reg];
    NSString* text = [NSString stringWithContentsOfFile:regFile encoding:NSASCIIStringEncoding];
    
    return [NSPortManager getRegistryEntry:line fromRegistryString:text];
}
+(NSString*)getRegistryEntry:(NSString*)line fromRegistryString:(NSString*)text
{
    NSString* registry = [text getFragmentAfter:line andBefore:@"\n\n"];
    if (!registry) return @"";
    
    NSMutableArray* fragments2 = [[registry componentsSeparatedByString:@"\n"] mutableCopy];
    if (fragments2.count <= 1) return @"";
    
    [fragments2 removeObjectAtIndex:0];
    if ([fragments2[0] hasPrefix:@"#time="]) [fragments2 removeObjectAtIndex:0];
    
    return [fragments2 componentsJoinedByString:@"\n"];
}

//Set value at registry entries
-(void)setValue:(NSString*)value forKey:(NSString*)key atRegistryEntryString:(NSMutableString*)registry
{
    BOOL validKey = key != nil && [key isKindOfClass:[NSString class]];
    NSString* keyEqualString = validKey ? [NSString stringWithFormat:@"\"%@\"=",key] : @"@=";
    NSRange valueRange = [registry rangeAfterString:keyEqualString andBeforeString:@"\n"];
    
    if (!value || value.length == 0)
    {
        if (valueRange.location == NSNotFound)
        {
            return;
        }
        
        NSRange keyRange = [registry rangeOfString:keyEqualString];
        [registry replaceCharactersInRange:NSMakeRange(keyRange.location, keyRange.length + valueRange.length) withString:@""];
        
        if (registry.length > keyRange.location &&  [registry characterAtIndex:keyRange.location] == '\n')
            [registry replaceCharactersInRange:NSMakeRange(keyRange.location, 1) withString:@""];
        
        if ([registry contains:@"\n\n"]) [registry replaceOccurrencesOfString:@"\n\n" withString:@"\n"];
        
        return;
    }
    
    if (valueRange.location != NSNotFound)
    {
        [registry replaceCharactersInRange:valueRange withString:value];
        return;
    }
    
    [registry setString:[NSString stringWithFormat:@"%@%@\n%@",keyEqualString,value,registry]];
}
-(void)setValues:(NSDictionary*)values atRegistryEntryString:(NSMutableString*)registry
{
    for (NSString* key in values.allKeys)
    {
        [self setValue:values[key] forKey:key atRegistryEntryString:registry];
    }
}
-(void)setValues:(NSDictionary*)values forEntry:(NSString*)registryEntry atRegistryFileNamed:(NSString*)regFileName
{
    NSMutableString* registry2 = [[self getRegistryEntry:registryEntry fromRegistryFileNamed:regFileName] mutableCopy];
    
    [self setValues:values atRegistryEntryString:registry2];
    
    [self deleteRegistry:registryEntry fromRegistryFileNamed:regFileName];
    [self addRegistry:[NSString stringWithFormat:@"%@\n%@\n",registryEntry,registry2] fromRegistryFileNamed:regFileName];
}

//Get values from registry entries
+(NSString*)getStringValueForKey:(NSString*)value fromRegistryString:(NSString*)registry
{
    BOOL validKey = value != nil && [value isKindOfClass:[NSString class]];
    NSString* keyEqualString = validKey ? [NSString stringWithFormat:@"\"%@\"=\"",value] : @"@=\"";
    return [registry getFragmentAfter:keyEqualString andBefore:@"\""];
}
+(NSString*)getValueForKey:(NSString*)value fromRegistryString:(NSString*)registry
{
    BOOL validKey = value != nil && [value isKindOfClass:[NSString class]];
    NSString* keyEqualString = validKey ? [NSString stringWithFormat:@"\"%@\"=",value] : @"@=";
    return [registry getFragmentAfter:keyEqualString andBefore:@"\n"];
}
+(NSArray*)getKeysFromRegistryString:(NSString*)registry
{
    NSMutableArray* registries = [[registry componentsSeparatedByString:@"\n"] mutableCopy];
    [registries removeObject:@""];
    
    [registries replaceObjectsWithVariation:^id(id object, NSUInteger index)
     {
         if ([object hasPrefix:@"@="]) return @"@";
         return [object getFragmentAfter:@"\"" andBefore:@"\"="];
     }];
    
    return registries;
}

@end
