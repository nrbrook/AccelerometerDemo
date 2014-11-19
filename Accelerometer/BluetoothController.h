//
//  BluetoothController.h
//  Accelerometer
//
//  Created by Nick Brook on 19/11/2014.
//  Copyright (c) 2014 NickBrook. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol BluetoothControllerDelegate <NSObject>
@required
- (void)newData:(NSData *)data;

@end

@interface BluetoothController : NSObject

@property(nonatomic, weak) id<BluetoothControllerDelegate> delegate;

@end
