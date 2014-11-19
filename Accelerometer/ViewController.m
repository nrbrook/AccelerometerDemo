//
//  ViewController.m
//  Accelerometer
//
//  Created by Nick Brook on 19/11/2014.
//  Copyright (c) 2014 NickBrook. All rights reserved.
//

#import "ViewController.h"
#import "CorePlot-CocoaTouch.h"
#import <CoreBluetooth/CoreBluetooth.h>

#define DATA_SCALE_FACTOR 0.00007

static const double kFrameRate = 15.0;  // frames per second

static const NSUInteger kMaxDataPoints = 50;
static NSString *const kPlotIdentifier = @"Data Source Plot";

@interface ViewController () <CPTPlotDataSource, CBCentralManagerDelegate, CBPeripheralDelegate>
@property (strong, nonatomic) IBOutletCollection(CPTGraphHostingView) NSArray *graphs;

@property(nonatomic, strong) CBCentralManager *manager;
@property(nonatomic, strong) CBPeripheral *peripheral;

@property(nonatomic, strong) NSArray *points;

@property(nonatomic, strong) NSArray *services;
@property(nonatomic, strong) NSArray *characteristics;

@property(nonatomic, assign) NSUInteger currentIndex;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self setupGraphs];
    
    self.currentIndex = 0;
    
    self.points = @[
                    [NSMutableArray arrayWithCapacity:kMaxDataPoints],
                    [NSMutableArray arrayWithCapacity:kMaxDataPoints],
                    [NSMutableArray arrayWithCapacity:kMaxDataPoints]
                    ];
    
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
    static BOOL reachedEnd = NO;
    int16_t newPoints[3];
    [characteristic.value getBytes:newPoints length:6];
    NSMutableArray *plots = [NSMutableArray arrayWithCapacity:3];
    for(int i = 0; i<3; i++) {
        CPTGraph *g = [self.graphs[i] hostedGraph];
        CPTPlot *plot = [g plotWithIdentifier:kPlotIdentifier];
        
        if(reachedEnd) {
            [self.points[i] removeObjectAtIndex:0];
            [plot deleteDataInIndexRange:NSMakeRange(0, 1)];
            CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)g.defaultPlotSpace;
            NSUInteger location       = (self.currentIndex >= kMaxDataPoints ? self.currentIndex - kMaxDataPoints + 2 : 0);
            
            CPTPlotRange *oldRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromUnsignedInteger( (location > 0) ? (location - 1) : 0 )
                                                                  length:CPTDecimalFromUnsignedInteger(kMaxDataPoints - 2)];
            CPTPlotRange *newRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromUnsignedInteger(location)
                                                                  length:CPTDecimalFromUnsignedInteger(kMaxDataPoints - 2)];
            
            [CPTAnimation animate:plotSpace
                         property:@"xRange"
                    fromPlotRange:oldRange
                      toPlotRange:newRange
                         duration:CPTFloat(1.0 / kFrameRate)];
        }
        
        [self.points[i] addObject:@(newPoints[i] * DATA_SCALE_FACTOR)];
        
        plots[i] = plot;
    }
    if(!reachedEnd) {
        if(self.currentIndex == kMaxDataPoints - 1) {
            reachedEnd = YES;
        }
    }
    self.currentIndex++;
    NSInteger c = [self.points[0] count] - 1;
    for(CPTPlot *p in plots) {
        [p insertDataAtIndex:c numberOfRecords:1];
    }
}

-(id)numberForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index
{
    NSNumber *num = nil;
    NSInteger graphIndex = [self.graphs indexOfObject:plot.graph.hostingView];
    if(graphIndex == NSNotFound) return nil;
    
    switch ( fieldEnum ) {
        case CPTScatterPlotFieldX:
            num = @(index + self.currentIndex - [self.points[graphIndex] count]);
            break;
            
        case CPTScatterPlotFieldY:
            num = [self.points[graphIndex] objectAtIndex:index];
            break;
            
        default:
            break;
    }
    
    return num;
}

- (NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot {
    return [self.points[0] count];
}


- (void)setupGraphs {
    for(CPTGraphHostingView *g in self.graphs) {
        CPTGraph *graph = [[CPTXYGraph alloc] initWithFrame:g.bounds];
        g.hostedGraph = graph;
        
        
        graph.plotAreaFrame.paddingTop    = 0;
        graph.plotAreaFrame.paddingRight  = 15.0;
        graph.plotAreaFrame.paddingBottom = 0;
        graph.plotAreaFrame.paddingLeft   = 55.0;
        graph.plotAreaFrame.masksToBorder = NO;
        
        // Grid line styles
        CPTMutableLineStyle *majorGridLineStyle = [CPTMutableLineStyle lineStyle];
        majorGridLineStyle.lineWidth = 0.75;
        majorGridLineStyle.lineColor = [[CPTColor colorWithGenericGray:CPTFloat(0.2)] colorWithAlphaComponent:CPTFloat(0.75)];
        
        CPTMutableLineStyle *minorGridLineStyle = [CPTMutableLineStyle lineStyle];
        minorGridLineStyle.lineWidth = 0.25;
        minorGridLineStyle.lineColor = [[CPTColor whiteColor] colorWithAlphaComponent:CPTFloat(0.1)];
        
        // Axes
        // X axis
        CPTXYAxisSet *axisSet = (CPTXYAxisSet *)graph.axisSet;
        CPTXYAxis *x          = axisSet.xAxis;
        x.labelingPolicy              = CPTAxisLabelingPolicyAutomatic;
        x.orthogonalCoordinateDecimal = CPTDecimalFromUnsignedInteger(0);
        x.majorGridLineStyle          = majorGridLineStyle;
        x.minorGridLineStyle          = minorGridLineStyle;
        x.minorTicksPerInterval       = 9;
        x.title                       = @"Time";
        x.titleOffset                 = 15 + g.bounds.size.height/2;
        NSNumberFormatter *labelFormatter = [[NSNumberFormatter alloc] init];
        labelFormatter.numberStyle = NSNumberFormatterNoStyle;
        x.labelFormatter           = labelFormatter;
        
        // Y axis
        CPTXYAxis *y = axisSet.yAxis;
        y.labelingPolicy              = CPTAxisLabelingPolicyAutomatic;
        y.orthogonalCoordinateDecimal = CPTDecimalFromUnsignedInteger(0);
        y.majorGridLineStyle          = majorGridLineStyle;
        y.minorGridLineStyle          = minorGridLineStyle;
        y.minorTicksPerInterval       = 3;
        y.labelOffset                 = 5.0;
        y.title                       = @"Acceleration";
        y.titleOffset                 = 30.0;
        y.axisConstraints             = [CPTConstraints constraintWithLowerOffset:0.0];
        
        // Rotate the labels by 45 degrees, just to show it can be done.
        x.labelRotation = CPTFloat(M_PI_4);
        
        // Create the plot
        CPTScatterPlot *dataSourceLinePlot = [[CPTScatterPlot alloc] init];
        dataSourceLinePlot.identifier     = kPlotIdentifier;
        dataSourceLinePlot.cachePrecision = CPTPlotCachePrecisionDouble;
        
        CPTMutableLineStyle *lineStyle = [dataSourceLinePlot.dataLineStyle mutableCopy];
        lineStyle.lineWidth              = 3.0;
        lineStyle.lineColor              = [CPTColor blueColor];
        dataSourceLinePlot.dataLineStyle = lineStyle;
        
        dataSourceLinePlot.dataSource = self;
        [graph addPlot:dataSourceLinePlot];
        
        // Plot space
        CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
        plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromUnsignedInteger(0) length:CPTDecimalFromUnsignedInteger(kMaxDataPoints - 2)];
        plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromInt(-2) length:CPTDecimalFromUnsignedInteger(4)];
    }
}

@end
