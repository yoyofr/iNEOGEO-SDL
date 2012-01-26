/*
  Simple DirectMedia Layer
  Copyright (C) 1997-2012 Sam Lantinga <slouken@libsdl.org>

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
*/
#include "SDL_config.h"

#if SDL_VIDEO_DRIVER_UIKIT

#include "SDL_video.h"
#include "SDL_assert.h"
#include "SDL_hints.h"
#include "../SDL_sysvideo.h"
#include "../../events/SDL_events_c.h"

#include "SDL_uikitwindow.h"
#include "SDL_uikitviewcontroller.h"
#include "SDL_uikitvideo.h"

@implementation SDL_uikitviewcontroller

@synthesize window;
#if SDL_ICADE
@synthesize control;
#endif

- (id)initWithSDLWindow:(SDL_Window *)_window
{
    self = [self init];
    if (self == nil) {
        return nil;
    }
    self.window = _window;

    
    return self;
}
#if SDL_ICADE
- (void)viewWillAppear:(BOOL)animated {
    control = [[iCadeReaderView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:control];
    control.active = YES;
    control.delegate = self;
    [control release];    
}

- (void)viewWillDisappear:(BOOL)animated {
    control.active = NO;
    [control removeFromSuperview];
}

#endif
#if SDL_ICADE
- (void)setState:(BOOL)state forButton:(iCadeState)button {
    switch (button) {
        case iCadeButtonA:
            SDL_SendKeyboardKey((state?SDL_PRESSED:SDL_RELEASED), SDL_SCANCODE_1);
            break;
        case iCadeButtonB:
            SDL_SendKeyboardKey((state?SDL_PRESSED:SDL_RELEASED), SDL_SCANCODE_2);
            break;
        case iCadeButtonC:
            SDL_SendKeyboardKey((state?SDL_PRESSED:SDL_RELEASED), SDL_SCANCODE_3);
            break;
        case iCadeButtonD:
            SDL_SendKeyboardKey((state?SDL_PRESSED:SDL_RELEASED), SDL_SCANCODE_4);
            break;
        case iCadeButtonE:
            SDL_SendKeyboardKey((state?SDL_PRESSED:SDL_RELEASED), SDL_SCANCODE_5);
            break;
        case iCadeButtonF:
            SDL_SendKeyboardKey((state?SDL_PRESSED:SDL_RELEASED), SDL_SCANCODE_6);
            break;
        case iCadeButtonG:
            SDL_SendKeyboardKey((state?SDL_PRESSED:SDL_RELEASED), SDL_SCANCODE_7);
            break;
        case iCadeButtonH:
            SDL_SendKeyboardKey((state?SDL_PRESSED:SDL_RELEASED), SDL_SCANCODE_8);
            break;
        case iCadeJoystickUp:
            SDL_SendKeyboardKey((state?SDL_PRESSED:SDL_RELEASED), SDL_SCANCODE_U);
            break;
        case iCadeJoystickRight:
            SDL_SendKeyboardKey((state?SDL_PRESSED:SDL_RELEASED), SDL_SCANCODE_R);
            break;
        case iCadeJoystickDown:
            SDL_SendKeyboardKey((state?SDL_PRESSED:SDL_RELEASED), SDL_SCANCODE_D);
            break;
        case iCadeJoystickLeft:
            SDL_SendKeyboardKey((state?SDL_PRESSED:SDL_RELEASED), SDL_SCANCODE_L);
            break;            
        default:
            break;
    }
}

- (void)buttonDown:(iCadeState)button {
    [self setState:YES forButton:button];
}

- (void)buttonUp:(iCadeState)button {
    [self setState:NO forButton:button];    
}

#endif

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orient
{
    const char *orientationsCString;
    if ((orientationsCString = SDL_GetHint(SDL_HINT_ORIENTATIONS)) != NULL) {
        BOOL rotate = NO;
        NSString *orientationsNSString = [NSString stringWithCString:orientationsCString
                                                            encoding:NSUTF8StringEncoding];
        NSArray *orientations = [orientationsNSString componentsSeparatedByCharactersInSet:
                                 [NSCharacterSet characterSetWithCharactersInString:@" "]];

        switch (orient) {
            case UIInterfaceOrientationLandscapeLeft:
                rotate = [orientations containsObject:@"LandscapeLeft"];
                break;

            case UIInterfaceOrientationLandscapeRight:
                rotate = [orientations containsObject:@"LandscapeRight"];
                break;

            case UIInterfaceOrientationPortrait:
                rotate = [orientations containsObject:@"Portrait"];
                break;

            case UIInterfaceOrientationPortraitUpsideDown:
                rotate = [orientations containsObject:@"PortraitUpsideDown"];
                break;

            default: break;
        }

        return rotate;
    }

    if (self->window->flags & SDL_WINDOW_RESIZABLE) {
        return YES;  // any orientation is okay.
    }

    // If not resizable, allow device to orient to other matching sizes
    //  (that is, let the user turn the device upside down...same screen
    //   dimensions, but it lets the user place the device where it's most
    //   comfortable in relation to its physical buttons, headphone jack, etc).
    switch (orient) {
        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationLandscapeRight:
            return (self->window->w >= self->window->h);

        case UIInterfaceOrientationPortrait:
        case UIInterfaceOrientationPortraitUpsideDown:
            return (self->window->h >= self->window->w);

        default: break;
    }

    return NO;  // Nothing else is acceptable.
}

- (void)loadView
{
    // do nothing.
}


// Send a resized event when the orientation changes.
- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    const UIInterfaceOrientation toInterfaceOrientation = [self interfaceOrientation];
    SDL_WindowData *data = self->window->driverdata;
    UIWindow *uiwindow = data->uiwindow;
    UIScreen *uiscreen;
    if (SDL_UIKit_supports_multiple_displays)
        uiscreen = [uiwindow screen];
    else
        uiscreen = [UIScreen mainScreen];
    const int noborder = (self->window->flags & (SDL_WINDOW_FULLSCREEN|SDL_WINDOW_BORDERLESS));
    CGRect frame = noborder ? [uiscreen bounds] : [uiscreen applicationFrame];
    const CGSize size = frame.size;
    int w, h;

    switch (toInterfaceOrientation) {
        case UIInterfaceOrientationPortrait:
        case UIInterfaceOrientationPortraitUpsideDown:
            w = (size.width < size.height) ? size.width : size.height;
            h = (size.width > size.height) ? size.width : size.height;
            break;

        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationLandscapeRight:
            w = (size.width > size.height) ? size.width : size.height;
            h = (size.width < size.height) ? size.width : size.height;
            break;

        default:
            SDL_assert(0 && "Unexpected interface orientation!");
            return;
    }

    [uiwindow setFrame:frame];
    [data->view setFrame:frame];
    [data->view updateFrame];
    SDL_SendWindowEvent(self->window, SDL_WINDOWEVENT_RESIZED, w, h);
}

#endif /* SDL_VIDEO_DRIVER_UIKIT */

@end
