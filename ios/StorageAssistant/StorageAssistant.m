//
//  StorageAssistant.m
//  StorageAssistant
//
//  Created by 程巍巍 on 10/18/16.
//  Copyright © 2016 程巍巍. All rights reserved.
//

#import "StorageAssistant.h"

#import <CommonCrypto/CommonCrypto.h>
#import <sqlite3.h>

//static NSString* MD5(const char *cstr)
//{
//    unsigned char result[16];
//    CC_MD5(cstr, (unsigned)strlen(cstr), result);
//    return[NSString stringWithFormat:
//           @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
//           result[0], result[1], result[2], result[3],
//           result[4], result[5], result[6], result[7],
//           result[8], result[9], result[10], result[11],
//           result[12], result[13], result[14], result[15]
//           ];
//}

@implementation StorageAssistant
{
    __strong NSMutableDictionary* _dbm;
}

- (id)init
{
    if (self = [super init]) {
        _dbm = [NSMutableDictionary new];
    }
    return self;
}

- (void)dealloc
{
    for (NSString* dbPath in [_dbm copy]) {
        sqlite3* ppdb = (sqlite3*)[_dbm[dbPath] integerValue];
        int status = sqlite3_close_v2(ppdb);
        if (SQLITE_OK != status) {
            NSLog(@"close sqlite3 error: %@\ncode: %i\nmsg: %s", dbPath, status, sqlite3_errstr(status));
        }
        [_dbm removeObjectForKey:dbPath];
    }
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


RCT_EXPORT_MODULE(StorageAssistant);

- (NSDictionary *)constantsToExport
{
    // 设置 DataBase 默认存储路径
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documents = paths.firstObject;
    
    NSFileManager* manager = [NSFileManager defaultManager];
    NSString *littocats = [documents stringByAppendingPathComponent:@"com.littocats/storageassistant"];
    if (![manager fileExistsAtPath:littocats]) [manager createDirectoryAtPath:littocats withIntermediateDirectories:true attributes:nil error:nil];
    
    return @{@"Home": littocats};
}

RCT_EXPORT_METHOD(open:(NSString*)dbPath callback:(RCTResponseSenderBlock)callback)
{
    
    sqlite3* ppdb = NULL;
    id error = NSNull.null;
    int status = SQLITE_OK;
    
    if (self->_dbm[dbPath]) {
        ppdb = (sqlite3*)[self->_dbm[dbPath] integerValue];
    }else{
        status = sqlite3_open_v2(dbPath.UTF8String, &ppdb, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, NULL);
    }
    
    if (SQLITE_OK != status) {
        error =
        @{
          @"code": @(status),
          @"msg": [NSString stringWithUTF8String:sqlite3_errstr(status)]
          };
    }
    
    callback(@[NSNull.null, @((ptrdiff_t)ppdb)]);
}

RCT_EXPORT_METHOD(execute:(NSUInteger)db withSql:(NSString*)sql params:(NSArray*)params callback:(RCTResponseSenderBlock)callback)
{
    sqlite3* ppdb = (sqlite3*)db;
    int status = SQLITE_OK;
    NSMutableArray* resust = nil;
    id error = nil;
    
    // 第一步，编译 sql
    sqlite3_stmt* stmt = NULL;
    if (SQLITE_OK == status) {
        status = sqlite3_prepare(ppdb, sql.UTF8String, (int)[sql lengthOfBytesUsingEncoding:NSUTF8StringEncoding], &stmt, NULL);
    }
    
    // 第二步，绑定 params
    if (SQLITE_OK == status) {
        int count = MIN((int)params.count, sqlite3_bind_parameter_count(stmt));
        
        for (int index = 0; index < count && SQLITE_OK == status; index++) {
            NSString* text = [NSString stringWithFormat:@"%@", params[index]];
            status = sqlite3_bind_text(stmt, index+1, text.UTF8String, (int)[text lengthOfBytesUsingEncoding:NSUTF8StringEncoding], NULL);
        }
    }
    
    // 执行 stmt
    if (SQLITE_OK == status) {
        status = sqlite3_step(stmt);
        
        if (SQLITE_ROW == status) resust = [NSMutableArray new];
            
        while (SQLITE_ROW == status) {
            int count = sqlite3_column_count(stmt);
            NSMutableDictionary* row = [NSMutableDictionary new];
            for (int index = 0; index < count; index++) {
                int type = sqlite3_column_type(stmt, index);
                NSString* name = [NSString stringWithUTF8String:sqlite3_column_name(stmt, index)];
                
                
                switch (type) {
                    case SQLITE_INTEGER: {
                        NSInteger num = sqlite3_column_int64(stmt, index);
                        row[name] = @(num);
                    }break;
                    case SQLITE_FLOAT: {
                        double num = sqlite3_column_double(stmt, index);
                        row[name] = @(num);
                    }break;
                    case SQLITE_TEXT: {
                        NSString* text = [NSString stringWithUTF8String:(char*)sqlite3_column_text(stmt, index)];
                        row[name] = text;
                    }break;
                    default:
                        break;
                }
            }
            [resust addObject:row];
            status = sqlite3_step(stmt);
        }
    }
    
    // 如果 status == SQLITE_ROW, 则读取结果
    if (SQLITE_DONE != status) {
        error =
        @{
          @"code": @(status),
          @"msg": [NSString stringWithUTF8String:sqlite3_errstr(status)]
          };
    }
    
    callback(@[error ?: NSNull.null, resust ?: NSNull.null]);
}

RCT_EXPORT_METHOD(close:(NSUInteger)db callback:(RCTResponseSenderBlock)callback)
{
    sqlite3* ppdb = (sqlite3*)db;
    id error = NSNull.null;
    
    int status = sqlite3_close_v2(ppdb);
    
    if (SQLITE_OK != status) {
        error =
        @{
          @"code": @(status),
          @"msg": [NSString stringWithUTF8String:sqlite3_errstr(status)]
          };
    }else{
        for (NSString* dbPath in [_dbm copy]) {
            if ([_dbm[dbPath] integerValue] == db) {
                [_dbm removeObjectForKey:dbPath];
                break;
            }
        }
    }
    
    callback(@[error]);
}


@end
