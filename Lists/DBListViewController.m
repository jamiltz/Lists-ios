//
//  DBListViewController.m
//  Lists
//
//  Created by Leah Culver on 7/29/14.
//  Copyright (c) 2014 Dropbox. All rights reserved.
//

#import "DBListViewController.h"

#import <Dropbox/Dropbox.h>
#import "DBShareViewController.h"

@interface DBListViewController ()

@property (nonatomic, strong) DBDatastore *datastore;
@property (nonatomic, strong) NSArray *sortDescriptors;
@property (nonatomic, assign) BOOL justLinkedToDropbox;

@end

@implementation DBListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Sort with newest items on the bottom
    self.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"fields.date" ascending:YES]];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Open the datastore for this list
    self.datastore = [[DBDatastoreManager sharedManager] openDatastore:self.datastoreId error:nil];
    [self.datastore sync:nil];
    [self.tableView reloadData];
    
    // Set the title to the title of the datastore
    self.title = self.datastore.title;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // Observe changes to datastore (possibly from other devices)
    __weak typeof(self) weakSelf = self;
    [self.datastore addObserver:self block:^() {
        if (weakSelf.datastore.status.incoming) {
            // Sync with updated data and reload
            [weakSelf.datastore sync:nil];
            [weakSelf.tableView reloadData];
            
            // Update title if needed
            weakSelf.title = weakSelf.datastore.title;
        }
    }];
    
    // Observe changes to datastore list (possibly from other devices)
    [[DBDatastoreManager sharedManager] addObserver:self block:^() {
        // Was this datastore deleted?
        if ([[[DBDatastoreManager sharedManager] listDatastoreInfo:nil] objectForKey:weakSelf.datastoreId] == nil) {
            // Show friendly error message and go back.
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Uh oh!" message:@"List does not exist." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Okay", nil];
            [alert show];
            [weakSelf.navigationController popToRootViewControllerAnimated:YES];
        }
    }];
    
    // Just linked to Dropbox? Go to sharing screen.
    DBAccount *account = [[DBAccountManager sharedManager] linkedAccount];
    if (account && self.justLinkedToDropbox == YES) {
        [self performSegueWithIdentifier:@"ShareListSegue" sender:nil];
        self.justLinkedToDropbox = NO;
        return;
    }
    
    [self.datastore sync:nil];
    [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    // Stop listening for changes to the datastore
    if (self.datastore) {
        [self.datastore close];
        [self.datastore removeObserver:self];
    }
    self.datastore = nil;
    
    // Stop listening for changes to the datastores
    [[DBDatastoreManager sharedManager] removeObserver:self];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if ([self.datastore isWritable]) {
        return 2; // Add item cell
    }

    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        // Items count
        DBTable *itemsTable = [self.datastore getTable:@"items"];
        NSArray *items = [itemsTable query:nil error:nil];
        return [items count];
    }
    
    return 1; // Add item cell
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        // Item cell
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ItemCell" forIndexPath:indexPath];
        
        DBTable *itemsTable = [self.datastore getTable:@"items"];
        NSArray *items = [[itemsTable query:nil error:nil] sortedArrayUsingDescriptors:self.sortDescriptors];
        DBRecord *item = [items objectAtIndex:indexPath.row];
        
        cell.textLabel.text = item[@"text"];
        
        return cell;
    }
    
    // Add item cell
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AddItemCell" forIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Item cell
    if (indexPath.section == 0 && [self.datastore isWritable]) {
        return YES;
    }
    
    return NO; // Add item cell
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        // Delete the row from the data source
        DBTable *itemsTable = [self.datastore getTable:@"items"];
        NSArray *items = [[itemsTable query:nil error:nil] sortedArrayUsingDescriptors:self.sortDescriptors];
        DBRecord *item = [items objectAtIndex:indexPath.row];
        
        [item deleteRecord];
        [self.datastore sync:nil];
        
        // Remove row from table view
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }
}

#pragma mark - Text field delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if ([textField.text length]) {
        // Add a new item to the list with text and date
        DBTable *itemsTable = [self.datastore getTable:@"items"];
        [itemsTable insert:@{ @"text": textField.text, @"date": [NSDate date] }];
        [self.datastore sync:nil];
        
        // Reload table to show new item
        [self.tableView reloadData];
    }
    
    // Clear text field
    textField.text = nil;
    [textField resignFirstResponder];
    
    return YES;
}

#pragma mark - Navigation

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    DBAccount *account = [[DBAccountManager sharedManager] linkedAccount];
    
    if (account == nil) {
        // Dropbox account required in order to share a list
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Link to Dropbox"
                                                        message:@"To share a list you'll need to link to Dropbox."
                                                       delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Okay", nil];
        [alert show];
        
        self.justLinkedToDropbox = YES;

        // Link to Dropbox
        [[DBAccountManager sharedManager] linkFromController:self];
        
        return NO;
    }
    
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Pass the selected datastoreInfo to the new view controller
    DBShareViewController *viewController = (DBShareViewController *)[segue destinationViewController];
    viewController.datastoreId = self.datastoreId;
}

@end
