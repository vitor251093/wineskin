//
//  NSThread+Extension.m
//  Wineskin Navy
//
//  Created by Vitor Marques de Miranda on 22/02/17.
//  Copyright © 2017 Vitor Marques de Miranda. All rights reserved.
//

#import "NSThread+Extension.h"

dispatch_queue_t queueWithNameAndPriority(const char* name, long priority, BOOL concurrent)
{
    dispatch_queue_t dispatchQueue = dispatch_queue_create(name, concurrent ? DISPATCH_QUEUE_CONCURRENT : DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t priorityQueue = dispatch_get_global_queue(priority, 0);
    dispatch_set_target_queue(dispatchQueue, priorityQueue);
    return dispatchQueue;
}

@implementation NSThread (PKThread)

+(void)dispatchQueueWithName:(const char*)name priority:(long)priority concurrent:(BOOL)concurrent withBlock:(void (^)(void))thread
{
    dispatch_async(queueWithNameAndPriority(name, priority, concurrent), ^
    {
        thread();
    });
}
+(void)dispatchBlockInMainQueue:(void (^)(void))thread
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        thread();
    });
}

@end
