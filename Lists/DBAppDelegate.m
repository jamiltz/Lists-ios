//
//  DBAppDelegate.m
//  Lists
//
//  Created by Leah Culver on 7/28/14.
//  Copyright (c) 2014 Dropbox. All rights reserved.
//

#import "DBAppDelegate.h"

#import <Dropbox/Dropbox.h>
#import "DBListViewController.h"

@implementation DBAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    DBAccountManager *accountManager = [[DBAccountManager alloc] initWithAppKey:@"gmd9bz0ihf8t30o" secret:@"gt6onalc86cbetu"];
    [DBAccountManager setSharedManager:accountManager];
    
    DBAccount *account = [[DBAccountManager sharedManager] linkedAccount];
    
    if (account) {
        // Use Dropbox datastores
        [DBDatastoreManager setSharedManager:[DBDatastoreManager managerForAccount:account]];
    } else {
        // Use local datastores
        [DBDatastoreManager setSharedManager:[DBDatastoreManager localManagerForAccountManager:[DBAccountManager sharedManager]]];
    }
    
    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    if ([[url lastPathComponent] isEqualToString:@"connect"]) {
        // Account linked to Dropbox -- db-gmd9bz0ihf8t30o://1/connect
        DBAccount *account = [[DBAccountManager sharedManager] handleOpenURL:url];
        
        if (account) {
            // App linked successfully!
            
            // Migrate any local datastores to Dropbox
            DBDatastoreManager *localDatastoreManager = [DBDatastoreManager localManagerForAccountManager:[DBAccountManager sharedManager]];
            [localDatastoreManager migrateToAccount:account error:nil];
            
            // Use Dropbox datastores
            [DBDatastoreManager setSharedManager:[DBDatastoreManager managerForAccount:account]];
            
            return YES;
        }
    } else {
        // Shared datastore -- Lists://
        NSString *datastoreId = [url host];
        
        NSLog(@"Opening datastore ID: %@", datastoreId);
        
        // Return to root view controller
        UINavigationController *navigationController = (UINavigationController *)self.window.rootViewController;
        [navigationController popToRootViewControllerAnimated:NO];
        
        DBAccount *account = [[DBAccountManager sharedManager] linkedAccount];

        if (account) {
            // Go to the shared list (will open the list)
            if ([DBDatastore isValidShareableId:datastoreId]) {
                
                DBListViewController *viewController = (DBListViewController *)[navigationController.storyboard instantiateViewControllerWithIdentifier:@"DBListViewController"];
                viewController.datastoreId = datastoreId;
                
                [navigationController pushViewController:viewController animated:NO];
            } else {
                // Notify user that this isn't a valid link
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Uh oh!"
                                                                message:@"Invalid List link."
                                                               delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Okay", nil];
                [alert show];
            }
        } else {
            // Notify user to link with Dropbox
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Link to Dropbox"
                                                            message:@"To accept a shared list you'll need to link to Dropbox first."
                                                           delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Okay", nil];
            [alert show];
        }
        
        return YES;
    }

    return NO;
}

@end
