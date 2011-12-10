//
//  JHJAMLHTMLDelegate.m
//  markdown-parser
//
//  Created by Jedd Haberstro on 12/9/11.
//  Copyright (c) 2011 Student. All rights reserved.
//

#import "JHJAMLHTMLDelegate.h"

@interface JHJAMLHTMLDelegate ()
@property (strong) NSMutableString *htmlString;
@end

@implementation JHJAMLHTMLDelegate

@dynamic html;
@synthesize htmlString = _htmlString;

- (id)init
{
    if (self = [super init]) {
        self.htmlString = [[NSMutableString alloc] init];
    }
    
    return self;
}

- (NSString *)html
{
    return [self.htmlString copy];
}

- (void)didBeginElement:(JHElement)element info:(NSDictionary *)info
{
    switch (element) {
        case JHOrderedListElement: {
            [self.htmlString appendString:@"<ol>\n"];
            break;
        }
            
        case JHUnorderedListElement: {
            [self.htmlString appendString:@"<ul>\n"];
            break;
        }
            
        case JHEmphasizeElement: {
            [self.htmlString appendString:@"<em>"];
            break;
        }
            
        case JHStrongElement: {
            [self.htmlString appendString:@"<strong>"];
            break;
        }
            
        case JHHeaderElement: {
            NSNumber* strength = [info objectForKey:JHHeaderStrength];
            [self.htmlString appendFormat:@"<h%i>", [strength intValue], nil];
            break;
        }
            
        case JHInlineCodeElement: {
            [self.htmlString appendString:@"<code>"];
            break;
        }
            
        case JHLinkElement: {
            NSString* url = [info objectForKey:JHLinkURL];
            [self.htmlString appendFormat:@"<a href=\"%@\">", url, nil];
            break;
        }
            
        case JHHardlineBreakElement: {
            [self.htmlString appendString:@"<br>"];
            break;
        }
            
        case JHParagraphElement: {
            [self.htmlString appendString:@"<p>"];
            break;
        }
            
        default:
            break;
    }
}

- (void)willParseListItem:(JHElement)element indent:(NSUInteger)indent
{
    [self.htmlString appendString:@"<li>"];
}

- (void)processText:(NSString *)text
{
    [self.htmlString appendString:text];
}

- (void)didParseHorizontalRule
{
    [self.htmlString appendString:@"<hr>"];
}

- (void)didEndElement:(JHElement)element info:(NSDictionary *)info
{
    switch (element) {
        case JHOrderedListElement:
            [self.htmlString appendString:@"</ol>\n"];
            break;
            
        case JHUnorderedListElement:
            [self.htmlString appendString:@"</ul>\n"];
            break;
            
        case JHEmphasizeElement:
            [self.htmlString appendString:@"</em>"];
            break;
            
        case JHStrongElement:
            [self.htmlString appendString:@"</strong>"];
            break;
            
        case JHHeaderElement: {
            [self.htmlString appendFormat:@"</h%i>", [[info objectForKey:JHHeaderStrength] intValue], nil];
            break;
        }
            
        case JHInlineCodeElement: {
            [self.htmlString appendFormat:@"</code>"];
            break;
        }
            
        case JHLinkElement: {
            [self.htmlString appendString:@"</a>"];
            break;
        }
            
        default:
            break;
    }
}

@end
