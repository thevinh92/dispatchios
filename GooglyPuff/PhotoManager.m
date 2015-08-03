//  PhotoManager.m
//  PhotoFilter
//
//  Created by A Magical Unicorn on A Sunday Night.
//  Copyright (c) 2014 Derek Selander. All rights reserved.
//

@import CoreImage;
@import AssetsLibrary;
#import "PhotoManager.h"

@interface PhotoManager ()
@property (nonatomic, strong) NSMutableArray *photosArray;
@property (nonatomic, strong) dispatch_queue_t concurrentPhotoQueue;
@end

@implementation PhotoManager

+ (instancetype)sharedManager
{
    static PhotoManager *sharedPhotoManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPhotoManager = [[PhotoManager alloc] init];
        sharedPhotoManager->_photosArray = [NSMutableArray array];
        sharedPhotoManager->_concurrentPhotoQueue = dispatch_queue_create("com.selander.GooglyPuff.photoQueue", DISPATCH_QUEUE_CONCURRENT);
    });
    return sharedPhotoManager;
}

//*****************************************************************************/
#pragma mark - Unsafe Setter/Getters
//*****************************************************************************/

- (NSArray *)photos
{
    __block NSArray* array; //1
    dispatch_sync(self.concurrentPhotoQueue, ^{
        array = [NSArray arrayWithArray:_photosArray];
    });
    return array;
}

- (void)addPhoto:(Photo *)photo
{
    // 1. Check that there’s a valid photo before performing all the following work.
    // 2. Add the write operation using your custom queue. When the critical section executes at a later time this will be the only item in your queue to execute.
    // 3. This is the actual code which adds the object to the array. Since it’s a barrier block, this block will never run simultaneously with any other block in concurrentPhotoQueue.
    // 4. Finally you post a notification that you’ve added the image. This notification should be posted from the main thread because it will do UI work, so here you dispatch another task asynchronously to the main queue for the notification.
    if (photo) { //1
        dispatch_barrier_async(self.concurrentPhotoQueue, ^{ //2
            [_photosArray addObject:photo]; //3
            dispatch_async(dispatch_get_main_queue(), ^{ //4
                [self postContentAddedNotification];
            });
        });
    }
}

//*****************************************************************************/
#pragma mark - Public Methods
//*****************************************************************************/


//    Here’s how your new asynchronous method works:
//    1. In this new implementation you don’t need to surround the method in an async call since you’re not blocking the main thread.
//    2. This is the same enter method; there aren’t any changes here.
//    3. This is the same leave method; there aren’t any changes here either.
//    4. dispatch_group_notify serves as the asynchronous completion block. This code executes when there are no more items left in the dispatch group and it’s the completion block’s turn to run. You also specify on which queue to run your completion code, here, the main queue is the one you want.
//    This approach is much cleaner way to handle this particular job and doesn’t block any threads.

- (void)downloadPhotosWithCompletionBlock:(BatchPhotoDownloadingCompletionBlock)completionBlock
{
        //1
        __block NSError* error;
        dispatch_group_t downloadGroup = dispatch_group_create();
    
        for (NSInteger i = 0; i < 5; i++) {
            NSURL *url;
            switch (i) {
                case 0:
                    url = [NSURL URLWithString:kOverlyAttachedGirlfriendURLString];
                    break;
                case 1:
                    url = [NSURL URLWithString:kSuccessKidURLString];
                    break;
                case 2:
                    url = [NSURL URLWithString:kLotsOfFacesURLString];
                    break;
                case 3:
                    url = [NSURL URLWithString:kBigImageData];
                    break;
                case 4:
                    url = [NSURL URLWithString:kBigImageData2];
                    break;
                default:
                    break;
            }
            dispatch_group_enter(downloadGroup); //2
            
            Photo* photo = [[Photo alloc] initwithURL:url withCompletionBlock:^(UIImage *image, NSError *_error) {
                if (_error) {
                    error = _error;
                }
                dispatch_group_leave(downloadGroup); //3
            }];
            [[PhotoManager sharedManager] addPhoto:photo];
        }

        dispatch_group_notify(downloadGroup,dispatch_get_main_queue(), ^{ //4
            if (completionBlock) {
                completionBlock(error);
            }
        });
}

//*****************************************************************************/
#pragma mark - Private Methods
//*****************************************************************************/

- (void)postContentAddedNotification
{
    static NSNotification *notification = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        notification = [NSNotification notificationWithName:kPhotoManagerAddedContentNotification object:nil];
    });
    
    [[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP coalesceMask:NSNotificationCoalescingOnName forModes:nil];
}

@end
