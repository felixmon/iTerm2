//
//  ProfilePreferencesViewController.h
//  iTerm
//
//  Created by George Nachman on 4/8/14.
//
//

#import "iTermPreferencesBaseViewController.h"
#import "ProfileModel.h"

@class ProfileModel;

// Posted when the name field ends editing in the "get info" dialog. The object is the guid of the
// profile that may have changed.
extern NSString *const kProfileSessionNameDidEndEditing;

// Posted when a session hotkey is changed through Edit Session
extern NSString *const kProfileSessionHotkeyDidChange;

@protocol ProfilePreferencesViewControllerDelegate <NSObject>

- (ProfileModel *)profilePreferencesModel;

@end

@interface ProfilePreferencesViewController : iTermPreferencesBaseViewController

@property(nonatomic, weak) IBOutlet id<ProfilePreferencesViewControllerDelegate> delegate;
@property (nonatomic) BOOL tmuxSession;

// Size of tab view.
@property(nonatomic, readonly) NSSize size;

- (void)layoutSubviewsForEditCurrentSessionMode;

- (Profile *)selectedProfile;

- (void)selectGuid:(NSString *)guid;

- (void)selectFirstProfileIfNecessary;

- (void)changeFont:(id)fontManager;
- (void)selectGeneralTab;

- (void)openToProfileWithGuid:(NSString *)guid selectGeneralTab:(BOOL)selectGeneralTab;
- (void)openToProfileWithGuidAndEditHotKey:(NSString *)guid;
- (void)openToProfileWithGuid:(NSString *)guid andEditComponentWithIdentifier:(NSString *)identifier;

// Update views for changed backing state.
- (void)refresh;

- (void)resizeWindowForCurrentTabAnimated:(BOOL)animated;
- (void)invalidateSavedSize;

@end
