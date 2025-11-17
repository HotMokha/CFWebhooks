#Requires AutoHotkey v2.0
#SingleInstance force

global Config := StrSplit(FileRead("config.txt"), ",")
	; [1] - Webhook URL
	; [2] - Player Name
	; [3] - Detection x
	; [4] - Detection y
	; [5] - Detection width
	; [6] - Detection height

global IndexCSV := FileRead("values.csv")
CSVtoArray(thisCSV) {
	thisArray := []
	Loop Parse, IndexCSV, "`n", "`r" {
		thisLine := StrSplit(A_LoopField, ",")
		thisArray.push({entry: thisLine[1], color: String(thisLine[2])})
	}
	return thisArray
}
global IndexEntries := CSVtoArray(IndexCSV)

global Terminate := false

;-------- GUI LAYOUT --------;
CFGui := Gui(,"CF Webhooks")
CFGuiTab := CFGui.AddTab3(,["Status","Settings","Debug"])

;-------- STATUS TAB --------;
CFGuiTab.UseTab("Status")
	; Status Text
	CFGui.SetFont("w700")
	CFGui.AddText("x20 y40","Status: ")

	CFGui.SetFont("w400")
	StatusText := CFGui.AddText("x70 y40","Not Running")

	; Buttons
	global StatusButtons := []
	StatusButtons.push( CFGui.AddButton("x20 y250 w100 h30", "Start") )
	StatusButtons.push( CFGui.AddButton("x120 y250 w100 h30 Disabled", "Stop") )
	StatusButtons[1].OnEvent("Click", (*) => StartReading(StatusText))
	StatusButtons[2].OnEvent("Click", (*) => StopReading(StatusText))

;-------- SETTINGS TAB --------;
TextFields := []
CFGuiTab.UseTab("Settings")
	;-------- WEBHOOK SETTINGS --------;
		; Webhook Header
		CFGui.SetFont("w700")
		CFGui.AddText("x20 y40","Webhook Settings")

		; Webhook URL Field
		CFGui.SetFont("w400")
		CFGui.AddText("x20 y60","Webhook URL")
		TextFields.push( CFGui.AddEdit("x100 YP-2 w530 h18", Config[1]) )

		; Player Name Field
		CFGui.SetFont("w400")
		CFGui.AddText("x20 y80","Player Name")
		TextFields.push( CFGui.AddEdit("x100 YP-2 w200 h18", Config[2]) )

	;-------- DETECTION SETTINGS --------;
		; Detection Header
		CFGui.SetFont("w700")
		CFGui.AddText("x20 y120","Detection Configuration")

		; Instructions
		CFGui.SetFont("w400")
		CFGui.AddText("x20 y140","*Position the edges of the red box to cover the edges of the notification window. Test this by refreshing quests at Stephen.")
		CFGui.AddText("x20 y160","Use ARROW KEYS to adjust the position of the detection box.")
		CFGui.AddText("x20 y180","Use CTRL + ARROW KEYS to adjust the size of the detection box.")
		CFGui.AddText("x20 y200","You will need to restart the application after saving your changes.")

	; SAVE CHANGES Button
	B_SaveChanges := CFGui.AddButton("x20 y250 w100 h30", "Save Changes")
	B_SaveChanges.OnEvent("Click", (*) => SaveChanges(TextFields))

;-------- DEBUG TAB --------;
debugFields := []
CFGuiTab.UseTab("Debug")
	CFGui.SetFont("w400")

	; Target
	CFGui.AddText("x20 y40","Upgrade/Extract Target (ex. (17) Turquoise)")
	debugFields.push( CFGui.AddEdit("x250 YP-2 w300 h18", "(17) Turquoise") )

	; Upgrade/Extract
	CFGui.AddText("x20 y60","Upgraded/Extracted")
	debugFields.push( CFGui.AddDropDownList("x250 YP-2 w300", ["upgraded", "extracted"]) )

	; Send Test Button
	B_SendTestWebhook := CFGui.AddButton("x20 y250 w150 h30", "Send Test Webhook")
	B_SendTestWebhook.OnEvent("Click", (*) => CreateTestWebhook(debugFields))

	; Debug Button
	B_Debug := CFGui.AddButton("x200 y250 w150 h30", "Debug")
	B_Debug.OnEvent("Click", (*) => MsgBox( FindRegexIndex(StrSplit("[ASCENDER]: Successfully upgraded core to (51) S+", " "), "(\d+)").value ))

;-------- DRAW GUI --------;
CFGui.Show("w650 h300")


{
	Levenshtein(s1, s2) {
		len1 := StrLen(s1)
		len2 := StrLen(s2)

		if (len1 = 0)
			return len2
		if (len2 = 0)
			return len1

		prev := []
		curr := []

		; Initialize prev row to [1, 2, 3, ..., len2+1]
		prev.push(1) ; prev[1] corresponds to DP cell (0,0)

		Loop len2
			prev.push(A_Index + 1)

		Loop len1 {
			i := A_Index

			curr.Length := 0
			curr.push(i + 1)  ; first column value for row i

			ch1 := SubStr(s1, i, 1)

			Loop len2 {
				j := A_Index
				ch2 := SubStr(s2, j, 1)

				cost := (ch1 == ch2) ? 0 : 1

				; DP recurrence (adjusted for 1-based indexing)
				deletion     := prev[j+1] + 1
				insertion    := curr[j]   + 1
				substitution := prev[j]   + cost

				m := deletion
				if (insertion < m)
					m := insertion
				if (substitution < m)
					m := substitution

				curr.push(m)
			}

			temp := prev
			prev := curr
			curr := temp
		}

		return (prev[len2+1] - 1)
	}

	FindRegexIndex(arr, pattern) {
		for i, v in arr {
			if RegExMatch(v, pattern, &m)
				return { index: i, value: m[1] }
		}
		return 0
	}
}

global x := Config[3], y := Config[4], w := Config[5], h := Config[6], minsize := 5, step := 3
Highlight(x?, y?, w?, h?, showTime:=0, color:="Red", d:=2) {
	static guis := []

	if !IsSet(x) {
        for _, r in guis
            r.Destroy()
        guis := []
		return
    }
    if !guis.Length {
        Loop 4
            guis.Push(Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000"))
    }
	Loop 4 {
		i:=A_Index
		, x1:=(i=2 ? x+w : x-d)
		, y1:=(i=3 ? y+h : y-d)
		, w1:=(i=1 or i=3 ? w+2*d : d)
		, h1:=(i=2 or i=4 ? h+2*d : d)
		guis[i].BackColor := color
		guis[i].Show("NA x" . x1 . " y" . y1 . " w" . w1 . " h" . h1)
	}
	if showTime > 0 {
		Sleep(showTime)
		Highlight()
	} else if showTime < 0
		SetTimer(Highlight, -Abs(showTime))

	if CFGuiTab.Value != 2 {
        for _, r in guis
            r.Destroy()
        guis := []
		return
    }
}

MoveBox(d, m, *) {
	global x, y, step
	if d = "vertical"
		y+=(step*m)
	if d = "horizontal"
		x+=(step*m)
}
AdjustBox(d, m, *) {
	global w, h, step
	if d = "vertical"
		h+=(step*m)
	if d = "horizontal"
		w+=(step*m)
}

SaveChanges(info) {
	FileDelete("config.txt")
	thisString := ""
	for k, v in info {
		thisString := thisString . v.Text
		if (A_Index != info.Length) {
			thisString := thisString . ","
		}
	}

	thisString := thisString . "," . x . "," . y . "," . w . "," . h

	FileAppend(thisString, "config.txt")
}

StartReading(sts) {
	global StatusButtons
	dir := A_ScriptDir "\Components"
	sts.Text := "Running"
	StatusButtons[1].Opt("+Disabled")
	StatusButtons[2].Opt("-Disabled")

	Run("ReadScreen.ahk", dir)
	Run("WebhookManager.ahk", dir)
}

StopReading(sts) {
	global StatusButtons
	DetectHiddenWindows(true)

	dir := A_ScriptDir "\Components\"
	sts.Text := "Not Running"
	StatusButtons[1].Opt("-Disabled")
	StatusButtons[2].Opt("+Disabled")

	WinClose(dir "ReadScreen.ahk ahk_class AutoHotkey")
	WinClose(dir "WebhookManager.ahk ahk_class AutoHotkey")
}

CreateTestWebhook(info) {
	global IndexEntries
	hex := "000000"

	if FileExist("test.txt") {
		FileDelete("test.txt")
	}
	; hex, value, type, rng
	for k, v in IndexEntries {
		if (v.entry = info[1].Text) {
			hex := v.color
			break
		}
	}

	thisString := hex . "," . info[1].Text . "," . info[2].Text . ",TEST"
	FileAppend(thisString, "test.txt")
}

ExitGui(*) {
	DetectHiddenWindows(true)
	global StatusText

	dir := A_ScriptDir "\Components\"
	if (StatusText.Text = "Running") {
		WinClose(dir "ReadScreen.ahk ahk_class AutoHotkey")
		WinClose(dir "WebhookManager.ahk ahk_class AutoHotkey")
	}

	ExitApp
}

CFGui.OnEvent("Close", (*) => ExitGui())

Loop {
	; Check if user is in the Settings tab
	if CFGuiTab.Value = 2 {
		; Create enable hotkeys for moving detection box
		Hotkey("Right", (*) => MoveBox("horizontal", 1), "On")
		Hotkey("Left", (*) => MoveBox("horizontal", -1), "On")
		Hotkey("Up", (*) => MoveBox("vertical", -1), "On")
		Hotkey("Down", (*) => MoveBox("vertical", 1), "On")
		Hotkey("^Right", (*) => AdjustBox("horizontal", 1), "On")
		Hotkey("^Left", (*) => AdjustBox("horizontal", -1), "On")
		Hotkey("^Up", (*) => AdjustBox("vertical", -1), "On")
		Hotkey("^Down", (*) => AdjustBox("vertical", 1), "On")
		Loop {
			Highlight(x, y, w, h)
			if CFGuiTab.Value != 2 {
				break
			}
		}
	}
	; Disable the hotkeys for moving the detection box
	Hotkey("Right", (*) => MoveBox("horizontal", 1), "Off")
	Hotkey("Left", (*) => MoveBox("horizontal", -1), "Off")
	Hotkey("Up", (*) => MoveBox("vertical", -1), "Off")
	Hotkey("Down", (*) => MoveBox("vertical", 1), "Off")
	Hotkey("^Right", (*) => AdjustBox("horizontal", 1), "Off")
	Hotkey("^Left", (*) => AdjustBox("horizontal", -1), "Off")
	Hotkey("^Up", (*) => AdjustBox("vertical", -1), "Off")
	Hotkey("^Down", (*) => AdjustBox("vertical", 1), "Off")
}