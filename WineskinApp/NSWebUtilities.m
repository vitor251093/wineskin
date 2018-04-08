//
//  NSWebUtilities.m
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 22/02/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#import "NSWebUtilities.h"
#import <SystemConfiguration/SystemConfiguration.h>

#import "NSString+Extension.h"

#define SECONDS_IN_MINUTE 60
#define MINUTES_IN_HOUR   60
#define HOURS_IN_DAY      24

#define WEBSITE_AVAILABLE_VERIFICATION_TIME_OUT 5.0

@implementation NSWebUtilities

+(NSString*)timeNeededToDownload:(long long int)needed withSpeed:(long long int)speed
{
    NSString* result = @"";
    
    if (speed < 1) result = @" ∞";
    else
    {
        int seconds, minutes, hours, days;
        needed = needed/speed;
        
        seconds = needed % SECONDS_IN_MINUTE;
        needed /= SECONDS_IN_MINUTE;
        if (seconds > 0 || (seconds==0 && needed==0)) result = [NSString stringWithFormat:@" %ds",seconds];
        
        if (needed)
        {
            minutes = needed % MINUTES_IN_HOUR;
            needed /= MINUTES_IN_HOUR;
            if (minutes > 0) result = [NSString stringWithFormat:@" %dm%@",minutes,result];
            
            if (needed)
            {
                hours = needed % HOURS_IN_DAY;
                needed /= HOURS_IN_DAY;
                if (hours > 0) result = [NSString stringWithFormat:@" %dh%@",hours,result];
                
                if (needed)
                {
                    days = (int)needed;
                    result = [NSString stringWithFormat:@" %dd%@",days,result];
                }
            }
        }
    }
    
    return [NSString stringWithFormat:NSLocalizedString(@"Time left:%@",nil),result];
}

@end
