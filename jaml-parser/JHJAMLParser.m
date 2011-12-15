//
//  JHJAMLParser.m
//  markdown-parser
//
//  Created by Jedd Haberstro on 12/8/11.
//  Copyright (c) 2011 Student. All rights reserved.
//

// TODO - hyperlinks, escape characters (\#, \*, \~, \_) 

#import "JHJAMLParser.h"

static BOOL IsHorizontalRule(char const* text, NSUInteger length) {
    if (length < 3) {
        return NO;
    }
    
    for (NSUInteger i = 0; i < length; ++i) {
        if (text[i] != '-') {
            return NO;
        }
    }
    
    return YES;
}

static BOOL StartsWithOrderedList(NSString* line, NSUInteger startIndex, NSUInteger* length) {
    NSRange periodIndex = [line rangeOfString:@". "];
    if (periodIndex.length == 0) {
        return NO;
    }
    
    NSNumberFormatter* numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setAllowsFloats:NO];
    NSString* proposedNumber = [line substringToIndex:periodIndex.location];
    NSNumber* number = [numberFormatter numberFromString:proposedNumber];
    if (number == nil) {
        return NO;
    }
    
    if ([number intValue] < 0) {
        return NO;
    }
    
    *length = [proposedNumber length] + 2 - startIndex;
    return YES;
}

static void UnrollStack(NSMutableArray* stack, NSUInteger count, void(^func)(id object)) {
    while ([stack count] && count > 0) {
        id object = [stack lastObject];
        [stack removeLastObject];
        func(object);
        --count;
    }
}

@interface _ListState : NSObject
@property (assign) JHElement type;
@property (assign) int indent;
@property (assign) int numberOfListElements;
@property (assign) int paragraphsInList;
@end

@implementation _ListState
@synthesize type;
@synthesize indent;
@synthesize numberOfListElements;
@synthesize paragraphsInList;
@end

@interface JHJAMLParser ()
- (void)_resetState;
- (void)_terminateEndItemForList:(_ListState *)state;
- (void)_unrollListStack:(NSUInteger)count;
- (void)_processListItem:(JHElement)listType indent:(int)indent;
- (void)_consumeHeader:(NSString *)line;
- (NSUInteger)_consumeLink:(NSString *)line previousText:(NSMutableString **)previousText;
- (NSString *)_parseLine:(NSString *)line;
@end

@implementation JHJAMLParser

@synthesize delegate = _delegate;

- (id)init
{
    if ((self = [super init])) {
        _listDepthStack = [[NSMutableArray alloc] init];
        _symbolStack = [[NSMutableArray alloc] init];
        _oldIndent = 0;
    }
    
    return self;
}

- (void)_resetState
{
    [_listDepthStack removeAllObjects];
    [_symbolStack removeAllObjects];
    _oldIndent = 0;
    _previousLineEmpty = NO;
    _ignoreHardBreak = NO;
}

- (void)_terminateEndItemForList:(_ListState *)state
{
    if (state.numberOfListElements > 0) {
        if (state.paragraphsInList > 0) {
            [self.delegate didEndElement:JHParagraphElement info:nil];
            --state.paragraphsInList;
            --_paragraphDepth;
        }
        [self.delegate didEndElement:JHListItemElement info:nil];
    }
}

- (void)_unrollListStack:(NSUInteger)count
{
    while ([_listDepthStack count] && count > 0) {
        _ListState* state = [_listDepthStack lastObject];
        [_listDepthStack removeLastObject];
        [self _terminateEndItemForList:state];
        if (state.type == JHOrderedListElement)
            [self.delegate didEndElement:JHOrderedListElement info:nil];
        else if (state.type == JHUnorderedListElement)
            [self.delegate didEndElement:JHUnorderedListElement info:nil];
        
        --count;
    }
}

- (void)_processListItem:(JHElement)listType indent:(int)indent
{
    if ([_listDepthStack count] && indent < _oldIndent) {
        _ListState* state = [_listDepthStack lastObject];
        [self _unrollListStack:(state.indent - indent)];
    }
    
    NSUInteger listDepth = [_listDepthStack count];
    if (listDepth == 0 || (listDepth > 0 && indent > ((_ListState*)[_listDepthStack lastObject]).indent)) {
        [self.delegate didBeginElement:listType info:nil];
        _ListState* state = [[_ListState alloc] init];
        state.type = listType;
        state.indent = indent;
        [_listDepthStack addObject:state];
    }
    
    _ListState* currentList = [_listDepthStack lastObject];
    if (currentList.numberOfListElements > 0 && currentList.indent == indent && currentList.type == listType) {
        [self _terminateEndItemForList:currentList];
    }
    
    [self.delegate didBeginElement:JHListItemElement info:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:indent] forKey:JHListIndent]];
    currentList.numberOfListElements += 1;
    _ignoreHardBreak = YES;
}


- (void)_consumeHeader:(NSString *)line
{
    // remove trailing headers symbols
    NSUInteger length = [line length];
    char const* lineString = [line UTF8String];
    NSUInteger end = length;
    while (lineString[end - 1] == '#' && end > 0) {
        --end;
    }
    
    if (end == (length - 1)) {
        return;
    }
    
    line = [line substringToIndex:end];
    
    // remove front header symbols
    int strength = 0;
    NSUInteger c = 0;
    while (lineString[c] == '#') {
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

- (NSUInteger)_consumeLink:(NSString *)line previousText:(NSMutableString **)previousText
{
    NSRegularExpression* regex = [[NSRegularExpression alloc] initWithPattern:@"\\[.*\\]\\(.*\\)" options:0 error:nil];
    NSRange range = [regex rangeOfFirstMatchInString:line options:0 range:NSMakeRange(0, [line length])];
    if (range.length == 0) {
        return 0;
    }
    
    NSRange nameRange = [[NSRegularExpression regularExpressionWithPattern:@"\\[.*\\]" options:0 error:nil] rangeOfFirstMatchInString:line options:0 range:NSMakeRange(0, [line length])];
    if (nameRange.length <= 2) {
        [NSException raise:@"JAMLLinkElementException" format:@"Link element's name's quotation is empty."];
        return 0;
    }
    
    NSRange urlRange = {
        .location = nameRange.location + nameRange.length + 1,
        .length = range.length - (nameRange.length + 2)
    };    
    
    // adjust name range to exclude brackets
    nameRange.location += 1;
    nameRange.length -= 2;
    
    if (*previousText) {
        [self.delegate processText:*previousText];
        [*previousText setString:@""];
    }
    
    [self.delegate didBeginElement:JHLinkElement info:[NSDictionary dictionaryWithObject:[line substringWithRange:urlRange] forKey:JHLinkURL]];
    [self.delegate processText:[self _parseLine:[line substringWithRange:nameRange]]];
    [self.delegate didEndElement:JHLinkElement info:nil];
    
    return range.location + range.length - 1;
};

- (NSString *)_parseLine:(NSString *)line
{
    NSLog(@"line: %@",line);
    NSMutableString* text = [NSMutableString string];
    NSUInteger length = [line length];
    char const* lineString = [line UTF8String];
    NSUInteger c = 0;
    BOOL hasRawText = NO;
    
    // Consume all leading whitespace
    int indent = 0;
    int spaces = 0;
    while (c < length && (lineString[c] == '\t' || lineString[c] == ' ')) {
        if (lineString[c] == '\t') {
            spaces += 4;
            indent += 1;
        }
        else {
            spaces += 1;
            if (spaces % 4 == 0) {
                indent += 1;
            }
        }
        
        ++c;
    }
    
    // test for empty line and insert paragraph tags as appropriate
    if (length == 0 || c == length) {
        _ignoreHardBreak = YES;
        BOOL inList = [_listDepthStack count] > 0;
        _ListState* currentList = inList ? [_listDepthStack lastObject] : nil;
        if (_paragraphDepth > 0 && (!inList || currentList.paragraphsInList > 0)) {
            [self.delegate didEndElement:JHParagraphElement info:nil];
            --_paragraphDepth;
            if (currentList.paragraphsInList > 0) {
                --currentList.paragraphsInList;
            }
        }
        
        [self.delegate didBeginElement:JHParagraphElement info:nil];
        _previousLineEmpty = YES;
        ++_paragraphDepth;
        if (inList) {
            ++currentList.paragraphsInList;
        }
        
        return text;
    }
    
    if (IsHorizontalRule(lineString, length)) {
        [self _unrollListStack:[_listDepthStack count]];
        [self.delegate didParseHorizontalRule];
        _ignoreHardBreak = YES;
    }
    else {
        NSUInteger startIndex = c;
        for (; c < length; ++c) {
            unichar character = lineString[c];            
            if (c == startIndex) {
                // check ordered lists
                NSUInteger orderedListSymbolLength = 0;
                if (StartsWithOrderedList(line, c, &orderedListSymbolLength)) {
                    [self _processListItem:JHOrderedListElement indent:indent];
                    c += orderedListSymbolLength - 1;
                }
                // check unordered list
                else if (character == '*') {
                    [self _processListItem:JHUnorderedListElement indent:indent];
                    c += 1;
                }
                else if ([_listDepthStack count]) {
                    _ListState* currentList = [_listDepthStack lastObject];
                    if (indent <= currentList.indent) {
                        // Reached a line that doesn't start with a list element with the right indent,
                        // so the list(s) must be done
                        [self _unrollListStack:(currentList.indent - indent) + 1];
                    }
                    else if (!_previousLineEmpty) {
                        [self.delegate didBeginElement:JHHardlineBreakElement info:nil];
                    }
                }
            }

            JHElement element = JHNullElement;
            switch (character) {
                case '_': element = JHEmphasizeElement;     break;
                case '~': element = JHStrongElement;        break;
                case '#': element = JHHeaderElement;        break;
                case '`': element = JHInlineCodeElement;    break;
                case '[': element = JHLinkElement;          break;
                default:                                    break;
            }
            
            BOOL falseOrNullElement = (element == JHNullElement);
            if (!falseOrNullElement) {
                if (element == JHHeaderElement) {
                    [self _consumeHeader:[line substringFromIndex:c]];
                    c = length;
                    _ignoreHardBreak = YES;
                }
                else if (element == JHLinkElement) {
                    NSUInteger linkLength = [self _consumeLink:[line substringFromIndex:c] previousText:&text];
                    if (linkLength > 0) {
                        c += linkLength;
                    }
                    
                    falseOrNullElement = (linkLength == 0);
                }
                else {
                    JHElement top = [[_symbolStack lastObject] intValue];
                    if (top != element) {
                        [self.delegate processText:[text copy]];
                        [text setString:@""];
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
            
            if (falseOrNullElement) {
                [text appendFormat:@"%c", lineString[c], nil];
                hasRawText = YES;
            }   
        }
        
        _oldIndent = indent;
    }
    
    if (_previousLineEmpty || !hasRawText) {
        _ignoreHardBreak = YES;
    }
    
    _previousLineEmpty = NO;
    return text;
}

- (void)parseJAML:(NSString *)markdownText
{
    [self _resetState];
    NSMutableString* text = [NSMutableString string];    
    for (NSString* line in [markdownText componentsSeparatedByString:@"\n"]) {
        [text appendString:[self _parseLine:line]];
        NSLog(@"[out]processing text: %@", text);
        [self.delegate processText:[text copy]];
        [text appendString:@"\n"];
        if (!_ignoreHardBreak) {
            [self.delegate didBeginElement:JHHardlineBreakElement info:nil];
        }
        _ignoreHardBreak = NO;
        
        [text setString:@""];
    }
    
    // Unwind remaining state
    [self _unrollListStack:[_listDepthStack count]];
    while (_paragraphDepth) {
        [self.delegate didEndElement:JHParagraphElement info:nil];
        --_paragraphDepth;
    }
}
@end