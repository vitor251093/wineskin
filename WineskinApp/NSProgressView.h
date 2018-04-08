//
//  NSProgressView.h
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 19/04/16.
//  Copyright © 2016 Vitor Marques de Miranda. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define PRIORITY_WRAPPER_CREATION     64
#define PRIORITY_APPLICATION_UPLOAD   32
#define PRIORITY_NEEDED_RESOURCES     16
#define PRIORITY_REORDERING_APPS      8
#define PRIORITY_LOAD_APP_DESCRIPTION 4
#define PRIORITY_LOCAL_APPS_LISTING   2
#define PRIORITY_SERVER_APPS_LISTING  1
#define PRIORITY_DEFAULT              0

@interface NSProgressView : NSView
{
    IBOutlet NSTextField* progressStatus;
    IBOutlet NSTextField* progressSubtitle;
    IBOutlet NSProgressIndicator* progressBar;
}

@property (nonatomic) int dialogPriority;

@property (nonatomic) IBOutlet NSView* mainBackground;

-(BOOL)showWithPriority:(int)priority;
-(BOOL)setMessage:(NSString*)status withPriority:(int)priority;
-(BOOL)setSubtitle:(NSString*)status withPriority:(int)priority;
-(BOOL)closeWithPriority:(int)priority;

-(void)setCurrentValue:(long long int)value;

-(void)setIndeterminate:(BOOL)need;

@end
