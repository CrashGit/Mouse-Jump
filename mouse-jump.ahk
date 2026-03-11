#Requires AutoHotkey v2.1-a
#Include ..\..\lib\Gdip_All.ahk

class MouseJump {
    static Call(*) {
        this.__CreatePreview()
    }

    static Hide() {
        this.Preview.Hide()
        this.image.Value := ''  ; don't remove
    }

    static __PreviewVisible {
        get {
            DetectHiddenWindows(false)
            return WinExist('ahk_id' this.Preview.Hwnd)
        }
    }

    static __isMouseOnPreview {
        get {
            MouseGetPos(,, &win)
            return win = this.Preview.Hwnd
        }
    }

    static __New() {
        Preview := Gui('+AlwaysOnTop +ToolWindow -SysMenu -Caption +E0x80000 +E0x02000000')
        Preview.MarginX := Preview.MarginY := 0
        this.image := Preview.AddPicture()
        Preview.Show('NoActivate Hide')
        this.Preview := Preview
        this._pToken := Gdip_Startup()

        SetupHotkeys()

        OnExit((*) {
            Gdip_Shutdown(this._pToken)
            return 0
        })

        SetupHotkeys() {
            HotIf((*) => this.__PreviewVisible)
            Hotkey('*LButton', (*) {
                if !this.__isMouseOnPreview {
                    this.Hide()
                    return
                }

                CoordMode('Mouse', 'Window')
                MouseGetPos(&x, &y)
                Preview.GetPos(,, &menuW, &menuH)

                scaleMouseMenuX := x / menuW
                scaleMouseMenuY := y / menuH
                l := SysGet(76)
                t := SysGet(77)
                r := SysGet(78)
                b := SysGet(79)

                newX := l + scaleMouseMenuX * (r)
                newY := t + scaleMouseMenuY * (b)

                struct := (Integer(newX) & 0xFFFFFFFF | Integer(newY) << 32)
                handle := DllCall('MonitorFromPoint', 'Int64', struct, 'UInt', 0)
                if !handle {
                    return
                }

                this.Hide()
                CoordMode('Mouse', 'Screen')
                MouseMove(newX, newY)
            })

            HotIf((*) => this.__PreviewVisible)
            Hotkey('*Escape', (*) => this.Hide())

            HotIf()
        }
    }

    static __CreatePreview() {
        if this.__PreviewVisible {
            this.Hide()
        }

        pBitmap := Gdip_BitmapFromScreen()
        width := Gdip_GetImageWidth(pBitmap)
        height := Gdip_GetImageHeight(pBitmap)

        targetWidth := 2000
        scale := targetWidth / width
        w := targetWidth
        h := height * scale

        CoordMode('Mouse', 'Screen')
        MouseGetPos(&mouseX, &mouseY)
        x := mouseX - (w / 2)
        y := mouseY - (h / 2)

        hMonMouse := MonitorFromPoint(mouseX, mouseY)

        if hMonMouse != MonitorFromPoint(x, y)
        || hMonMouse != MonitorFromPoint(x+w, y+h) {
            NumPut('UInt', 40, monInfo := Buffer(40))
            if !DllCall('user32\GetMonitorInfo', 'Ptr', hMonMouse, 'Ptr', monInfo) {
                throw Error('Something went wrong getting monitor info.')
            }

            left    := NumGet(monInfo,  4, 'Int')
            top     := NumGet(monInfo,  8, 'Int')
            right   := NumGet(monInfo, 12, 'Int')
            bottom  := NumGet(monInfo, 16, 'Int')
            monWidth := right - left

            if w > monWidth {
                w := monWidth
                scale := w / width
                h := height * scale
                x := mouseX - (w / 2)
                y := mouseY - (h / 2)
            }

            if x < left {
                x := left
            } else if x + w > right {
                x := right - w
            }

            if y < top {
                y := top
            } else if y + h > bottom {
                y := bottom - h
            }
        }

        pBitmap := ResizeBitmap(pBitmap, w, h)
        hBitmap := Gdip_CreateHBITMAPFromBitmap(pBitmap)
        if !hBitmap {
            MsgBox('failed hBitmap')
        }

        this.Preview.Move(x, y, w, h)
        this.image.Value := 'HBITMAP:' hBitmap
        this.Preview.Show()

        ; cleanup
        Gdip_DisposeImage(pBitmap)
        DeleteObject(hBitmap)

        MonitorFromPoint(x, y) {
            struct := (Integer(x) & 0xFFFFFFFF | Integer(y) << 32)
            return DllCall('MonitorFromPoint', 'Int64', struct, 'UInt', 0)
        }

        ResizeBitmap(pBitmap, newWidth, newHeight) {
            pNewBitmap := Gdip_CreateBitmap(newWidth, newHeight)
            G := Gdip_GraphicsFromImage(pNewBitmap)
            Gdip_DrawImage(G, pBitmap, 0, 0, newWidth, newHeight)
            Gdip_DisposeImage(pBitmap)
            Gdip_DeleteGraphics(G)
            return pNewBitmap
        }
    }
}