//
//  JHMulticastDelegate.m
//  jaml-parser
//
//  Created by Jedd Haberstro on 12/19/11.
//  Copyright (c) 2011 Student. All rights reserved.
//

#import "JHMulticastDelegate.h"

@interface JHMulticastDelegate ()
@property (strong) NSMutableArray* delegates;
@property (assign) Protocol* protocol;
@end

@implementation JHMulticastDelegate

@synthesize delegates = _delegates;
@synthesize protocol = _protocol;

- (id)initWithProtocol:(Protocol *)protocol
{
    if (self = [super init]) {
        self.delegates = [NSMutableArray array];
        self.protocol = protocol;
    }
    
    return self;
}

- (void)addDelegate:(id)delegate
{
    NSAssert([delegate conformsToProtocol:self.protocol], @"Object does not respond to protocol");
    [self.delegates addObject:delegate];
}

- (void)removeDelegate:(id)delegate
{
    [self.delegates removeObject:delegate];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
    if (self.delegates.count) {
        return [[self.delegates objectAtIndex:0] methodSignatureForSelector:sel];
    }
    
    return nil;
}

- (void)forwardInvocation:(NSInvocation *)inv
{
    for(id obj in self.delegates) {
        [inv invokeWithTarget:obj];
    }
}


@end
