//
//  JHMulticastDelegate.h
//  jaml-parser
//
//  Created by Jedd Haberstro on 12/19/11.
//  Copyright (c) 2011 Student. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JHMulticastDelegate : NSObject

- (id)initWithProtocol:(Protocol *)protocol;

- (void)addDelegate:(id)delegate;

- (void)removeDelegate:(id)delegate;

@end
