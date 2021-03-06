//
//  AppDelegate+notification.m
//  pushtest
//
//  Created by Robert Easterday on 10/26/12.
//
//

#import "AppDelegate+notification.h"
#import <objc/runtime.h>

static char launchNotificationKey;

@implementation AppDelegate (notification)

// its dangerous to override a method from within a category.
// Instead we will use method swizzling. we set this up in the load call.
+ (void)load
{
    Method original, swizzled;

    original = class_getInstanceMethod(self, @selector(init));
    swizzled = class_getInstanceMethod(self, @selector(swizzled_init));
    method_exchangeImplementations(original, swizzled);
}

- (AppDelegate *)swizzled_init
{
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createNotificationChecker:)
               name:@"UIApplicationDidFinishLaunchingNotification" object:nil];

	// This actually calls the original init method over in AppDelegate. Equivilent to calling super
	// on an overrided method, this is not recursive, although it appears that way. neat huh?
	return [self swizzled_init];
}

// This code will be called immediately after application:didFinishLaunchingWithOptions:. We need
// to process notifications in cold-start situations
- (void)createNotificationChecker:(NSNotification *)notification
{
	if (notification) {
        //NSLog(@"AppDelegate+notification=>createNotificationChecker=>notification -> %@", notification);
		NSDictionary *launchOptions = [notification userInfo];
        if (launchOptions){
			
            NSMutableDictionary* notification = [NSMutableDictionary dictionaryWithDictionary:
                                                 [launchOptions objectForKey: @"UIApplicationLaunchOptionsRemoteNotificationKey"]];
            
            [notification setObject:[NSNumber numberWithBool:NO] forKey:@"foreground"];
            [notification setObject:[NSNumber numberWithBool:YES] forKey:@"userAction"];

            [[NotificationService instance] receivedNotification:notification];
            
        }
	}
}

-(void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {

    [[NotificationService instance] didRegisterUserNotificationSettings:notificationSettings];
    
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    
    [[NotificationService instance] onRegistered:deviceToken];
   
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    
    [[NotificationService instance] failToRegister:error];

}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {

    // Get application state for iOS4.x+ devices, otherwise assume active
    UIApplicationState appState = UIApplicationStateActive;
    if ([application respondsToSelector:@selector(applicationState)]) {
        appState = application.applicationState;
    }

    NSMutableDictionary* notification = [NSMutableDictionary dictionaryWithDictionary:[userInfo mutableCopy]];
    NSLog(@"AppDelegate+notification=>didReceiveRemoteNotification=>notification -> %@", notification);
    //NSLog(@"AppDelegate+notification=>didReceiveRemoteNotification=>notification -> %@", userInfo);

    /*UIApplicationState appState = application.applicationState;

    NSMutableDictionary* notification = [NSMutableDictionary dictionaryWithDictionary:[userInfo objectForKey:@"aps"]];
    NSMutableDictionary* payload = [NSMutableDictionary dictionaryWithDictionary:[userInfo mutableCopy]];
    [payload removeObjectForKey:@"aps"];

    [notification setObject: payload forKey:@"custom"];*/
    [notification setObject:[self getUUID] forKey:@"uuid"];
    [notification setObject:[self getCurrentDate] forKey:@"timestamp"];

    /**/
    NSDictionary* aps = [userInfo objectForKey:@"aps"];
    NSLog(@"AppDelegate+notification=>didReceiveRemoteNotification=>userInfo=>aps -> %@", aps);
    NSString *alert = [aps objectForKey:@"alert"];

    if(!alert.length){
        NSLog(@"AppDelegate+notification=>didReceiveRemoteNotification=>is an R2 ");
    }else{
        NSString *pushEchoUrl = [[NSUserDefaults standardUserDefaults] stringForKey:@"pushEchoUrl"];
        NSLog(@"AppDelegate+notification=>didReceiveRemoteNotification=>pushEchoUrl -> %@", pushEchoUrl);

        //NSLog(@"AppDelegate+notification=>didReceiveRemoteNotification=>userInfo -> %@", userInfo);
        NSDictionary* payload = [userInfo objectForKey:@"data"];
        //NSLog(@"AppDelegate+notification=>didReceiveRemoteNotification=>userInfo=>payload(data) -> %@", payload);
        NSDictionary* jsondata = [payload objectForKey:@"json"];
        NSLog(@"AppDelegate+notification=>didReceiveRemoteNotification=>userInfo=>payload(data)=>jsondata -> %@", jsondata);
        NSString *postid = [jsondata objectForKey:@"postid"];
        NSString *serial = [jsondata objectForKey:@"serial"];
        NSString *rRec = [NSString stringWithFormat: @"{\"rRec\":\"%@|%@\"}", postid,serial]; 
        NSString *escapedrRec = [rRec stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
        NSString *p = [NSString stringWithFormat: @"?p=%@", escapedrRec]; 
        NSString *url = [NSString stringWithFormat: @"%@%@", pushEchoUrl,p];
        NSLog(@"AppDelegate+notification=>didReceiveRemoteNotification=>pushEcho=>url -> %@", url);
        //NSString *url = pushEchoUrl;

        NSURLRequest *theRequest=[NSURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
        NSURLConnection *theConnection=[[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
        if (theConnection) {
            NSLog(@"Connection establisted successfully");
        } else {
            NSLog(@"Connection failed.");
        }
        NSURLResponse* response = nil;
        NSData* data = [NSURLConnection sendSynchronousRequest:theRequest returningResponse:&response error:nil];

        NSLog(@"AppDelegate+notification=>didReceiveRemoteNotification=>pushEcho=>data -> %@", data);

    }

    if (appState == UIApplicationStateActive) {
        [notification setObject:[NSNumber numberWithBool:YES] forKey:@"foreground"];
    }
    else {
        [notification setObject:[NSNumber numberWithBool:NO] forKey:@"foreground"];
        [notification setObject:[NSNumber numberWithBool:YES] forKey:@"coldstart"];
    }

    [[NotificationService instance] receivedNotification:notification];

    if (appState == UIApplicationStateBackground) {
        completionHandler(UIBackgroundFetchResultNewData);
    }
}

/*- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult result))completionHandler{
    NSLog(@"AppDelegate+notification=>performFetchWithCompletionHandler=>log -");
}*/

/*- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions{
    
    NSDictionary *remoteNotify = [launchOptions objectForKey: UIApplicationLaunchOptionsRemoteNotificationKey];
    //Accept push notification when app is not open
    if (remoteNotify)         // it is only true when you get the notification
    {
        // use the remoteNotify dictionary for notification data
        NSLog(@"AppDelegate+notification=>didFinishLaunchingWithOptions=>remoteNotify -> %@", remoteNotify);
    }
    return true;
}*/



- (NSString*) getCurrentDate {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];

    NSDate *now = [NSDate date];
    NSString *iso8601String = [dateFormatter stringFromDate:now];
    return iso8601String;
}

- (NSString*) getUUID {
    NSString* UUID = [[NSUUID UUID] UUIDString];
    return UUID;
}

@end
