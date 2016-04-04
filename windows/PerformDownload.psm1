param (
  [string]$mirror = "",
  [int]$timeout = 3600000
)

function Get-FileHash($targetFile) {
  $size = (Get-Item $targetFile).length / 1000000
  Write-Host "Hashing $size MB $targetFile"
  $readStream = [system.io.file]::openread($targetFile)
  $hasher = [System.Security.Cryptography.HashAlgorithm]::create('sha256')
  $hash = $hasher.ComputeHash($readStream)
  $readStream.Close()
  return [system.bitconverter]::toString($hash)
}

function Check-GpgSig ($targetfile, $cert, $sig) {
    gpg --import $targetCert
    gpg --verify $targetSig $targetFile
    return $LastExitCode
}

Function PerformDownloadGeneric ($url, $targetFile) {
    Write-Host "Input URL: [$url] downloading to [$targetFile]"

    # Create the request and do our best to avoid any local caching or socket reusing (causes backend caching)
    # Core of this code is by Jason Niver's blog.
    # http://blogs.msdn.com/b/jasonn/archive/2008/06/13/downloading-files-from-the-internet-in-powershell-with-progress.aspx
    $uri = New-Object "System.Uri" "$url"
    $request = [System.Net.HttpWebRequest]::Create($uri)
    $request.CachePolicy = New-Object System.Net.Cache.HttpRequestCachePolicy([System.Net.Cache.HttpRequestCacheLevel]::NoCacheNoStore)
    $request.Headers.Add("Cache-Control", "no-cache")
    $request.KeepAlive = 0
    $request.set_Timeout($timeout)
    $tmp1 = $request.RequestUri
    $tmp2 = $request.Timeout

    # Make the actual request
    try {
      $response = $request.GetResponse()
      # Get the file size, allowing the pretty progress bar
      $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024)
      Write-Host "Total length is $totalLength KiB."

      # Set up the buffer for reading the file and writing it to disk
      $responseStream = $response.GetResponseStream()
      $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create
      $buffer = new-object byte[] 10KB
      $count = $responseStream.Read($buffer,0,$buffer.length)
      $downloadedBytes = $count

      # Download the file and write to disk
      while ($count -gt 0)
      {
        $targetStream.Write($buffer, 0, $count)
        $count = $responseStream.Read($buffer,0,$buffer.length)
        $downloadedBytes = $downloadedBytes + $count
        Write-Progress -activity "Downloading file '$($url.split('/') | Select -Last 1)'" -status "Downloaded ($([System.Math]::Floor($downloadedBytes/1024))K of $($totalLength)K): " -PercentComplete ((([System.Math]::Floor($downloadedBytes/1024)) / $totalLength)  * 100)
      }
      # Clean up after ourselves
      $targetStream.Flush()
      $targetStream.Close()
      $targetStream.Dispose()
      $responseStream.Dispose()
    } catch {
       Write-Host "Unable to download $url error " $_.Exception.Message
       return $False
    }

    return $True
}

Function PerformDownload ($url, $target, $expectedHash) {
    $targetFile = $env:temp + "\" + $target

    # Check if the file is already downloaded
    if (($expectedHash) -and (Test-Path $targetFile)) {
      $hash = Get-FileHash($targetFile)
      if ($hash -eq $expectedHash) {
         Write-Host "[Already have $targetFile with hash $hash so skipping download]"
         return
      } else {
         Write-Host "[Already have $targetFile but its hash $hash is not $expectedHash so downloading again]"
      }
    }

    # Download the file
    if ($mirror) {
       if (-Not (PerformDownloadGeneric "$($mirror)/$($target)" $targetFile)) {
          Write-Host "Downloading $target from the mirror $mirror failed, falling back to the upstream URL: $url"
          if (-Not (PerformDownloadGeneric "$url" $targetFile)) {
             Exit 1
          }
       }
    } else {
       if (-Not (PerformDownloadGeneric "$url" $targetFile)) {
          Exit 1
       }
    }

    # Check the hash of the downloaded file
    $hash = Get-FileHash($targetFile)
    Write-Host "$hash calculated for $targetFile"
    if ($expectedHash -and ($hash -ne $expectedHash)) {
        Write-Host "ERROR: $targetFile does not contain the expected content (found hash $hash rather than $expectedHash)"
        Exit 2
    }
}

Function PerformDownloadGpg ($url, $target, $cert, $sig) {
    Import-Module BitsTransfer

    $targetFile = $env:temp + "\" + $target

    # Download cert and sig
    $targetCert = $targetFile + ".cert"
    Start-BitsTransfer -Source $cert -Destination $targetCert
    $targetSig = $targetFile + ".sig"
    Start-BitsTransfer -Source $sig -Destination $targetSig

    # Check if the target file is already downloaded
    Check-GpgSig $targetFile $targetCert $targetSig
    $gpg_valid = $LastExitCode
    if ($gpg_valid -ne 0) {
        Write-Host "[Already have $targetFile but its signature is bad so downloading again]"
    } else {
        Write-Host "[Already have $targetFile with a correct signature so skipping download]"
        return
    }

    # Download the file
    if ($mirror) {
       if (-Not (PerformDownloadGeneric "$($mirror)/$($target)" $targetFile)) {
          Write-Host "Downloading $target from the mirror $mirror failed, falling back to the upstream URL: $url"
          if (-Not (PerformDownloadGeneric "$url" $targetFile)) {
             Exit 1
          }
       }
    } else {
       if (-Not (PerformDownloadGeneric "$url" $targetFile)) {
          Exit 1
       }
    }

    # Check the signature of the downloaded file
    Check-GpgSig $targetFile $targetCert $targetSig
    $gpg_valid = $LastExitCode
    if ($gpg_valid -ne 0) {
        Write-Host "ERROR: $targetFile does not contain the expected content"
        Exit 2
    }
}
