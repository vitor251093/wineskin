//
//  IconDragAndDrop.m
//  Wineskin
//
//  Created by doh123 on 11/16/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "IconDragAndDrop.h"


@implementation IconDragAndDrop

- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
    //re-draw the view with our new data
    [self setNeedsDisplay:YES];
}


@end
