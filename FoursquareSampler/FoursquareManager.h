//
//  FoursquareManager.h
//  FoursquareSampler
//
//  Created by Daniel Shein on 5/16/12.
//  Copyright (c) 2012 LoFT. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import <Foundation/Foundation.h>


enum {
    FSErrorGettingCategory,
    FSErrorGettingVenues,
    FSErrorGettingMenus,
    FSErrorConnection
};

@protocol FoursquareManagerDelegate <NSObject>

-(void)didFailRequestWithError:(NSError*)_error;

@optional
-(void)receivedCategoryId:(NSString*)_id forName:(NSString*)_name;

// Category is nil if no category filter was used
-(void)receivedVenues:(NSDictionary*)_venues;
-(void)receivedMenu:(NSArray*)menu forVenue:(NSDictionary*)_venue;
@end

@interface FoursquareManager : NSObject <NSURLConnectionDelegate, CLLocationManagerDelegate>
{
    NSString *clientId, *clientSecret;
    
    NSString *filterCategory;

    NSMutableDictionary *dataFromConnectionsByTag;
    
    id<FoursquareManagerDelegate> delegate;
}

@property (nonatomic, retain) NSString *clientId, *clientSecret;
@property (nonatomic, assign) id<FoursquareManagerDelegate> delegate;

-(id)initWithClientId:(NSString*)_clientId andSecrect:(NSString*)_clientSecret;

-(void)requestCategoryForString:(NSString*)_category;
-(void)requestVenuesNearLocation:(CLLocation*)_location byCategory:(NSString*)_categoryId;
-(void)requestVenuesNearLocation:(CLLocation*)_location;
-(void)requsetVenuesNearCurrentLocation;
-(void)requestMenuForVenueById:(NSString*)_venueId;

@end