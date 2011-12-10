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
//

#import <Foundation/Foundation.h>


enum {
    JHNullElement = 0,
    JHEmphasizeElement,
    JHStrongElement,
    JHOrderedListElement,
    JHUnorderedListElement,
    JHHeaderElement
};
typedef NSUInteger JHElement;

#define JHHeaderStrength @"JHHeaderStrength"

@protocol JHJAMLParserDelegate <NSObject>

- (void)didBeginElement:(JHElement)element info:(NSDictionary *)info;
- (void)willParseListItem:(JHElement)element indent:(NSUInteger)indent;
- (void)processText:(NSString *)text;
- (void)didParseHorizontalRule;
- (void)didEndElement:(JHElement)element info:(NSDictionary *)info;

@end

@interface JHJAMLParser : NSObject {
    NSMutableArray* _listDepthStack;
    NSMutableArray* _symbolStack;
    int _oldIndent;
}

- (void)parseJAML:(NSString *)markdownText;

@property (weak) id< JHJAMLParserDelegate > delegate;

@end
