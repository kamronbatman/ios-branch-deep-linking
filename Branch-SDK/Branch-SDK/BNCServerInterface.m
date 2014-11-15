//
//  BNCServerInterface.m
//  Branch-SDK
//
//  Created by Alex Austin on 6/6/14.
//  Copyright (c) 2014 Branch Metrics. All rights reserved.
//

#import "BNCServerInterface.h"
#import "BNCPreferenceHelper.h"
#import "BNCConfig.h"

@implementation BNCServerInterface

// make a generalized get request
- (void)getRequestAsync:(NSDictionary *)params url:(NSString *)url andTag:(NSString *)requestTag {
    [self getRequestAsync:params url:url andTag:requestTag log:YES];
}

- (void)getRequestAsync:(NSDictionary *)params url:(NSString *)url andTag:(NSString *)requestTag log:(BOOL)log {
    url = [url stringByAppendingString:@"?"];
    
    if (params) {
        NSArray *allKeys = [params allKeys];

        for (NSString *key in allKeys) {
            if ([key length] > 0) {
                if ([params objectForKey:key]) {
                    url = [url stringByAppendingString:key];
                    url = [url stringByAppendingString:@"="];
                    url = [url stringByAppendingString:[[params objectForKey:key] description]];
                    url = [url stringByAppendingString:@"&"];
                }
            }
        }
    }
    
    url = [url stringByAppendingFormat:@"sdk=ios%@", BNC_SDK_VERSION];
    if (log) {
        [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"using url = %@", url];
    }
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:url]];
    
    [request setHTTPMethod:@"GET"];
    [request setValue:@"0" forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"applications/json" forHTTPHeaderField:@"Content-type"];
    [request setHTTPBody:nil];
    
    [self genericHTTPRequest:request withTag:requestTag];
}

// make a generalized post request
- (void)postRequestAsync:(NSDictionary *)post url:(NSString *)url andTag:(NSString *)requestTag {
    [self postRequestAsync:post url:url andTag:requestTag log:YES];
}

- (void)postRequestAsync:(NSDictionary *)post url:(NSString *)url andTag:(NSString *)requestTag log:(BOOL)log {
    [post setValue:[NSString stringWithFormat:@"ios%@", BNC_SDK_VERSION] forKey:@"sdk"];
    NSData *postData = [BNCServerInterface encodePostParams:post];
    NSString *postLength = [NSString stringWithFormat:@"%lu", (unsigned long)[postData length]];
    
    if (log) {
        [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"using url = %@", url];
        [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"body = %@", [post description]];
    }
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:url]];
    [request setTimeoutInterval:3];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-type"];
    [request setHTTPBody:postData];
    
    [self genericHTTPRequest:request withTag:requestTag];
}

+ (NSData *)encodePostParams:(NSDictionary *)params {
    NSError *writeError = nil;
    NSData *postData = [NSJSONSerialization dataWithJSONObject:params options:NSJSONWritingPrettyPrinted error:&writeError];
    return postData;
}

+ (NSString *)encodePostToUniversalString:(NSDictionary *)params {
    NSMutableString *encodedParams = [[NSMutableString alloc] initWithString:@"{ "];
    for (NSString *key in params) {
        NSString *value = nil;
        BOOL string = YES;
        if ([[params objectForKey:key] isKindOfClass:[NSString class]]) {
            value = [params objectForKey:key];
        } else if ([[params objectForKey:key] isKindOfClass:[NSDictionary class]]) {
            value = [BNCServerInterface encodePostToUniversalString:[params objectForKey:key]];
        } else if ([[params objectForKey:key] isKindOfClass:[NSNumber class]]) {
            value = [[params objectForKey:key] stringValue];
            string = NO;
        }
        [encodedParams appendString:@"\""];
        [encodedParams appendString:key];
        if (string) [encodedParams appendString:@"\":\""];
        else [encodedParams appendString:@"\":"];
        [encodedParams appendString:value];
        if (string) [encodedParams appendString:@"\","];
        else [encodedParams appendString:@","];
    }
    [encodedParams appendString:@"\"source\":\"ios\" }"];
    [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"encoded params : %@", encodedParams];
    return encodedParams;
}

- (void)genericHTTPRequest:(NSMutableURLRequest *)request withTag:(NSString *)requestTag {
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler: ^(NSURLResponse *response, NSData *POSTReply, NSError *error) {
        BNCServerResponse *serverResponse;
        if (!error) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            NSNumber *statusCode = [NSNumber numberWithLong:[httpResponse statusCode]];
            
            serverResponse = [[BNCServerResponse alloc] initWithTag:requestTag andStatusCode:statusCode];
            
            if (POSTReply != nil) {
                NSError *convError;
                id jsonData = [NSJSONSerialization JSONObjectWithData:POSTReply options:NSJSONReadingMutableContainers error:&convError];
                serverResponse.data = jsonData;
            }
        } else {
            serverResponse = [[BNCServerResponse alloc] initWithTag:requestTag andStatusCode:[NSNumber numberWithInteger:error.code]];
            serverResponse.data = error.userInfo;
        }
        if (![requestTag isEqualToString:REQ_TAG_SEND_LOG] && ![requestTag isEqualToString:REQ_TAG_DEBUG_CONNECT]) {
            [BNCPreferenceHelper log:FILE_NAME line:LINE_NUM message:@"returned = %@", [serverResponse description]];
        }
        
        if (self.delegate) [self.delegate serverCallback:serverResponse];
    }];
}


@end
