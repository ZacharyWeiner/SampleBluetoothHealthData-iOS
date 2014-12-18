//
//  LGViewController.m
//  LGBluetoothExample
//
//  Created by David Sahakyan on 2/7/14.
//  Copyright (c) 2014 David Sahakyan. All rights reserved.
//

#import "LGViewController.h"

#import "LGBluetooth.h"

@implementation LGViewController
-(void) viewWillAppear:(BOOL)animated{
    self.resultsTextView.text = self.output;
}
- (IBAction)testPressed:(UIButton *)sender
{
    self.output = @"Scanning....";
    self.resultsTextView.text = @"scanning....";
    // Scaning 4 seconds for peripherals
    __block LGViewController *blockSelf = self;
    [[LGCentralManager sharedInstance] scanForPeripheralsByInterval:4
                                                         completion:^(NSArray *peripherals)
     {
         NSLog(@"Discovered:%lu Peripherals: ", peripherals.count);
         blockSelf.output = [NSString stringWithFormat:@"Discovered:%lu Peripherals: ", peripherals.count];
         // If we found any peripherals sending to test
         if (peripherals.count) {
             for (LGPeripheral *peripheral in peripherals) {
                 NSLog(@"peripheral found:%@", peripheral.name);
                 blockSelf.output = [NSString stringWithFormat:@"peripheral found:%@", peripheral.name];
                 [self updateUI];
                 [self testPeripheral:peripheral];
             }
         }
         else{
             NSLog(@"There were no peripherals found");
         }
     }];
    [self updateUI];
}

- (void)updateUI
{
    if ([NSThread isMainThread])
    {
       self.resultsTextView.text = self.output;
    }
    else
    {
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.resultsTextView.text = self.output;
        });
    }
}

- (void)testPeripheral:(LGPeripheral *)peripheral
{
    __block LGViewController *blockSelf = self;
    __block LGPeripheral *blockPeripheral = peripheral;
    // First of all connecting to peripheral
    [peripheral connectWithCompletion:^(NSError *error) {
        if(error)
        {
            NSLog(@"peripheral: %@ connection error: %@", blockPeripheral.name, error);
            blockSelf.output = [NSString stringWithFormat:@"peripheral: %@ connection error: %@", blockPeripheral.name, error];
            [blockSelf updateUI];
        }
        NSLog(@"peripheral connected: %@", peripheral.name);
        blockSelf.output = [NSString stringWithFormat:@"peripheral connected: %@", blockPeripheral.name];
        // Discovering services of peripheral
        [blockSelf updateUI];
        [blockSelf getServicesFromPeripheral:blockPeripheral andUpdateSelf:blockSelf];
    }];
}


-(void) getServicesFromPeripheral:(LGPeripheral *)peripheral andUpdateSelf:(LGViewController *) blockSelf
{
    __block LGPeripheral *blockPeripheral = peripheral;
    [blockPeripheral discoverServicesWithCompletion:^(NSArray *services, NSError *error)
     {
         if(services.count == 0)
         {
             NSLog(@"no services detected for %@", blockPeripheral.name);
             blockSelf.output = [NSString stringWithFormat: @"%@ /r peripheral connected: %@", self.output, blockPeripheral.name];
             [blockSelf updateUI];
         }
         for (LGService *service in services)
         {
             [blockSelf getCharacteristicsForService:service OnPeripheral:blockPeripheral andUpdateSelf:blockSelf];
         }
     }
     ];
}

-(void) getCharacteristicsForService:(LGService *) service OnPeripheral:(LGPeripheral *)peripheral andUpdateSelf:(LGViewController *)blockSelf
{
    __block LGService *blockService = service;
    __block LGPeripheral *blockPeripheral = peripheral;
    NSLog(@"service: %@ detected for %@", service.UUIDString, blockPeripheral.name);
    self.output = [NSString stringWithFormat: @"%@ /r service: %@ detected for %@",
                   self.output,
                   blockService.UUIDString,
                   blockPeripheral.name];
    // Finding out our service
    //if ([service.UUIDString isEqualToString:@"5ec0"])
    //{
    // Discovering characteristics of our service
    dispatch_async(dispatch_get_main_queue(), ^{ self.resultsTextView.text = self.output; });
    [service discoverCharacteristicsWithCompletion:^(NSArray *characteristics, NSError *error)
     {
         // We need to count down completed operations for disconnecting
         __block int i = 0;
         if(characteristics.count ==0)
         {
             NSLog(@" no characteristics for service: %@ on peripheral %@", blockService.UUIDString, blockPeripheral.name);
             self.output = [NSString stringWithFormat: @"%@ no characteristics for service: %@ on peripheral %@", self.output, blockService.UUIDString, blockPeripheral.name];
             dispatch_async(dispatch_get_main_queue(), ^{ self.resultsTextView.text = self.output; });
         }
         
         for (LGCharacteristic *charact in characteristics)
         {
             NSLog(@"characteristic: %@ for service: %@ on peripheral %@", charact.UUIDString, blockService.UUIDString, blockPeripheral.name);
             self.output = [NSString stringWithFormat: @"%@ characteristic: %@ for service: %@ on peripheral %@", self.output, charact.UUIDString, blockService.UUIDString, blockPeripheral.name];
             // cef9 is a writabble characteristic, lets test writting
             if ([charact.UUIDString isEqualToString:@"cef9"])
             {
                 [charact writeByte:0xFF completion:^(NSError *error) {
                     if (++i == 3) {
                         // finnally disconnecting
                         NSLog(@"disconnecting from peripheral: %@", blockPeripheral.name );
                         self.output = [NSString stringWithFormat:@"disconnecting from peripheral: %@", blockPeripheral.name];
                         [blockPeripheral disconnectWithCompletion:nil];
                     }
                 }];
             } else {
                 // Other characteristics are readonly, testing read
                 [charact readValueWithBlock:^(NSData *data, NSError *error)
                  {
                      if (++i == 3)
                      {
                          // finnally disconnecting
                          NSLog(@"disconnecting from peripheral: %@", blockPeripheral.name );
                          self.output = [NSString stringWithFormat:@"disconnecting from peripheral: %@", blockPeripheral.name];
                          [blockPeripheral disconnectWithCompletion:nil];
                      }
                  }];
             }
         }
         dispatch_async(dispatch_get_main_queue(), ^{ self.resultsTextView.text = self.output; });
     }];
    //}
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    // Initialization of CentralManager
    [LGCentralManager sharedInstance];
    self.resultsTextView.text = self.output;
}

@end
