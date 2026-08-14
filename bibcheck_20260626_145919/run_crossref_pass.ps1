param([string]$RunDir)
$entriesDir = Join-Path $RunDir 'entries'
$reportsDir = Join-Path $RunDir 'reports'
function Get-Fields($entry) {
  $fields = @{}
  if ($entry -match '(?s)^@(\w+)\s*\{\s*([^,]+),') { $fields['_type'] = $Matches[1]; $fields['_key'] = $Matches[2].Trim() }
  $pattern = '(?ms)^\s*([A-Za-z][A-Za-z0-9_-]*)\s*=\s*(\{(?:[^{}]|\{[^{}]*\})*\}|"[^"]*"|[^,]+)\s*,?\s*$'
  foreach ($m in [regex]::Matches($entry, $pattern)) {
    $name = $m.Groups[1].Value.ToLowerInvariant()
    $val = $m.Groups[2].Value.Trim()
    if (($val.StartsWith('{') -and $val.EndsWith('}')) -or ($val.StartsWith('"') -and $val.EndsWith('"'))) { $val = $val.Substring(1, $val.Length-2) }
    $fields[$name] = ($val -replace '\s+', ' ').Trim()
  }
  return $fields
}
function Normalize($s) {
  if ($null -eq $s) { return '' }
  $t = [System.Net.WebUtility]::HtmlDecode($s).ToLowerInvariant()
  $t = $t -replace '\{\s*\\''?e\s*\}', 'e'
  $t = $t -replace '\{\\`e\}', 'e'
  $t = $t -replace '\{\\~n\}', 'n'
  $t = $t -replace '\\&', '&'
  $t = $t -replace '[^a-z0-9]+', ' '
  return ($t -replace '\s+', ' ').Trim()
}
function FirstTitle($obj) {
  if ($obj.title -and $obj.title.Count -gt 0) { return [string]$obj.title[0] }
  return $null
}
$results = @()
foreach ($file in Get-ChildItem -LiteralPath $entriesDir -Filter '*.bib' | Sort-Object Name) {
  $entry = Get-Content -LiteralPath $file.FullName -Raw
  $f = Get-Fields $entry
  $key = $f['_key']
  $status = 'unverifiable'
  $canonical = $null
  $issues = New-Object System.Collections.Generic.List[object]
  $sourceTitle = $null; $sourceYear = $null; $sourceVenue = $null; $sourceVolume = $null; $sourceIssue = $null; $sourcePages = $null; $sourceDoi = $null
  $note = ''
  try {
    if ($f.ContainsKey('doi')) {
      $doiEsc = [uri]::EscapeDataString($f['doi'])
      $url = "https://api.crossref.org/works/$doiEsc"
      $resp = Invoke-RestMethod -Uri $url -Headers @{ 'User-Agent'='CodexBibcheck/1.0 (mailto:none@example.com)' } -TimeoutSec 20
      $m = $resp.message
      $canonical = if ($m.URL) { $m.URL } else { 'https://doi.org/' + $f['doi'] }
      $sourceTitle = FirstTitle $m
      $sourceYear = if ($m.published.'date-parts') { [string]$m.published.'date-parts'[0][0] } elseif ($m.issued.'date-parts') { [string]$m.issued.'date-parts'[0][0] } else { $null }
      $sourceVenue = if ($m.'container-title' -and $m.'container-title'.Count -gt 0) { [string]$m.'container-title'[0] } else { $null }
      $sourceVolume = [string]$m.volume
      $sourceIssue = [string]$m.issue
      $sourcePages = [string]$m.page
      $sourceDoi = [string]$m.DOI
      $status = 'clean'
    } else {
      $q = [uri]::EscapeDataString($f['title'])
      $url = "https://api.crossref.org/works?query.title=$q&rows=3"
      $resp = Invoke-RestMethod -Uri $url -Headers @{ 'User-Agent'='CodexBibcheck/1.0 (mailto:none@example.com)' } -TimeoutSec 20
      $items = @($resp.message.items)
      if ($items.Count -gt 0) {
        $best = $items[0]
        $sourceTitle = FirstTitle $best
        $scoreTitleA = Normalize $f['title']
        $scoreTitleB = Normalize $sourceTitle
        if ($scoreTitleA -eq $scoreTitleB -or $scoreTitleB.Contains($scoreTitleA) -or $scoreTitleA.Contains($scoreTitleB)) {
          $canonical = if ($best.URL) { $best.URL } elseif ($best.DOI) { 'https://doi.org/' + $best.DOI } else { $null }
          $sourceYear = if ($best.published.'date-parts') { [string]$best.published.'date-parts'[0][0] } elseif ($best.issued.'date-parts') { [string]$best.issued.'date-parts'[0][0] } else { $null }
          $sourceVenue = if ($best.'container-title' -and $best.'container-title'.Count -gt 0) { [string]$best.'container-title'[0] } else { $null }
          $sourceVolume = [string]$best.volume; $sourceIssue = [string]$best.issue; $sourcePages = [string]$best.page; $sourceDoi = [string]$best.DOI
          $status = 'clean'
        } else {
          $note = "Crossref top hit title mismatch: $sourceTitle"
        }
      }
    }
    if ($sourceTitle -and (Normalize $sourceTitle) -ne (Normalize $f['title'])) {
      $issues.Add([pscustomobject]@{field='title'; original=$f['title']; corrected=$sourceTitle; reason='Canonical source title differs in spelling/case/punctuation'})
    }
    if ($sourceYear -and $f.ContainsKey('year') -and $sourceYear -ne $f['year']) {
      $issues.Add([pscustomobject]@{field='year'; original=$f['year']; corrected=$sourceYear; reason='Canonical source year differs'})
    }
    if ($sourceVenue -and $f.ContainsKey('journal') -and (Normalize $sourceVenue) -ne (Normalize $f['journal'])) {
      $issues.Add([pscustomobject]@{field='journal'; original=$f['journal']; corrected=$sourceVenue; reason='Canonical source venue differs'})
    }
    if ($sourceVolume -and $f.ContainsKey('volume') -and $sourceVolume -ne $f['volume']) {
      $issues.Add([pscustomobject]@{field='volume'; original=$f['volume']; corrected=$sourceVolume; reason='Canonical source volume differs'})
    }
    if ($sourceIssue -and $f.ContainsKey('number') -and $sourceIssue -ne $f['number']) {
      $issues.Add([pscustomobject]@{field='number'; original=$f['number']; corrected=$sourceIssue; reason='Canonical source issue differs'})
    }
    if ($sourcePages -and $f.ContainsKey('pages') -and (Normalize $sourcePages) -ne (Normalize $f['pages'])) {
      $issues.Add([pscustomobject]@{field='pages'; original=$f['pages']; corrected=$sourcePages; reason='Canonical source pages/article number differs'})
    }
    if ($sourceDoi -and $f.ContainsKey('doi') -and (Normalize $sourceDoi) -ne (Normalize $f['doi'])) {
      $issues.Add([pscustomobject]@{field='doi'; original=$f['doi']; corrected=$sourceDoi; reason='Canonical DOI differs'})
    }
    if ($issues.Count -gt 0 -and $status -eq 'clean') { $status = 'corrected' }
  } catch {
    $note = $_.Exception.Message
  }
  $one = if ($sourceTitle) { $sourceTitle } else { $f['title'] }
  $obj = [pscustomobject]@{
    key=$key; status=$status; one_sentence=$one; canonical_url=$canonical; issues=@($issues); note=$note; original_bib=$entry; corrected_bib=$entry
  }
  $obj | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $reportsDir ($key + '.json')) -Encoding UTF8
  $results += $obj
  Start-Sleep -Milliseconds 120
}
$results | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $RunDir 'crossref_pass.json') -Encoding UTF8
$results | Select-Object key,status,canonical_url,note | Format-Table -AutoSize
