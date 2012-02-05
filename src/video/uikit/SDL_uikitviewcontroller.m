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
#import "BTstack/wiimote.h"
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
    
/*	BTstackError err = [bt activate];
	if (err) NSLog(@"activate err 0x%02x!", err);*/
	
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

void startWiimoteDetection(void) {
    NSLog(@"Looking for wiimote");
    
    BTstackManager * bt = [BTstackManager sharedInstance];
    BTstackError err = [bt activate];
	if (err) NSLog(@"activate err 0x%02x!", err);
}

void stopWiimoteDetection(void) {
    NSLog(@"Stop looking for wiimote");
	[[BTstackManager sharedInstance] stopDiscovery];
}


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
	if (device) bt_send_cmd(&l2cap_create_channel, [device address], 0x13);
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
            
        case L2CAP_DATA_PACKET://0x06
        {
            struct wiimote_t *wm = NULL; 
            
            wm = wiimote_get_by_source_cid(channel);
            
            if(wm!=NULL)
            {
                
                byte* msg = packet + 2;
                byte event = packet[1];
                
                switch (event) {
                    case WM_RPT_BTN:
                    {
                        /* button */
                        wiimote_pressed_buttons(wm, msg);
                        break;
                    }
                    case WM_RPT_READ:
                    {
                        /* data read */
                        
                        if(WIIMOTE_DBG)printf("WM_RPT_READ data arrive!\n");
                        
                        wiimote_pressed_buttons(wm, msg);
                        
                        byte err = msg[2] & 0x0F;
                        
                        if (err == 0x08)
                            printf("Unable to read data - address does not exist.\n");
                        else if (err == 0x07)
                            printf("Unable to read data - address is for write-only registers.\n");
                        else if (err)
                            printf("Unable to read data - unknown error code %x.\n", err);
                        
                        unsigned short offset = BIG_ENDIAN_SHORT(*(unsigned short*)(msg + 3));
                        
                        byte len = ((msg[2] & 0xF0) >> 4) + 1;
                        
                        byte *data = (msg + 5);
                        
                        if(WIIMOTE_DBG)
                        {
                            int i = 0;
                            printf("Read: 0x%04x ; ",offset);
                            for (; i < len; ++i)
                                printf("%x ", data[i]);
                            printf("\n");
                        }
                        
                        if(wiimote_handshake(wm,WM_RPT_READ,data,len))
                        {
                            //btUsed = 1;                                                    
                            //                            [inqViewControl showConnected:nil];
                            //                            [inqViewControl showConnecting:nil];
                            //Create UIAlertView alert
                            //                            [inqViewControl showConnecting:nil];
                            
/*                            UIAlertView* alert = 
                            [[UIAlertView alloc] initWithTitle:@"Connection detected!"
                                                       message: [NSString stringWithFormat:@"%@ '%@' connection sucessfully completed!",
                                                                 (wm->exp.type != EXP_NONE ? @"Classic Controller" : @"WiiMote"),
                                                                 [NSNumber numberWithInt:(wm->unid)+1]]        
                                                      delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles: nil];
                            [alert show];                                           
                            //[alert dismissWithClickedButtonIndex:0 animated:TRUE];                                           
                            [alert release];
                            */
                            if(device!=nil)
                            {
                                [device setConnectionState:kBluetoothConnectionConnected];
                                device = nil;
                            }
                            [[BTstackManager sharedInstance] startDiscovery];
                        }										
                        
                        return;
                    }
                    case WM_RPT_CTRL_STATUS:
                    {
                        wiimote_pressed_buttons(wm, msg);
                        
                        /* find the battery level and normalize between 0 and 1 */
                        if(WIIMOTE_DBG)
                        {
                            wm->battery_level = (msg[5] / (float)WM_MAX_BATTERY_CODE);
                            
                            printf("BATTERY LEVEL %d\n", wm->battery_level);
                        }
                        
                        //handshake stuff!
                        if(wiimote_handshake(wm,WM_RPT_CTRL_STATUS,msg,-1))
                        {
                            //btUsed = 1;                                                    
                            //                            [inqViewControl showConnected:nil];
                            //                            [inqViewControl showConnecting:nil];
/*                            UIAlertView* alert = 
                            [[UIAlertView alloc] initWithTitle:@"Connection detected!"
                                                       message: [NSString stringWithFormat:@"WiiMote '%@' connection sucessfully completed!",[NSNumber numberWithInt:(wm->unid)+1]]        
                                                      delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles: nil];
                            [alert show];                                           
                            //[alert dismissWithClickedButtonIndex:0 animated:TRUE];                                           
                            [alert release];*/
                            [device setConnectionState:kBluetoothConnectionConnected];
                            
                            if(device!=nil)
                            {
                                [device setConnectionState:kBluetoothConnectionConnected];
                                device = nil;
                            }
                            [[BTstackManager sharedInstance] startDiscovery];
                        }
                        
                        return;
                    }
                    case WM_RPT_BTN_EXP:
                    {
                        /* button - expansion */
                        wiimote_pressed_buttons(wm, msg);
                        wiimote_handle_expansion(wm, msg+2);
                        
                        break;
                    }
                    case WM_RPT_WRITE:
                    {
                        /* write feedback - safe to skip */
                        break;
                    }
                    default:
                    {
                        printf("Unknown event, can not handle it [Code 0x%x].", event);
                        return;
                    }
                }                   
            }                                                                 
            break;
        }
        case HCI_EVENT_PACKET://0x04
        {
            switch (packet[0]){
                    
                case L2CAP_EVENT_CHANNEL_OPENED:
                    
                    // data: event (8), len(8), status (8), address(48), handle (16), psm (16), local_cid(16), remote_cid (16)                                         
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
                            if(WIIMOTE_DBG)printf("open control channel\n");
                            bt_send_cmd(&l2cap_create_channel, event_addr, 0x11);
                            struct wiimote_t *wm = NULL;  
                            wm = &joys[num_of_joys];
                            memset(wm, 0, sizeof(struct wiimote_t));
                            wm->unid = num_of_joys;                                                        
                            wm->i_source_cid = source_cid;
                            memcpy(&wm->addr,&event_addr,BD_ADDR_LEN);
                            if(WIIMOTE_DBG)printf("addr %02x:%02x:%02x:%02x:%02x:%02x\n", wm->addr[0], wm->addr[1], wm->addr[2],wm->addr[3], wm->addr[4], wm->addr[5]);                                                    
                            if(WIIMOTE_DBG)printf("saved 0x%02x  0x%02x\n",source_cid,wm->i_source_cid);
                            wm->exp.type = EXP_NONE;
                            
                        } else {
                            
                            //inicializamos el wiimote!   
                            struct wiimote_t *wm = NULL;  
                            wm = &joys[num_of_joys];                                                                                                                                                                  
                            wm->wiiMoteConHandle = wiiMoteConHandle; 
                            wm->c_source_cid = source_cid;                                                           
                            wm->state = WIIMOTE_STATE_CONNECTED;
                            num_of_joys++;
                            if(WIIMOTE_DBG)printf("Devices Number: %d\n",num_of_joys);
                            wiimote_handshake(wm,-1,NULL,-1);                                                                                                                                                                                                                                                                      
                        }
                    }
                    break;
                case L2CAP_EVENT_CHANNEL_CLOSED:
                {                                
                    // data: event (8), len(8), channel (16)                                                                                       
                    uint16_t  source_cid = READ_BT_16(packet, 2);                                              
                    NSLog(@"Channel successfully closed: cid 0x%02x",source_cid);
                    
                    bd_addr_t addr;
                    int unid = wiimote_remove(source_cid,&addr);
                    if(unid!=-1)
                    {
                        //                        [inqViewControl removeDeviceForAddress:&addr];
                        UIAlertView* alert = 
                        [[UIAlertView alloc] initWithTitle:@"Disconnection!"
                                                   message:[NSString stringWithFormat:@"WiiMote '%@' disconnection detected.\nIs battery drainned?",[NSNumber numberWithInt:(unid+1)]] 
                                                  delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles: nil];
                        [alert show];                                           
                        
                        [alert release];
                    }
                    
                }
                    break;                                        
                    
                default:
                    break;
            }
            break;
        }
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
