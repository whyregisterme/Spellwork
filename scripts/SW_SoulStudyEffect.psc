Scriptname SW_SoulStudyEffect extends ActiveMagicEffect
{SW_SoulStudyEffect, on the Soul Study lesser power: opens the choice of school and soul. SW_Main hands the
 power out on every load.}

SW_Main Property MainQuest Auto
{SW_Quest.}

Event OnEffectStart(Actor akTarget, Actor akCaster)
    if MainQuest
        MainQuest.OpenStudy()
    endif
EndEvent
