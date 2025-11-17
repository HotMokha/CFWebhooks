#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
#SingleInstance force

SplitPath, A_ScriptDir,, parentDirectory
SetWorkingDir %parentDirectory%

FileRead, DataString, data.txt
global Data := StrSplit(DataString, ",")
	; [1] - Quest Status
	; [2] - Last Notification
	; [3] - Last Notification Type
	; [4] - Last Notification RNG
	; [5] - Last Notification Color
global PriorData := Data

FileRead, ConfigString, config.txt
global Config := StrSplit(ConfigString, ",")

global WebHookURL := Config[1]

FormatSeconds(seconds)
{
	If seconds < 0
	{
		return "0:00:00"
	}


	hours := Floor(seconds/3600)
	minutes := Floor(Mod(seconds, 3600)/60)
	seconds := Mod(seconds, 60)

	if (minutes < 10)
	{
		minutes = 0%minutes%
	}
	if (seconds < 10)
	{
		seconds = 0%seconds%
	}

	FinalTime := hours . ":" . minutes . ":" . seconds
	return FinalTime
}

FormatSeconds60(seconds)
{
	If seconds < 0
	{
		return "0:00"
	}

	minutes := Floor(seconds/60)
	seconds := Mod(seconds, 60)

	if (seconds < 10)
	{
		seconds = 0%seconds%
	}

	FinalTime := minutes . ":" . seconds
	return FinalTime
}

GetDaysSince()
{
	yr := SubStr(A_NowUTC, 1, 4)
	mm := SubStr(A_NowUTC, 5, 2)
	iter1 := yr - 2024
	iter2 := mm

	days := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

	total := 0

	while (iter1 >= 0)
	{
		if (iter1 != 0)
		{
			if( Mod(yr - iter1, 4) == 0 )
			{
				total += 366
			}
			else
			{
				total += 365
			}
			iter1 -= 1
			Continue
		}

		while (iter2 >= 1)
		{
			if (iter2 != 1)
			{
				if( Mod(yr - iter1, 4) == 0 && (mm - iter2 + 1) = 2)
				{
					total += days[mm - iter2 + 1] + 1
				}
				else
				{
					total += days[mm - iter2 + 1]
				}
			}
			else
			{
				total += SubStr(A_NowUTC, 7, 2) - 1
			}
			iter2 -= 1
		}
		iter1 -= 1
	}
	return total
}

GetUnixTimestamp(future)
{
	basis := 1704088800 ; Jan 01, 2024

	et1 := A_NowUTC
	EnvAdd, et1, future, seconds

	hh := SubStr(et1, 9, 2) - 6
	mm := SubStr(et1, 11, 2)
	ss := SubStr(et1, 13, 2)

	ts := basis + (GetDaysSince() * 86400) + (hh * 3600) + (mm * 60) + ss
	return ts
}

SendCoreWebhook(type, value, hex, rng, player)
{
	Time := GetUnixTimestamp(0)
	Color1 := "0x" . hex

	Color := Color1 + 0
	url:= % WebHookURL
	Type := type
	RNG := rng
	Value := value

	if(Type="upgraded"){
		Description := "**" . player . "** upgraded their core to **" . Value . "**."
	}
	if(Type="extracted"){
		Description := "**" . player . "**  extracted a(n) **" . Value . "** core."
	}
	postdata=
	(
	{
		"content": "",
  		"embeds": [
    		{
      			"title": "Core %Type%!",
      			"description": "%Description%",
      			"color": %Color%,
				"fields":
					[{
						"name": "RNG",
						"value": "%RNG%",
						"inline": true
					},
					{
						"name": "Date",
						"value": "<t:%Time%>",
						"inline": true
					}]
    		}]
	}
) ; Use https://leovoel.github.io/embed-visualizer/ to generate above webhook code

	WebRequest := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	WebRequest.Open("POST", url, false)
	WebRequest.SetRequestHeader("Content-Type", "application/json")
	WebRequest.SetProxy(false)
	WebRequest.Send(postdata)
}

SendTestWebhook(type, value, hex, rng, player)
{
	Time := GetUnixTimestamp(0)
	Color1 := "0x" . hex

	Color := Color1 + 0
	url:= % WebHookURL
	Type := type
	RNG := rng
	Value := value

	if(Type="upgraded"){
		Description := "**" . player . "** upgraded their core to **" . Value . "**."
	}
	if(Type="extracted"){
		Description := "**" . player . "**  extracted a(n) **" . Value . "** core."
	}
	postdata=
	(
	{
		"content": "This is a TEST!!",
  		"embeds": [
    		{
      			"title": "Core %Type%!",
      			"description": "%Description%",
      			"color": %Color%,
				"fields":
					[{
						"name": "RNG",
						"value": "%RNG%",
						"inline": true
					},
					{
						"name": "Date",
						"value": "<t:%Time%>",
						"inline": true
					}]
    		}]
	}
) ; Use https://leovoel.github.io/embed-visualizer/ to generate above webhook code

	WebRequest := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	WebRequest.Open("POST", url, false)
	WebRequest.SetRequestHeader("Content-Type", "application/json")
	WebRequest.SetProxy(false)
	WebRequest.Send(postdata)
}

ReadInformation() {
	FileRead, ConfigString, config.txt
	global Config := StrSplit(ConfigString, ",")

	if FileExist("test.txt") {
		FileRead, TestString, test.txt
		test := StrSplit(TestString, ",")
		SendTestWebhook(test[3], test[2], test[1], test[4], Config[2])
		FileDelete, test.txt
	}

	if FileExist("webhookData.txt") {
		FileRead, TestString, webhookData.txt
		data := StrSplit(TestString, ",,")
		SendCoreWebhook(data[1], data[2], data[3], data[4], Config[2])
		FileDelete, webhookData.txt
	}
}

Loop {
	ReadInformation()
	Sleep 1000
}