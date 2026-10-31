Scriptname SW_PracticeWardEffect extends ActiveMagicEffect
{SW_PracticeWardEffect, on the Practice Ward lesser power: conjures the practice dummy. SW_Ward hands the
 power out on every load.}

SW_Ward Property WardQuest Auto
{SW_Quest.}

Event OnEffectStart(Actor akTarget, Actor akCaster)
    if WardQuest
        WardQuest.Conjure()
    endif
EndEvent
