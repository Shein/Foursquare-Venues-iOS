//
//  FoursquareManager.m
//  FoursquareSampler
//
//  Created by Daniel Shein on 5/16/12.
//  Copyright (c) 2012 LoFT. All rights reserved.
//

#import "FoursquareManager.h"
#import "NSURLConnection+Tag.h"
#import "NSDictionary+Iteration.h"


@implementation RestaurantObject
@synthesize name, venueId, hasMenu;

-(NSString*)description
{
    return [NSString stringWithFormat:@"Restaurant %@ with VenueID %@ has menu %d", name, venueId, hasMenu];
}
@end


@implementation MenuItemObject
@synthesize name, menuItemId, price;
@end


typedef enum {
    FSQueryCategories,
    FSQueryVenues,
    FSQueryMenues
} FSQuery;


@interface FoursquareManager ()
-(void)performQueryForURL:(NSString*)_url withQueryType:(FSQuery)_type;

-(void)parseCategoryFromResponse:(NSDictionary*)_response;
-(void)parseMenusFromResponse:(NSDictionary*)_response;
@end

@implementation FoursquareManager
@synthesize clientId, clientSecret;
@synthesize delegate;

#define VENUE_SEARCH_FORMAT         @"https://api.foursquare.com/v2/venues/search?"
#define VENUE_MENU_SEARCH_FORMAT    @"https://api.foursquare.com/v2/venues/%@/menu"
#define VENUE_CATEGORY_SEARCH       @"https://api.foursquare.com/v2/venues/categories"


//TODO: handle clientSecret securely - preferably with Block action to retrieve it
-(id)initWithClientId:(NSString*)_clientId andSecrect:(NSString*)_clientSecret
{
    self = [super init];
    if (self) {
        clientId = _clientId;
        clientSecret = _clientSecret;
    }
    
    return self;
}


-(void)requestCategoryForString:(NSString*)_category
{
    filterCategory = _category;
    
    NSString *categoriesQuery = [NSString stringWithFormat:@"%@", VENUE_CATEGORY_SEARCH];
    [self performQueryForURL:categoriesQuery withQueryType:FSQueryCategories];
}


-(void)requestVenuesNearLocation:(CLLocation*)_location byCategory:(NSString*)_categoryId
{
    NSString *request = [NSString stringWithFormat:@"%@ll=%f,%f&categoryId=%@", VENUE_SEARCH_FORMAT, _location.coordinate.latitude, _location.coordinate.longitude, _categoryId];
    [self performQueryForURL:request withQueryType:FSQueryVenues];
    
}


-(void)requestVenuesNearLocation:(CLLocation*)_location
{
    NSString *request = [NSString stringWithFormat:@"%@ll=%f,%f", VENUE_SEARCH_FORMAT, _location.coordinate.latitude, _location.coordinate.longitude];
    [self performQueryForURL:request withQueryType:FSQueryVenues];
}


-(void)requsetVenuesNearCurrentLocation
{

    if(![CLLocationManager locationServicesEnabled])
    {
        NSError *error = [NSError errorWithDomain:@"Foursquare Interface Error" code:100001 userInfo:[NSDictionary dictionaryWithObject:@"Location Services" forKey:NSLocalizedDescriptionKey]];
        if (delegate != nil && [delegate respondsToSelector:@selector(didFailRequestWithError:)]) {
            [delegate performSelector:@selector(didFailRequestWithError:) withObject:error];
        }   
        return;
    }
    
    CLLocationManager *lm = [[CLLocationManager alloc] init];
    lm.delegate = self;
    [lm startUpdatingLocation];
}


-(void)requestMenuForVenueById:(NSString*)_venueId
{
    NSString *request = [NSString stringWithFormat:VENUE_MENU_SEARCH_FORMAT, _venueId];
    [self performQueryForURL:request withQueryType:FSQueryMenues];
}


#pragma mark - Internal Methods


-(void)performQueryForURL:(NSString*)_url withQueryType:(FSQuery)_type
{
    NSMutableString *destination = [_url mutableCopy];

    if ([destination rangeOfString:@"?"].location == NSNotFound) {
        [destination appendString:@"?"];
    }
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    [df setDateFormat:@"YYYYMMdd"];

    [destination appendFormat:@"&client_id=%@&client_secret=%@&v=%@", clientId, clientSecret, [df stringFromDate:[NSDate date]]];
    
    NSURLRequest *urlRequest = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:destination]];
    [NSURLConnection connectionWithRequest:urlRequest delegate:self tag:_type];
}


#pragma mark - CLLocationManager delegate methods

- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation
{
    [self requestVenuesNearLocation:newLocation];
    [manager stopUpdatingLocation];
    [manager release];
}

#pragma mark - NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if (delegate != nil && [delegate respondsToSelector:@selector(didFailRequestWithError:)]) {
        [delegate performSelector:@selector(didFailRequestWithError:) withObject:error];
    }
}


- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	
    if (dataFromConnectionsByTag == nil) {
		dataFromConnectionsByTag = [[NSMutableDictionary alloc] init];
	}
    
	if ([dataFromConnectionsByTag objectForKey:connection.tag] == nil) {
		NSMutableData *newData = [[NSMutableData alloc] initWithData:data];
		[dataFromConnectionsByTag setObject:newData forKey:connection.tag];
		return;
	} else {
		[[dataFromConnectionsByTag objectForKey:connection.tag] appendData:data];
	}
	
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    NSError *error;
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:[dataFromConnectionsByTag objectForKey:connection.tag] options:NSJSONReadingMutableContainers error:&error];
    
    if (dictionary == nil) {

        if (delegate != nil && [delegate respondsToSelector:@selector(didFailRequestWithError:)]) {
            [delegate performSelector:@selector(didFailRequestWithError:) withObject:error];
        }
        
        return;
    }
    
    if (![[dictionary objectForKey:@"meta"] objectForKey:@"code"] == 200) {

        error = [NSError errorWithDomain:@"Foursquare API Error" 
                                    code:[[[dictionary objectForKey:@"meta"] objectForKey:@"code"] intValue] 
                                userInfo:[NSDictionary dictionaryWithObject:[[dictionary objectForKey:@"meta"] objectForKey:@"errorDetail"] forKey:NSLocalizedDescriptionKey]];
        
        if (delegate != nil && [delegate respondsToSelector:@selector(didFailRequestWithError:)]) {
            [delegate performSelector:@selector(didFailRequestWithError:) withObject:error];
        }
        return;
    }
    
    NSDictionary *response = [dictionary objectForKey:@"response"];
    
    switch ([[connection tag] intValue]) {
        case FSQueryCategories:{
            [self parseCategoryFromResponse:response];
        }break;
            
        case FSQueryVenues:{
            
            NSArray *venues = [response objectForKey:@"venues"];
            
            if (venues == nil) {
                error = [NSError errorWithDomain:@"Foursquare API Error" code:FSErrorGettingVenues userInfo:[NSDictionary dictionaryWithObject:@"Failed Getting Venues from Foursquare" forKey:NSLocalizedDescriptionKey]];
                if (delegate != nil && [delegate respondsToSelector:@selector(didFailRequestWithError:)]) {
                    [delegate performSelector:@selector(didFailRequestWithError:) withObject:error];
                }
                return;
            }
            
            if (delegate != nil && [delegate respondsToSelector:@selector(receivedVenues:)]) {
                [delegate performSelector:@selector(receivedVenues:) withObject:venues];
            }
            
        }break;
            
        case FSQueryMenues:
            [self parseMenusFromResponse:response];
            break;
        default:
            break;
    }
    
    [[dataFromConnectionsByTag objectForKey:connection.tag] release];
	[dataFromConnectionsByTag removeObjectForKey:connection.tag];
}


-(void)parseCategoryFromResponse:(NSDictionary*)_response
{
    NSDictionary *categories = [_response objectForKey:@"categories"];
    if (categories == nil) {
        NSError *error = [NSError errorWithDomain:@"Foursquare API Error" code:FSErrorGettingCategory userInfo:[NSDictionary dictionaryWithObject:@"Failed Getting Categories from Foursquare" forKey:NSLocalizedDescriptionKey]];
        if (delegate != nil && [delegate respondsToSelector:@selector(didFailRequestWithError:)]) {
            [delegate performSelector:@selector(didFailRequestWithError:) withObject:error];
        }
    } else {
        NSString *categoryId = nil;
        for (NSDictionary *category in categories) {
            
            if ([[category objectForKey:@"name"] isEqualToString:filterCategory]) {
                categoryId = [category objectForKey:@"id"];
            }
            
            if ([[category allKeys] containsObject:@"categories"]) {
                for (NSDictionary *subcategory in [category objectForKey:@"categories"]) {
                    
                    if ([[subcategory objectForKey:@"name"] isEqualToString:filterCategory]) {
                        categoryId = [subcategory objectForKey:@"id"];
                    }
                    
                    if ([[subcategory allKeys] containsObject:@"categories"]) {
                        for (NSDictionary *subsubcategory in [subcategory objectForKey:@"categories"]) {
                            
                            if ([[subsubcategory objectForKey:@"name"] isEqualToString:filterCategory]) {
                                categoryId = [subsubcategory objectForKey:@"id"];
                            }
                            
                        }
                    }
                }
            }
        }
        
        if (delegate != nil && [delegate respondsToSelector:@selector(receivedCategoryId:forName:)]) {
            [delegate performSelector:@selector(receivedCategoryId:forName:) withObject:categoryId withObject:filterCategory];
        }
    }
}

-(void)parseMenusFromResponse:(NSDictionary*)_response
{
    NSMutableArray *menuItems = [NSMutableArray array];   
    NSMutableArray *items = [NSMutableArray arrayWithArray:[_response objectsForKey:@"items" recursive:YES]];

    for (id item in items){
        if ([item isKindOfClass:[NSArray class]]) {
            for (id child in item){
                if ([child isKindOfClass:[NSDictionary class]]) {
                    if ([[child allKeys] containsObject:@"entryId"]) {
                        [menuItems addObject:child];
                    }
                }
            }
        }
        
    }
        
    if (delegate != nil && [delegate respondsToSelector:@selector(receivedMenu:forVenue:)]) {
        [delegate performSelector:@selector(receivedMenu:forVenue:) withObject:menuItems];
    }
}

@end
