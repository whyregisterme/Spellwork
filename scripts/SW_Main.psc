Scriptname SW_Main extends Quest
{Spellwork: train the five schools of magic. This is Soul Study: the player casts the lesser power, picks a
 school and a soul to spend, two hours pass, and the school rises one level, as a trainer would raise it.
 The soul is spent only when it does.

 A soul teaches up to a level set by its size (a petty soul to 25, a grand soul to 90), and the player can
 study five times per character level, as vanilla allows five trainings. A soul gem is used up; a
 reusable one (Azura's Star, the Black Star) gives up its soul and comes back empty.

 Souls are read from the gem's own record (SoulGem.GetSoulSize), which is how gems bought or found
 filled hold them, and how YASTM stores every soul it traps, partial fills included. Vanilla soul trap
 without YASTM keeps a partly filled gem's soul where scripts can't read it, so those gems don't count.

 The choice shows on a Magelight UI page when Magelight is installed (SW_UI), and as two message boxes
 otherwise, or whenever the page can't be used.

 Stuck? From the console: stopquest SW_Quest, then startquest SW_Quest.}

Spell Property SoulStudyPower Auto
{SW_SoulStudyPower, the Soul Study lesser power. Given to the player on every load (SetupUI).}

Message Property SchoolMsg Auto
{The box path's first question: which school. Five schools, then "Put it away".}

Message Property SoulMsg Auto
{The box path's second question: which soul. Petty to grand, then "Put it away".}

GlobalVariable Property GameHour Auto
{Skyrim.esm GameHour (0x38). Hours are added to it, as the vanilla wait and Pass the Time do.}

GlobalVariable Property UseMagelight Auto
{SW_UseMagelight, default 1. 0 = always message boxes. Console: set SW_UseMagelight to 0. Turning it back
 on takes effect at the next load.}

Keyword Property ReusableSoulGem Auto
{Skyrim.esm ReusableSoulGem (0xED2F1): Azura's Star, the Black Star, and YASTM's filled forms of them.}

SoulGem Property AzurasStar Auto
{Skyrim.esm DA01SoulGemAzurasStar (0x63B27), the empty star a filled one goes back to.}

SoulGem Property BlackStar Auto
{Skyrim.esm DA01SoulGemBlackStar (0x63B29), likewise.}

; Tuning.
int Property StudyHours = 2 AutoReadOnly
int Property SessionsPerLevel = 5 AutoReadOnly
int Property MaxLevel = 90 AutoReadOnly          ; as far as a master trainer goes; past it, only practice

; Sessions spent at this character level. A new level clears them (CheckSessions).
int sessionsLevel = 0
int sessionsUsed = 0

; ScanGems' result, indexed by soul size 1 (petty) to 5 (grand): how many of each the player holds, and
; the gem to spend for each, the smallest that holds that soul, a reusable one last.
int[] soulCount
Form[] soulGem

; Magelight page: its view id (0 = message boxes this session), and whether the page is up.
int uiView = 0
bool uiShowing = false

; States: "" (idle), "Choosing" (the page or a box is up), "Studying" (the fade and the skill).

Event OnInit()
    Reset()
    SetupUI()
EndEvent

; SW_PlayerAlias.OnPlayerLoadGame. A reload mid-study leaves the screen black and controls off.
Function OnGameLoad()
    SetupUI()
    if GetState() == "Studying"
        Game.EnablePlayerControls()
        Game.FadeOutGame(false, true, 0.0, 0.5)
    endif
    Reset()
EndFunction

; Magelight forgets mods, views and listeners between sessions, and mod event registrations last one
; load, so this runs on every load. The power is handed out here too, so an old save gets it.
Function SetupUI()
    Actor player = Game.GetPlayer()
    if SoulStudyPower && !player.HasSpell(SoulStudyPower)
        player.AddSpell(SoulStudyPower, false)
    endif
    uiView = 0
    uiShowing = false
    if !UseMagelight || UseMagelight.GetValue() <= 0
        return
    endif
    uiView = SW_UI.Setup()
    if uiView
        RegisterForModEvent("Magelight_JS_swChoice", "OnUiChoice")
        RegisterForModEvent("Magelight_UIModeExited", "OnUiExited")
        RegisterForModEvent("Magelight_ViewLoadFailed", "OnUiFailed")
    endif
EndFunction

; SW_SoulStudyEffect: the power was cast.
Function OpenStudy()
    if !SchoolMsg || !SoulMsg || !GameHour
        Debug.Trace("[Spellwork] SW_Quest properties are not filled; is Spellwork.esp enabled?", 2)
        return
    endif
    if GetState() != ""
        return
    endif
    Actor player = Game.GetPlayer()
    if player.IsInCombat()
        Debug.Notification("You can't study in the middle of a fight.")
        return
    endif
    CheckSessions()
    if sessionsUsed >= SessionsPerLevel
        Debug.Notification("You've studied all you can this level. You can study again when you level up.")
        return
    endif
    ScanGems()
    GoToState("Choosing")
    if uiView && UseMagelight && UseMagelight.GetValue() > 0
        uiShowing = true
        if SW_UI.Open(uiView, "swStudy", StudyJson())
            return
        endif
        uiShowing = false
    endif
    ChooseWithBoxes()
EndFunction

; The box path: a school, then a soul. A box can't carry text, but it can show numbers (%.0f in its text).
Function ChooseWithBoxes()
    Actor player = Game.GetPlayer()
    int school = SchoolMsg.Show(player.GetBaseActorValue("Alteration"), player.GetBaseActorValue("Conjuration"), \
        player.GetBaseActorValue("Destruction"), player.GetBaseActorValue("Illusion"), \
        player.GetBaseActorValue("Restoration"), sessionsUsed, SessionsPerLevel)
    if school < 0 || school > 4
        Reset()
        return
    endif
    int soul = SoulMsg.Show(soulCount[1], soulCount[2], soulCount[3], soulCount[4], soulCount[5])
    if soul < 0 || soul > 4
        Reset()
        return
    endif
    Study(SchoolName(school), soul + 1)
EndFunction

; Checks the choice, then spends the soul and raises the school. asSchool must be one of the five.
Function Study(string asSchool, int aiSoul)
    if GetState() != "Choosing" || !IsSchool(asSchool) || aiSoul < 1 || aiSoul > 5
        Reset()
        return
    endif
    Actor player = Game.GetPlayer()
    int level = player.GetBaseActorValue(asSchool) as int
    string why = ""
    if level >= MaxLevel
        why = asSchool + " is at " + level + ". Past " + MaxLevel + ", only practice teaches."
    elseif level >= SoulCap(aiSoul)
        why = "A " + SoulName(aiSoul) + " soul can't teach " + asSchool + " past " + SoulCap(aiSoul) + "."
    elseif soulCount[aiSoul] <= 0 || !soulGem[aiSoul]
        why = "You have no " + SoulName(aiSoul) + " souls."
    endif
    if why != ""
        Debug.Notification(why)
        Reset()
        return
    endif

    GoToState("Studying")
    SoulGem gem = soulGem[aiSoul] as SoulGem

    ; The hours pass behind black, controls off, as the vanilla wait does.
    Game.DisablePlayerControls()
    Game.FadeOutGame(true, true, 0.0, 1.5)
    Utility.Wait(1.6)
    GameHour.SetValue(GameHour.GetValue() + StudyHours)
    float xpBefore = Game.GetPlayerExperience()
    int after = RaiseOneLevel(asSchool, level)
    Debug.Trace("[Spellwork] study " + asSchool + " with a " + SoulName(aiSoul) + " soul (" + gem.GetName() + "): " \
        + level + " -> " + after + ", character xp " + xpBefore + " -> " + Game.GetPlayerExperience())
    Utility.Wait(0.5)
    Game.FadeOutGame(false, true, 0.5, 1.5)
    Game.EnablePlayerControls()

    ; The soul is spent only for a level actually gained.
    if after <= level
        Debug.Notification("The study taught you nothing: " + asSchool + " didn't rise. Your soul is kept.")
        Debug.Trace("[Spellwork] " + asSchool + " did not rise; is another mod capping the skill?", 1)
        Reset()
        return
    endif
    SoulGem empty = None
    if ReusableSoulGem && gem.HasKeyword(ReusableSoulGem)
        empty = EmptyReusable(gem)
    endif
    player.RemoveItem(gem, 1, true)
    if empty
        player.AddItem(empty, 1, true)
    endif
    sessionsUsed += 1

    string spent = "The " + SoulName(aiSoul) + " soul is spent."
    if empty
        spent = "The " + SoulName(aiSoul) + " soul is spent; " + empty.GetName() + " is empty again."
    endif
    Debug.Notification(asSchool + " rises to " + after + ". " + spent)
    Debug.Notification("Studied " + sessionsUsed + " of " + SessionsPerLevel + " times this level.")
    ; For any mod that listens; Spellwork's SkyrimNet layer narrates it (triggers/sw_studied.yaml).
    SendModEvent("Spellwork_Studied", asSchool, after as float)
    Reset()
EndFunction

; Adds the experience still missing for the next level, through the engine's own skill-use path so its
; level-up runs. Not Game.IncrementSkill: measured 2026-10-30, it added experience without raising the
; level (Alteration held 1553 of the 1327 its level 28 needs, and stayed 28).
; AddSkillExperience takes skill USE, which the engine multiplies by the skill's use mult and then by the
; player's own modifiers (stones, perks, other mods). Those can be below 1: measured 2026-10-30, 1 use of
; Illusion (use mult 4.6) gave 4.14 experience, 90%, so paying exactly the missing amount left Illusion
; just short of 34. So the first payment also measures the rate that actually lands, and the rest is paid
; at that rate.
; Then the progress the player had made toward the old level carries into the new one, as a trainer's
; does (UESP: the training bar empties, but the Skills menu shows the progress kept). Without it a study
; made at 93% of a level taught only the last 7%.
; Returns the level afterwards.
int Function RaiseOneLevel(string asSchool, int aiLevel)
    Actor player = Game.GetPlayer()
    ActorValueInfo info = ActorValueInfo.GetActorValueInfoByName(asSchool)
    if !info
        return aiLevel
    endif
    float useMult = info.GetSkillUseMult()
    if useMult <= 0.0
        useMult = 1.0
    endif
    float progress = 0.0                             ; share of the old level already learned
    float need = info.GetExperienceForLevel(aiLevel)
    if need > 0.0
        progress = info.GetSkillExperience() / need
    endif
    float rate = 1.0                                 ; experience landed per (use x use mult)
    bool rateKnown = false
    int tries = 0
    while tries < 4 && (player.GetBaseActorValue(asSchool) as int) <= aiLevel
        float before = info.GetSkillExperience()
        float missing = info.GetExperienceForLevel(aiLevel) - before
        ; Already past the mark (IncrementSkill's leftovers): any use at all tips it over.
        if missing < 1.0
            missing = 1.0
        endif
        float use = (missing + 1.0) / (useMult * rate)
        info.AddSkillExperience(use)
        if (player.GetBaseActorValue(asSchool) as int) <= aiLevel
            float gained = info.GetSkillExperience() - before
            if gained <= 0.0
                ; Nothing lands: something holds the skill. The caller keeps the soul.
                return aiLevel
            endif
            rate = gained / (use * useMult)
            rateKnown = true
        endif
        tries += 1
    endwhile
    if (player.GetBaseActorValue(asSchool) as int) != aiLevel + 1 || progress <= 0.0
        return player.GetBaseActorValue(asSchool) as int
    endif

    ; The carry. Kept 2 short of the next mark so it can never tip into a second level. While the rate is
    ; unknown (the first payment raised the level outright, so a bonus may be above 1), half is paid
    ; first and measured.
    need = info.GetExperienceForLevel(aiLevel + 1)
    float carry = progress * need
    if carry > need - 2.0
        carry = need - 2.0
    endif
    tries = 0
    while tries < 4 && (player.GetBaseActorValue(asSchool) as int) == aiLevel + 1
        float before = info.GetSkillExperience()
        float short = carry - before
        if short < 1.0
            return aiLevel + 1
        endif
        float use = short / (useMult * rate)
        if !rateKnown
            use = use / 2.0
        endif
        info.AddSkillExperience(use)
        float gained = info.GetSkillExperience() - before
        if gained <= 0.0
            return player.GetBaseActorValue(asSchool) as int
        endif
        rate = gained / (use * useMult)
        rateKnown = true
        tries += 1
    endwhile
    return player.GetBaseActorValue(asSchool) as int
EndFunction

; Nothing differs while choosing or studying; the state itself is the guard.
State Choosing
EndState

State Studying
EndState

Function Reset()
    uiShowing = false
    GoToState("")
EndFunction

; A new character level gives five more sessions.
Function CheckSessions()
    int level = Game.GetPlayer().GetLevel()
    if level != sessionsLevel
        sessionsLevel = level
        sessionsUsed = 0
    endif
EndFunction

; Counts the souls the player holds, by size, and picks the gem to spend for each size.
Function ScanGems()
    soulCount = new int[6]
    soulGem = new Form[6]
    int[] rank = new int[6]
    Actor player = Game.GetPlayer()
    int n = player.GetNumItems()
    int i = 0
    while i < n
        SoulGem g = player.GetNthForm(i) as SoulGem
        if g
            int soul = g.GetSoulSize()
            if soul >= 1 && soul <= 5
                bool reusable = ReusableSoulGem && g.HasKeyword(ReusableSoulGem)
                ; A reusable gem Spellwork can't give back empty is left alone rather than lost.
                if !reusable || EmptyReusable(g)
                    soulCount[soul] = soulCount[soul] + player.GetItemCount(g)
                    ; The smallest gem first, so a petty soul in a grand gem keeps the grand gem's space
                    ; for later; a reusable one last.
                    int r = g.GetGemSize()
                    if reusable
                        r += 100
                    endif
                    if !soulGem[soul] || r < rank[soul]
                        soulGem[soul] = g
                        rank[soul] = r
                    endif
                endif
            endif
        endif
        i += 1
    endwhile
EndFunction

; The empty star a filled reusable gem goes back to. YASTM's filled stars share the star's name ("The
; Black Star (White)" starts with it), so a name that starts with the empty one's is that star.
; None: not a reusable gem Spellwork knows.
SoulGem Function EmptyReusable(SoulGem akGem)
    if AzurasStar && StringUtil.Find(akGem.GetName(), AzurasStar.GetName()) == 0
        return AzurasStar
    elseif BlackStar && StringUtil.Find(akGem.GetName(), BlackStar.GetName()) == 0
        return BlackStar
    endif
    return None
EndFunction

; {schools:[{name,level,pct}], souls:[{size,name,count,cap}], used, max, hours, maxLevel}
string Function StudyJson()
    Actor player = Game.GetPlayer()
    string schools = ""
    int i = 0
    while i < 5
        string s = SchoolName(i)
        int level = player.GetBaseActorValue(s) as int
        float pct = 0.0
        ActorValueInfo info = ActorValueInfo.GetActorValueInfoByName(s)
        if info
            float need = info.GetExperienceForLevel(level)
            if need > 0.0
                pct = info.GetSkillExperience() / need
            endif
        endif
        if i > 0
            schools += ","
        endif
        schools += "{\"name\":\"" + s + "\",\"level\":" + level + ",\"pct\":" + pct + "}"
        i += 1
    endwhile
    string souls = ""
    int size = 1
    while size <= 5
        if size > 1
            souls += ","
        endif
        souls += "{\"size\":" + size + ",\"name\":\"" + SoulName(size) + "\",\"count\":" + soulCount[size] \
            + ",\"cap\":" + SoulCap(size) + "}"
        size += 1
    endwhile
    return "{\"schools\":[" + schools + "],\"souls\":[" + souls + "],\"used\":" + sessionsUsed \
        + ",\"max\":" + SessionsPerLevel + ",\"hours\":" + StudyHours + ",\"maxLevel\":" + MaxLevel + "}"
EndFunction

; ---------------------------------------------------------------------------------------------
; Magelight page events. Every mod hears every Magelight event, so each checks the view id first.
; Functions, not Events: Caprica refuses new event names on a non-native script, and in a Skyrim .pex an
; event is only a function; SKSE calls the handler by name either way.
; ---------------------------------------------------------------------------------------------

; "<school>:<soul size>" to study, "cancel" to put it away.
Function OnUiChoice(string asEventName, string asChoice, float afView, Form akSender)
    if uiView == 0 || afView as int != uiView || !uiShowing
        return
    endif
    uiShowing = false
    SW_UI.Close(uiView)
    string[] parts = StringUtil.Split(asChoice, ":")
    if parts.Length == 2
        Study(parts[0], parts[1] as int)
    else
        Reset()
    endif
EndFunction

; Escape or the host's toggle key closed the page: put away. SW_UI.Close raises this too, after
; uiShowing is already cleared, so that one is ignored.
Function OnUiExited(string asEventName, string asModId, float afView, Form akSender)
    if uiView == 0 || afView as int != uiView || !uiShowing
        return
    endif
    uiShowing = false
    SW_UI.Close(uiView)
    Reset()
EndFunction

; The page couldn't load: message boxes for the rest of the session, and the choice goes to them now.
Function OnUiFailed(string asEventName, string asDetail, float afView, Form akSender)
    if uiView == 0 || afView as int != uiView
        return
    endif
    Debug.Trace("[Spellwork] Magelight page failed to load (" + asDetail + "): message boxes this session")
    SW_UI.Close(uiView)
    uiView = 0
    bool showing = uiShowing
    uiShowing = false
    if showing && GetState() == "Choosing"
        ChooseWithBoxes()
    endif
EndFunction

; ---------------------------------------------------------------------------------------------
; Helpers
; ---------------------------------------------------------------------------------------------

; In SchoolMsg's button order.
string Function SchoolName(int i)
    if i == 0
        return "Alteration"
    elseif i == 1
        return "Conjuration"
    elseif i == 2
        return "Destruction"
    elseif i == 3
        return "Illusion"
    endif
    return "Restoration"
EndFunction

; Only these may be raised, so a stray page answer can never raise anything else.
bool Function IsSchool(string s)
    return s == "Alteration" || s == "Conjuration" || s == "Destruction" || s == "Illusion" || s == "Restoration"
EndFunction

string Function SoulName(int aiSize)
    if aiSize == 1
        return "petty"
    elseif aiSize == 2
        return "lesser"
    elseif aiSize == 3
        return "common"
    elseif aiSize == 4
        return "greater"
    endif
    return "grand"
EndFunction

; The highest level a soul of this size can teach a school to.
int Function SoulCap(int aiSize)
    if aiSize == 1
        return 25
    elseif aiSize == 2
        return 40
    elseif aiSize == 3
        return 50
    elseif aiSize == 4
        return 75
    endif
    return 90
EndFunction
