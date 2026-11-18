# Speaks every line in voice_lines.json with Windows' built-in TTS into
# gen_scripts/voice_raw/<id>.wav (post-processed by gen_voice_post.py).
param([string]$Here = $PSScriptRoot)
Add-Type -AssemblyName System.Speech
$lines = Get-Content -Raw -Encoding UTF8 (Join-Path $Here "voice_lines.json") | ConvertFrom-Json
$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(44100, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono)
foreach ($l in $lines) {
    $s = New-Object System.Speech.Synthesis.SpeechSynthesizer
    try { $s.SelectVoice($l.voice) } catch { }
    $s.Rate = [int]$l.rate
    $out = Join-Path $Here ("voice_raw\" + $l.id + ".wav")
    $s.SetOutputToWaveFile($out, $fmt)
    $s.Speak($l.text)
    $s.Dispose()
    Write-Output ("spoke " + $l.id)
}
