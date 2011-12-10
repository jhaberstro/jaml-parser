//
//  JHJAMLHTMLDelegate.h
//  markdown-parser
//
//  Created by Jedd Haberstro on 12/9/11.
//  Copyright (c) 2011 Student. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JHJAMLParser.h"

@interface JHJAMLHTMLDelegate : NSObject< JHJAMLParserDelegate >

- (void)didBeginElement:(JHElement)element info:(NSDictionary *)info;
- (void)willParseListItem:(JHElement)element indent:(NSUInteger)indent;
- (void)processText:(NSString *)text;
- (void)didParseHorizontalRule;
- (void)didEndElement:(JHElement)element info:(NSDictionary *)info;

@property (readonly) NSString *html;

@end
