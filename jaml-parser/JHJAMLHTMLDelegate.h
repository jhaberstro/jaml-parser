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

- (void)didParseHorizontalRule;
- (void)didParseLinkWithURL:(NSString *)url name:(NSString *)name info:(NSDictionary *)info;
- (void)didParseInlineCode:(NSString *)inlineCode info:(NSDictionary *)info;
- (void)didBeginElement:(JHElement)element info:(NSDictionary *)info;
- (void)processText:(NSString *)text startLocation:(NSUInteger)locationIndex;
- (void)didEndElement:(JHElement)element info:(NSDictionary *)info;

@property (readonly) NSString *html;

@end
