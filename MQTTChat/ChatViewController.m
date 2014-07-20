//
//  ChatViewController.m
//  MQTTChat
//
//  Created by George Villasboas on 7/18/14.
//  Copyright (c) 2014 CocoaHeads Brasil. All rights reserved.
//

#import "ChatViewController.h"
#import <MQTTKit.h>

// Please, dont abuse the server of our dear friends at Eclipse.org!
// Consider deploying your own!
#define kMQTTServerHost @"iot.eclipse.org"
#define kTopic @"mosquitochat/ghvillasboas"

@interface ChatViewController ()
@property (nonatomic, strong) MQTTClient *client;
@property (strong, nonatomic) UIImage *userImage;
@property (strong, nonatomic) NSString *userName;
@property (strong, nonatomic) NSMutableArray *messages;
@property (copy, nonatomic) NSDictionary *avatars;
@property (strong, nonatomic) UIImageView *outgoingBubbleImageView;
@property (strong, nonatomic) UIImageView *incomingBubbleImageView;
@end

@implementation ChatViewController

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
 *  Setup the connection with the MQTT broker
 */
- (void)setupMQTTClient
{
    
    // create the MQTT client with an unique identifier
    NSString *clientID = [UIDevice currentDevice].identifierForVendor.UUIDString;
    self.client = [[MQTTClient alloc] initWithClientId:clientID];
    
    // define the handler that will be called when MQTT messages are received by the client
    __weak typeof(self)weakSelf = self;
    
    [self.client setMessageHandler:^(MQTTMessage *message) {
        // extract the switch status from the message payload
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:message.payload options:kNilOptions error:nil];
        
        // the MQTTClientDelegate methods are called from a GCD queue.
        // Any update to the UI must be done on the main queue
        
        dispatch_async(dispatch_get_main_queue(), ^{
            /**
             *  Sending a message. Your implementation of this method should do *at least* the following:
             *
             *  1. Play sound (optional)
             *  2. Add new id<JSQMessageData> object to your data source
             *  3. Call `finishSendingMessage`
             */
            
            
            NSString *dateString = json[@"date"] ;
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"YYYY-MM-dd HH:mm:ss"];
            NSDate *dateFromString = [[NSDate alloc] init];
            dateFromString = [dateFormatter dateFromString:dateString];
            
            JSQMessage *message = [[JSQMessage alloc] initWithText:json[@"text"] sender:json[@"sender"] date:dateFromString];
            
            
            // generate avatar and save to cache
            if (![weakSelf avatarFromCache:json[@"sender"]]) {
                CGFloat outgoingDiameter = weakSelf.collectionView.collectionViewLayout.outgoingAvatarViewSize.width;
                
                UIImage *userAvatar = [JSQMessagesAvatarFactory avatarWithUserInitials:[weakSelf userInitialsForName:json[@"sender"]]
                                                                       backgroundColor:[UIColor colorWithWhite:0.85f alpha:1.0f]
                                                                             textColor:[UIColor colorWithWhite:0.60f alpha:1.0f]
                                                                                  font:[UIFont systemFontOfSize:14.0f]
                                                                              diameter:outgoingDiameter];
                [weakSelf saveAvatarToCache:userAvatar forUser:json[@"sender"]];
            }
            
            // send message to timeline if not from user
            if (![weakSelf.sender isEqualToString:json[@"sender"]]) {
                [JSQSystemSoundPlayer jsq_playMessageSentSound];
                [weakSelf.messages addObject:message];
                [weakSelf finishSendingMessage];
            }
        });
    }];
}

/**
 *  Connects to the broker
 */
- (void)connectoToMQTTBroker
{
    [self.client connectToHost:kMQTTServerHost completionHandler:^(MQTTConnectionReturnCode code) {
        if (code == ConnectionAccepted) {
            // The client is connected when this completion handler is called
            NSLog(@"client is connected with id %@", self.client.clientID);
            // Subscribe to the topic
            [self.client subscribe:kTopic withCompletionHandler:^(NSArray *grantedQos) {
                // The client is effectively subscribed to the topic when this completion handler is called
                NSLog(@"subscribed to topic %@", kTopic);
            }];
        }
    }];
}

/**
 *  Setup the test model
 */
- (void)setupTestModel
{
    // Model to store the messages
    self.messages = [[NSMutableArray alloc] init];
    
    // connected user's avatar
    CGFloat outgoingDiameter = self.collectionView.collectionViewLayout.outgoingAvatarViewSize.width;
    UIImage *userAvatar = [JSQMessagesAvatarFactory avatarWithImage:self.userImage
                                                           diameter:outgoingDiameter];
    self.avatars = @{ self.sender : userAvatar };
}

/**
 *  Save avatar to a local cache
 *
 *  @param avatar   Avatar image to cache
 *  @param userName User name to cache
 */
- (void)saveAvatarToCache:(UIImage *)avatar forUser:(NSString *)userName
{
    NSMutableDictionary *avatars = [self.avatars mutableCopy];
    if (!self.avatars[userName]) {
        [avatars setObject:avatar forKey:userName];
        self.avatars = [avatars copy];
    }
}

/**
 *  Retrieve the avatar image from cache
 *
 *  @param userName The user name to retrieve
 *
 *  @return The avatar image
 */
- (UIImage *)avatarFromCache:(NSString *)userName
{
    return self.avatars[userName];
}

/**
 *  Gets the two letter initials given an name.
 *  If the name has only one word, gets the first two chars.
 *
 *  @param username The fullname
 *
 *  @return The two letter initials in uppercase
 */
- (NSString *)userInitialsForName:(NSString *)username
{
    NSString *initials;
    NSArray *namesTokens = [username componentsSeparatedByString:@" "];
    
    if (namesTokens.count > 0) {
        if (namesTokens.count == 1) initials = [[username substringToIndex:2] uppercaseString];
        else {
            initials = [[NSString stringWithFormat:@"%@%@", [namesTokens.firstObject substringToIndex:1], [namesTokens.lastObject substringToIndex:1]] uppercaseString];
        }
    }
    
    return initials;
}

/**
 *  Posts message to MQTT broker
 *
 *  @param message The message object
 */
- (void)postMessageToBroker:(JSQMessage *)message
{
    // when the client is connected, send a MQTT message
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"YYYY-MM-dd HH:mm:ss"];
    NSString *strDate = [dateFormatter stringFromDate:[NSDate date]];
    
    [self.client publishString:[NSString stringWithFormat:@"{\"text\": \"%@\",\"sender\":\"%@\", \"date\":\"%@\"}", message.text, message.sender, strDate]
                       toTopic:kTopic
                       withQos:AtMostOnce
                        retain:NO
             completionHandler:^(int mid) {
                 NSLog(@"message has been delivered to MQTT broker");
             }];
}

#pragma mark -
#pragma mark ViewController life cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSData *imageData = [[NSUserDefaults standardUserDefaults] objectForKey:@"imageKey"];
    self.userImage = [UIImage imageWithData:imageData];
    self.userName = [[NSUserDefaults standardUserDefaults] objectForKey:@"userKey"];
    
    self.sender = self.userName;
    
    [self setupTestModel];
    [self setupMQTTClient];
    
    // Create bubble images.
    // Be sure to create your avatars one time and reuse them for good performance.
    self.outgoingBubbleImageView = [JSQMessagesBubbleImageFactory
                                    outgoingMessageBubbleImageViewWithColor:[UIColor jsq_messageBubbleLightGrayColor]];
    
    self.incomingBubbleImageView = [JSQMessagesBubbleImageFactory
                                    incomingMessageBubbleImageViewWithColor:[UIColor jsq_messageBubbleBlueColor]];
    
    [self.navigationController setNavigationBarHidden:NO animated:NO];
    [self.navigationItem setHidesBackButton:YES animated:YES];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // connect the MQTT client
    if (!self.client.connected) {
        [self connectoToMQTTBroker];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    /**
     *  Enable/disable springy bubbles, default is NO.
     *  You must set this from `viewDidAppear:`
     *  Note: this feature is mostly stable, but still experimental
     */
    self.collectionView.collectionViewLayout.springinessEnabled = YES;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // disconnect the MQTT client
    [self.client disconnectWithCompletionHandler:^(NSUInteger code) {
        // The client is disconnected when this completion handler is called
        NSLog(@"MQTT is disconnected");
    }];
}

#pragma mark -
#pragma mark Overriden methods

- (void)didPressSendButton:(UIButton *)button
           withMessageText:(NSString *)text
                    sender:(NSString *)sender
                      date:(NSDate *)date
{
    // Sending a message. Your implementation of this method should do *at least* the following:
    
    // 1. Play sound (optional)
    [JSQSystemSoundPlayer jsq_playMessageSentSound];
    
    
    // 2. Add new id<JSQMessageData> object to your data source
    JSQMessage *message = [[JSQMessage alloc] initWithText:text sender:sender date:date];
    [self sendMessageToMQTTBroker:message];
    [self.messages addObject:message];
    
    // 3. Call `finishSendingMessage`
    [self finishSendingMessage];
}

- (void)sendMessageToMQTTBroker:(JSQMessage *)message
{
    // connect to the MQTT server
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        if (self.client.connected) {
            [self postMessageToBroker:message];
        }
        else{
            [self.client connectToHost:kMQTTServerHost
                     completionHandler:^(NSUInteger code) {
                         if (code == ConnectionAccepted) {
                             [self postMessageToBroker:message];
                         }
                     }];
        }
    });
}

- (void)didPressAccessoryButton:(UIButton *)sender
{
    NSLog(@"Camera pressed!");
}

#pragma mark -
#pragma mark Storyboards Segues

#pragma mark -
#pragma mark Target/Actions

- (IBAction)logoff:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"imageKey"];
    [[NSUserDefaults standardUserDefaults] setObject:nil forKey:@"userKey"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self.navigationController popToRootViewControllerAnimated:YES];
}

#pragma mark -
#pragma mark Delegates and Datasources

#pragma mark JSQMessages CollectionView DataSource

- (id<JSQMessageData>)collectionView:(JSQMessagesCollectionView *)collectionView messageDataForItemAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.messages objectAtIndex:indexPath.item];
}

- (UIImageView *)collectionView:(JSQMessagesCollectionView *)collectionView bubbleImageViewForItemAtIndexPath:(NSIndexPath *)indexPath
{
    /**
     *  You may return nil here if you do not want bubbles.
     *  In this case, you should set the background color of your collection view cell's textView.
     */
    
    /**
     *  Reuse created bubble images, but create new imageView to add to each cell
     *  Otherwise, each cell would be referencing the same imageView and bubbles would disappear from cells
     */
    
    JSQMessage *message = [self.messages objectAtIndex:indexPath.item];
    
    if ([message.sender isEqualToString:self.sender]) {
        return [[UIImageView alloc] initWithImage:self.outgoingBubbleImageView.image
                                 highlightedImage:self.outgoingBubbleImageView.highlightedImage];
    }
    
    return [[UIImageView alloc] initWithImage:self.incomingBubbleImageView.image
                             highlightedImage:self.incomingBubbleImageView.highlightedImage];
}

- (UIImageView *)collectionView:(JSQMessagesCollectionView *)collectionView avatarImageViewForItemAtIndexPath:(NSIndexPath *)indexPath
{
    JSQMessage *message = [self.messages objectAtIndex:indexPath.item];
    
    UIImage *avatarImage = [self avatarFromCache:message.sender];
    return [[UIImageView alloc] initWithImage:avatarImage];
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    /**
     *  This logic should be consistent with what you return from `heightForCellTopLabelAtIndexPath:`
     *  The other label text delegate methods should follow a similar pattern.
     *
     *  Show a timestamp for every 3rd message
     */
    if (indexPath.item % 3 == 0) {
        JSQMessage *message = [self.messages objectAtIndex:indexPath.item];
        return [[JSQMessagesTimestampFormatter sharedFormatter] attributedTimestampForDate:message.date];
    }
    
    return nil;
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    JSQMessage *message = [self.messages objectAtIndex:indexPath.item];
    
    /**
     *  iOS7-style sender name labels
     */
    if ([message.sender isEqualToString:self.sender]) {
        return nil;
    }
    
    if (indexPath.item - 1 > 0) {
        JSQMessage *previousMessage = [self.messages objectAtIndex:indexPath.item - 1];
        if ([[previousMessage sender] isEqualToString:message.sender]) {
            return nil;
        }
    }
    
    /**
     *  Don't specify attributes to use the defaults.
     */
    return [[NSAttributedString alloc] initWithString:message.sender];
}

- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return nil;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [self.messages count];
}

- (UICollectionViewCell *)collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    /**
     *  Override point for customizing cells
     */
    JSQMessagesCollectionViewCell *cell = (JSQMessagesCollectionViewCell *)[super collectionView:collectionView cellForItemAtIndexPath:indexPath];
    
    JSQMessage *msg = [self.messages objectAtIndex:indexPath.item];
    
    if ([msg.sender isEqualToString:self.sender]) {
        cell.textView.textColor = [UIColor blackColor];
    }
    else {
        cell.textView.textColor = [UIColor whiteColor];
    }
    
    cell.textView.linkTextAttributes = @{ NSForegroundColorAttributeName : cell.textView.textColor,
                                          NSUnderlineStyleAttributeName : @(NSUnderlineStyleSingle | NSUnderlinePatternSolid) };
    
    return cell;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    /**
     *  Each label in a cell has a `height` delegate method that corresponds to its text dataSource method
     */
    
    /**
     *  This logic should be consistent with what you return from `attributedTextForCellTopLabelAtIndexPath:`
     *  The other label height delegate methods should follow similarly
     *
     *  Show a timestamp for every 3rd message
     */
    if (indexPath.item % 3 == 0) {
        return kJSQMessagesCollectionViewCellLabelHeightDefault;
    }
    
    return 0.0f;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
{
    /**
     *  iOS7-style sender name labels
     */
    JSQMessage *currentMessage = [self.messages objectAtIndex:indexPath.item];
    if ([[currentMessage sender] isEqualToString:self.sender]) {
        return 0.0f;
    }
    
    if (indexPath.item - 1 > 0) {
        JSQMessage *previousMessage = [self.messages objectAtIndex:indexPath.item - 1];
        if ([[previousMessage sender] isEqualToString:[currentMessage sender]]) {
            return 0.0f;
        }
    }
    
    return kJSQMessagesCollectionViewCellLabelHeightDefault;
}

- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
                   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
{
    return 0.0f;
}

- (void)collectionView:(JSQMessagesCollectionView *)collectionView
                header:(JSQMessagesLoadEarlierHeaderView *)headerView didTapLoadEarlierMessagesButton:(UIButton *)sender
{
    NSLog(@"Load earlier messages!");
}

#pragma mark -
#pragma mark Notification center

@end
