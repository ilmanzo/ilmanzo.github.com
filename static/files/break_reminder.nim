import std/[os, osproc, strformat, strutils]

const
  StateFile = "/tmp/presence_state"
  CountdownFile = "/tmp/break_countdown"
  TickSeconds = 10
  BreakLimit = 5 * 60 ## minimum absence (seconds) that counts as "took a break"
  BarWidth = 20

func formatTime(seconds: int): string =
  fmt"{seconds div 60}m {seconds mod 60:02}s"

func progressBar(done, total: int): string =
  let filled = clamp((done * BarWidth) div max(total, 1), 0, BarWidth)
  "[" & repeat('#', filled) & repeat('-', BarWidth - filled) & "]"

proc presenceState(): string =
  try: readFile(StateFile).strip()
  except IOError: "idle"

proc writeCountdown(text: string) =
  try: writeFile(CountdownFile, text & "\n")
  except IOError: discard

proc showStatus(line: string) =
  stdout.write "\r" & alignLeft(line, 70)
  stdout.flushFile()

proc speak(lang, text: string) =
  discard execProcess("espeak-ng", args = ["-v", lang, text], options = {poUsePath})

proc triggerAlarm(minutes: int, lang, customMsg: string) =
  echo fmt"BREAK TIME LIMIT REACHED ({minutes} minutes)!"
  let text =
    if customMsg.len > 0: customMsg
    elif lang == "it": fmt"Andrea, fai una pausa! Hai lavorato per {minutes} minuti."
    else: fmt"Andrea, please take a break! You have been working for {minutes} minutes."
  speak(lang, text)
  discard execProcess("wall", args = [fmt"TAKE A BREAK NOW! You have been active for {minutes} minutes."], options = {poUsePath})

proc parseMinutes(s: string): int =
  try: parseInt(s)
  except ValueError: 60

proc paramOrDefault(idx: int, default: string): string =
  if paramCount() >= idx and paramStr(idx).len > 0: paramStr(idx) else: default

proc main =
  let workLimitMinutes = if paramCount() >= 1: parseMinutes(paramStr(1)) else: 60
  let lang = paramOrDefault(2, "it")
  let customMsg = if paramCount() >= 3: paramStr(3) else: ""
  let workLimitSeconds = workLimitMinutes * 60

  echo "Presence-Aware Break Reminder started (Void Linux, motion-integrated)."
  echo fmt"Work limit: {workLimitMinutes}m | Language: {lang}"
  if customMsg.len > 0: echo fmt"Custom message: {customMsg}"

  var presentSeconds, absentSeconds = 0

  while true:
    sleep(TickSeconds * 1000)
    case presenceState()
    of "active":
      presentSeconds += TickSeconds
      absentSeconds = 0
      let remaining = max(0, workLimitSeconds - presentSeconds)
      showStatus fmt"{progressBar(presentSeconds, workLimitSeconds)} Active {formatTime(presentSeconds)} | Remaining {formatTime(remaining)}"
      writeCountdown(formatTime(remaining))
    else:
      absentSeconds += TickSeconds
      let remaining = max(0, workLimitSeconds - presentSeconds)
      if absentSeconds >= BreakLimit and presentSeconds > 0:
        stdout.write "\n"
        echo "Away for 5+ minutes: work clock reset."
        presentSeconds = 0
        writeCountdown("0m 00s (reset)")
      else:
        showStatus fmt"{progressBar(presentSeconds, workLimitSeconds)} Away, countdown paused: {formatTime(remaining)}"
        writeCountdown(fmt"{formatTime(remaining)} (paused)")

    if presentSeconds >= workLimitSeconds:
      stdout.write "\n"
      triggerAlarm(workLimitMinutes, lang, customMsg)
      presentSeconds = 0
      writeCountdown("0m 00s (alarm reset)")

main()