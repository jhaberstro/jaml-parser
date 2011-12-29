//
//  JHJAMLParser.h
//  markdown-parser
//
//  Created by Jedd Haberstro on 12/8/11.
//  Copyright (c) 2011 Student. All rights reserved.
//
//
// Rules
//  _emphasize_   
//  ~strong~
//  ("link" www.google.com)  
//  headers are the same as markdown
//  @ will denote ordered list
//  * will denote unordered list
//  --- (or more) denote horizontal rule
//  `inline code`
//

#import <Foundation/Foundation.h>
#import "JHMulticastDelegate.h"

enum {
    JHNullElement = 0,
    JHEmphasizeElement = 1,
    JHStrongElement = 2,
    JHInlineCodeElement = 3,
    JHOrderedListElement,
    JHUnorderedListElement,
    JHListItemElement,
    JHHeaderElement,
    JHLinkElement,
    JHHardlineBreakElement,
    JHParagraphElement
};
typedef NSUInteger JHElement;

#define JHHeaderStrength    @"JHHeaderStrength"
#define JHLinkURL           @"JHLinkURL"
#define JHListIndent        @"JHListIndent"
#define JHElementRange      @"JHElementRange"
#define JHElementLocation   @"JHElementLocation"

@protocol JHJAMLParserDelegate <NSObject>

- (void)didParseHorizontalRule;
- (void)didParseLinkWithURL:(NSString *)url name:(NSString *)name info:(NSDictionary *)info;
- (void)didParseInlineCode:(NSString *)inlineCode info:(NSDictionary *)info;
- (void)didBeginElement:(JHElement)element info:(NSDictionary *)info;
- (void)processText:(NSString *)text startLocation:(NSUInteger)locationIndex;
- (void)didEndElement:(JHElement)element info:(NSDictionary *)info;

@end

@interface JHJAMLParser : NSObject

@property (readonly, strong) JHMulticastDelegate< JHJAMLParserDelegate >* delegates;

- (void)parseJAML:(NSString *)markdownText;

@end
