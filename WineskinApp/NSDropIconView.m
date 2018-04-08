//
//  NSCImageView.m
//  Porting Center
//
//  Created by Vitor Marques de Miranda.
//  Copyright 2014 UFRJ. All rights reserved.
//

#import "NSDropIconView.h"

#import "NSData+Extension.h"
#import "NSTask+Extension.h"
#import "NSImage+Extension.h"
#import "NSString+Extension.h"
#import "NSFileManager+Extension.h"

#define MAX_ICON_SIZE 512

@implementation NSDropIconView

NSString* IconPath = @"";

-(NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender
{
    if ((NSDragOperationGeneric & [sender draggingSourceOperationMask]) == NSDragOperationGeneric)
        return NSDragOperationGeneric;
    return NSDragOperationNone;
}
-(void)draggingExited:(id <NSDraggingInfo>)sender
{
}
-(NSDragOperation)draggingUpdated:(id<NSDraggingInfo>)sender
{
    return NSDragOperationCopy;
}
-(BOOL)performDragOperation:(id <NSDraggingInfo>)sender
{
    NSPasteboard *paste = [sender draggingPasteboard];
    NSArray *fileArray = [paste propertyListForType:@"NSFilenamesPboardType"];
    
    IconPath = [[fileArray firstObject] copy];
    if (!IconPath) IconPath = [NSString stringWithFormat:@"%@",[NSURL URLFromPasteboard:paste]];
    
    return YES;
}
-(void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
    if (IconPath && [IconPath isKindOfClass:[NSString class]])
    {
        if ([IconPath hasPrefix:@"/"]) [self loadIconFromFile:IconPath];
        if ([IconPath isAValidURL])    [self loadIconFromWebLink:IconPath];
        [[NSSound soundNamed:@"Pop"] play];
    }
}

-(NSImage*)getQuickLookImageFromFileAtPath:(NSString*)arquivo
{
    NSImage* img = [[NSWorkspace sharedWorkspace] iconForFile:arquivo];
    BOOL isFile = [[NSFileManager defaultManager] regularFileExistsAtPath:BINARY_QLMANAGE];
    if (isFile)
    {
        [NSTask runProgram:BINARY_QLMANAGE atRunPath:[arquivo stringByDeletingLastPathComponent]
                      withFlags:@[@"-t", @"-s",[NSString stringWithFormat:@"%d",MAX_ICON_SIZE], @"-o.", arquivo] wait:YES];
        
        NSString* newFile = [NSString stringWithFormat:@"%@.png",arquivo, nil];
        isFile = [[NSFileManager defaultManager] regularFileExistsAtPath:newFile];
        if (isFile)
        {
            img = [[NSImage alloc] initWithContentsOfFile:newFile];
            [[NSFileManager defaultManager] removeItemAtPath:newFile];
        }
    }
    return img;
}
-(NSImage*)getImageFromFile:(NSString*)arquivo
{
    NSImage *img;
    
    NSString *loweredExtension = arquivo.pathExtension.lowercaseString;
    NSSet *validImageExtensions = [NSSet setWithArray:NSImage.imageFileTypes];
    
    if ([validImageExtensions containsObject:loweredExtension])
         img = [[NSImage alloc] initWithContentsOfFile:arquivo];
    else img = [self getQuickLookImageFromFileAtPath:arquivo];
    
    if (img) return img;
    return [[NSWorkspace sharedWorkspace] iconForFile:arquivo];
}

-(void)loadIconFromWebLink:(NSString*)link
{
    NSString *loweredExtension = link.pathExtension.lowercaseString;
    NSSet *validImageExtensions = [NSSet setWithArray:NSImage.imageFileTypes];
    
    if ([validImageExtensions containsObject:loweredExtension])
    {
        NSData* imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:link] timeoutInterval:5];
        NSImage *img = [[NSImage alloc] initWithData:imageData];
        [self loadImageIcon:img];
    }
}
-(void)loadIconFromFile:(NSString*)arquivo
{
    [self loadImageIcon:[self getImageFromFile:arquivo]];
}
-(void)loadImageIcon:(NSImage*)image
{
    if (self.squareImage) [image imageByFramingImageResizing:NO];
    
    [self setImage:image];
}

@end
