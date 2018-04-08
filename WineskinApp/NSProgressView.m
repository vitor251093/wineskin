//
//  NSProgressView.m
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 19/04/16.
//  Copyright © 2016 Vitor Marques de Miranda. All rights reserved.
//

#import "NSProgressView.h"

#import "NSThread+Extension.h"

@implementation NSProgressView

-(void)awakeFromNib
{
    self.dialogPriority = PRIORITY_DEFAULT;
    
    [progressBar setMaxValue:PROGRESS_VIEW_BAR_PRECISION];
}

-(BOOL)showWithPriority:(int)priority
{
    [NSThread dispatchBlockInMainQueue:^
    {
        BOOL showDialog = priority >= self.dialogPriority;
        
        if ((self.dialogPriority & priority) == 0 && priority != 0) self.dialogPriority += priority;
        
        if (showDialog)
        {
            [self setSubtitle:@"" withPriority:priority];
            [self setIndeterminate:YES];
            
            // Set view height to 111
            //[self setHeight:PROGRESS_VIEW_HEIGHT];
        }
    }];
    
    return TRUE;
}
-(BOOL)setMessage:(NSString*)status withPriority:(int)priority
{
    NSDebugLog(@"%@",status);
    
    if (priority < self.dialogPriority) return FALSE;
        
    [NSThread dispatchBlockInMainQueue:^
    {
        [progressStatus setStringValue:status ? status : @""];
    }];
    
    return TRUE;
}
-(BOOL)setSubtitle:(NSString*)status withPriority:(int)priority
{
    if (priority < self.dialogPriority) return FALSE;
    
    [NSThread dispatchBlockInMainQueue:^
    {
        [progressSubtitle setStringValue:status ? status : @""];
    }];
    
    return TRUE;
}
-(BOOL)closeWithPriority:(int)priority
{
    [NSThread dispatchBlockInMainQueue:^
    {
        BOOL hideDialog = (self.dialogPriority - priority) == 0;
        
        if ((self.dialogPriority & priority) != 0 && priority != 0) self.dialogPriority -= priority;
        
        if (hideDialog)
        {
            // Set view height to 0
            //[self setHeight:0];
        }
    }];
    return TRUE;
}

-(void)setCurrentValue:(long long int)value
{
    [NSThread dispatchBlockInMainQueue:^
    {
        [progressBar setIndeterminate:NO];
        [progressBar setDoubleValue:[[NSNumber numberWithLongLong:value] doubleValue]];
        
#if IS_LEGACY_VERSION == TRUE
        [progressBar setNeedsDisplay:YES];
#endif
    }];
}

-(void)setIndeterminate:(BOOL)need
{
    [NSThread dispatchBlockInMainQueue:^
    {
        [progressBar setIndeterminate:need];
    }];
}

@end
