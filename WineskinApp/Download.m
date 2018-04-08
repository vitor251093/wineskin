//
//  Download.m
//  Gamma Board
//
//  Created by Vitor Marques de Miranda on 26/04/14.
//  Copyright (c) 2014 Vitor Marques de Miranda. All rights reserved.
//

#import "Download.h"

#import "NSWebUtilities.h"

#import "NSAlert+Extension.h"
#import "NSString+Extension.h"
#import "NSThread+Extension.h"
#import "NSFileManager+Extension.h"

@implementation Download

-(void)dealloc
{
    if (self.monitorTimer) [self stopChronometer];
}

- (void)updateUI
{
    if (_responseData)
    {
        NSString* downloadedAmount = [NSString humanReadableSizeForBytes:(long long int)[_responseData length] withDecimalMeasureSystem:NO];
        NSString* downloadedSpeed  = [NSString humanReadableSizeForBytes:_downloadedAtSecond withDecimalMeasureSystem:NO];
        
        if (_fullSize)
        {
            if ((long long int)[_responseData length] != _fullSize)
            {
                NSString* fullSizeAmount = [NSString humanReadableSizeForBytes:_fullSize withDecimalMeasureSystem:NO];
                
                double elapsedTime = [[NSDate date] timeIntervalSinceDate:_downloadStartMoment];
                long long int downloadSpeed = elapsedTime ? (long long int)[_responseData length]/elapsedTime : 0;
                NSString* estimatedTime = [NSWebUtilities timeNeededToDownload:_fullSize-[_responseData length] withSpeed:downloadSpeed];
                
                [self.progressWindow setSubtitle:[NSString stringWithFormat:NSLocalizedString(@"%@ of %@ (%@/s) - %@",nil),
                                                  downloadedAmount,fullSizeAmount,downloadedSpeed,estimatedTime]
                                    withPriority:PRIORITY_WRAPPER_CREATION];
            }
        }
        else
        {
            [self.progressWindow setSubtitle:[NSString stringWithFormat:NSLocalizedString(@"%@ (%@/s)",nil),downloadedAmount,downloadedSpeed] withPriority:PRIORITY_WRAPPER_CREATION];
        }
    }
}
- (void)timerFireMethod:(NSTimer*)time
{
    [self updateUI];
    
    _downloadedAtSecond = 0;
}
- (void)startChronometer
{
    [NSThread dispatchBlockInMainQueue:^
    {
        self.monitorTimer = [NSTimer scheduledTimerWithTimeInterval:PROGRESS_VIEW_UPDATE_INTERVAL target:self
                                                           selector:@selector(timerFireMethod:) userInfo:nil repeats:YES];
        NSRunLoop* theRunLoop = [NSRunLoop currentRunLoop];
        [theRunLoop addTimer:self.monitorTimer forMode:NSRunLoopCommonModes];
    }];
}
- (void)stopChronometer
{
    [self.monitorTimer invalidate];
}

- (BOOL)shouldCancelDownloadOfFile:(NSURL*)file to:(NSString*)path inSilence:(BOOL)silence
{
    BOOL fileExistsAtPath = [[NSFileManager defaultManager] regularFileExistsAtPath:path];
    
    if ((!file || !file.host || !file.path) && !fileExistsAtPath)
    {
        if (_promptingErrors) [NSAlert showAlertOfType:NSAlertTypeError withMessage:[NSString stringWithFormat:NSLocalizedString(@"The download link of %@ seems to be invalid.",nil), path.lastPathComponent]];
        return TRUE;
    }
    
    return FALSE;
}
- (BOOL)shouldDownloadFile:(NSURL*)file to:(NSString*)path inSilence:(BOOL)silence
{
    BOOL fileExistsAtPath = [[NSFileManager defaultManager] regularFileExistsAtPath:path];
    
    if ((!file || !file.host || !file.path) && fileExistsAtPath)
    {
        if (!_promptingErrors) return FALSE;
        
        return ![NSAlert showBooleanAlertOfType:NSAlertTypeWarning withMessage:[NSString stringWithFormat:NSLocalizedString(@"The link seems to be invalid, but there is already a file called \"%@\" in the specified folder. Do you want to use it instead?",nil), [path lastPathComponent]] withDefault:YES];
    }
    
    while ([[NSFileManager defaultManager] regularFileExistsAtPath:path])
    {
        if (!_promptingErrors) [[NSFileManager defaultManager] removeItemAtPath:path];
        else
        {
            if ([NSAlert showBooleanAlertOfType:NSAlertTypeWarning withMessage:[NSString stringWithFormat:NSLocalizedString(@"There is already a file called \"%@\" in the specified folder. Do you want to use it instead?",nil), [path lastPathComponent]] withDefault:YES])
            {
                return FALSE;
            }
            else
            {
                if ([NSAlert showBooleanAlertOfType:NSAlertTypeWarning
                                        withMessage:NSLocalizedString(@"Do you want to override it?",nil) withDefault:NO])
                {
                    [[NSFileManager defaultManager] removeItemAtPath:path];
                }
                else
                {
                    [NSAlert showAlertOfType:NSAlertTypeWarning withMessage:NSLocalizedString(@"Move that file to a different folder and then press Ok.",nil)];
                }
            }
        }
    }
    
    return TRUE;
}

- (BOOL)downloadFile:(NSURL*)file to:(NSString*)path inSilence:(BOOL)silence promptingErrors:(BOOL)errors
{
    _isSilence = silence;
    _promptingErrors = errors;
    _downloadPath = path;
    _error = nil;
    
    if ([self shouldCancelDownloadOfFile:file to:path inSilence:silence])
    {
        return FALSE;
    }
    
    if (![self shouldDownloadFile:file to:path inSilence:silence])
    {
        return TRUE;
    }
    
    if (!_isSilence)
    {
        [self.progressWindow setIndeterminate:NO];
        [self.progressWindow setCurrentValue:0];
    }
    
    _percentage = 0;
    _fullSize = 0;
    _downloadedAtSecond = 0;
    _downloadStartMoment = [NSDate date];
    
    self.connectionDidFinishLoading = NO;
    self.condition = [[NSCondition alloc] init];
    _responseData = [[NSMutableData alloc] initWithLength:0];
    if (!_isSilence) [self startChronometer];
    
    NSMutableURLRequest* wineskinDownload = [[NSURLRequest requestWithURL:file cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                          timeoutInterval:TIMEOUT_REGULAR_DOWNLOAD] mutableCopy];
    
    NSURLConnection* connection = [[NSURLConnection alloc] initWithRequest:wineskinDownload delegate:self startImmediately:NO];
    [connection scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [connection start];
    
    [self waitForConnectionToFinishLoading];
    return [self saveDownloadedFile:file atPath:path];
}

- (void)waitForConnectionToFinishLoading
{
    [self.condition lock];
    while (!self.connectionDidFinishLoading)
    {
        [self.condition wait];
    }
    [self.condition unlock];
}
- (BOOL)saveDownloadedFile:(NSURL*)file atPath:(NSString*)path
{
    if (!_promptingErrors)
    {
        if ([_responseData length] && !_error && [_responseData length] >= _fullSize)
        {
            [[NSFileManager defaultManager] createFileAtPath:path contents:_responseData attributes:nil];
            return TRUE;
        }
        
        return FALSE;
    }
    
    if ([_responseData length])
    {
        if (!_error && [_responseData length] >= _fullSize)
        {
            [[NSFileManager defaultManager] createFileAtPath:path contents:_responseData attributes:nil];
        }
        else
        {
            if ([NSAlert showBooleanAlertOfType:NSAlertTypeError withMessage:[NSString stringWithFormat:NSLocalizedString(@"%@ Do you want to try again?",nil), _error ? _error.localizedDescription : NSLocalizedString(@"The download seems to have been corrupted.",nil)]withDefault:YES])
            {
                return [self downloadFile:file to:_downloadPath inSilence:_isSilence promptingErrors:_promptingErrors];
            }
            else
            {
                [[NSFileManager defaultManager] createFileAtPath:path contents:_responseData attributes:nil];
            }
        }
    }
    else
    {
        if ([NSAlert showBooleanAlertOfType:NSAlertTypeError withMessage:NSLocalizedString(@"The informed file isn't available. Do you want to inform an updated link?",nil) withDefault:YES])
        {
            NSString* newlink = [NSAlert inputDialogWithTitle:[NSString stringWithFormat:NSLocalizedString(@"%@ URL",nil),path.lastPathComponent] message:NSLocalizedString(@"Inform the updated link:",nil) defaultValue:@""];
            return [self downloadFile:[NSURL URLWithString:newlink] to:_downloadPath inSilence:_isSilence promptingErrors:_promptingErrors];
        }
    }
    
    return TRUE;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    _fullSize = [response expectedContentLength];
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // That will avoid random crashes that might happen here
    if (_responseData && data && data.length > 0) [_responseData appendData:data];
    else
    {
        [NSAlert showAlertOfType:NSAlertTypeError withMessage:NSLocalizedString(@"An unknown error happened during the download.",nil)];
        [self finishDownload];
    }
    
    if (!_isSilence)
    {
        _downloadedAtSecond += [data length];
        
        if (_fullSize && _percentage != (PROGRESS_VIEW_BAR_PRECISION*[_responseData length])/_fullSize)
        {
            _percentage = (PROGRESS_VIEW_BAR_PRECISION*[_responseData length])/_fullSize;
            [self.progressWindow setCurrentValue:_percentage];
        }
    }
}
- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse*)cachedResponse
{
    return nil;
}
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)err
{
    _error = [err copy];
    [self finishDownload];
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self finishDownload];
}
- (void)finishDownload
{
    [self.condition lock];
    self.connectionDidFinishLoading = YES;
    [self.condition signal];
    [self.condition unlock];
    if (!_isSilence)
    {
        [self.progressWindow setIndeterminate:YES];
        [self.progressWindow setSubtitle:@"" withPriority:PRIORITY_WRAPPER_CREATION];
        [self stopChronometer];
    }
}
- (void)terminateDownload
{
    _responseData = [[NSData data] mutableCopy];
    _isSilence = true;
    _promptingErrors = false;
    [self finishDownload];
}

@end
