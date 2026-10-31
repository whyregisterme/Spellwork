Scriptname SW_UI Hidden
{Every Magelight UI call Spellwork makes. Magelight is optional: when it is missing, too old or
 not ready, Available() is false, nothing below calls it, and SW_Main falls back to message boxes.
 Kept apart from SW_Main so that script never names Magelight at all.

 The page is Data/Magelight/Spellwork/views/study/index.html, created hidden at startup by that
 folder's manifest.json. Magelight keeps nothing in the save, so Setup() runs on every load.}

string Function ModId() Global
    return "Spellwork"
EndFunction

; The manifest's view name. Not "study": Papyrus strings are interned without regard to case, so a
; "Study" any other script or record used first is what reaches Magelight, whose FindView compares
; names case-sensitively, and the view is never found (measured 2026-10-30: FindView returned 0 for
; "study" while Magelight's log showed the view registered). A name nobody else uses can't collide.
string Function ViewName() Global
    return "sw_study"
EndFunction

; 1.3.0: the oldest host this was tested on.
bool Function Available() Global
    if SKSE.GetPluginVersion("Magelight") <= 0
        return false
    endif
    return Magelight.GetVersion() >= 10300 && Magelight.IsReady()
EndFunction

; The page's view id, or 0 when there is no usable page this session.
int Function Setup() Global
    if !Available()
        return 0
    endif
    if !Magelight.RegisterMod(ModId(), "Spellwork")
        Debug.Trace("[Spellwork] Magelight refused the mod: " + Magelight.GetLastError(ModId()))
        return 0
    endif
    int view = Magelight.FindView(ModId(), ViewName())
    if view == 0
        Debug.Trace("[Spellwork] Magelight has no " + ViewName() + " view; is the Magelight/Spellwork folder installed?")
        return 0
    endif
    Magelight.RegisterListener(view, "swChoice")
    return view
EndFunction

; Hands the page its content, shows it and takes the cursor with the game paused. False when another
; mod holds the cursor: the view is hidden again and the caller uses a message box instead.
bool Function Open(int aiView, string asFunction, string asJson) Global
    Magelight.Call(aiView, asFunction, asJson)
    Magelight.ShowView(aiView, true)
    if !Magelight.RequestUIMode(aiView, true)
        Debug.Trace("[Spellwork] Magelight UI mode refused: " + Magelight.GetLastError(ModId()))
        Magelight.ShowView(aiView, false)
        return false
    endif
    return true
EndFunction

Function Close(int aiView) Global
    Magelight.ReleaseUIMode(ModId())
    Magelight.ShowView(aiView, false)
EndFunction
