Scriptname SW_WardDummy extends ObjectReference
{On SW_PracticeWardDummy, the conjured practice dummy: activating it dismisses it.}

SW_Ward Property WardQuest Auto
{SW_Quest.}

Event OnActivate(ObjectReference akActionRef)
    if WardQuest && akActionRef == Game.GetPlayer()
        WardQuest.Dismiss()
    endif
EndEvent
