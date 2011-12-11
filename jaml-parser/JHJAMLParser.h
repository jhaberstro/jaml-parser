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
    JHEmphasizeElement,
    JHStrongElement,
    JHOrderedListElement,
    JHUnorderedListElement,
    JHListItemElement,
    JHHeaderElement,
    JHInlineCodeElement,
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

@interface JHJAMLParser : NSObject {
    NSMutableArray* _listDepthStack;
    NSMutableArray* _symbolStack;
    int _paragraphDepth;
    int _oldIndent;
    BOOL _previousLineEmpty;
}

- (void)parseJAML:(NSString *)markdownText;

@property (weak) id< JHJAMLParserDelegate > delegate;

@end
