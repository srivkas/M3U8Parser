//
//  NSString+m3u8.m
//  M3U8Kit
//
//  Created by Oneday on 13-1-11.
//  Copyright (c) 2013年 0day. All rights reserved.
//

#import "NSString+m3u8.h"
#import "M3U8SegmentInfo.h"
#import "M3U8SegmentInfoList.h"
#import "M3U8ExtXStreamInf.h"
#import "M3U8ExtXStreamInfList.h"

#import "M3U8TagsAndAttributes.h"

@implementation NSString (m3u8)

/**
 The Extended M3U file format defines two tags: EXTM3U and EXTINF.  An
 Extended M3U file is distinguished from a basic M3U file by its first
 line, which MUST be #EXTM3U.
 
 reference url:http://tools.ietf.org/html/draft-pantos-http-live-streaming-00
 */
- (BOOL)isExtendedM3Ufile {
    NSRange rangeOfEXTM3U = [self rangeOfString:M3U8_EXTM3U];
    return rangeOfEXTM3U.location != NSNotFound;
}

- (BOOL)isMasterPlaylist {
    BOOL isM3U = [self isExtendedM3Ufile];
    if (isM3U) {
        NSRange r1 = [self rangeOfString:M3U8_EXT_X_STREAM_INF];
        NSRange r2 = [self rangeOfString:M3U8_EXT_X_I_FRAME_STREAM_INF];
        if (r1.location != NSNotFound || r2.location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isMediaPlaylist {
    BOOL isM3U = [self isExtendedM3Ufile];
    if (isM3U) {
        NSRange r = [self rangeOfString:M3U8_EXTINF];
        if (r.location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

- (M3U8SegmentInfoList *)m3u8SegementInfoListValueRelativeToURL:(NSURL *)baseURL {
    // self == @""
    if (0 == self.length)
        return nil;
    
    /**
     The Extended M3U file format defines two tags: EXTM3U and EXTINF.  An
     Extended M3U file is distinguished from a basic M3U file by its first
     line, which MUST be #EXTM3U.
     
     reference url:http://tools.ietf.org/html/draft-pantos-http-live-streaming-00
     */
    NSRange rangeOfEXTM3U = [self rangeOfString:M3U8_EXTM3U];
    if (rangeOfEXTM3U.location == NSNotFound ||
        rangeOfEXTM3U.location != 0) {
        return nil;
    }
    
    M3U8SegmentInfoList *segmentInfoList = [[M3U8SegmentInfoList alloc] init];
    
    NSRange segmentRange = [self rangeOfString:M3U8_EXTINF];
    NSString *remainingSegments = self;
    
    while (NSNotFound != segmentRange.location) {
        NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
        if (baseURL) {
            [params setObject:baseURL forKey:M3U8_BASE_URL];
        }
        
		// Read the EXTINF number between #EXTINF: and the comma
		NSRange commaRange = [remainingSegments rangeOfString:@","];
        NSRange valueRange = NSMakeRange(segmentRange.location + 8, commaRange.location - (segmentRange.location + 8));
        if (commaRange.location == NSNotFound || valueRange.location > remainingSegments.length -1)
            break;
        
		NSString *value = [remainingSegments substringWithRange:valueRange];
		[params setValue:value forKey:M3U8_EXTINF_DURATION];
        
        // ignore the #EXTINF line
        remainingSegments = [remainingSegments substringFromIndex:segmentRange.location];
        NSRange extinfoLFRange = [remainingSegments rangeOfString:@"\n"];
        remainingSegments = [remainingSegments substringFromIndex:extinfoLFRange.location + 1];
        
        // Read the segment link, and ignore line start with # && blank line
        while (1) {
            NSRange lfRange = [remainingSegments rangeOfString:@"\n"];
            NSString *line = [remainingSegments substringWithRange:NSMakeRange(0, lfRange.location)];
            line = [line stringByReplacingOccurrencesOfString:@" " withString:@""];
            
            remainingSegments = [remainingSegments substringFromIndex:lfRange.location + 1];
            
            if ([line characterAtIndex:0] != '#' && 0 != line.length) {
                // remove the CR character '\r'
                unichar lastChar = [line characterAtIndex:line.length - 1];
                if (lastChar == '\r') {
                    line = [line substringToIndex:line.length - 1];
                }
                
                [params setValue:line forKey:M3U8_EXTINF_URI];
                break;
            }
        }
        
        M3U8SegmentInfo *segment = [[M3U8SegmentInfo alloc] initWithDictionary:params];
        if (segment) {
            [segmentInfoList addSegementInfo:segment];
        }
        
		segmentRange = [remainingSegments rangeOfString:M3U8_EXTINF];
    }
    
    return segmentInfoList;
}

- (M3U8SegmentInfoList *)m3u8KeyList {
    NSArray *allLinedStrings = [self componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    M3U8SegmentInfoList *result = [[M3U8SegmentInfoList alloc] init];

    for (NSString *line in allLinedStrings) {
        NSRange range = [line rangeOfString:M3U8_EXT_X_KEY];
        if (range.location == NSNotFound) {
            continue;
        }

        NSMutableDictionary *dictionary = NSMutableDictionary.new;

        NSString *attributeList = [line substringFromIndex:range.location + range.length];
        NSArray *attributes = [attributeList componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@","]];
        for (NSString *attribute in attributes) {
            NSArray *parts = [attribute componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"="]];

            NSString *key = parts[0];
            NSString *value = parts[1];

            dictionary[key] = value;
        }

        M3U8SegmentInfo *segmentInfo = [[M3U8SegmentInfo alloc] initWithDictionary:[NSDictionary dictionaryWithDictionary:dictionary]];
        [result addSegementInfo:segmentInfo];
    }

    return result;
}

@end
