//
//  ViewController.m
//  FoursquareSampler
//
//  Created by Daniel Shein on 5/16/12.
//  Copyright (c) 2012 LoFT. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    location = [[CLLocation alloc] initWithLatitude:40.7 longitude:-74];
    
    fm = [[FoursquareManager alloc] initWithClientId:@"[CLIENT_ID]" andSecrect:@"[CLIENT_SECRET]"];
    fm.delegate = self;
    [fm requestCategoryForString:@"Restaurant"];
}

-(void)didFailRequestWithError:(NSError*)_error
{
    NSLog(@"Error: %@", _error);
}


-(void)receivedCategoryId:(NSString*)_id forName:(NSString*)_name
{
    [fm requestVenuesNearLocation:location byCategory:_id];
}

-(void)receivedVenues:(NSDictionary*)_venues
{
    for (NSDictionary *venue in _venues){
        [fm requestMenuForVenueById:[venue objectForKey:@"id"]];
        break;
    }
}

-(void)receivedMenu:(NSArray*)menu forVenue:(NSDictionary*)_venue
{
    for (NSDictionary *menuItem in menu){
        NSLog(@"%@ is %@", [menuItem objectForKey:@"name"], [[menuItem objectForKey:@"prices"] objectAtIndex:0]);
    }
}

@end
