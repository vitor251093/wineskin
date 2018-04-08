//
//  NSImage+Extension.m
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 12/03/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#import <CoreImage/CoreImage.h>

#import "NSImage+Extension.h"

#import "NSComputerInformation.h"

#import "NSTask+Extension.h"
#import "NSString+Extension.h"
#import "NSFileManager+Extension.h"

#define INNER_GOG_ICON_SIDE     440
#define INNER_GOG_ICON_X_MARGIN 36
#define INNER_GOG_ICON_Y_MARGIN 35

#define FULL_ICON_SIZE          512


#define SMALLER_ICONSET_NEEDED_SIZE 16
#define BIGGEST_ICONSET_NEEDED_SIZE 1024

#define TIFF2ICNS_ICON_SIZE 512


@implementation NSImage (PKImage)

-(NSImage*)imageByFramingImageResizing:(BOOL)willResize
{
    int MAX_ICON_SIZE = FULL_ICON_SIZE/RETINA_SCALE;
    
    if (self.size.width > self.size.height)
    {
        CGFloat newHeight = (MAX_ICON_SIZE / self.size.width) * self.size.height;
        [self setSize:NSMakeSize(MAX_ICON_SIZE,newHeight)];
        
        NSRect dim = [self alignmentRect];
        dim.size.height = MAX_ICON_SIZE;
        dim.origin.y = self.size.height/2 - MAX_ICON_SIZE/2;
        [self setAlignmentRect:dim];
    }
    
    else if (self.size.width < self.size.height)
    {
        CGFloat newWidth = (MAX_ICON_SIZE / self.size.height) * self.size.width;
        [self setSize: NSMakeSize(newWidth,MAX_ICON_SIZE)];
        
        NSRect dim = [self alignmentRect];
        dim.size.width = MAX_ICON_SIZE;
        dim.origin.x = self.size.width/2 - MAX_ICON_SIZE/2;
        [self setAlignmentRect:dim];
    }
    
    else [self setSize:NSMakeSize(MAX_ICON_SIZE,MAX_ICON_SIZE)];
    
    if (willResize)
    {
        NSImage *resizedImage = [[NSImage alloc] initWithSize:NSMakeSize(MAX_ICON_SIZE,MAX_ICON_SIZE)];
        [resizedImage lockFocus];
        
        [self drawInRect:NSMakeRect(0,0,MAX_ICON_SIZE,MAX_ICON_SIZE) fromRect:self.alignmentRect operation:NSCompositeSourceOver fraction:1.0];
        
        [resizedImage unlockFocus];
        return resizedImage;
    }
    else return self;
}

-(BOOL)saveAsPngImageWithSize:(int)size atPath:(NSString*)pngPath
{
    CIImage *ciimage = [CIImage imageWithData:[self TIFFRepresentation]];
    CIFilter *scaleFilter = [CIFilter filterWithName:@"CILanczosScaleTransform"];
    
    int originalWidth  = [ciimage extent].size.width;
    float scale = (float)size / (float)originalWidth;
    
    [scaleFilter setValue:@(scale) forKey:@"inputScale"];
    [scaleFilter setValue:@(1.0)   forKey:@"inputAspectRatio"];
    [scaleFilter setValue:ciimage  forKey:@"inputImage"];
    
    ciimage = [scaleFilter valueForKey:@"outputImage"];
    if (!ciimage) return false;
    
    NSBitmapImageRep* rep;
    
    @try
    {
        rep = [[NSBitmapImageRep alloc] initWithCIImage:ciimage];
    }
    @catch (NSException* exception)
    {
        return false;
    }
    
    NSData *data = [rep representationUsingType:NSPNGFileType properties:@{}];
    [data writeToFile:pngPath atomically:YES];
    
    return true;
}
-(BOOL)saveIconsetWithSize:(int)size atFolder:(NSString*)folder
{
    BOOL result = [self saveAsPngImageWithSize:size atPath:[NSString stringWithFormat:@"%@/icon_%dx%d.png",folder,size,size]];
    if (result == false) return false;
    
    result = [self saveAsPngImageWithSize:size*2 atPath:[NSString stringWithFormat:@"%@/icon_%dx%d@2x.png",folder,size,size]];
    return result;
}
-(BOOL)saveAsIcnsAtPath:(NSString*)icnsPath
{
    if (!icnsPath) return false;
    
    if (![icnsPath hasSuffix:@".icns"]) icnsPath = [icnsPath stringByAppendingString:@".icns"];
    NSString* iconsetPath = [[icnsPath substringToIndex:icnsPath.length - 5] stringByAppendingString:@".iconset"];
    
    [[NSFileManager defaultManager] createDirectoryAtPath:iconsetPath withIntermediateDirectories:NO];
    for (int validSize = SMALLER_ICONSET_NEEDED_SIZE; validSize <= BIGGEST_ICONSET_NEEDED_SIZE; validSize=validSize*2)
        [self saveIconsetWithSize:validSize atFolder:iconsetPath];
    
    [[NSFileManager defaultManager] removeItemAtPath:icnsPath];
    [NSTask runProgram:@"iconutil" atRunPath:nil withFlags:@[@"-c", @"icns", iconsetPath] wait:YES];
    [[NSFileManager defaultManager] removeItemAtPath:iconsetPath];
    
    if ([[NSFileManager defaultManager] sizeOfRegularFileAtPath:icnsPath] > 10)
    {
        return true;
    }
    
    NSString *tiffPath = [NSString stringWithFormat:@"%@.tiff",icnsPath];
    
    CGFloat correctIconSize = TIFF2ICNS_ICON_SIZE/RETINA_SCALE;
    NSImage *resizedImage = [[NSImage alloc] initWithSize:NSMakeSize(correctIconSize,correctIconSize)];
    [resizedImage lockFocus];
    [self drawInRect:NSMakeRect(0,0,correctIconSize, correctIconSize) fromRect:self.alignmentRect
           operation:NSCompositeSourceOver fraction:1.0];
    [resizedImage unlockFocus];
    
    [[resizedImage TIFFRepresentation] writeToFile:tiffPath atomically:YES];
    [[NSFileManager defaultManager] removeItemAtPath:icnsPath];
    [NSTask runProgram:@"tiff2icns" atRunPath:nil withFlags:@[@"-noLarge", tiffPath, icnsPath] wait:YES];
    [[NSFileManager defaultManager] removeItemAtPath:tiffPath];
    
    return [[NSFileManager defaultManager] regularFileExistsAtPath:icnsPath];
}

@end
