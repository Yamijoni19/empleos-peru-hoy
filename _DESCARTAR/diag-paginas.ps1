$h = (Invoke-WebRequest "https://empleosperuhoy.blogspot.com/" -UseBasicParsing).Content
$ms = [regex]::Matches($h, 'href="([^"]*/p/[^"]+)"')
$urls = @($ms | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
Write-Output ("paginas: " + ($urls -join " , "))
foreach ($u in $urls) {
    try {
        $c = (Invoke-WebRequest $u -UseBasicParsing).Content
        $cb = $c -match 'empleosPeruHoyCallback'
        $sec = $c -match 'data-sector-inicial'
        Write-Output ($u + " -> len=" + $c.Length + " callback=" + $cb + " sector=" + $sec)
    } catch {
        Write-Output ($u + " -> ERROR")
    }
}
