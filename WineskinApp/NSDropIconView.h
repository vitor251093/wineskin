//
//  NSCImageView.h
//  Porting Center
//
//  Created by Vitor Marques de Miranda.
//  Copyright 2014 UFRJ. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSDropIconView : NSImageView

-(void)loadIconFromFile:(NSString*)arquivo;

@property (nonatomic) BOOL squareImage;

@end
