//
//  BluetoothController.m
//  Accelerometer
//
//  Created by Nick Brook on 19/11/2014.
//  Copyright (c) 2014 NickBrook. All rights reserved.
//

#import "BluetoothController.h"
#import <CoreBluetooth/CoreBluetooth.h>

@interface BluetoothController() <CBCentralManagerDelegate, CBPeripheralDelegate>

@property(nonatomic, strong) CBCentralManager *manager;
@property(nonatomic, strong) CBPeripheral *peripheral;

@property(nonatomic, strong) NSArray *services;
@property(nonatomic, strong) NSArray *characteristics;

@end

@implementation BluetoothController

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        
        self.services = @[[CBUUID UUIDWithString:@"6d480f49-91d3-4a18-be29-0d27f4109c23"]];
        self.characteristics = @[[CBUUID UUIDWithString:@"11c3876c-9bda-42cc-a30b-1be83c8059d3"]];
    }
    return self;
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if(central.state == CBCentralManagerStatePoweredOn) {
        [self.manager scanForPeripheralsWithServices:self.services options:nil];
        NSLog(@"Scanning");
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    NSLog(@"Discovered device");
    self.peripheral = peripheral;
    [self.manager connectPeripheral:peripheral options:nil];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Connected");
    peripheral.delegate = self;
    [peripheral discoverServices:self.services];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    NSLog(@"Discovered services %@", peripheral.services);
    for(CBService *s in peripheral.services) {
        if([s.UUID isEqual:self.services[0]]) {
            [self.peripheral discoverCharacteristics:self.characteristics forService:s];
        }
    }
    
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    NSLog(@"Discovered characteristics");
    CBCharacteristic *dataChar = service.characteristics[0];
    [self.peripheral setNotifyValue:YES forCharacteristic:dataChar];
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    [self.delegate newData:characteristic.value];
}

@end
