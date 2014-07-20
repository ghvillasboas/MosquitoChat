//
//  LoginViewController.m
//  MQTTChat
//
//  Created by George Villasboas on 7/18/14.
//  Copyright (c) 2014 CocoaHeads Brasil. All rights reserved.
//

#import "LoginViewController.h"
#import <Social/Social.h>
#import <Accounts/Accounts.h>

@interface LoginViewController ()<UIActionSheetDelegate>
@property (strong, nonatomic) NSArray *twitterAccounts;
@property (weak, nonatomic) IBOutlet UIView *loginButtonView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *loginButtonViewConstraint;
@property (weak, nonatomic) IBOutlet UIButton *loginButton;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;
@end

@implementation LoginViewController

#pragma mark -
#pragma mark Getters overriders

#pragma mark -
#pragma mark Setters overriders

#pragma mark -
#pragma mark Designated initializers

#pragma mark -
#pragma mark Public methods

#pragma mark -
#pragma mark Private methods

/**
 *  Send the request to twitter using a givin account
 *
 *  @param twitterAccount The twitter account
 */
- (void)sendRequestToTwitterUsingAccount:(ACAccount *)twitterAccount
{
    // Make request
    SLRequest *postRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:[NSURL URLWithString:@"https://api.twitter.com/1.1/account/verify_credentials.json"] parameters:nil];
    [postRequest setAccount:twitterAccount];
    [postRequest performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error) {
        if (!error) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:responseData options:kNilOptions error:nil];
            
            if (!json[@"errors"]) {
                NSURL *imageURL = [NSURL URLWithString:json[@"profile_image_url"]];
                NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
                UIImage *image = [UIImage imageWithData:imageData];
                [[NSUserDefaults standardUserDefaults] setObject:UIImageJPEGRepresentation(image, 1.0) forKey:@"imageKey"];
                [[NSUserDefaults standardUserDefaults] setObject:json[@"name"] forKey:@"userKey"];
                
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self performSegueWithIdentifier:@"showChatSegue" sender:self];
                });
            }
            else{
                [self showAlertWithTitle:@"Oops..." andMessage:@"Error connecting to Twitter. Try again."];
            }
        }
        else{
            NSLog(@"ERROR: %@", error.localizedDescription);
        }
    }];
}

/**
 *  Build a account picker so the user can choose between accounts
 *
 *  @param accountsArray The array of twitter accounts to choose from
 */
- (void)buildAndShowAccountPickerForAccountList:(NSArray *)accountsArray
{
    // Make sure its running on the main thread.
    dispatch_async(dispatch_get_main_queue(), ^{
        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Select one of your Twitter accounts", @"When the user has more then one twitter account, he must pick one to follow the company on twitter")
                                                                 delegate:self
                                                        cancelButtonTitle:NSLocalizedString(@"Cancel", @"A cancel button label")
                                                   destructiveButtonTitle:nil
                                                        otherButtonTitles:nil];
        
        [accountsArray enumerateObjectsUsingBlock:^(ACAccount *account, NSUInteger idx, BOOL *stop) {
            [actionSheet addButtonWithTitle:account.username];
        }];
        
        [actionSheet showInView:self.view];
    });
}

/**
 *  Shows an alert with a given title and message.
 *
 *  @param title   The title
 *  @param message The message
 */
- (void)showAlertWithTitle:(NSString *)title andMessage:(NSString *)message
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alert show];
        
        [self.spinner stopAnimating];
    });
}

#pragma mark -
#pragma mark ViewController life cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"userKey"]) {
        [self performSegueWithIdentifier:@"showChatSegue" sender:self];
    }
    
    // prepare uiview animation
    self.loginButtonViewConstraint.constant = -CGRectGetHeight(self.loginButtonView.frame);
    self.loginButton.alpha = 0.0;
    
    [self.navigationController setNavigationBarHidden:YES animated:NO];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // animate the login.
    // just eye candy
    self.loginButtonViewConstraint.constant = 0;
    [UIView animateWithDuration:1.0 animations:^{
        [self.view layoutIfNeeded];
    } completion:^(BOOL finished) {
        
        [UIView animateWithDuration:0.5 animations:^{
            self.loginButton.alpha = 1.0;
        }];
    }];
}

#pragma mark -
#pragma mark Overriden methods

#pragma mark -
#pragma mark Storyboards Segues

#pragma mark -
#pragma mark Target/Actions

- (IBAction)loginToTwiiter:(id)sender
{
    
    [self.spinner startAnimating];
    
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
    
    ACAccountType *accountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    
    [accountStore requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error) {
        
        if(granted && !error) {
            // Get the list of Twitter accounts.
            self.twitterAccounts = [accountStore accountsWithAccountType:accountType];
            
            // execute actions according number of accounts
            
            if (self.twitterAccounts.count == 1) {
                // only one account. Send request right away.
                [self sendRequestToTwitterUsingAccount:self.twitterAccounts.lastObject];
            }
            else if (self.twitterAccounts.count > 1){
                // more then 1 account.
                // build and show a action list for user to pick one
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self buildAndShowAccountPickerForAccountList:self.twitterAccounts];
                });
            }
            else{
                
                // No Twitter account
                [self showAlertWithTitle:@"No Twitter account" andMessage:@"Sorry. You don't have any Twitter account on your device."];
            }
        }
        else{
            // problem.
            [self showAlertWithTitle:@"Oops." andMessage:@"There was a problem logging you into Twitter."];
        }
    }];
}

#pragma mark -
#pragma mark Delegates

#pragma mark UIActionSheet Delegates

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *username = [actionSheet buttonTitleAtIndex:buttonIndex];
    ACAccount *account = (ACAccount *)[[self.twitterAccounts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"username == %@", username]] lastObject];
    
    if (account) [self sendRequestToTwitterUsingAccount:account];
    
}

#pragma mark -
#pragma mark Notification center

@end
