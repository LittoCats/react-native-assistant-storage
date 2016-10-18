//
//  StorageAssistant.m
//  StorageAssistant
//
//  Created by 程巍巍 on 10/18/16.
//  Copyright © 2016 程巍巍. All rights reserved.
//

#import "StorageAssistant.h"
#import <sqlite3.h>

@implementation StorageAssistant

RCT_EXPORT_MODULE(StorageAssistant);

RCT_REMAP_METHOD(open, open:(NSString*)dbPath resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    
}

RCT_REMAP_METHOD(execute, execute:(NSString*)sql withParams:(NSArray*)params resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    
}

RCT_REMAP_METHOD(close, closeWithResolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    
}
- (dispatch_queue_t)methodQueue
{
    return self.class.methodQueue;
}
+ (dispatch_queue_t)methodQueue
{
    static dispatch_queue_t queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create("com.littocats.StorageAssistantQueue", DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

@end
