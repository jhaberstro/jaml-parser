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

#define JHHeaderStrength @"JHHeaderStrength"
#define JHLinkURL        @"JHLinkURL"
#define JHListIndent     @"JHListIndent"

@protocol JHJAMLParserDelegate <NSObject>

- (void)didParseHorizontalRule;
- (void)didBeginElement:(JHElement)element info:(NSDictionary *)info;
- (void)processText:(NSString *)text;
- (void)didEndElement:(JHElement)element info:(NSDictionary *)info;

@end

@interface JHJAMLParser : NSObject

- (void)parseJAML:(NSString *)markdownText;

@property (weak) id< JHJAMLParserDelegate > delegate;

@end
