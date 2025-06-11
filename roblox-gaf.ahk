#Requires AutoHotkey v2

; Roblox window needs to be small as possible (800x600)

HWNDs := WinGetList("ahk_exe RobloxPlayerBeta.exe")

CoordMode("Pixel", "Client")
CoordMode("Mouse", "Client")

DllCall("SetProcessDpiAwarenessContext", "ptr", -4)

get_window_coords(window_id) {
    rc := Buffer(16)

    ; GetClientRect fills rc with left, top, right, bottom (in client coords)
    DllCall("GetClientRect", "ptr", window_id, "ptr", rc)

    ; Extract values
    x := NumGet(rc, 0, "int")
    y := NumGet(rc, 4, "int")
    right := NumGet(rc, 8, "int")
    bottom := NumGet(rc, 12, "int")
    width := right
    height := bottom

    dpi := DllCall("GetDpiForWindow", "ptr", window_id, "uint")

    return {x: x, y: y, width: width, height: height, dpi: dpi}
}

show_window_coords(window_id) {
    coords := get_window_coords(window_id)
    x := coords.x
    y := coords.y
    width := coords.width
    height := coords.height
    dpi := coords.dpi
    MsgBox "Client Area (Screen Coords):`nX: " x "`nY: " y "`nW: " width "`nH: " height "`nDPI: " dpi
}

move_mouse_to_coords(location_x, location_y) {
    MouseMove(location_x, location_y + 1)
    Sleep(1) ; Small delay to ensure the mouse moves correctly
    MouseMove(location_x, location_y)
}

move_mouse_to_center(coords) {
    center_x := coords.x + Round(coords.width / 2)
    center_y := coords.y + Round(coords.height / 2)
    move_mouse_to_coords(center_x, center_y)
}

move_mouse_to_top_left() {
    move_mouse_to_coords(0, 0)
}

find_and_buy_item(coords, item) {
    Loop {
        move_mouse_to_center(coords)
        if ImageSearch(
            &TopLeftFoundImageX,
            &TopLeftFoundImageY,
            0,
            0,
            coords.width,
            coords.height,
            Format("*Trans0x4E2C1D *175 {:}.png", item)
        ) {
            ; Open the item to buy it
            move_mouse_to_coords(TopLeftFoundImageX, TopLeftFoundImageY + 19)
            MouseClick("left")
            Sleep(1000) ;
            move_mouse_to_top_left()
            Sleep(500) ;
            break ;
        }
        else {
            Send("{WheelDown}")
            Sleep(500) ;
        }
    }
    Loop {
        if ImageSearch(
            &TopLeftNoStockX,
            &TopLeftNoStockY,
            0,
            0,
            coords.width,
            coords.height,
            "*Trans0x959595 *135 no_stock.png"
        ) {
            Sleep(500) ;
            move_mouse_to_coords(TopLeftNoStockX, TopLeftNoStockY - 50)
            MouseClick("left")
            Sleep(500) ;
            move_mouse_to_top_left()
            Sleep(500) ;
            break ;
        }
        if ImageSearch(
            &TopLeftFoundImageX2,
            &TopLeftFoundImageY2,
            0,
            0,
            coords.width,
            coords.height,
            Format("*Trans0x4E2C1D *175 {:}.png", item)
        ) {
            ; Click the "Buy" button
            move_mouse_to_coords(TopLeftFoundImageX2, TopLeftFoundImageY2 + 159)
            MouseClick("left")
            Sleep(500) ;
            move_mouse_to_top_left()
            Sleep(500) ;
        }
    }
}

F1:: {
    for window_id in HWNDs {
        WinActivate("ahk_id" window_id)
        show_window_coords(window_id)
    }

}

F2:: {
    Pause True  ;
    Suspend True  ;
	Reload ;
} ;

; buy items in store
F3:: {
    Loop {
        for window_id in HWNDs {
            WinActivate("ahk_id" window_id)
            coords := get_window_coords(window_id)
            ; find watering can image (top of the store)
            Loop {
                move_mouse_to_center(coords)
                Send("{WheelUp}")
                Sleep(250) ;
                if ImageSearch(
                    &TopLeftFoundImageX,
                    &TopLeftFoundImageY,
                    0,
                    0,
                    coords.width,
                    coords.height,
                    "*Trans0x4E2C1D *150 watering_can.png"
                ) {
                    ; found, now break so that we can scroll down to find the items we want to buy
                    break
                }
            }
            
            ; find items to buy
            find_and_buy_item(coords, "watering_can")
            find_and_buy_item(coords, "basic_sprinkler")
            find_and_buy_item(coords, "advanced_sprinkler")
            find_and_buy_item(coords, "godly_sprinkler")
            find_and_buy_item(coords, "lightning_rod")
            find_and_buy_item(coords, "master_sprinkler")
        }
    }
}