#Requires AutoHotkey v2
#Include <OCR>

class Config {
    first_item := ""
    items := []

    __New(section) {
        this.load(section)
    }

    load(section) {
        raw := IniRead("config.ini", section)
        for line in StrSplit(raw, "`n") {
            line := Trim(line)
            if (line != "") {
                kv := StrSplit(line, "=")
                k := Trim(kv[1])
                v := Trim(StrSplit(kv[2], ";")[1])
                if (k = "FirstItem") {
                    this.first_item := v
                } else if (k ~= "Item") {
                    this.items.Push(v)
                }
            }
        }
    }
}

seed_shop_config := Config("SeedShop")
gear_shop_config := Config("GearShop")

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


find_text(text, &foundX, &foundY) {
    res := OCR.FromWindow("A")
    try {
        found := res.FindString(text, { SearchFunc: LevenshteinSearchFunc.Bind(1, false) })
        foundX := found.x
        foundY := found.y
        return true
    }
    catch {
        return false
    }
}

F5:: {
    if find_text("Advanced Sprinkler", &foundX, &foundY) {
        MsgBox "Found item at X: " foundX ", Y: " foundY
        MouseMove(foundX, foundY)
    }
}


buy_item(coords, item) {
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
            return ;
        }
    }
}

; buy items in store
buy_items_in_store(config) {
    Loop {
        for window_id in HWNDs {
            WinActivate(window_id)
            coords := get_window_coords(window_id)
            ; find watering can image (top of the store)
            Loop {
                move_mouse_to_center(coords)
                Send("{WheelUp}")
                Sleep(1) ;
                if find_text(config.first_item, &foundX, &foundY) {
                    break ;
                }
            }

            count := 0
            bought_items := Map()
            move_mouse_to_center(coords)
            Sleep(1) ;
            Loop {
                ; find items to buy
                for item in config.items {
                    if (bought_items.Has(item)) {
                        continue ; Skip already bought items
                    }
                    if find_text(item, &foundX, &foundY) {
                        ; Open the item to buy it
                        move_mouse_to_coords(foundX, foundY)
                        MouseClick("left")
                        Sleep(1000) ;
                        buy_item(coords, item)
                        bought_items[item] := true
                    }
                }
                move_mouse_to_center(coords)
                Send("{WheelDown}")
                Sleep(250) ;
                count += 1
                if (count > 20 or bought_items.Count >= config.items.Length) {
                    ; If we have scrolled down too much, break the loop
                    break ;
                }
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
    buy_items_in_store(gear_shop_config)
}

F4:: {
    buy_items_in_store(seed_shop_config)
}
