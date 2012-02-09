//  Keys.m, for the Applescript WineskinLauncher to tell what keys are pressed
//  Copyright 2011 by The Wineskin Project and doh123@doh123.com All rights reserved.
//  Licensed for use under the LGPL <http://www.gnu.org/licenses/lgpl-2.1.txt>

#import <Cocoa/Cocoa.h>
int main (int argc, const char * argv[])
{
	CGEventRef event = CGEventCreate(NULL);
	CGEventFlags modifiers = CGEventGetFlags(event);
	CFRelease(event);
	if ((modifiers & kCGEventFlagMaskAlternate) == kCGEventFlagMaskAlternate || (modifiers & kCGEventFlagMaskSecondaryFn) == kCGEventFlagMaskSecondaryFn)
		printf("1");
	else
		printf("0");
    return 0;
}






