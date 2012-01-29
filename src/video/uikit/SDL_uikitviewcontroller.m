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

#ifdef SDL_IOS_JOY_EXT
#import "BTstack/BTDevice.h"
#import "BTstack/btstack.h"
#import "BTstack/run_loop.h"
#import "BTstack/hci_cmds.h"
static BTDevice *device;
static uint16_t wiiMoteConHandle = 0;

#endif

@implementation SDL_uikitviewcontroller

@synthesize window;
#if SDL_IOS_JOY_EXT
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
#if SDL_IOS_JOY_EXT


- (void)viewWillAppear:(BOOL)animated {
    //ICADE
    control = [[iCadeReaderView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:control];
    control.active = YES;
    control.delegate = self;
    [control release];    
    //WIIMOTE
    // create discovery controller
	discoveryView = [[BTDiscoveryViewController alloc] init];
	[discoveryView setDelegate:self];
    [self.view addSubview:discoveryView.view];
    discoveryView.view.hidden=TRUE;
    // BTstack
	BTstackManager * bt = [BTstackManager sharedInstance];
	[bt setDelegate:self];
	[bt addListener:self];
	[bt addListener:discoveryView];
    
	BTstackError err = [bt activate];
	if (err) NSLog(@"activate err 0x%02x!", err);
	
}

- (void)viewWillDisappear:(BOOL)animated {
    control.active = NO;
    [control removeFromSuperview];
}



/****************************************************/
/****************************************************/
/*        ICADE                                     */
/****************************************************/
/****************************************************/

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

/****************************************************/
/****************************************************/
/*        BTSTACK / WIIMOTE                         */
/****************************************************/
/****************************************************/

-(void) activatedBTstackManager:(BTstackManager*) manager {
	NSLog(@"activated!");
	[[BTstackManager sharedInstance] startDiscovery];
}

-(void) btstackManager:(BTstackManager*)manager deviceInfo:(BTDevice*)newDevice {
	NSLog(@"Device Info: addr %@ name %@ COD 0x%06x", [newDevice addressString], [newDevice name], [newDevice classOfDevice] ); 
	if ([newDevice name] && [[newDevice name] caseInsensitiveCompare:@"Nintendo RVL-CNT-01"] == NSOrderedSame){
		NSLog(@"WiiMote found with address %@", [newDevice addressString]);
		device = newDevice;
		[[BTstackManager sharedInstance] stopDiscovery];
	}
}

-(void) discoveryStoppedBTstackManager:(BTstackManager*) manager {
	NSLog(@"discoveryStopped!");
	// connect to device
	bt_send_cmd(&l2cap_create_channel, [device address], 0x13);
}


// direct access
-(void) btstackManager:(BTstackManager*) manager
  handlePacketWithType:(uint8_t) packet_type
			forChannel:(uint16_t) channel
			   andData:(uint8_t *)packet
			   withLen:(uint16_t) size
{
	bd_addr_t event_addr;
	
	switch (packet_type) {
			
		case L2CAP_DATA_PACKET:
			if (packet[0] == 0xa1 && packet[1] == 0x31){
				//bt_data_cb(packet[4], packet[5], packet[6]);
			}
			break;
			
		case HCI_EVENT_PACKET:
			
			switch (packet[0]){
					
				case L2CAP_EVENT_CHANNEL_OPENED:
					if (packet[2] == 0) {
						// inform about new l2cap connection
						bt_flip_addr(event_addr, &packet[3]);
						uint16_t psm = READ_BT_16(packet, 11); 
						uint16_t source_cid = READ_BT_16(packet, 13); 
						wiiMoteConHandle = READ_BT_16(packet, 9);
						NSLog(@"Channel successfully opened: handle 0x%02x, psm 0x%02x, source cid 0x%02x, dest cid 0x%02x",
							  wiiMoteConHandle, psm, source_cid,  READ_BT_16(packet, 15));
						if (psm == 0x13) {
							// interupt channel openedn succesfully, now open control channel, too.
							bt_send_cmd(&l2cap_create_channel, event_addr, 0x11);
						} else {
							// request acceleration data.. 
							uint8_t setMode31[] = { 0x52, 0x12, 0x00, 0x31 };
							bt_send_l2cap( source_cid, setMode31, sizeof(setMode31));
							uint8_t setLEDs[] = { 0x52, 0x11, 0x10 };
							bt_send_l2cap( source_cid, setLEDs, sizeof(setLEDs));
							
							// start demo
							//[self startDemo];
						}
					}
					break;
					
				default:
					break;
			}
			break;
			
		default:
			break;
	}
	
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
