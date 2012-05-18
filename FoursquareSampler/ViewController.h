//
//  ViewController.h
//  FoursquareSampler
//
//  Created by Daniel Shein on 5/16/12.
//  Copyright (c) 2012 LoFT. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FoursquareManager.h"

@interface ViewController : UIViewController <FoursquareManagerDelegate>
{
    CLLocation *location;
    FoursquareManager *fm;
}

@end
