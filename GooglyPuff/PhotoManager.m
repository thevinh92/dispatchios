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


//1. Since you’re using the synchronous dispatch_group_wait which blocks the current thread, you use dispatch_async to place the entire method into a background queue to ensure you don’t block the main thread.
//2. This creates a new dispatch group which behaves somewhat like a counter of the number of uncompleted tasks.
//3. dispatch_group_enter manually notifies a group that a task has started. You must balance out the number of dispatch_group_enter calls with the number of dispatch_group_leave calls or else you’ll experience some weird crashes.
//4. Here you manually notify the group that this work is done. Again, you’re balancing all group enters with an equal amount of group leaves.
//5. dispatch_group_wait waits until either all of the tasks are complete or until the time expires. If the time expires before all events complete, the function will return a non-zero result. You could put this into a conditional block to check if the waiting period expired; however, in this case you specified for it to wait forever by supplying DISPATCH_TIME_FOREVER. This means, unsurprisingly, it’ll wait, forever! That’s fine, because the completion of the photos creation will always complete.
//6. At this point, you are guaranteed that all image tasks have either completed or timed out. You then make a call back to the main queue to run your completion block. This will append work onto the main thread to be executed at some later time.
//7. Finally, check if the completion block is nil, and if not, run the completion block.

- (void)downloadPhotosWithCompletionBlock:(BatchPhotoDownloadingCompletionBlock)completionBlock
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{ //1
        __block NSError* error;
        dispatch_group_t downloadGroup = dispatch_group_create(); //2
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
            dispatch_group_enter(downloadGroup); //3
            Photo* photo = [[Photo alloc] initwithURL:url withCompletionBlock:^(UIImage *image, NSError *_error) {
                if (_error) {
                    error = _error;
                }
                dispatch_group_leave(downloadGroup); //4
            }];
            [[PhotoManager sharedManager] addPhoto:photo];
        }
        dispatch_group_wait(downloadGroup, DISPATCH_TIME_FOREVER); //5
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionBlock) {
                completionBlock(error);
            }
        });
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
