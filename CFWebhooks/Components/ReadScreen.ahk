#Requires AutoHotkey 2.0.19+
#include ..\Lib\OCR.ahk
#include ..\Lib\jsongo.v2.ahk
#SingleInstance force
SplitPath A_ScriptDir,, &parentDirectory
SetWorkingDir parentDirectory

CoordMode "Pixel", "Screen"
CoordMode "Mouse", "Screen"

OCR.PerformanceMode := 1

global IndexCSV := FileRead("values.csv")
global Data := StrSplit(FileRead("data.txt"), ",")
	; [1] - Quest Status
	; [2] - Last Notification
	; [3] - Last Notification Type
	; [4] - Last Notification RNG
	; [5] - Last Notification Color
global QuestStatus := Data[1]
global NotificationTypes := []
	NotificationTypes.push({entry:"upgraded"})
	NotificationTypes.push({entry:"extracted"})

global Config := StrSplit(FileRead("config.txt"), ",")
	; [1] - Webhook URL
	; [2] - Player Name
	; [3] - Detection x
	; [4] - Detection y
	; [5] - Detection width
	; [6] - Detection height

CSVtoArray(thisCSV) {
	thisArray := []
	Loop Parse, IndexCSV, "`n", "`r" {
		thisLine := StrSplit(A_LoopField, ",")
		thisArray.push({entry: thisLine[1], color: String(thisLine[2])})
	}
	return thisArray
}
global IndexEntries := CSVtoArray(IndexCSV)

SearchForString(txt, x, y, w, h) {
    Loop 10 {
        result := OCR.FromRect(x, y, w, h, {scale:2})
        if(result.FindStrings(txt, {SearchFunc: RegExMatch}).Length){
            return true
        }
    }
    return false
}
SearchForStrings(data, x, y, w, h) {
    Loop 5 {
		result := OCR.FromRect(x, y, w, h, {scale:4})
		;msgbox(result.text)
		for k, v in data {
			;msgbox(A_Index . ": " . v.entry)

			if(result.text){
				if(InStr(result.text, v.entry)){
					return v
				}
			}
		}
    }
    return 0
}

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
ParseNotification(x, y, w, h) {
	type := ""
	value := ""
	color := ""
	rng := ""
	loops := 50

	failsafe := ""

	valueArr := []
	rngArr := []
	rngArr.Push({num: "1/1", count: 0})

	Loop loops {
		NTEXT := StrSplit(OCR.FromRect(x, y, w, h, {scale:4}).Text, " ")

		if (NTEXT.Length = 0) {
			continue
		}

		TENTRY := FindRegexIndex(NTEXT, "(\d+)")
		rngIndex := NTEXT.Length ; Default value as a failsafe

		; This value will be reported if no entry is found in the index that matches the (ID) VALUE combination, within error
		if (TENTRY != 0 && failsafe = "") {
			failsafe := TENTRY.value
		}

		; Find the RNG index with some error
		for k, v in NTEXT {
			if (Levenshtein(v, "RNG") <= 1) {
				if (k + 1 <= NTEXT.Length) { ; Ensure rngIndex doesn't attempt to index out of bounds
					rngIndex := k + 1
				}
			}
		}

		; Read and report RNG if no acceptable value has been found yet. If RNG is not the last index, it may not detect properly.
		trng := NTEXT[rngIndex]
		if RegExMatch(trng, "^1/(?:(?:\d{1,3}(?:,\d{3})+)|\d+)\.\d{2}$") {
			; If the reported number is a valid format, push it to the RNG array. If the entry already exists, add +1 count.
			for k, v in rngArr {
				if (v.num = trng) {
					v.count += 1
					break
				}
				if (A_Index = rngArr.Length) {
					rngArr.Push({num: trng, count: 1})
				}
			}
		}

		; Read and report "upgraded" or "extracted". Levenshtein matches with distance <4. Go with first result.
		if (type = "") {
			for k, v in NTEXT {
				if (Levenshtein(v, "upgraded") < 4) {
					type := "upgraded"
				} else if (Levenshtein(v, "extracted") < 4) {
					type := "extracted"
				}
			}
		}

		; Levenshtein match any index entry with (ID) matching TENTRY with distance <4
		for k, v in IndexEntries {
			; If a valid index wasn't found, skip detection for this loop
			if (TENTRY = 0) {
				break
			}
			; Only evaluate index entries with matching (ID)
			if (!RegExMatch(v.entry, TENTRY.value)) {
				continue
			}
			; Push to values array
			if (NTEXT.Length >= (TENTRY.index + 1)) ; Ensure index is not out of bounds
			{
				dist := Levenshtein(NTEXT[TENTRY.index] . " " . NTEXT[TENTRY.index+1], v.entry)
				if (dist < 4) {
					valueArr.Push({entry: v.entry, color: v.color, dist: dist})
				}
			}
		}
	}

	; Find the value in rngArr with the highest count
	bestRNG := []
	bestRNG.Push({num: "", count: 0})
	for k, v in rngArr {
		if (v.count > bestRNG[1].count) {
			bestRNG := []
			bestRNG.Push({num: v.num, count: v.count})
		}
	}

	; Find the value in valueArr with the highest count
	bestValue := []
	bestValue.Push({entry: "", color: "", dist: 5})
	for k, v in valueArr {
		if (v.dist < bestValue[1].dist) {
			bestValue := []
			bestValue.Push({entry: v.entry, color: v.color, dist: v.dist})
		}
	}

	rng := bestRNG[1].num
	value := bestValue[1].entry
	color := bestValue[1].color

	; Report this if no valid value found.
	if (value = "") {
		value := "(" . failsafe . ") *failed to detect value*. Try adjusting your detection box if this is a reoccurring issue"
		color := 000000
	}

	; Report this if no valid RNG found.
	if (rng = "") {
		rng := "*Failed to detect RNG*"
	}

	; Report this if no valid type found.
	if (type = "") {
		type := "upgraded"
	}

	return {type: type, value: value, color: color, rng: rng}
}
ReadInformation() {
	; If a notification containing "ASCENDER" or "MACHINE" is detected, start parsing the notification for relevant information and send webhook data.
	if(SearchForString("ASCENDER", Config[3], Config[4], Config[5], Config[6]) || SearchForString("MACHINE", Config[3], Config[4], Config[5], Config[6])){
		webhookData := ParseNotification(Config[3], Config[4], Config[5], Config[6])
		CreateWebhookData(webhookData)
	}

	; If a notification containing "ASCENDER" or "MACHINE" is detected, start parsing the notification for relevant information and send webhook data.
	if(SearchForString("discovered", Config[3], Config[4], Config[5], Config[6])){
		if(SearchForString("ASCENDER", Config[3], Config[4] - (Config[6] * 1.05), Config[5], Config[6]) || SearchForString("MACHINE", Config[3], Config[4], Config[5], Config[6])){
			webhookData := ParseNotification(Config[3], Config[4] - (Config[6] * 1.05), Config[5], Config[6])
			CreateWebhookData(webhookData)
		}
	}
}

CreateWebhookData(data){
	; If webhook data already exists, clear it.
	if FileExist("webhookData.txt") {
		FileDelete("webhookData.txt")
	}

	; Generate data string for webhook handler and create txt file.
	str := data.type . ",," . data.value . ",," . data.color . ",," . data.rng
	FileAppend(str, "webhookData.txt")

	; Wait before trying to read another webhook to avoid duplicate webhooks.
	Sleep 6000
}

SetTimer(ReadInformation, 500)