//
//  main.m
//  jaml-parser
//
//  Created by Jedd Haberstro on 12/9/11.
//  Copyright (c) 2011 Student. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JHJAMLParser.h"
#import "JHJAMLHTMLDelegate.h"

#include <mach/mach.h>
#include <mach/mach_time.h>
#include <unistd.h>

static uint64_t mach_nano_seconds(uint64_t start, uint64_t end) {
    static mach_timebase_info_data_t    sTimebaseInfo;
    uint64_t elapsed = end - start;
    
    // Convert to nanoseconds.
    
    // If this is the first time we've run, get the timebase.
    // We can use denom == 0 to indicate that sTimebaseInfo is 
    // uninitialised because it makes no sense to have a zero 
    // denominator is a fraction.
    
    if ( sTimebaseInfo.denom == 0 ) {
        (void) mach_timebase_info(&sTimebaseInfo);
    }
    
    // Do the maths. We hope that the multiplication doesn't 
    // overflow; the price you pay for working in fixed point.
    return elapsed * sTimebaseInfo.numer / sTimebaseInfo.denom;
}

int main (int argc, const char * argv[])
{
    argc -= 1;
    argv += 1;
    @autoreleasepool {
        if (argc != 1 && argc != 2) {
            fprintf(stderr, "Invalid number of arguments.\nusage: jaml input_file [output_file]");
            return 1;
        }
        
        NSError* error = nil;
        NSString* file = [NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%s", argv[0], nil] encoding:NSUTF8StringEncoding error:&error];
        if (error) {
            fprintf(stderr, "%s\n", [[error localizedDescription] UTF8String]);
            return 1;
        }
        
        JHJAMLHTMLDelegate* delegate = [[JHJAMLHTMLDelegate alloc] init];
        JHJAMLParser* parser = [[JHJAMLParser alloc] init];
        parser.delegate = delegate;
        
        uint64_t start = mach_absolute_time();
        [parser parseJAML:file];
        uint64_t end = mach_absolute_time();
        uint64_t nanoseconds = mach_nano_seconds(start, end);
        NSLog(@"nanoseconds: %llu", nanoseconds);
        
        if (argc == 2) {
            [delegate.html writeToFile:[NSString stringWithFormat:@"%s", argv[1], nil] atomically:YES encoding:NSUTF8StringEncoding error:&error];
            if (error) {
                fprintf(stderr, "%s\n", [[error localizedDescription] UTF8String]);
                return 1;
            }
        }
        else {
            printf("%s", [delegate.html UTF8String]);
        }
    }
    
    return 0;
}

