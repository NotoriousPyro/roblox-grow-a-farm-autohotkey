#Requires AutoHotkey v2
#Include <OCR>

; Roblox window needs to be small as possible (800x600)

; shop items must be in the same order as they appear in the shop

; gear shop items
first_gear_shop_item := "Watering Can" ; first item in the gear shop
gear_shop_items := [
    "Watering Can",
    "Trowel",
    "Recall Wrench",
    "Basic Sprinkler",
    "Advanced S", ; "Advanced Sprinkler - using Advanced S to avoid OCR issues with the full word"
    "Godly Sprinkler",
    "Lightning Rod",
    "Master Sprinkler"
]

first_seed_shop_item := "Carrot" ; first item in the seed shop
; seed shop items
seed_shop_items := [
    ; "Carrot",
    ; "Strawberry",
    ; "Blueberry",
    ; "Orange Tulip",
    ; "Tomato",
    ; "Corn",
    ; "Daffodil",
    ; "Watermelon",
    ; "Pumpkin",
    ; "Apple",
    ; "Bamboo",
    ; "Coconut",
    ; "Cactus",
    ; "Dragon Fruit",
    ; "Mango",
    "Grape",
    "Mushroom",
    "Pepper",
    "Cacao",
    "Beanstalk",
    "Ember Lily",
    "Sugar Apple",
]

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

find_text(text, &foundX, &foundY) {
    res := OCR.FromWindow("A")
    try {
        found := res.FindString(text)
        foundX := found.x
        foundY := found.y
        return true
    }
    catch {
        return false
    }
}

find_and_buy_item(coords, item) {
    count := 0
    move_mouse_to_center(coords)
    Sleep(1) ;
    Loop {
        if find_text(item, &foundX, &foundY) {
            ; Open the item to buy it
            move_mouse_to_coords(foundX, foundY)
            MouseClick("left")
            Sleep(1000) ;
            break ;
        }
        else {
            move_mouse_to_center(coords)
            Send("{WheelDown}")
            Sleep(250) ;
            count += 1
            if (count > 20) {
                ; If we have scrolled down too much, break the loop
                return ;
            }
        }
    }
    Loop {
        if ImageSearch(
            &BuyButtonX,
            &BuyButtonY,
            0,
            0,
            coords.width,
            coords.height,
            "*TransWhite *50 buy_button.png"
        ) {
            ; Click the "Buy" button
            move_mouse_to_coords(BuyButtonX + 15, BuyButtonY + 15)
            MouseClick("left")
            Sleep(500) ;
        }
        else {
            ; If we can't find the buy button, break the loop
            break ;
        }
    }
}

; buy items in store
buy_items_in_store(store_items, first_item_in_store) {
    Loop {
        for window_id in HWNDs {
            WinActivate(window_id)
            coords := get_window_coords(window_id)
            ; find watering can image (top of the store)
            Loop {
                move_mouse_to_center(coords)
                Send("{WheelUp}")
                Sleep(1) ;
                if find_text(first_item_in_store, &foundX, &foundY) {
                    break ;
                }
            }
            
            ; find items to buy
            for item in store_items {
                find_and_buy_item(coords, item)
            }
        }
    }
}

F1:: {
    for window_id in HWNDs {
        WinActivate(window_id)
        show_window_coords(window_id)
    }
}

F2:: {
    Pause True  ;
    Suspend True  ;
	Reload ;
}

F3:: {
    buy_items_in_store(gear_shop_items, first_gear_shop_item)
}

F4:: {
    buy_items_in_store(seed_shop_items, first_seed_shop_item)
}
