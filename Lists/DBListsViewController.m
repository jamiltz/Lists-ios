//
//  DBListsViewController.m
//  Lists
//
//  Created by Leah Culver on 7/28/14.
//  Copyright (c) 2014 Dropbox. All rights reserved.
//

#import "DBListsViewController.h"

#import <Dropbox/Dropbox.h>
#import "DBListViewController.h"

#import <CouchbaseLite/CouchbaseLite.h>

static void *liveQueryContext = &liveQueryContext;

@interface DBListsViewController () <UIActionSheetDelegate>

@property (nonatomic, strong) NSArray *sortDescriptors;
@property (nonatomic, assign) BOOL isAddingList;

@property CBLDatabase *database;
@property CBLLiveQuery *liveQuery;
@property NSArray *result;

@end

@implementation DBListsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.database = [[CBLManager sharedInstance] databaseNamed:@"listsapp" error:nil];

    self.liveQuery = [[self.database createAllDocumentsQuery] asLiveQuery];
    [self.liveQuery addObserver:self forKeyPath:@"rows" options:0 context:liveQueryContext];
    
    // No lists yet? Show row to add a list
//    self.isAddingList = [[self liveQuery] count] < 1;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == liveQueryContext) {
        self.result = self.liveQuery.rows.allObjects;
        [self.tableView reloadData];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.isAddingList) {
        return 2;
    }

    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.isAddingList && section == 0) {
        return 1; // Add list cell
    }
    
    // List count
    return [self.result count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.isAddingList && indexPath.section == 0) {
        // Add list cell
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AddListCell" forIndexPath:indexPath];
        return cell;
    }

    // List cell
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ListCell" forIndexPath:indexPath];

    CBLQueryRow *aRow = [self.result objectAtIndex:indexPath.row];
    CBLDocument *aList = [aRow document];
    
    cell.textLabel.text = [aList propertyForKey:@"title"];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.isAddingList && indexPath.section == 0) {
        // Add list cell
        return NO;
    }
    
    return YES; // List cell
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {

        // Delete the row from the data source
        NSArray *datastores = [[[DBDatastoreManager sharedManager] listDatastores:nil] sortedArrayUsingDescriptors:self.sortDescriptors];
        DBDatastoreInfo *datastoreInfo = [datastores objectAtIndex:indexPath.row];
        
        [[DBDatastoreManager sharedManager] deleteDatastore:datastoreInfo.datastoreId error:nil];
        
        // Remove row from table view
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

#pragma mark - Table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44.0;
}

#pragma mark - Text field delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if ([textField.text length]) {
        // Add new list / datastore
        CBLDocument *newList = [self.database createDocument];

        NSDictionary *properties = @{@"title": textField.text};
        [newList putProperties:properties error:nil];
    }
    
    // Clear text field
    textField.text = nil;
    [textField resignFirstResponder];
    
    // Hide row for adding a list
    self.isAddingList = NO;
    [self.tableView reloadData];
    
    return YES;
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Pass the selected datastoreInfo to the new view controller
    NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
    NSArray *datastores = [[[DBDatastoreManager sharedManager] listDatastores:nil] sortedArrayUsingDescriptors:self.sortDescriptors];
    DBDatastoreInfo *datastoreInfo = [datastores objectAtIndex:indexPath.row];
    
    DBListViewController *viewController = (DBListViewController *)[segue destinationViewController];
    viewController.datastoreId = datastoreInfo.datastoreId;
}

#pragma mark - IB actions

- (IBAction)addButtonPressed:(id)sender
{
    // Toggle row for adding a new list
    self.isAddingList = !self.isAddingList;
    [self.tableView reloadData];
}

- (IBAction)settingsButtonPressed:(id)sender
{
    // Show settings action sheet to link or unlink with a Dropbox account
    UIActionSheet *actionSheet = nil;
    DBAccount *account = [[DBAccountManager sharedManager] linkedAccount];
    
    if (account == nil) {
        // Link to Dropbox
        actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                  delegate:self
                                         cancelButtonTitle:@"Cancel"
                                    destructiveButtonTitle:nil
                                         otherButtonTitles:@"Link to Dropbox", nil];
    } else {
        // Unlink from Dropbox
        actionSheet = [[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:@"Linked with Dropbox account:\n%@", account.info.displayName]
                                                  delegate:self
                                         cancelButtonTitle:@"Cancel"
                                    destructiveButtonTitle:@"Unlink from Dropbox"
                                         otherButtonTitles:nil];
    }
    
    // Display action sheet
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [actionSheet showFromBarButtonItem:sender animated:YES];
    } else {
        [actionSheet showInView:self.view];
    }
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != actionSheet.cancelButtonIndex) {

        DBAccount *account = [[DBAccountManager sharedManager] linkedAccount];
        
        if (account == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                // Link to Dropbox
                [[DBAccountManager sharedManager] linkFromController:self];
            });
        } else {
            // Unlink from Dropbox
            [account unlink];
            
            // Shutdown and stop listening for changes to the datastores
            [[DBDatastoreManager sharedManager] shutDown];
            [[DBDatastoreManager sharedManager] removeObserver:self];
            
            // Use local datastores
            [DBDatastoreManager setSharedManager:[DBDatastoreManager localManagerForAccountManager:[DBAccountManager sharedManager]]];
            
            // No lists yet? Show row to add a list
            self.isAddingList = [[[DBDatastoreManager sharedManager] listDatastores:nil] count] < 1;
            
            // Observe changes to datastore list (possibly from other devices)
            __weak typeof(self) weakSelf = self;
            [[DBDatastoreManager sharedManager] addObserver:self block:^() {
                // Reload list of lists to get changes
                [weakSelf.tableView reloadData];
            }];
            
            // Reload list
            [self.tableView reloadData];
        }
    }
}

@end
