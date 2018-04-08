//
//  SelectMainEXE.m
//  Porting Center
//
//  Created by Vitor Marques de Miranda.
//  Copyright 2014 UFRJ. All rights reserved.
//

#import "NSExeSelection.h"

#import "NSPortManager.h"

#import "NSPathUtilities.h"

#import "NSString+Extension.h"
#import "NSFileManager+Extension.h"

@implementation NSExeSelection

// URL files functions
+(NSString*)getSteamExePathForPort:(NSString*)wrapperPath
{
    NSPortManager* port = [NSPortManager managerWithPath:wrapperPath];
    NSString* programFiles = port ? [port programFilesPathFor64bitsApplication:NO] : @"C:/Program Files";
    return [programFiles stringByAppendingString:@"/Steam/steam.exe"];
}
+(NSString*)getURLFlagsFromSteamFileContents:(NSString*)text
{
    // The file contents in the 'text' variable is a .url or .desktop file which points to a Steam app
    // Since we can't run .url files in Wineskin (they are redirected to the main system) we need to
    // convert it into a common path. That function will return the flags for that path
    
    // Firstly, we need to find the app code
    NSString* code = [text getFragmentAfter:@"steam://rungameid/" andBefore:@"\n"];
    if (!code) return @"";
    
    // If base is bigger than 1, then that's a valid Steam path
    if (code && ![code isEqualToString:@""])
    {
        // That function will remove Windows's newline characters from the string, just in case
        code = [code stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        
        // Now, we return the code with the '-applaunch' flag
        // Doing that, the port will open that Steam app directly
        return [@"-applaunch " stringByAppendingString:code];
    }
    
    // Otherwise, we return an empty string
    // In that way, even if we can't find the game, at least we are going to launch Steam
    return @"";
}

// LNK files auxiliar functions
+(NSString*)getLNKDriveFromString:(NSString*)text
{
    // Sometimes we may need to detect the drive of a file pointed by a .lnk file separately
    
    // The 00 (hex) char need to be know in order to find errors
    NSString* nullHex = [NSString stringWithHexString:@"00"];
    
    // Since the drive is always followed by ':\' we are going to look for it
    NSArray* fragments = [text componentsSeparatedByString:@":\\"];
    
    // If there is more than 1 item in the array, there is a ':\' somewhere
    if (fragments.count > 1)
    {
        // While the character before ':\' is 00 and we have any other chances, we are going to continue
        int index = 0;
        while (index<fragments.count && [fragments[index] hasSuffix:nullHex]) index++;
        
        // If the char before ':\' isn't 00 then we have a success and can catch the drive
        if (![fragments[index] hasSuffix:nullHex])
        {
            // We copy the drive to a new variable...
            NSString* drive = fragments[index];
            
            // So we can use these function to copy only its last char has string
            return [drive substringFromIndex:drive.length-1];
        }
    }
    
    // Otherwise, we return "C", which in almost all cases will be the correct drive
    return @"C";
}
+(NSString*)getLNKPathFromString:(NSString*)text forType:(nonnull NSString*)type
{
    // That function will return the path from a .lnk file (text) that points to file of a certain type (type)
    int index = 0;
    
    // Here, we are going to set the correct case for the file extension
    // If we can find it in lowercase (which is the most common), then we set it to lowercase
    if ([text contains:[type lowercaseString]]) type = type.lowercaseString;
    
    // First, we are going to look for the extension inside the .lnk file
    NSMutableArray* fragments = [[text componentsSeparatedByString:type] mutableCopy];
    NSString* drive;
    
    // Now, we need the 00 unichar (we gonna use it later)
    unichar char00 = [[NSString stringWithHexString:@"00"] characterAtIndex:0];
    
    // Since the path won't be after the extension we don't need to verify the last item in the array, so we remove it
    [fragments removeLastObject];
    
    // Now we analise every other item in the array individually
    for (NSString* fragment in fragments)
    {
        // Our index variable will detect when the path starts, 'walking backwards' until finding one of the terminators.
        index = (int)[fragment length]-1;
        
        // - If it finds a 00 (hex) char, then that's the end of the string.
        // - If it finds a ':' char, then we found the root directory of the drive, and the complete path is just 1 char far.
        // - If it's at index 0, it's the first char of the .lnk file or it will be just after an extension (both impossible).
        // - If it finds a ".." it means that the path is relative to another path, and that's the end of the path.
        // If none of these conditions is matched, it continues 'moonwalking'.
        while (index > 0 && [fragment characterAtIndex:index] != char00 && [fragment characterAtIndex:index] != ':' &&
                      !([fragment characterAtIndex:index-1] == '.'  && [fragment characterAtIndex:index] == '.'))
            index--;
        
        // Just in case it stopped because it reached the index 0, we gonna use that 'if'.
        if (index > 0)
        {
            // If the actual char is a ':', so it's simple to get the complete path:
            if ([fragment characterAtIndex:index] == ':')
            {
                // Backing 1 char, we have the complete path of the file; we just need to append the extension
                drive = [[fragment substringFromIndex:index-1] stringByAppendingString:type];
                
                // Now, replacing '\' with '/' to change from Windows path style to the Mac style
                return [drive stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
            }
            
            // Otherwise, it's a bit more complicated:
            else
            {
                // Firstly we have to add one to the index, because all the other possibilities ('..' or '00' (hex))
                // points to an invalid char, where the one before it was still valid
                index++;
                
                // If in that index we have a '\' then that string is a valid path
                if ([fragment characterAtIndex:index] == '\\')
                {
                    // Getting the LNK drive and adding ':' we have the part that is missing in that string
                    drive = [[self getLNKDriveFromString:text] stringByAppendingString:@":"];
                    
                    // Here we append both and the file extension, and we get the complete path
                    drive = [NSString stringWithFormat:@"%@%@%@",drive,[fragment substringFromIndex:index],type];
                    
                    // Now, replacing '\' with '/' to change from Windows path style to the Mac style
                    return [drive stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
                }
            }
        }
    }
    
    return nil;
}
+(NSString*)getLNKFlagsFromString:(NSString*)text forPath:(NSString*)destino
{
    // That function will return the flags from a .lnk file (text) that are used on a path (destino)
    int index;
    
    // First, we are going to look for the path inside the .lnk file (which was already found before)
    NSMutableArray* fragments = [[text componentsSeparatedByString:destino] mutableCopy];
    
    // Now, we need the 10 (hex) string...
    NSString* string10 = [NSString stringWithHexString:@"10"];
    
    // And the 00 unichar (they will be used later)
    unichar char00 = [[NSString stringWithHexString:@"00"] characterAtIndex:0];
    
    // Since the flags always come after the path, we are going to verify every string after the path
    [fragments removeObjectAtIndex:0];
    
    for (NSString* fragment in fragments)
    {
        // We are going to verify that string, char by char, looking for the 00 string
        // The 00 string in that case marks the end of the flag, which started just after the path
        index = 0;
        while (index < fragment.length && [fragment characterAtIndex:index] != char00) index++;
        
        // The while can only stop with one of these conditions:
        // 1- The string is over and index is equal to fragment length
        // 2- The 00 char was found, and index is pointing to it
        //
        // However, even meeting these conditions, if the index is smaller then 3 it's a false positive.
        // The reason for this is: the first char is 10 (hex) and the last ones are an invalid char and 00 (hex),
        // so the flags would have a length of 1, which would clearly be a false positive, since Windows flags have at least 2 of length.
        if (index < fragment.length && index > 2 && [fragment hasPrefix:string10])
            return [fragment substringWithRange:NSMakeRange(1,index-2)];
    }
    
    return nil;
}
+(NSString*)getLNKFlagsFromRareString:(NSString*)text forPath:(NSString*)destino
{
    // That function will return the flags from a .lnk file (text) that are used on a path (destino)
    // Note: these conditions only happened in one test, but still happened so it's handled.
    // In that case, the path is in the normal string, but the flags has 00 (hex) chars between them.
    NSArray* fragments = [text componentsSeparatedByString:destino];
    
    // If the array has more than 1 item, it means that it has the path inside it
    if (fragments.count > 1)
    {
        // The second item is the only one that might have the flags in that string, so we gonna separate it
        NSString* part = fragments[1];
        
        // We need to be sure that it has a length bigger than 2 because the first two chars are invalid chars
        if (part.length > 2)
        {
            // Firstly, we remove these invalid chars
            text = [part substringFromIndex:2];
            
            // Now, we remove the 00 chars in the even positions from the string
            text = [NSString stringByRemovingEvenCharsFromString:text];
            
            // The text will still have 00 (hex) chars, and they will set where is begins and where it ends
            fragments = [text componentsSeparatedByString:[NSString stringWithHexString:@"00"]];
            
            // If the array has more than 1 item, it means that it has the path inside it
            if (fragments.count > 1 && [fragments[1] length] > 1)
            {
                // The second item is the flags themselves, but there is one last thing that must be checked before confirming that
                part = fragments[1];
                
                // We need to remove the last path component of the path to check if it's inside the flags
                // If it is, then we haven't found the flags at all, but the run path of the .lnk file
                // We can't use the Objective-C method stringByRemovingLastPathComponent because it's for Mac paths, and that's a Windows one
                NSMutableArray* destinyParts = [[destino componentsSeparatedByString:@"\\"] mutableCopy];
                [destinyParts removeLastObject];
                NSString* subDestino = [destinyParts componentsJoinedByString:@"\\"];
                
                // If the file location path isn't inside the flags they can be returned,
                // but since their first char is an invalid one, it should be removed first.
                if (![part contains:subDestino]) return [part substringFromIndex:1];
            }
        }
    }
    
    // If any of the conditions weren't met, then it isn't the rare string case
    return nil;
}

// LNK files functions
+(NSString*)getLNKFlagsFromFileContents:(NSString*)text forPath:(NSString*)destino
{
    // Here, we want to extract Windows flags from a LNK file; a string with its content is in the 'text' variable
    
    // A fact is: the flags are ALWAYS after the path; that's a rule
    // However, sometimes the path is divided in pieces (drive, folder path and filename) so we should only use the folder path,
    // which is usually the biggest one
    NSString* pathFolder = [destino stringByDeletingLastPathComponent];
    pathFolder = [pathFolder stringByReplacingOccurrencesOfString:@"/" withString:@"\\"];
    pathFolder = [pathFolder substringFromIndex:2];
    if (!pathFolder || pathFolder.length == 0) return @"";
    
    // In rare occasions the full path may be necessary, so we gonna prepared it for use
    destino = [destino stringByReplacingOccurrencesOfString:@"/" withString:@"\\"];
    
    // Firstly, we will try to get it directly from the string with the 'getLNKPathFromString' function
    NSString* finalText = [self getLNKFlagsFromString:text forPath:pathFolder];
    
    // Sometimes, there are 00 (hexadecimal) characters between every char in the LNK file, starting by the first
    // In that case, we should remove them before extracting the path
    if (!finalText) finalText = [self getLNKFlagsFromString:[NSString stringByRemovingEvenCharsFromString:text] forPath:pathFolder];
    
    // However, sometimes it didn't start by the first, but by the second; so we need to remove the first char and try again
    if (!finalText) finalText = [self getLNKFlagsFromString:[NSString stringByRemovingEvenCharsFromString:[text substringFromIndex:1]]
                                                  forPath:pathFolder];
    
    // At least, there is a final possibility: the rare occasion. That case was found in only one .lnk file
    // during my researchs, but since the idea is to support every .lnk file, that function is necessary
    if (!finalText) finalText = [self getLNKFlagsFromRareString:text forPath:destino];
    
    // If we found it, good. If we didn't, we should return an empty string, but not nil
    return finalText ? finalText : @"";
}
+(NSString*)getLNKPathFromFileContents:(NSString*)text forType:(nonnull NSString*)type
{
    // Here, we want to extract a Windows path from a LNK file; a string with its content is in the 'text' variable
    
    // Firstly, we will try to get it directly from the string with the 'getLNKPathFromString' function
	NSString* finalText = [self getLNKPathFromString:text forType:type];
    
    // Sometimes, there are 00 (hexadecimal) characters between every char in the LNK file, starting by the first
    // In that case, we should remove them before extracting the path
    if (!finalText) finalText = [self getLNKPathFromString:[NSString stringByRemovingEvenCharsFromString:text] forType:type];
    
    // However, sometimes it didn't start by the first, but by the second; so we need to remove the first char and try again
    if (!finalText) finalText = [self getLNKPathFromString:[NSString stringByRemovingEvenCharsFromString:[text substringFromIndex:1]]
                                                   forType:type];
    
    // If we found it, good. If we didn't, we should return an empty string, but not nil
    return finalText ? finalText : @"";
}

// DESKTOP files auxiliar functions
+(NSString*)getLNKFileFromDESKTOPFileContents:(NSString*)text forPort:(NSString*)wrapperUrl
{
    text = [text getFragmentAfter:@" /Unix " andBefore:@"\n"];
    if (!text) return nil;
    
    text = [text stringByReplacingOccurrencesOfString:@"\\" withString:@""];
    
    if ([text contains:@"/dosdevices/"])
    {
        if (!wrapperUrl) return nil;
        
        NSArray* temp = [text componentsSeparatedByString:@"/dosdevices/"];
        text = [NSPathUtilities getMacPathForWindowsPath:temp[1] ofWrapper:wrapperUrl];
    }
    
    if ([[NSFileManager defaultManager] regularFileExistsAtPath:text]) return text;
    return nil;
}
+(NSString*)getEXEFileFromDESKTOPFileContents:(NSString*)text
{
    // If there is an .exe file path inside the .desktop file, it is after the ' wine ' string
    text = [text getFragmentAfter:@" wine " andBefore:@"\n"];
    if (!text) return nil;
    
    // These functions will clean the path string
    text = [text stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
    text = [text stringByReplacingOccurrencesOfString:@"//" withString:@"/"];
    text = [text stringByReplacingOccurrencesOfString:@"//" withString:@"/"];
    text = [text stringByReplacingOccurrencesOfString:@"/ " withString:@" "];
    while ([text hasSuffix:@" "]) text = [text substringToIndex:text.length-1];
    
    // Now we can return it
    return text;
}

// DESKTOP files functions
+(NSString*)getDESKTOPFlagsFromFileContents:(NSString*)text forPath:(NSString*)destino forPort:(NSString*)wrapperUrl
{
    // First, let's check if inside that .desktop file there is a .lnk file path
    NSString* arquivo = [self getLNKFileFromDESKTOPFileContents:text forPort:wrapperUrl];
    
    if (arquivo)
    {
        // If so, we need to get the flags from that .lnk file
        if ([[NSFileManager defaultManager] fileExistsAtPath:arquivo])
        {
            // Firstly, we read the .lnk file
            arquivo = [NSString stringWithContentsOfFile:arquivo encoding:NSASCIIStringEncoding];
            
            // Now we get the flags from it
            return arquivo ? [NSExeSelection getLNKFlagsFromFileContents:arquivo forPath:destino] : nil;
        }
    }
    
    // If it don't, then there is nothing to do here. We need to return an empty string because it mustn't be nil
    return @"";
}
+(NSString*)getDESKTOPPathFromFileContents:(NSString*)arquivo forPort:(NSString*)wrapperUrl
{
    // First, we gonna try to extract a .lnk file path from the .desktop file
	NSString* temp = [self getLNKFileFromDESKTOPFileContents:arquivo forPort:wrapperUrl];
    
    if (temp)
    {
        // If there is one, then we need to get the path from that .lnk file
        if ([[NSFileManager defaultManager] fileExistsAtPath:temp])
        {
            // Firstly, we read the .lnk file
            temp = [NSString stringWithContentsOfFile:temp encoding:NSASCIIStringEncoding];
            
            // Now we get the path from it
            return temp ? [NSExeSelection getLNKPathFromFileContents:temp forType:@".EXE"] : @"";
        }
        
        // If the .lnk file disappered, we gonna return the .lnk path; it's the best we can do
        return temp;
    }
    else
    {
        // If there is no .lnk file, then it should have an EXE file
        temp = [NSExeSelection getEXEFileFromDESKTOPFileContents:arquivo];
        if (temp) return temp;
        
        // Otherwise, there is nothing we can do, but we can't return a nil in that function, so...
        return @"";
    }
}

// INF files function
+(NSString*)getAutorunPathFromFile:(NSString*)arquivo forPort:(NSString*)wrapperUrl
{
    // Autorun files use ASCII encoding, so let's load it
	NSString* text = [NSString stringWithContentsOfFile:arquivo encoding:NSASCIIStringEncoding];
    if (!text) return nil;
    
	NSString *fileToOpen = @"";
	NSScanner *scanner = [NSScanner scannerWithString:text];
    
    // Here, we are going to search for the string 'open=' in the autorun file, and get everything after it and before a skip line char
	[scanner scanUpToString:@"open=" intoString:nil];
	while (![scanner isAtEnd])
    {
		NSString *substring = nil;
		[scanner scanString:@"open=" intoString:nil];
		if ([scanner scanUpToString:@"\n" intoString:&substring])
			fileToOpen = [NSString stringWithFormat:@"%@%@",fileToOpen,substring];
		[scanner scanUpToString:@"open=" intoString:nil];
	}
    
    // If we can't find it, we are going to look for it in uppercase ('OPEN=') has your last resource
	if ([fileToOpen isEqualToString:@""])
    {
		[scanner scanUpToString:@"OPEN=" intoString:nil];
		while (![scanner isAtEnd])
        {
			NSString *substring = nil;
			[scanner scanString:@"OPEN=" intoString:nil];
			if ([scanner scanUpToString:@"\n" intoString:&substring])
				fileToOpen = [NSString stringWithFormat:@"%@%@",fileToOpen,substring];
			[scanner scanUpToString:@"OPEN=" intoString:nil];
		}
	}
	
    // That line will remove any '"' from the string, resulting in the file name
	fileToOpen = [fileToOpen stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    
    // Here, we append the file name to the folder name (if there is no file, we have only the first path)
	text = [NSString stringWithFormat:@"%@/%@",[arquivo stringByDeletingLastPathComponent],fileToOpen];
    
    // Since the skip line char is also copied that function will remove it (removing the / if there was no file)
	text = [text substringToIndex:text.length-1];
	
    // Now we just return the Windows path for that path
    return [NSPathUtilities getWindowsPathForMacPath:text ofWrapper:wrapperUrl];
}

// Other files function
+(NSString*)pathByUpdatingPath:(NSString*)arquivo forPort:(NSString*)wrapperUrl
{
    // The use might also click on a folder, so we gonna check if there is an autorun.inf inside that folder
	NSString* arquivo2 = [NSString stringWithFormat:@"%@/autorun.inf",arquivo];
	
    if ([[NSFileManager defaultManager] fileExistsAtPath:arquivo2])
    {
        // If it do, let's returns it's execution app
        return [self getAutorunPathFromFile:arquivo2 forPort:wrapperUrl];
    }
    else
    {
        // If it don't, then we just return the Windows path for that file
        return [NSPathUtilities getWindowsPathForMacPath:arquivo ofWrapper:wrapperUrl];
    }
}

+(NSString*)selectAsMainExe:(NSString*)arquivo forPort:(NSString*)wrapperUrl
{
    NSString* text;
    NSString* path;
    NSString* flags = @"";
    NSString* lowerCaseFile = arquivo.lowercaseString;
    
    if ([lowerCaseFile hasSuffix:@".lnk"])
    {
        text = [NSString stringWithContentsOfFile:arquivo encoding:NSASCIIStringEncoding];
        
        if (text)
        {
            path  = [NSExeSelection getLNKPathFromFileContents:text forType:@".EXE"];
            flags = [NSExeSelection getLNKFlagsFromFileContents:text forPath:path];
        }
    }
    else if ([lowerCaseFile hasSuffix:@".desktop"])
    {
        text = [NSString stringWithContentsOfFile:arquivo encoding:NSUTF8StringEncoding];
        
        if (text)
        {
            if ([text contains:@"steam://rungameid/"])
            {
                path  = [NSExeSelection getSteamExePathForPort:wrapperUrl];
                flags = [NSExeSelection getURLFlagsFromSteamFileContents:text];
            }
            else
            {
                path  = [NSExeSelection getDESKTOPPathFromFileContents:text forPort:wrapperUrl];
                flags = [NSExeSelection getDESKTOPFlagsFromFileContents:text forPath:path forPort:wrapperUrl];
            }
        }
    }
    else if ([lowerCaseFile hasSuffix:@".url"])
    {
        text = [NSString stringWithContentsOfFile:arquivo encoding:NSASCIIStringEncoding];
        
        if (text)
        {
            path  = [NSExeSelection getSteamExePathForPort:wrapperUrl];
            flags = [NSExeSelection getURLFlagsFromSteamFileContents:text];
        }
    }
    else if ([lowerCaseFile hasSuffix:@".inf"])
    {
        path = [NSExeSelection getAutorunPathFromFile:arquivo forPort:wrapperUrl];
    }
    
    
    if (!path)
    {
        path = [NSExeSelection pathByUpdatingPath:arquivo forPort:wrapperUrl];
    }
    
    return [NSString stringWithFormat:@"\"%@\" %@",[path stringByReplacingOccurrencesOfString:@"/" withString:@"\\"],flags];
}

@end
