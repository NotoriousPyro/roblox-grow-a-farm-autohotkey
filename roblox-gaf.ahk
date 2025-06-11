#Requires AutoHotkey v2

HWNDs := WinGetList("ahk_exe RobloxPlayerBeta.exe")

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

scale_coords(coords, location_x, location_y) {
    scaled_x := coords.x + Round((location_x / 800) * coords.width)
    scaled_y := coords.y + Round((location_y / 600) * coords.height)
    return {x: scaled_x, y: scaled_y}
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

find_and_buy_item(coords, item) {
    Loop {
        Send("{WheelDown}")
        Sleep(1000) ;
        if ImageSearch(
            &TopLeftFoundImageX,
            &TopLeftFoundImageY,
            0,
            0,
            coords.width,
            coords.height,
            Format("*Trans0x4E2C1D *150 {:}.png", item)
        ) {
            ; Open the item to buy it
            MouseMove(TopLeftFoundImageX, TopLeftFoundImageY + 19)
            Sleep(1000) ;
            MouseMove(TopLeftFoundImageX, TopLeftFoundImageY + 20)
            Sleep(1000) ;
            MouseClick("left")
            Sleep(1000) ;
            MouseMove(290, 388) ; Move to the "Buy" button
            Loop {
                if ImageSearch(
                    &TopLeftFoundImageX,
                    &TopLeftFoundImageY,
                    0,
                    0,
                    coords.width,
                    coords.height,
                    "*Trans0x6B6B6C *150 no_stock.png"
                ) {
                    Sleep (1000) ;
                    MouseMove(405, 275) ; Move back to the sprinkler
                    Sleep(1000) ;
                    MouseMove(405, 276)
                    MouseClick("left") ; Close the item
                    break
                }
                MouseClick("left") ;
                Sleep (1000) ;
            }
            break
        }
    }
}

F1:: {
    for window_id in HWNDs {
        WinActivate("ahk_id " window_id)
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
    for window_id in HWNDs {
        WinActivate("ahk_id " window_id)
        coords := get_window_coords(window_id)
        location_x := 400
        location_y := 300
        ;scaled_coords := scale_coords(coords, location_x, location_y)
        MouseMove(400, 300, 1)
        MouseMove(400, 301. 1)
        ; find watering can image (top of the store)
        Loop {
            Send("{WheelUp}")
            Sleep (50) ;
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
        
        ; find sprinklers
        find_and_buy_item(coords, "basic_sprinkler")
    }
}