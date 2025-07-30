#Requires AutoHotkey v2
#Include <OCR>

class Config {
    first_item := ""
    items := []

    __New(section) {
        this.load(section)
    }
    
    /**
     * @description
     * Loads the configuration from the specified section.
     * @param {string} section The section to load.
     */
    load(section) {
        raw := IniRead("config.ini", section)
        for line in StrSplit(raw, "`n") {
            line := Trim(line)
            if (line = "") {
                continue ; Skip empty lines and comments
            }
            kv := StrSplit(line, "=")
            if (kv.Length < 2) {
                continue ; Skip lines that do not have a key-value pair
            }
            k := Trim(kv[1])
            v := Trim(StrSplit(kv[2], ";")[1]) ; ignore comments after semicolon in value
            if (k = "FirstItem") {
                this.first_item := v
            } else if (k ~= "Item") {
                this.items.Push(v)
            }
        }
    }
}

HWNDs := WinGetList("ahk_exe RobloxPlayerBeta.exe")

CoordMode("Pixel", "Client")
CoordMode("Mouse", "Client")

; Use Windows 10 DPI awareness https://learn.microsoft.com/en-us/windows/win32/hidpi/dpi-awareness-context
DllCall("SetProcessDpiAwarenessContext", "ptr", -4)

/**
 * @description
 * Gets the coordinates of the client area of a window.
 * @param {Integer} window_id
 * The ID of the window to get the coordinates for.
 * @returns {Object}
 * An object containing the x, y, w, h, and dpi of the client area.
 */
get_window_coords(window_id) {
    rc := Buffer(16)

    ; GetClientRect fills rc with left, top, right, bottom (in client coords)
    DllCall("GetClientRect", "ptr", window_id, "ptr", rc)

    ; Extract values
    x := NumGet(rc, 0, "int")
    y := NumGet(rc, 4, "int")
    right := NumGet(rc, 8, "int")
    bottom := NumGet(rc, 12, "int")
    w := right
    h := bottom

    dpi := DllCall("GetDpiForWindow", "ptr", window_id, "uint")

    return {x: x, y: y, w: w, h: h, dpi: dpi}
}

/**
 * @description
 * Displays the coordinates of the client area of the specified window.
 * @param {Integer} window_id
 * The ID of the window to get the coordinates for.
 */
show_window_coords(window_id) {
    coords := get_window_coords(window_id)
    x := coords.x
    y := coords.y
    w := coords.w
    h := coords.h
    dpi := coords.dpi
    MsgBox "Client Area (Screen Coords):`nX: " x "`nY: " y "`nW: " w "`nH: " h "`nDPI: " dpi
}

/**
 * @description
 * Moves the mouse to the specified coordinates.
 * @param {Integer} location_x
 * The X coordinate to move the mouse to.
 * @param {Integer} location_y
 * The Y coordinate to move the mouse to.
 */
move_mouse_to_coords(location_x, location_y) {
    MouseMove(location_x, location_y + 1)
    Sleep(1) ; Small delay to ensure the mouse moves correctly
    MouseMove(location_x, location_y)
}

/**
 * @description
 * Moves the mouse to the center of the client window.
 * @param {Object} coords
 * An object containing the coordinates of the window.
 * @see {@link get_window_coords}
 */
move_mouse_to_center(coords) {
    center_x := coords.x + Round(coords.w / 2)
    center_y := coords.y + Round(coords.h / 2)
    move_mouse_to_coords(center_x, center_y)
}

/**
 * @description
 * Moves the mouse to the top-left corner of the client window.
 */
move_mouse_to_top_left() {
    move_mouse_to_coords(0, 0)
}

LevenshteinSearchFunc(maxDistance, caseSense, haystack, needle, &foundstr) {
    if StrLen(haystack) < StrLen(needle)
        return 0
    needleLen := StrLen(needle)

    Loop StrLen(haystack) - StrLen(needle) + 1 {
        firstChar := SubStr(haystack, A_Index, 1)
        if firstChar ~= "\s"
            continue

        str := SubStr(haystack, A_Index, needleLen)
        if LD(str, needle, caseSense) <= maxDistance {
            foundstr := str
            return A_index
        }
    }
    return 0
}

; Credit: iPhilip, Source: https://www.autohotkey.com/boards/viewtopic.php?style=17&p=509167#p509167
; https://en.wikipedia.org/wiki/Levenshtein_distance#Iterative_with_two_matrix_rows
LD(Source, Target, CaseSense := True) {
    if CaseSense ? Source == Target : Source = Target
        return 0
    Source := StrSplit(Source)
    Target := StrSplit(Target)
    if !Source.Length
        return Target.Length
    if !Target.Length
        return Source.Length

    v0 := [], v1 := []
    loop Target.Length + 1
        v0.Push(A_Index - 1)
    v1.Length := v0.Length

    for Index, SourceChar in Source {
        v1[1] := Index
        for TargetChar in Target
            v1[A_Index + 1] := Min(v1[A_Index] + 1, v0[A_Index + 1] + 1, v0[A_Index] + (CaseSense ? SourceChar !==
                TargetChar : SourceChar != TargetChar))
        loop Target.Length + 1
            v0[A_Index] := v1[A_Index]
    }
    return v1[Target.Length + 1]
}


/**
 * @description 
 * Finds a string in the current active window using OCR (Optical Character Recognition).
 * @param {String} text
 * The text to search for in the active window.
 * @param {Integer} foundX
 * The X coordinate where the text was found, passed by reference.
 * @param {Integer} foundY
 * The Y coordinate where the text was found, passed by reference.
 * @returns {Boolean}
 * Returns true if the text was found, false otherwise.
 */
find_text(text, coords, &foundX, &foundY) {
    res := OCR.FromWindow("A", {
        x: coords.x,
        y: coords.y,
        w: coords.w,
        h: coords.h,
    })
    try {
        found := res.FindString(text, {
            SearchFunc: LevenshteinSearchFunc.Bind(1, false),
        })
        foundX := found.x
        foundY := found.y
        return true
    }
    catch {
        return false
    }
}

/**
 * @description
 * Buys an item in the game by clicking the buy button until the stock is depleted.
 * @param {Object} coords
 * An object containing the coordinates of the window.
 */
buy_item(coords) {
    Loop {
        ; We have to search for the buy button every time before we click it to monitor if it changes to no more stock
        if ImageSearch(
            &BuyButtonX,
            &BuyButtonY,
            coords.x,
            coords.y,
            coords.w,
            coords.h,
            "*TransWhite *50 buy_button.png"
        ) {
            ; Click the "Buy" button
            move_mouse_to_coords(BuyButtonX + 15, BuyButtonY + 15)
            MouseClick("left")
            Sleep(500) ;
        }
        else {
            ; If we can't find the buy button, break the loop
            return ;
        }
    }
}

/**
 * @description
 * Buys items in the store by scrolling through the list and clicking on each item.
 * @param {string} config_name
 * The configuration object name from ini containing the items to buy and the first item to scroll to.
 */
buy_items_in_store(config_name) {
    config_ := Config(config_name)
    Loop {
        for window_id in HWNDs {
            WinActivate(window_id)
            coords := get_window_coords(window_id)
            ; find first item in store and break, this signifies top of the store list
            shop_coords := {
                x: coords.x + 200, ; Adjust to remove the left side (containing shop button)
                y: coords.y + 130, ; Adjust to remove the top side (containing the teleport buttons)
                w: coords.w - 130, ; Adjust to remove the right side (containing the pet buttons), for consistency to match shop_y
                h: coords.h - 85, ; Adjust to remove the bottom side (containing the hotbar)
            }
            Loop {
                move_mouse_to_center(coords)
                Send("{WheelUp}")
                Sleep(1) ;
                if find_text(config_.first_item, shop_coords, &foundX, &foundY) {
                    break ;
                }
            }

            scroll_count := 0
            bought_items := Map()
            move_mouse_to_center(coords)
            Sleep(1) ;
            Loop {
                ; find items to buy each time we scroll, then record it as being bought
                for item in config_.items {
                    if (bought_items.Has(item)) {
                        continue ; Skip already bought items
                    }
                    if find_text(item, shop_coords, &foundX, &foundY) {
                        ; Open the item to buy it
                        move_mouse_to_coords(foundX, foundY)
                        MouseClick("left")
                        Sleep(1000) ;
                        buy_item(shop_coords)
                        bought_items[item] := true
                        scroll_count := 0 ; Reset count after successfully buying an item
                    }
                }
                move_mouse_to_center(coords)
                Send("{WheelDown}")
                Sleep(250) ;
                scroll_count += 1
                if (scroll_count > 20 or bought_items.Count >= config_.items.Length) {
                    ; If we have scrolled down too much, break the loop
                    break ;
                }
            }
        }
    }
}

/**
 * @description
 * Iterates through all Roblox windows and shows their client area coordinates.
 * This is useful for debugging.
 */
F1:: {
    for window_id in HWNDs {
        WinActivate(window_id)
        show_window_coords(window_id)
    }
}

/**
 * @description
 * Pauses the script, suspends it, and reloads the script.
 * This is useful when changing settings or stopping the script.
 */
F2:: {
    Pause True  ;
    Suspend True  ;
    Reload ;
}

/**
 * @description
 * Buys items in the gear store by scrolling through the list and clicking on each item.
 */
F3:: {
    buy_items_in_store("GearShop")
}

/**
 * @description
 * Buys items in the seed store by scrolling through the list and clicking on each item.
 */
F4:: {
    buy_items_in_store("SeedShop")
}

/**
 * @description
 * Buys items in the seed store by scrolling through the list and clicking on each item.
 */
F5:: {
    buy_items_in_store("EggShop")
}

; for debugging purposes, uncomment to find a specific item
; F5:: {
;     if find_text("Advanced Sprinkler", &foundX, &foundY) {
;         MsgBox "Found item at X: " foundX ", Y: " foundY
;         MouseMove(foundX, foundY)
;     }
; }