//
//  ViewController.m
//  Accelerometer
//
//  Created by Nick Brook on 19/11/2014.
//  Copyright (c) 2014 NickBrook. All rights reserved.
//

#import "ViewController.h"
#import "BEMSimpleLineGraphView.h"
#import <CoreBluetooth/CoreBluetooth.h>

@interface ViewController () <BEMSimpleLineGraphDataSource, CBCentralManagerDelegate, CBPeripheralDelegate>
@property (strong, nonatomic) IBOutletCollection(BEMSimpleLineGraphView) NSArray *graphs;

@property(nonatomic, strong) CBCentralManager *manager;
@property(nonatomic, strong) CBPeripheral *peripheral;

@property(nonatomic, strong) NSArray *points;

@property(nonatomic, strong) NSArray *services;
@property(nonatomic, strong) NSArray *characteristics;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    for(BEMSimpleLineGraphView *g in self.graphs) {
        g.colorLine = [UIColor whiteColor];
        g.colorXaxisLabel = [UIColor whiteColor];
        g.colorYaxisLabel = [UIColor whiteColor];
        g.dataSource = self;
        g.animationGraphStyle = BEMLineAnimationNone;
        g.graphValuesForXAxis
    }
    
#define DATA_POINTS 50
    
    self.points = @[
                    [NSMutableArray arrayWithCapacity:DATA_POINTS],
                    [NSMutableArray arrayWithCapacity:DATA_POINTS],
                    [NSMutableArray arrayWithCapacity:DATA_POINTS]
                    ];
    
    for(int i = 0; i < 3; i++) {
        for(int j = 0; j < DATA_POINTS; j++) {
            [self.points[i] addObject:@(0)];
        }
    }
    
    self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    
    self.services = @[[CBUUID UUIDWithString:@"6d480f49-91d3-4a18-be29-0d27f4109c23"]];
    self.characteristics = @[[CBUUID UUIDWithString:@"11c3876c-9bda-42cc-a30b-1be83c8059d3"]];
}

// bluetooth

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

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"%@",error);
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"Connected");
    peripheral.delegate = self;
    [peripheral discoverServices:self.services];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    NSLog(@"Discovered services %@", peripheral.services);
    NSLog(@"%@",error);
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
    static int counter = 0;
    static BOOL reachedEnd = NO;
    int16_t newPoints[3];
    [characteristic.value getBytes:newPoints length:6];
    for(int i = 0; i<3; i++) {
        if(reachedEnd) {
            [self.points[i] removeObjectAtIndex:0];
        }
        [self.points[i] insertObject:@(newPoints[i]) atIndex:counter];
        [self.graphs[i] reloadGraph];
    }
    if(!reachedEnd) {
        if(counter == DATA_POINTS - 1) {
            reachedEnd = YES;
        } else {
            counter++;
        }
    }
}


// provide graph data

- (NSInteger)numberOfPointsInLineGraph:(BEMSimpleLineGraphView *)graph {
    return DATA_POINTS;
}

- (CGFloat)lineGraph:(BEMSimpleLineGraphView *)graph valueForPointAtIndex:(NSInteger)index {
    NSInteger indexOfGraph = [self.graphs indexOfObject:graph];
    NSMutableArray *pointsArray = self.points[indexOfGraph];
    return [pointsArray[index] floatValue];
}

@end
