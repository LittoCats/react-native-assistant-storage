//
//  StorageAssistant.m
//  StorageAssistant
//
//  Created by 程巍巍 on 10/18/16.
//  Copyright © 2016 程巍巍. All rights reserved.
//

#import "StorageAssistant.h"

#include <sys/types.h>
#include <sys/socket.h>
#include <ifaddrs.h>
#include <netdb.h>
#include <net/if_dl.h>
#include <string.h>

#import <CommonCrypto/CommonCrypto.h>
#import <sqlite3.h>

#define AssistantDomain @"com.littocats.StorageAssistant"

static NSString* MD5(const char *cstr)
{
    unsigned char result[16];
    CC_MD5(cstr, (unsigned)strlen(cstr), result);
    return[NSString stringWithFormat:
           @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
           result[0], result[1], result[2], result[3],
           result[4], result[5], result[6], result[7],
           result[8], result[9], result[10], result[11],
           result[12], result[13], result[14], result[15]
           ];
}

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

#pragma mark - SQLite3 Bridge

RCT_EXPORT_METHOD(sqlite3_open:(NSString*)dbPath callback:(RCTResponseSenderBlock)callback)
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

RCT_EXPORT_METHOD(sqlite3_execute:(NSUInteger)db withSql:(NSString*)sql params:(NSArray*)params callback:(RCTResponseSenderBlock)callback)
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
    
    NSString* retStr = nil;
    if (resust) {
        NSData* data = [NSJSONSerialization dataWithJSONObject:resust options:0 error:nil];
        retStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    callback(@[error ?: NSNull.null, retStr ?: NSNull.null]);
}

RCT_EXPORT_METHOD(sqlite3_close:(NSUInteger)db callback:(RCTResponseSenderBlock)callback)
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

#pragma mark - KeyChain
RCT_EXPORT_METHOD(keychain_Put:(NSString*)account :(NSString*)password :(NSString*)service :(BOOL)updateExisting callback:(RCTResponseSenderBlock)callback)
{
    NSError* error = nil;
    mKeyChainPut(MD5(account.UTF8String), password, service ?: AssistantDomain, updateExisting, &error);
    callback(@[mKeyChainError(error)]);
}

RCT_EXPORT_METHOD(keychain_Get:(NSString*)account :(NSString*)service callback:(RCTResponseSenderBlock)callback)
{
    NSError* error = nil;
    NSString* password = mKeyChainGet(MD5(account.UTF8String), service ?: AssistantDomain, &error);
    callback(password ? @[mKeyChainError(error), password] : @[mKeyChainError(error)]);
}

RCT_EXPORT_METHOD(keychain_Remove:(NSString*)account :(NSString*)service callback:(RCTResponseSenderBlock)callback)
{
    NSError* error = nil;
    mKeyChainRemove(MD5(account.UTF8String), service ?: AssistantDomain, &error);
    callback(@[mKeyChainError(error)]);
}

static NSDictionary* mKeyChainError(NSError* error) {
    if (!error) return NSNull.null;
    
    char* msg = "";
    int code = error.code;
    switch (code) {
        case errSecSuccess               : msg = "No error."; break;
        case errSecUnimplemented         : msg = "Function or operation not implemented."; break;
        case errSecIO                    : msg = "I/O error (bummers"; break;
        case errSecOpWr                  : msg = "file already open with with write permissio"; break;
        case errSecParam                 : msg = "One or more parameters passed to a function where not valid."; break;
        case errSecAllocate              : msg = "Failed to allocate memory."; break;
        case errSecUserCanceled          : msg = "User canceled the operation."; break;
        case errSecBadReq                : msg = "Bad parameter or invalid state for operation."; break;
        case errSecNotAvailable          : msg = "No keychain is available. You may need to restart your computer."; break;
        case errSecDuplicateItem         : msg = "The specified item already exists in the keychain."; break;
        case errSecItemNotFound          : msg = "The specified item could not be found in the keychain."; break;
        case errSecInteractionNotAllowed : msg = "User interaction is not allowed."; break;
        case errSecDecode                : msg = "Unable to decode the provided data."; break;
        case errSecAuthFailed            : msg = "The user name or passphrase you entered is not correct."; break;
        case -1999                      : msg = "item had been exists."; break;
        case -2000                      : msg = "not enough arguments."; break;
        default:
            msg = "unknown error.";
    }
    return @{ @"code": @(code), @"msg": [NSString stringWithFormat:@"%s", msg]};
}

static NSString* mKeyChainGet(NSString* username, NSString* serviceName, NSError** error)
{
    if (!username || !serviceName) {
        *error = [NSError errorWithDomain: AssistantDomain code: -2000 userInfo: nil];
        return nil;
    }
    
    *error = nil;
    
    // Set up a query dictionary with the base query attributes: item type (generic), username, and service
    
    NSArray *keys = [[NSArray alloc] initWithObjects: (NSString *) kSecClass, kSecAttrAccount, kSecAttrService, nil];
    NSArray *objects = [[NSArray alloc] initWithObjects: (NSString *) kSecClassGenericPassword, username, serviceName, nil];
    
    NSMutableDictionary *query = [[NSMutableDictionary alloc] initWithObjects: objects forKeys: keys];
    
    // First do a query for attributes, in case we already have a Keychain item with no password data set.
    // One likely way such an incorrect item could have come about is due to the previous (incorrect)
    // version of this code (which set the password as a generic attribute instead of password data).
    
    NSMutableDictionary *attributeQuery = [query mutableCopy];
    [attributeQuery setObject: (id) kCFBooleanTrue forKey:(id) kSecReturnAttributes];
    OSStatus status = SecItemCopyMatching((CFDictionaryRef) attributeQuery,  nil);
    
    if (status != noErr) {
        // No existing item found--simply return nil for the password
        if (status != errSecItemNotFound) {
            //Only return an error if a real exception happened--not simply for "not found."
            *error = [NSError errorWithDomain: AssistantDomain code: status userInfo: nil];
        }
        
        return nil;
    }
    
    // We have an existing item, now query for the password data associated with it.
    
    CFTypeRef resultData = nil;
    NSMutableDictionary *passwordQuery = [query mutableCopy];
    [passwordQuery setObject: (id) kCFBooleanTrue forKey: (id) kSecReturnData];
    
    status = SecItemCopyMatching((CFDictionaryRef) passwordQuery, &resultData);
    
    if (status != noErr) {
        if (status == errSecItemNotFound) {
            // We found attributes for the item previously, but no password now, so return a special error.
            // Users of this API will probably want to detect this error and prompt the user to
            // re-enter their credentials.  When you attempt to store the re-entered credentials
            // using storeUsername:andPassword:forServiceName:updateExisting:error
            // the old, incorrect entry will be deleted and a new one with a properly encrypted
            // password will be added.
            *error = [NSError errorWithDomain: AssistantDomain code: -1999 userInfo: nil];
        }else {
            // Something else went wrong. Simply return the normal Keychain API error code.
            *error = [NSError errorWithDomain: AssistantDomain code: status userInfo: nil];
        }
        
        return nil;
    }
    
    NSString *password = nil;
    
    if (resultData) {
        password = [[NSString alloc] initWithData: (__bridge NSData * _Nonnull)(resultData) encoding: NSUTF8StringEncoding];
        CFRelease(resultData);
    }else {
        // There is an existing item, but we weren't able to get password data for it for some reason,
        // Possibly as a result of an item being incorrectly entered by the previous code.
        // Set the -1999 error so the code above us can prompt the user again.
        *error = [NSError errorWithDomain: AssistantDomain code: -1999 userInfo: nil];
    }
    
    return password;
}

static BOOL mKeyChainPut(NSString* username, NSString* password, NSString* serviceName, BOOL updateExisting, NSError** error)
{
    if (!username || !password || !serviceName){
        *error = [NSError errorWithDomain: AssistantDomain code: -2000 userInfo: nil];
        return NO;
    }
    
    // See if we already have a password entered for these credentials.
    NSError *getError = nil;
    NSString *existingPassword = mKeyChainGet(username, serviceName, &getError);
    
    if ([getError code] == -1999){
        // There is an existing entry without a password properly stored (possibly as a result of the previous incorrect version of this code.
        // Delete the existing item before moving on entering a correct one.
        
        getError = nil;
        mKeyChainRemove(username, serviceName, &getError);
        
        if ([getError code] != noErr){
            *error = getError;
            return NO;
        }
    }else if ([getError code] != noErr) {
        *error = getError;
        return NO;
    }
    
    *error = nil;
    
    OSStatus status = noErr;
    
    if (existingPassword) {
        // We have an existing, properly entered item with a password.
        // Update the existing item.
        
        if (![existingPassword isEqualToString:password] && updateExisting) {
            //Only update if we're allowed to update existing.  If not, simply do nothing.
            
            NSArray *keys = [[NSArray alloc] initWithObjects: (NSString *) kSecClass,
                             kSecAttrService,
                             kSecAttrLabel,
                             kSecAttrAccount,
                             nil];
            
            NSArray *objects = [[NSArray alloc] initWithObjects: (NSString *) kSecClassGenericPassword,
                                serviceName,
                                serviceName,
                                username,
                                nil];
            
            NSDictionary *query = [[NSDictionary alloc] initWithObjects: objects forKeys: keys];
            
            status = SecItemUpdate((CFDictionaryRef) query, (CFDictionaryRef) [NSDictionary dictionaryWithObject: [password dataUsingEncoding: NSUTF8StringEncoding] forKey: (NSString *) kSecValueData]);
        }
    } else {
        // No existing entry (or an existing, improperly entered, and therefore now
        // deleted, entry).  Create a new entry.
        
        NSArray *keys = [[NSArray alloc] initWithObjects: (NSString *) kSecClass,
                         kSecAttrService,
                         kSecAttrLabel,
                         kSecAttrAccount,
                         kSecValueData,
                         nil];
        
        NSArray *objects = [[NSArray alloc] initWithObjects: (NSString *) kSecClassGenericPassword,
                            serviceName,
                            serviceName,
                            username,
                            [password dataUsingEncoding: NSUTF8StringEncoding],
                            nil];
        
        NSDictionary *query = [[NSDictionary alloc] initWithObjects: objects forKeys: keys];
        
        status = SecItemAdd((CFDictionaryRef) query, NULL);
    }
    
    if (status != noErr) {
        // Something went wrong with adding the new item. Return the Keychain error code.
        *error = [NSError errorWithDomain: AssistantDomain code: status userInfo: nil];
        return NO;
    }
    
    return YES;
}

static BOOL mKeyChainRemove(NSString* username, NSString* serviceName, NSError** error)
{
    if (!username || !serviceName){
        *error = [NSError errorWithDomain: AssistantDomain code: -2000 userInfo: nil];
        return NO;
    }
    
    *error = nil;
    
    NSArray *keys = [[NSArray alloc] initWithObjects: (NSString *) kSecClass, kSecAttrAccount, kSecAttrService, kSecReturnAttributes, nil];
    NSArray *objects = [[NSArray alloc] initWithObjects: (NSString *) kSecClassGenericPassword, username, serviceName, kCFBooleanTrue, nil];
    
    NSDictionary *query = [[NSDictionary alloc] initWithObjects: objects forKeys: keys];
    
    OSStatus status = SecItemDelete((CFDictionaryRef) query);
    
    if (status != noErr) {
        *error = [NSError errorWithDomain: AssistantDomain code: status userInfo: nil];
        return NO;
    }
    
    return YES;
}

@end
