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
        [parser parseJAML:file];
        
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

