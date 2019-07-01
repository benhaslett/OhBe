Remove-Module OhBeFrameWork

$paths = "C:\Windows\System32\WindowsPowerShell\v1.0\Modules\OhBeFramework",
"c:\scripts",
"$env:USERPROFILE\documents\windowspowershell" 

foreach($path in $paths){
    if(-not (test-path $path)){
        try{
            mkdir $path
        }
        catch{
            write-output "Couldn't make $path Did you run as admin?"
            return
        }
    }
}

try{
    Import-Module PSHEATAPI -ErrorAction Stop
}
Catch{
    Write-Output "PSHEATAPI not found. Downloading it from https://github.com/audaxdreik/PSHEATAPI/archive/master.zip"
    Try{
        Invoke-WebRequest -Uri "https://github.com/audaxdreik/PSHEATAPI/archive/master.zip" -OutFile c:\scripts\master.zip -ErrorAction Stop
    }
    Catch{
        write-output "Couldn't download PSHEATAPI Did you run as admin?"
        return
    }
    try{
        Expand-Archive c:\scripts\master.zip C:\Scripts\
        copy-item .\master\PSHEATAPI-master\PSHEATAPI\ C:\Windows\System32\WindowsPowerShell\v1.0\Modules\ -Recurse -ErrorAction Stop
    }
    Catch{
        write-output "Couldn't install PSHEATAPI Did you run as admin?"
        return
    }
    try{
        Remove-Item c:\scripts\master -Confirm:$false -Recurse
        Remove-Item c:\scripts\master.zip -Confirm:$false
    }
    catch{
        write-output "Couldn't clean up master and master.zip go delete them from c:\scripts"
        return       
    }
    try{
        Import-Module PSHEATAPI -ErrorAction Stop
    }
    Catch{
        write-output "Couldn't import PSHEATAPI"
        return        
    }
}
Try{
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/benhaslett/OhBe/master/OhBeFrameWork.psm1" -OutFile c:\scripts\OhBeFrameWork.psm1 -ErrorAction Stop
}
Catch{
    write-output "Couldn't download ohbeframework Did you run as admin?"
    return
}

try{
    copy-item c:\scripts\OhBeFrameWork.psm1 C:\Windows\System32\WindowsPowerShell\v1.0\Modules\OhBeFramework\OhBeFrameWork.psm1 -Recurse -ErrorAction Stop
}
Catch{
    write-output "Couldn't install ohbe Did you run as admin?"
    return
}


Get-ChildItem C:\Windows\System32\WindowsPowerShell\v1.0\Modules\OhBeFramework\OhBeFrameWork.psm1 | Select-Object LastWriteTime

import-Module OhBeFrameWork