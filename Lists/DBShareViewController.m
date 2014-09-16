//
//  DBShareViewController.m
//  Lists
//
//  Created by Leah Culver on 7/31/14.
//  Copyright (c) 2014 Dropbox. All rights reserved.
//

#import "DBShareViewController.h"

#import <Dropbox/Dropbox.h>
#import <MessageUI/MessageUI.h>
#import "DBPickerCell.h"

@interface DBShareViewController () <MFMailComposeViewControllerDelegate, MFMessageComposeViewControllerDelegate>

@property (nonatomic, strong) DBDatastore *datastore;

@end

@implementation DBShareViewController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Open the datastore for this list
    self.datastore = [[DBDatastoreManager sharedManager] openDatastore:self.datastoreId error:nil];
    
    [self.tableView reloadData];
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

#pragma mark - Table view helpers

- (BOOL)isTeamAccount
{
    DBAccount *account = [[DBAccountManager sharedManager] linkedAccount];

    return [account.info.orgName length] > 0;
}

- (BOOL)isSharePubliclySection:(NSInteger)section
{
    return section == 0;
}

- (BOOL)isShareTeamSection:(NSInteger)section
{
    return [self isTeamAccount] && section == 1;
}

- (BOOL)isShareViaSection:(NSInteger)section
{
    if ([self isTeamAccount]) {
        return section == 2;
    }

    return section == 1;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSInteger numSections = 1;
    
    // Show team role section if account is part of a team
    if ([self isTeamAccount]) {
        numSections++;
    }
    
    // Show messaging section if datastore is shared
    if ([self.datastore getRoleForPrincipal:DBPrincipalPublic] > 0 || [self.datastore getRoleForPrincipal:DBPrincipalTeam] > 0) {
        numSections ++;
    }

    return numSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if ([self isShareViaSection:section]) {
        return 2;
    }

    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self isSharePubliclySection:indexPath.section]) {
        DBPickerCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PickerCell" forIndexPath:indexPath];
        cell.principal = DBPrincipalPublic;
        
        DBRole role = [self.datastore getRoleForPrincipal:DBPrincipalPublic];
        [cell updateRole:role effectiveRole:self.datastore.effectiveRole];

        return cell;
    }
    
    if ([self isShareTeamSection:indexPath.section]) {
        DBPickerCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PickerCell" forIndexPath:indexPath];
        cell.principal = DBPrincipalTeam;
        
        DBRole role = [self.datastore getRoleForPrincipal:DBPrincipalTeam];
        [cell updateRole:role effectiveRole:self.datastore.effectiveRole];
        
        return cell;
    }
    
    if ([self isShareViaSection:indexPath.section]) {
        NSString *identifier = (indexPath.row == 0) ? @"EmailCell" : @"MessageCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier forIndexPath:indexPath];
        
        return cell;
    }
    
    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if ([self isSharePubliclySection:section]) {
        return @"Share Publicly";
    }
    
    if ([self isShareTeamSection:section]) {
        DBAccount *account = [[DBAccountManager sharedManager] linkedAccount];
        return [NSString stringWithFormat:@"Share with Team (%@)", account.info.orgName];
    }
    
    if ([self isShareViaSection:section]) {
        return @"Share via";
    }
    
    return nil;
}

#pragma mark - Table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self isShareViaSection:indexPath.section]) {
        return 44.0;
    }
    
    // Share publicly / Share team section picker
    return 88.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self isShareViaSection:indexPath.section]) {
        
        NSLog(@"Sharing datastore ID: %@", self.datastoreId);
        
        NSString *shareURL = [NSString stringWithFormat:@"https://dslists.site44.com/#%@", self.datastoreId];
        
        if (indexPath.row == 0) {

            // Share via email
            if ([MFMailComposeViewController canSendMail]) {
                
                MFMailComposeViewController *composeController = [[MFMailComposeViewController alloc] init];
                composeController.mailComposeDelegate = self;
                DBAccount *account = [[DBAccountManager sharedManager] linkedAccount];
                [composeController setSubject:[NSString stringWithFormat:@"%@ would like to share a list with you", account.info.userName]];
                [composeController setMessageBody:[NSString stringWithFormat:@"Hi,\n\nI'd like to share a List with you!\n\n%@\n\n%@", shareURL, account.info.userName] isHTML:NO];
                
                [self.navigationController presentViewController:composeController animated:YES completion:nil];
                
            } else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Uh oh!" message:@"Unable to send email." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Okay", nil];
                [alert show];
            }
            
        } else if (indexPath.row == 1) {
            
            // Share via text message
            if ([MFMessageComposeViewController canSendText]) {
                
                MFMessageComposeViewController *composeController = [[MFMessageComposeViewController alloc] init];
                composeController.messageComposeDelegate = self;
                composeController.body = [NSString stringWithFormat:@"I'd like to share a List with you! %@", shareURL];
                
                [self.navigationController presentViewController:composeController animated:YES completion:nil];
                
            } else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Uh oh!" message:@"Unable to send text messages." delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Okay", nil];
                [alert show];
            }
        }
    }
}

#pragma mark - Picker view data source

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    return 3;
}

#pragma mark - Picker view delegate

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    // Roles are None, Viewer, Editor, and Owner - but Owner cannot be picked.
    switch (row) {
        case 0:
            return @"None";
            break;
        case 1:
            return @"Viewable";
            break;
        case 2:
            return @"Editable";
            break;
        default:
            break;
    }
    
    return nil;
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    DBPickerCell *cell = (DBPickerCell *)pickerView.superview.superview.superview; // hacky way to get cell
    
    [self.datastore setRoleForPrincipal:cell.principal to:(DBRole)row];
    [self.datastore sync:nil];
    
    // Reload to update sections
    [self.tableView reloadData];
}

#pragma mark - Mail compose delegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];

    if (result == MFMailComposeResultSent) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"Email sent!" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Okay", nil];
        [alert show];
    } else if (result == MFMailComposeResultFailed) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Uh oh!" message:@"Email failed to send" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Okay", nil];
        [alert show];
    }
}

#pragma mark - Message compose delegate

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result
{
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    
    if (result == MessageComposeResultSent) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"Message sent!" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Okay", nil];
        [alert show];
    } else if (result == MessageComposeResultFailed) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Uh oh!" message:@"Message failed to send" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Okay", nil];
        [alert show];
    }
}

@end
