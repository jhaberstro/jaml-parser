//
//  JHJAMLParser.m
//  markdown-parser
//
//  Created by Jedd Haberstro on 12/8/11.
//  Copyright (c) 2011 Student. All rights reserved.
//

// TODO - escape characters (\#, \*, \~, \_) 

#import "JHJAMLParser.h"

#define JHInlineCode @"JHInlineCode"
#define JHLinkName   @"JHLinkName"
#define JHText       @"JHText"

enum {
    JHNullToken,
    JHEmphasizeToken = 1,
    JHStrongToken = 2,
    JHInlineCodeToken = 3,
    JHTextToken,
    JHIndentToken,
    JHEmptyLineToken,
    JHNewLineToken,
    JHOrderedListToken,
    JHUnorderedListToken,
    JHHeaderBeginToken,
    JHHeaderEndToken,
    JHLinkToken,
    JHHorizontalRuleToken,
    
    JHParagraphBeginToken,
    JHParagraphEndToken,
    JHOrderedListBeginToken,
    JHOrderedListEndToken,
    JHUnorderedListBeginToken,
    JHUnorderedListEndToken,
    JHHardlineBreakToken
};

typedef NSUInteger JHJAMLTokenType;

@interface JHJAMLToken : NSObject
- (id)initWithType:(JHJAMLTokenType)type;
@property (nonatomic, assign) JHJAMLTokenType type;
@property (nonatomic, strong) NSDictionary* info;
@end

@implementation JHJAMLToken
@synthesize type = _type;
@synthesize info = _info;

- (id)initWithType:(JHJAMLTokenType)type
{
    self = [super init];
    if (self) {
        self.type = type;
    }
    
    return self;
}

- (NSString *)description
{
    switch (self.type) {
        case JHTextToken:
            return [NSString stringWithFormat:@"JHTextToken : %@", [self.info objectForKey:JHText], nil];
        case JHIndentToken:
            return @"JHIndentToken";
        case JHEmptyLineToken:
            return @"JHEmptyLineToken";
        case JHNewLineToken:
            return @"JHNewLineToken";
        case JHEmphasizeToken:
            return @"JHEmphasizeToken";
        case JHStrongToken:
            return @"JHStrongToken";
        case JHOrderedListToken:
            return @"JHOrderedListToken";
        case JHUnorderedListToken:
            return @"JHUnorderedListToken";
        case JHHeaderBeginToken:
            return @"JHHeaderBeginToken";
        case JHHeaderEndToken:
            return @"JHHeaderEndToken";
        case JHInlineCodeToken:
            return [NSString stringWithFormat:@"JHInlineCodeToken : %@", [self.info objectForKey:JHInlineCode], nil];
        case JHLinkToken:
            return [NSString stringWithFormat:@"JHLinkToken : [name %@] : [url %@]", [self.info objectForKey:JHLinkName], [self.info objectForKey:JHLinkURL], nil];
        case JHHorizontalRuleToken:
            return @"JHHorizontalRuleToken";
            
        case JHOrderedListBeginToken:
            return @"JHOrderedListBeginToken";
        case JHOrderedListEndToken:
            return @"JHOrderedListEndToken";
        case JHUnorderedListBeginToken:
            return @"JHUnorderedListBeginToken";
        case JHUnorderedListEndToken:
            return @"JHUnorderedListEndToken";
        case JHParagraphBeginToken:
            return @"JHParagraphBeginToken";
        case JHParagraphEndToken:
            return @"JHParagraphEndToken";
        case JHHardlineBreakToken:
            return @"JHHardlineBreakToken";
    }
    
    
    assert(false);
    return nil;
}

@end

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
- (NSArray *)_tokenize:(NSString *)jamlText;
- (NSArray *)_annotateTokens:(NSArray *)tokens;
@end

@implementation JHJAMLParser

@synthesize delegate = _delegate;

- (id)init
{
    if ((self = [super init])) {
    }
    
    return self;
}

- (NSArray *)_tokenize:(NSString *)jamlText
{
    NSMutableArray* tokens = [[NSMutableArray alloc] init];
    for (NSString* line in [jamlText componentsSeparatedByString:@"\n"]) {
        NSMutableString* text = [[NSMutableString alloc] init];
        NSUInteger length = [line length];
        char const* lineString = [line UTF8String];
        NSUInteger c = 0;
        NSUInteger orderedListNumberLength = 0;
        BOOL isHeader = NO;
        void (^submitTextToken)(void) = ^{
            if ([text length] > 0) {
                JHJAMLToken* token = [[JHJAMLToken alloc] initWithType:JHTextToken];
                token.info = [NSDictionary dictionaryWithObject:[text copy] forKey:JHText];
                [tokens addObject:token];
                [text setString:@""];
            }
        };
        
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
        
        if (length == 0 || c == length) {
            [tokens addObject:[[JHJAMLToken alloc] initWithType:JHEmptyLineToken]];
            goto END_OF_LINE;
        }
        
        if (IsHorizontalRule(lineString, length)) {
            [tokens addObject:[[JHJAMLToken alloc] initWithType:JHHorizontalRuleToken]];
            goto END_OF_LINE;
        }
        
        for (int i = 0; i < indent; ++i) {
            [tokens addObject:[[JHJAMLToken alloc] initWithType:JHIndentToken]];
        }
        
        int headerStrength = 0;
        if (lineString[c] == '#') {
            while (lineString[c] == '#') {
                headerStrength += 1;
                c += 1;
            }
            
            JHJAMLToken* token = [[JHJAMLToken alloc] initWithType:JHHeaderBeginToken];
            token.info = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:headerStrength] forKey:JHHeaderStrength];
            [tokens addObject:token];
            isHeader = YES;
        }
        else if (lineString[c] == '*') {
            [tokens addObject:[[JHJAMLToken alloc] initWithType:JHUnorderedListToken]];
            c += 1;
        }
        else if (StartsWithOrderedList(line, c, &orderedListNumberLength)) {
            [tokens addObject:[[JHJAMLToken alloc] initWithType:JHOrderedListToken]];
            c += orderedListNumberLength - 1;
        }
        
        for (; c < length; ++c) {
            switch (lineString[c]) {
                case '_':
                    submitTextToken();
                    [tokens addObject:[[JHJAMLToken alloc] initWithType:JHEmphasizeToken]];
                    continue;
                case '~':
                    submitTextToken();
                    [tokens addObject:[[JHJAMLToken alloc] initWithType:JHStrongToken]];
                    continue;
                case '`': {
                    NSUInteger start = c + 1;
                    NSUInteger offset = 0;
                    while (lineString[start + offset] != '`' && (start + offset) < length) {
                        offset += 1;
                    }
                    
                    if (lineString[start + offset] == '`') {
                        submitTextToken();
                        NSString* inlineCodeContents = [line substringWithRange:NSMakeRange(start, offset)];
                        JHJAMLToken* token = [[JHJAMLToken alloc] initWithType:JHInlineCodeToken];
                        token.info = [NSDictionary dictionaryWithObject:inlineCodeContents forKey:JHInlineCode];
                        [tokens addObject:token];
                        c += offset + 1;
                        continue;
                    }
                    
                    break;
                }
                case '[': {
                    NSString* startLink = [line substringFromIndex:c];
                    NSRegularExpression* regex = [[NSRegularExpression alloc] initWithPattern:@"\\[.*\\]\\(.*\\)" options:0 error:nil];
                    NSRange range = [regex rangeOfFirstMatchInString:startLink options:0 range:NSMakeRange(0, [startLink length])];
                    if (range.length == 0) {
                        break;
                    }
                    assert(range.location == 0);
                    NSRange nameRange = [[NSRegularExpression regularExpressionWithPattern:@"\\[.*\\]" options:0 error:nil] rangeOfFirstMatchInString:startLink options:0 range:NSMakeRange(0, [startLink length])];
                    if (nameRange.length <= 2) {
                        break;
                    }
                    
                    NSRange urlRange = {
                        .location = nameRange.location + nameRange.length + 1,
                        .length = range.length - (nameRange.length + 2)
                    };    
                    
                    // adjust name range to exclude brackets
                    nameRange.location += 1;
                    nameRange.length -= 2;
                    
                    submitTextToken();
                    NSString* name = [startLink substringWithRange:nameRange];
                    NSString* url  = [startLink substringWithRange:urlRange];
                    JHJAMLToken* token = [[JHJAMLToken alloc] initWithType:JHLinkToken];
                    token.info = [NSDictionary dictionaryWithObjectsAndKeys:name, JHLinkName, url, JHLinkURL, nil];
                    [tokens addObject:token];
                    c += range.length;
                    break;
                }
            }
            
            [text appendFormat:@"%c", lineString[c]];
        }
        
    END_OF_LINE:
        submitTextToken();
        if (isHeader) {
            JHJAMLToken* token = [[JHJAMLToken alloc] initWithType:JHHeaderEndToken];
            token.info = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:headerStrength] forKey:JHHeaderStrength];
            [tokens addObject:token];
        }
        [tokens addObject:[[JHJAMLToken alloc] initWithType:JHNewLineToken]];
    }
    
    return tokens;
}

- (NSArray *)_annotateTokens:(NSArray *)tokens
{
    void (^popListStack)(NSMutableArray*, NSMutableArray*, NSUInteger) = ^(NSMutableArray* listStack, NSMutableArray* lineTokens, NSUInteger count) {
        while (count > 0) {
            _ListState* endedList = [listStack lastObject];
            JHJAMLTokenType type = endedList.type == JHOrderedListToken ? JHOrderedListEndToken : JHUnorderedListEndToken;
            [listStack removeLastObject];
            [lineTokens insertObject:[[JHJAMLToken alloc] initWithType:type] atIndex:0];
            --count;
        }  
    };
    
    NSMutableArray* tokensByLine = [[NSMutableArray alloc] init];
    NSMutableArray* temporaryLine = [[NSMutableArray alloc] init];
    for (JHJAMLToken* token in tokens) {
        if (token.type == JHNewLineToken) {
            [tokensByLine addObject:[temporaryLine mutableCopy]];
            [temporaryLine removeAllObjects];
        }
        else {
            [temporaryLine addObject:token];
        }
    }

    int indents[[tokensByLine count]];
    for (NSUInteger line = 0; line < [tokensByLine count]; ++line) {
        NSMutableArray* lineTokens = [tokensByLine objectAtIndex:line];
        int indent = 0;
        for (int i = 0; i < [lineTokens count]; ++i) {
            JHJAMLToken* token = [lineTokens objectAtIndex:i];
            if (token.type == JHIndentToken) {
                indent += 1;
            }
            else {
                indents[line] = indent;
                break;
            }
        }
    }
    
    // insert list begin/end tokens
    NSMutableArray* listStack = [NSMutableArray array];
    for (NSUInteger line = 0; line < [tokensByLine count]; ++line) {
        NSMutableArray* lineTokens = [tokensByLine objectAtIndex:line];
        int indent = indents[line];
        JHJAMLToken* firstToken = [lineTokens objectAtIndex:indent];
        //NSLog(@"line: %@", lineTokens);
        //NSLog(@"firstToken: %@", [firstToken description]);
        BOOL isList = firstToken.type == JHOrderedListToken || firstToken.type == JHUnorderedListToken;
        if (isList) {
            // If (there exists no other current lists) or (there exists a list and the indent is greater than that list's indent)
            // then we have a new list
            if ((indent == 0 && [listStack count] == 0) || ([listStack count] > 0 && indent > [[listStack lastObject] indent])) {
                JHJAMLTokenType type = firstToken.type == JHOrderedListToken ? JHOrderedListBeginToken : JHUnorderedListBeginToken;
                [lineTokens insertObject:[[JHJAMLToken alloc] initWithType:type] atIndex:indent];
                _ListState* list = [[_ListState alloc] init];
                list.type = firstToken.type;
                list.indent = indent;
                [listStack addObject:list];
            }
            // if (the current list is nested) and (the indent is less than that list's indent)
            // then the nested list ended
            else if ([listStack count] > 1 && indent < [[listStack lastObject] indent]) {
                int endCount = [[listStack lastObject] indent] - indent;
                popListStack(listStack, lineTokens, endCount);               
            }
        }
        else if ((firstToken.type != JHEmptyLineToken && [listStack count] > 0)) {
            _ListState* endedList = [listStack lastObject];
            if (indent <= endedList.indent) {
                NSUInteger previousLine = line - 1;
                while ([(JHJAMLToken *)[[tokensByLine objectAtIndex:previousLine] objectAtIndex:0] type] == JHEmptyLineToken) {
                    --previousLine;
                }
                
                previousLine += 1;
                int endCount = ([[listStack lastObject] indent] - indent) + 1;
                popListStack(listStack, [tokensByLine objectAtIndex:previousLine], endCount);                             
            }            
        }     
    }
    
    // insert paragraph symbols, and check for horizontal rule
    // TODO - merge with pass above
    int listDepth = 0;
    for (NSUInteger line = 0; line < [tokensByLine count]; ++line) {
        BOOL skipBreakLine = NO;
        NSMutableArray* lineTokens = [tokensByLine objectAtIndex:line];
        JHJAMLToken* firstToken = [lineTokens objectAtIndex:0];
        int previousLine = (int)line - 1;
        if (previousLine == -1) {
            [lineTokens insertObject:[[JHJAMLToken alloc] initWithType:JHParagraphBeginToken] atIndex:0];
        }
        
        if (firstToken.type == JHHorizontalRuleToken || firstToken.type == JHHeaderBeginToken) {
            skipBreakLine = YES;
        }
        
        for (NSUInteger tokenIndex = 0; tokenIndex < [lineTokens count]; ++tokenIndex) {
            JHJAMLToken* token = [lineTokens objectAtIndex:tokenIndex];
            switch (token.type) {
                case JHOrderedListBeginToken:
                case JHUnorderedListBeginToken:
                    listDepth += 1;
                    break;
                    
                case JHOrderedListEndToken:
                case JHUnorderedListEndToken:
                    listDepth -= 1;
                    break;
                    
                case JHEmptyLineToken: {
                    if (previousLine >= 0) {
                        if (listDepth == 0) {
                            JHJAMLToken* previousLineToken = [[tokensByLine objectAtIndex:previousLine] objectAtIndex:indents[previousLine]];
                            if (previousLineToken.type != JHParagraphEndToken && previousLineToken.type != JHEmptyLineToken) {
                                token.type = JHParagraphEndToken;
                                [lineTokens insertObject:[[JHJAMLToken alloc] initWithType:JHParagraphBeginToken] atIndex:tokenIndex + 1];
                                skipBreakLine = YES;
                            }
                        }
                    }
                    
                    break;
                }
            }
            
            tokenIndex += 1;
        }
        
        if (!skipBreakLine) {
            [lineTokens addObject:[[JHJAMLToken alloc] initWithType:JHHardlineBreakToken]];
        }
    }
    
    NSMutableArray* lineForEndTokens = [[NSMutableArray alloc] init];
    popListStack(listStack, lineForEndTokens, [listStack count]);
    [tokensByLine addObject:[[lineForEndTokens reverseObjectEnumerator] allObjects]];
    
    NSMutableArray* merged = [[NSMutableArray alloc] init];
    for (NSMutableArray* lineTokens in tokensByLine) {
        [merged addObjectsFromArray:lineTokens];
    }
    
    [merged addObject:[[JHJAMLToken alloc] initWithType:JHParagraphEndToken]];
    return merged;
}

- (void)parseJAML:(NSString *)markdownText
{
    NSArray* tokens = [self _annotateTokens:[self _tokenize:markdownText]];
    int tokenIndex = 0;
    NSMutableArray* symbolStack = [[NSMutableArray alloc] init]; 
    for (JHJAMLToken* token in tokens) {
        switch (token.type) {
            case JHTextToken:
                [self.delegate processText:[token.info objectForKey:JHText]];
                break;
                
            case JHStrongToken:
            case JHEmphasizeToken: {
                if ([symbolStack count] && [[symbolStack lastObject] unsignedIntegerValue] == token.type) {
                    [self.delegate didEndElement:token.type info:nil];
                    [symbolStack removeLastObject];
                }
                else {
                    [symbolStack addObject:[NSNumber numberWithUnsignedInteger:token.type]];
                    [self.delegate didBeginElement:token.type info:nil];
                }
                break;
            }
                
            case JHInlineCodeToken: {
                NSString* inlineCode = [token.info objectForKey:JHInlineCode];
                [self.delegate didBeginElement:JHInlineCodeElement info:nil];
                [self.delegate processText:inlineCode];
                [self.delegate didEndElement:JHInlineCodeElement info:nil];
                break;
            }
                
            case JHParagraphBeginToken:
                [self.delegate didBeginElement:JHParagraphElement info:nil];
                break;
                
            case JHParagraphEndToken:
                [self.delegate didEndElement:JHParagraphEndToken info:nil];
                break;
                
            case JHOrderedListBeginToken:
                [self.delegate didBeginElement:JHOrderedListElement info:nil];
                break;
                
            case JHOrderedListEndToken:
                [self.delegate didEndElement:JHOrderedListElement info:nil];
                break;
                
            case JHUnorderedListBeginToken:
                [self.delegate didBeginElement:JHUnorderedListElement info:nil];
                break;
                
            case JHUnorderedListEndToken:
                [self.delegate didEndElement:JHUnorderedListElement info:nil];
                break;
                
            case JHOrderedListToken:
            case JHUnorderedListToken: {
                JHJAMLTokenType previousToken = [(JHJAMLToken *)[tokens objectAtIndex:(tokenIndex - 1)] type];
                if (previousToken != JHOrderedListBeginToken && previousToken != JHUnorderedListBeginToken) {
                    [self.delegate didEndElement:JHListItemElement info:nil];
                }
                
                [self.delegate didBeginElement:JHListItemElement info:nil];
                break;
            }
                
            case JHHeaderBeginToken: {
                NSNumber* strength = [token.info objectForKey:JHHeaderStrength];
                [self.delegate didBeginElement:JHHeaderElement info:[NSDictionary dictionaryWithObject:strength forKey:JHHeaderStrength]];
                break;
            }
                
            case JHHeaderEndToken: {
                NSNumber* strength = [token.info objectForKey:JHHeaderStrength];
                [self.delegate didEndElement:JHHeaderElement info:[NSDictionary dictionaryWithObject:strength forKey:JHHeaderStrength]];
                break;
            }
                
            case JHHorizontalRuleToken:
                [self.delegate didParseHorizontalRule];
                break;
                
            case JHHardlineBreakToken:
                [self.delegate didBeginElement:JHHardlineBreakElement info:nil];
                break;
                
            case JHLinkToken: {
                NSString* url = [token.info objectForKey:JHLinkURL];
                NSString* name = [token.info objectForKey:JHLinkName];
                [self.delegate didBeginElement:JHLinkElement info:[NSDictionary dictionaryWithObject:url forKey:JHLinkURL]];
                [self.delegate processText:name];
                [self.delegate didEndElement:JHLinkElement info:nil];
                break;
            }
        }
        
        tokenIndex += 1;
        
        printf("{%s} ", [[token description] UTF8String]);
        if (token.type == JHHardlineBreakToken || token.type == JHParagraphBeginToken || token.type == JHParagraphEndToken) {
            printf("\n");
        }
    }
}
@end