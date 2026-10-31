Scriptname SW_Ward extends Quest
{Spellwork: Practice Ward. The lesser power conjures a practice dummy in front of the player for a few
 minutes, and school spells cast within its reach earn half again the experience they would anyway.

 A cast is worth its base magicka cost in skill use, as vanilla counts it, so the bonus goes through the
 same path (AddSkillExperience) and the same multipliers. The bonus tapers as practice piles up and
 recovers over game hours. That tiredness belongs to the player, not the ward, so a fresh ward can't
 reset it.

 Activating the dummy dismisses it; casting the power again moves it. Not in combat, and casts made in
 combat don't count.

 On SW_Quest beside SW_Main. SW_PlayerAlias passes on the load event and every spell the player casts.}

Spell Property WardPower Auto
{SW_PracticeWardPower, the Practice Ward lesser power. Given to the player on every load.}

Activator Property WardBase Auto
{SW_PracticeWardDummy: the vanilla practice dummy mesh, as Skyrim.esm's CombatDummy01 uses it.}

EffectShader Property WardShader Auto
{Skyrim.esm GhostFXShader (0x3B6CB): the conjured shimmer. A shader doesn't survive a load, so it is
 played again then.}

; Tuning.
float Property Bonus = 0.5 AutoReadOnly          ; a fresh cast earns half again its experience
float Property FreshPractice = 1000.0 AutoReadOnly ; base magicka cast at the ward by which the bonus halves
float Property RecoveryPerHour = 250.0 AutoReadOnly ; base magicka of tiredness that one game hour clears
float Property TiredAt = 2000.0 AutoReadOnly     ; when to say so: the bonus is down to a sixth
float Property Reach = 1500.0 AutoReadOnly       ; about 21 m around the dummy
float Property Lifetime = 180.0 AutoReadOnly     ; real seconds the dummy stands
float Property Ahead = 200.0 AutoReadOnly        ; how far in front of the player it appears

ObjectReference ward = None
int casts = 0                                    ; payments at this ward (casts, and seconds held), for Spellwork_WardGone

; The concentration spell being paid for right now, and the last one, with when its hold ended.
Spell heldSpell = None
Spell lastHeld = None
float lastHeldEnd = 0.0

; Base magicka cast at the ward lately, and the game time it was last brought up to date.
float tiredness = 0.0
float tirednessTime = 0.0
bool tiredSaid = false

; SW_PlayerAlias.OnPlayerLoadGame, and so on every load; an old save gets the power here.
Function OnGameLoad()
    Actor player = Game.GetPlayer()
    if WardPower && !player.HasSpell(WardPower)
        player.AddSpell(WardPower, false)
    endif
    if ward && WardShader
        WardShader.Play(ward)
    endif
    ; A hold cut off by the load must not leave its spell marked as held, or it would never pay again.
    heldSpell = None
EndFunction

; SW_PracticeWardEffect: the power was cast. A ward already standing is moved, not doubled.
Function Conjure()
    if !WardBase
        Debug.Trace("[Spellwork] SW_Ward properties are not filled; is Spellwork.esp enabled?", 2)
        return
    endif
    Actor player = Game.GetPlayer()
    if player.IsInCombat()
        Debug.Notification("You can't practice in the middle of a fight.")
        return
    endif
    Remove()
    casts = 0
    float angle = player.GetAngleZ()
    ward = player.PlaceAtMe(WardBase, 1, false, true)
    ward.MoveTo(player, Ahead * Math.Sin(angle), Ahead * Math.Cos(angle), 0.0, false)
    ; The player's own heading turns the dummy to face them: PracticeDummy01.nif's front faces -Y. (Turned
    ; half round, angle + 180, it showed the player its back, seen in game 2026-10-30.)
    ward.SetAngle(0.0, 0.0, angle)
    ward.Enable(true)
    if WardShader
        WardShader.Play(ward)
    endif
    RegisterForSingleUpdate(Lifetime)
    Recover()
    Debug.Notification("A practice ward stands ready. Cast your spells near it.")
    if tiredness >= TiredAt
        Debug.Notification("You're still tired from your last practice.")
    endif
    ; For any mod that listens; Spellwork's SkyrimNet layer narrates it (triggers/sw_ward_conjured.yaml).
    SendModEvent("Spellwork_WardConjured")
EndFunction

Event OnUpdate()
    Finish("expired")
EndEvent

; The dummy's own script (SW_WardDummy) calls this when the player activates it.
Function Dismiss()
    Finish("dismissed")
EndFunction

; The ward is gone for good: "expired" or "dismissed". Told to listeners only when the player is near
; enough to see it go; a ward that runs out after they have walked off goes unremarked.
; Spellwork's SkyrimNet layer narrates it (triggers/sw_ward_expired.yaml, sw_ward_dismissed.yaml).
Function Finish(string asHow)
    if !ward
        return
    endif
    bool seen = Game.GetPlayer().GetDistance(ward) <= Reach
    Remove()
    if seen
        SendModEvent("Spellwork_WardGone", asHow, casts as float)
    endif
EndFunction

; Takes the dummy away without a word: Finish, and Conjure when the ward is moved.
Function Remove()
    UnregisterForUpdate()
    if !ward
        return
    endif
    if WardShader
        WardShader.Stop(ward)
    endif
    ward.Disable(true)
    ward.Delete()
    ward = None
EndFunction

; SW_PlayerAlias.OnSpellCast: every spell the player casts. Only a school spell, cast near the ward and
; out of combat, earns anything.
Function Practice(Form akSpell)
    if !ward
        return
    endif
    Spell s = akSpell as Spell                       ; not scrolls, staffs or shouts
    if !s
        return
    endif
    Actor player = Game.GetPlayer()
    if player.IsInCombat() || player.GetDistance(ward) > Reach
        return
    endif
    float cost = s.GetMagickaCost() as float         ; powers cost nothing and fall out here
    if cost <= 0.0
        return
    endif
    MagicEffect fx = s.GetNthEffectMagicEffect(s.GetCostliestEffectIndex())
    if !fx
        return
    endif
    string school = fx.GetAssociatedSkill()
    if !IsSchool(school)
        return
    endif
    ActorValueInfo info = ActorValueInfo.GetActorValueInfoByName(school)
    if !info
        return
    endif
    if fx.GetCastingType() == 2
        Hold(s, info, cost)
    else
        Pay(info, cost)
    endif
EndFunction

; A concentration spell. OnSpellCast fires only once or twice a press however long it is held
; (measured 2026-10-30: ten seconds of Lesser Ward counted about twice), and its cost is per second.
; So a hold is paid a second at a time, checked once a second, and only while it lasts: nothing runs
; between casts.
Function Hold(Spell akSpell, ActorValueInfo akInfo, float afCost)
    if akSpell == heldSpell
        return                                       ; this hold is already being paid
    endif
    if akSpell == lastHeld && Utility.GetCurrentRealTime() - lastHeldEnd < 1.0
        return                                       ; the release report of a hold that just ended
    endif
    heldSpell = akSpell
    Pay(akInfo, afCost)
    Actor player = Game.GetPlayer()
    bool going = true
    while going
        Utility.Wait(1.0)
        going = ward && StillCasting(player, akSpell) && !player.IsInCombat() && player.GetDistance(ward) <= Reach
        if going
            Pay(akInfo, afCost)
        endif
    endwhile
    lastHeld = akSpell
    lastHeldEnd = Utility.GetCurrentRealTime()
    heldSpell = None
EndFunction

; Whether the player still holds akSpell in a hand that is casting. The graph's IsCasting flags stay up
; exactly as long as a concentration spell is held (measured 2026-10-30: Lesser Ward 8 s, Sparks 2 s).
bool Function StillCasting(Actor akPlayer, Spell akSpell)
    bool left = akPlayer.GetEquippedSpell(0) == akSpell
    bool right = akPlayer.GetEquippedSpell(1) == akSpell
    if left && akPlayer.GetAnimationVariableBool("IsCastingLeft")
        return true
    elseif right && akPlayer.GetAnimationVariableBool("IsCastingRight")
        return true
    endif
    return (left || right) && akPlayer.GetAnimationVariableBool("IsCastingDual")
EndFunction

; One cast, or one second of a held spell: half again its experience, less as the player tires.
Function Pay(ActorValueInfo akInfo, float afCost)
    Recover()
    akInfo.AddSkillExperience(afCost * Bonus * FreshPractice / (FreshPractice + tiredness))
    tiredness += afCost
    casts += 1
    if !tiredSaid && tiredness >= TiredAt
        tiredSaid = true
        Debug.Notification("Your practice is losing its edge. Rest a while.")
    endif
EndFunction

; Takes off the tiredness the hours since the last practice have cleared.
Function Recover()
    float now = Utility.GetCurrentGameTime()
    if tirednessTime > 0.0 && tiredness > 0.0
        tiredness -= (now - tirednessTime) * 24.0 * RecoveryPerHour
        if tiredness < 0.0
            tiredness = 0.0
        endif
    endif
    tirednessTime = now
    if tiredness < TiredAt
        tiredSaid = false
    endif
EndFunction

bool Function IsSchool(string s)
    return s == "Alteration" || s == "Conjuration" || s == "Destruction" || s == "Illusion" || s == "Restoration"
EndFunction
