Scriptname SW_PlayerAlias extends ReferenceAlias
{On the PlayerAlias of SW_Quest. Quest scripts get no load or cast events, so this passes them on.}

Event OnPlayerLoadGame()
    SW_Main main = GetOwningQuest() as SW_Main
    if main
        main.OnGameLoad()
    endif
    SW_Ward ward = GetOwningQuest() as SW_Ward
    if ward
        ward.OnGameLoad()
    endif
EndEvent

Event OnSpellCast(Form akSpell)
    SW_Ward ward = GetOwningQuest() as SW_Ward
    if ward
        ward.Practice(akSpell)
    endif
EndEvent
