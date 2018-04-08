//
//  Download.h
//  Gamma Board
//
//  Created by Vitor Marques de Miranda on 26/04/14.
//  Copyright (c) 2014 Vitor Marques de Miranda. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSProgressView.h"

@interface Download : NSObject

#if IS_LEGACY_VERSION == TRUE
    <NSConnectionDelegate>
#else
    <NSURLConnectionDelegate>
#endif

{
    NSString* _downloadPath;
    NSError* _error;
    
    NSMutableData *_responseData;
    long long int _percentage;
    long long int _fullSize;
    
    BOOL _isSilence;
    BOOL _promptingErrors;
    
    NSDate* _downloadStartMoment;
    long long int _downloadedAtSecond;
}

@property (nonatomic, strong) NSCondition *condition;
@property (nonatomic) BOOL connectionDidFinishLoading;

@property (nonatomic, retain) NSTimer *monitorTimer;

@property (nonatomic, strong) IBOutlet NSProgressView* progressWindow;

-(BOOL)downloadFile:(NSURL*)file to:(NSString*)path inSilence:(BOOL)silence promptingErrors:(BOOL)errors;
-(void)finishDownload;
-(void)terminateDownload;

@end
