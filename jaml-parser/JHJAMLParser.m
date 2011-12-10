//
//  JHJAMLParser.m
//  markdown-parser
//
//  Created by Jedd Haberstro on 12/8/11.
//  Copyright (c) 2011 Student. All rights reserved.
//

// TODO - hyperlinks, escape characters (\#, \*, \^, \@) 

#import "JHJAMLParser.h"

static BOOL IsHorizontalRule(NSString *text) {
    // validate length requirement
    if ([text length] < 3) {
        return NO;
    }
    
    // validate all dashes
    for (NSUInteger i = 0; i < [text length]; ++i) {
        if ([text characterAtIndex:i] != '-') {
            return NO;
        }
    }
    
    return YES;
}

static BOOL IsEmpty(NSString *text) {
    return [text rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]].length == [text length];
}

static BOOL IsDigit(unichar character) {
    return character >= '0' && character <= '9';
}

static void UnrollStack(NSMutableArray* stack, void(^func)(id object)) {
    while ([stack count]) {
        id object = [stack lastObject];
        [stack removeLastObject];
        func(object);
    }
}

@interface JHJAMLParser ()
- (void)_consumeHeader:(NSString *)line;
- (NSString *)_parseLine:(NSString *)line;
@end

@implementation JHJAMLParser

@synthesize delegate = _delegate;

+ (void)_unrollListStack:(NSMutableArray *)listStack delegate:(id< JHJAMLParserDelegate >)delegate
{
    UnrollStack(listStack, ^(NSNumber* listType) {
        if ([listType intValue] == JHOrderedListElement)
            [delegate didEndElement:JHOrderedListElement info:nil];
        else if ([listType intValue] == JHUnorderedListElement)
            [delegate didEndElement:JHUnorderedListElement info:nil];
    });
}

- (id)init
{
    if ((self = [super init])) {
        _listDepthStack = [NSMutableArray array];
        _symbolStack = [NSMutableArray array];
        _oldIndent = 0;
    }
    
    return self;
}

- (void)_consumeHeader:(NSString *)line
{
    // remove trailing headers symbols
    NSUInteger end = [line length] - 1;
    while ([line characterAtIndex:end] == '#') {
        --end;
    }
    line = [line substringToIndex:end + 1];
    
    // remove front header symbols
    int strength = 0;
    NSUInteger c = 0;
    while ([line characterAtIndex:c] == '#') {
        strength += 1;
        c += 1;
    }
    
    // replace middle # symbols with \# and then parse contents
    NSString* contents = [[line substringFromIndex:c] stringByReplacingOccurrencesOfString:@"#" withString:@"\\#"];
    
    // reparse
    [self.delegate didBeginElement:JHHeaderElement info:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:strength] forKey:JHHeaderStrength]];
    [self.delegate processText:[self _parseLine:contents]];
    [self.delegate didEndElement:JHHeaderElement info:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:strength] forKey:JHHeaderStrength]];
}

- (NSString *)_parseLine:(NSString *)line
{
    NSMutableString* text = [NSMutableString string];
    NSUInteger length = [line length];
    if (IsHorizontalRule(line)) {
        [JHJAMLParser _unrollListStack:_listDepthStack delegate:self.delegate];
        [self.delegate didParseHorizontalRule];
    }
    else {
        int indent = 0;
        NSUInteger c = 0;
        // Consume all leading tabs
        while (c < length && [line characterAtIndex:c] == '\t') {
            c += 1;
            indent += 1;
        }
        
        NSUInteger startIndex = c;
        for (; c < length; ++c) {
            unichar character = [line characterAtIndex:c];
            
            // check ordered lists
            if (character == '@' && c == startIndex) {
                if ([_listDepthStack count] && indent < _oldIndent) {
                    NSNumber* listType = [_listDepthStack lastObject];
                    [_listDepthStack removeLastObject];
                    [self.delegate didEndElement:[listType intValue] info:nil];
                }
                
                if ([_listDepthStack count] == 0 || indent > _oldIndent) {
                    [self.delegate didBeginElement:JHOrderedListElement info:nil];
                    [_listDepthStack addObject:[NSNumber numberWithInt:JHOrderedListElement]];
                }
                
                [self.delegate willParseListItem:JHOrderedListElement indent:indent];
            }
            // check unordered list
            else if (character == '*' && c == startIndex) {
                if ([_listDepthStack count] && indent < _oldIndent) {
                    NSNumber* listType = [_listDepthStack lastObject];
                    [_listDepthStack removeLastObject];
                    [self.delegate didEndElement:[listType intValue] info:nil];
                }
                
                if ([_listDepthStack count] == 0 || indent > _oldIndent) {
                    [self.delegate didBeginElement:JHUnorderedListElement info:nil];
                    [_listDepthStack addObject:[NSNumber numberWithInt:JHUnorderedListElement]];
                }
                
                [self.delegate willParseListItem:JHUnorderedListElement indent:indent];
            }
            else {
                if (c == startIndex && [_listDepthStack count]) {
                    // Reached a line that doesn't start with list element, so the list(s) must be done
                    [JHJAMLParser _unrollListStack:_listDepthStack delegate:self.delegate];
                }
                
                JHElement element = JHNullElement;
                switch (character) {
                    case '~':
                        element = JHEmphasizeElement;
                        break;
                        
                    case '^':
                        element = JHStrongElement;
                        break;
                        
                    case '#':
                        element = JHHeaderElement;
                        break;
                        
                    default:
                        break;
                }
                
                if (element != JHNullElement) {
                    if (element == JHHeaderElement) {
                        [self _consumeHeader:[line substringFromIndex:c]];
                        c = length;
                    }
                    else {
                        JHElement top = [[_symbolStack lastObject] intValue];
                        if (top != element) {
                            [_symbolStack addObject:[NSNumber numberWithInt:(int)element]];
                            [self.delegate didBeginElement:element info:nil];
                        }
                        else {
                            [_symbolStack removeLastObject];
                            [self.delegate processText:[text copy]];
                            [text setString:@""];
                            [self.delegate didEndElement:element info:nil];
                        }
                    }
                }
                else {
                    [text appendFormat:@"%c", [line characterAtIndex:c], nil];
                }                    
            }
        }
        
        _oldIndent = indent;
    }
    
    return text;
}

- (void)parseJAML:(NSString *)markdownText
{
    NSMutableString* text = [NSMutableString string];    
    for (NSString* line in [markdownText componentsSeparatedByString:@"\n"]) {
        [text appendString:[self _parseLine:line]];
        [text appendString:@"\n"];
        [self.delegate processText:[text copy]];
        [text setString:@""];
    }
    
    // Unwind remaining list state
    [JHJAMLParser _unrollListStack:_listDepthStack delegate:self.delegate];
}
@end