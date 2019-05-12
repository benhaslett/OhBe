
function Write-OhBeLog{
    [CmdletBinding()]
    param(
        # The User
        [Parameter(ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
        [string]
        $user = "Unknown",
        # The Status to Write to the Log
        [Parameter(mandatory=$true,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
        [string]
        $status,
        # The Path to the log
        [Parameter(mandatory=$true,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
        [System.IO.FileInfo]$Log,
        # The service request Number
        [Parameter(ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
        [string]
        $RequestNumber = "Unknown",
        # The number of the task
        [Parameter(ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
        [string]
        $TaskNumber = "Unknown"
    )
    $temp = "" | Select-Object time, RequestNumber, TaskNumber, User, status
    $temp.time = get-date
    $temp.user = $user
    $temp.status = $status
    $temp.RequestNumber = $RequestNumber
    $temp.TaskNumber = $TaskNumber
    $temp | export-csv $log -NoTypeInformation -Append
}

function connect-OhBeIvantiFramework{
    try{
        $CredXmlPath = Join-Path (Split-Path $Profile) OhBeIvantiFramework.credential
        $Credential = Import-CliXml $CredXmlPath
    }
    catch{
        $credential = Get-Credential -Message "No Credentials Saved for OhBeIvantiFramework"
        $CredXmlPath = Join-Path (Split-Path $Profile) OhBeIvantiFramework.credential
        $credential | Export-CliXml $CredXmlPath
        $Credential = Import-CliXml $CredXmlPath
    }    
        
    Try{
        Import-Module PSHEATAPI
        Connect-HEATProxy -TenantID northernbeaches.saasitau.com -Role Admin -Credential $Credential
    }
    Catch{
        Write-OhBeLog -status "Failed to Sign into Ivanti" -log $Global:log
    }
}

function connect-OhBeO365ramework{
    try{
        $CredXmlPath = Join-Path (Split-Path $Profile) OhBeO365ramework.credential
        $Credential = Import-CliXml $CredXmlPath
    }
    catch{
        $credential = Get-Credential -Message "No Credentials Saved for OhBeO365ramework"
        $CredXmlPath = Join-Path (Split-Path $Profile) OhBeO365ramework.credential
        $credential | Export-CliXml $CredXmlPath
        $Credential = Import-CliXml $CredXmlPath
    }    

    $Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $Credential -Authentication Basic -AllowRedirection
    Import-PSSession $Session -AllowClobber
    connect-msolservice -Credential $Credential
}

function Get-OhBeRequest{
    [CmdletBinding()]
    param(
        # The Name of the request to search for
        [Parameter(mandatory=$true,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
        [string]
        $requestname
    )
    try{
        #There's a bug in this where a certain combination of status's in Ivanti can hang the bot from processing.
        #Eventual fix is to make this a loop that goes over all service requests. Doing them on at a time while we develop the framework
        $request = ""
        try{
            $requests = Get-HEATBusinessObject -Type 'ServiceReq#' -Value 'Submitted' -Field 'Status' | Where-Object subject -eq $requestname | Sort-Object ServiceReqNumber | Select-Object -first 1
        }
        Catch{
            $requests = Get-HEATBusinessObject -Type 'ServiceReq#' -Value 'Active' -Field 'Status' | Where-Object subject -eq $requestname| Sort-Object ServiceReqNumber | Select-Object -first 1
        }

    }
    catch{
        Write-OhBeLog -status "No Service Request" -Log $global:log
        return
    }
    foreach($request in $requests){
        $incompletereqeust = ""
        try{
            Write-OhBeLog -status "Looking for an incomplete reqest to work n" -user $request.createdby -RequestNumber $request.ServiceReqNumber -Log $global:log
            $incompletereqeust = Get-HEATRequestOffering -RequestNumber $request.ServiceReqNumber   
        }
        Catch{
            Write-OhBeLog -status "Couldn't find an incomplete reqest to work on" -user $request.createdby -RequestNumber $request.ServiceReqNumber -Log $global:log
            return
        }
        $temp = New-Object -TypeName psobject
        $temp | Add-Member -MemberType NoteProperty -Name createdby -Value (get-aduser $incompletereqeust.strCreatedBy -Properties emailaddress).emailaddress   
        $temp | Add-Member -MemberType NoteProperty -Name ServiceReqNumber -Value $request.ServiceReqNumber   
        $temp | Add-Member -MemberType NoteProperty -Name Subject -Value $request.Subject   
                          
        foreach ($param in $incompletereqeust.lstParameters){
            $temp | Add-Member -MemberType NoteProperty -Name $param.strName -Value $param.strDefaultValue    
        }
        Write-OhBeLog -status "Found a request" -user $request.createdby -RequestNumber $request.ServiceReqNumber -Log $global:log
        $temp      
    }
}

function Get-OhBeTasks {
    [CmdletBinding()]
    param(
        # Parameter help description
        [Parameter(Mandatory=$true)]
        [string]
        $ServiceReqNumber
    )
    try{
        $tasks = Get-HEATBusinessObject -Type 'Task#' `
            -Value $ServiceReqNumber `
            -Field 'ParentObjectDisplayID' | `
            Where-Object {$_.status -eq 'Assigned' -or $_.status -eq 'Completed'} | `
            Sort-Object AssignmentID 
    }
    Catch{
        Write-OhBeLog -log $Global:log -status "Problem Finding Tasks $_" -user $global:object.createdby -RequestNumber $ServiceReqNumber
        return
    }
    If($tasks.status -contains 'Assigned'){
        $tasks | Where-Object {$_.status -eq 'Assigned' -and $_.Owner -eq 'oh.be' } #| Select-Object -first 1
    }
    else{
        if(($tasks| Where-Object {$_.Owner -eq 'oh.be' }).status -notcontains 'Assigned'){
            $data = @(
                @{name = 'Status'; Value = 'Fulfilled'}
            )
            Get-HEATBusinessObject -Type 'ServiceReq#' -Value $ServiceReqNumber -Field 'ServiceReqNumber' | Set-HEATBusinessObject -Type 'ServiceReq#' -Data $data
            Write-OhBeLog -log $Global:log -status "Changing Request to Fulfilled... No Waiting on Humans /dance" -user $global:object.createdby -RequestNumber $ServiceReqNumber
            ########################################################
            #Todo: Email the requestor this a well formatted email #
            ########################################################
            $body = "<head><style>"
            $body += "body { background-color:#FFFFFF;
            font-family:Tahoma;
            font-size:12pt; }
            td, th { border:1px solid #0054A5;
            border-collapse:collapse; }
            th { color:white;
            background-color:#0054A5;
            text-align:left; }
            table, tr, td, th { margin: 5px }
            table { margin-left:5px; margin-bottom:20px;}
            .stopped {color: Red }
            .running {color: Green }
            .pending {color: #DF01D7 }
            .paused {color: #FF8000 }
            .other {color: Black }"
            $body += "</style></head>"
            $body += "" + $global:object.createdby + " Requested - " + $global:object.subject + " </br></br>"
            $body += "</br></br>details</br>"
            $body += ($global:object  | ConvertTo-Html | Out-String)
            $body += "</br></br>Tasks</br>"
            $body += ($tasks | select-object Subject, Status, Owner, ResolvedDateTime| ConvertTo-Html | Out-String)

            try{
                $CredXmlPath = Join-Path (Split-Path $Profile) emailRobot.credential
                $UserCredential = Import-CliXml $CredXmlPath
            }
            catch{
                $credential = Get-Credential -Message "No Credentials Saved for emailrobot"
                $CredXmlPath = Join-Path (Split-Path $Profile) emailRobot.credential
                $credential | Export-CliXml $CredXmlPath
                $UserCredential = Import-CliXml $CredXmlPath
            }

            ####################################################################################################################################
            #yes I'm keeping a copy of every interaction. Mainly to keep an eye on the framework as it starts up and help where I can          #
            #TODO: Create a consistent rule for naming the Target User Field in the user facing forms so we don't have to customise each script#
            ####################################################################################################################################
            Send-MailMessage -To "ben.haslett@northernbeaches.nsw.gov.au", $global:object.createdby `
                -UseSsl -Port 587 `
                -Credential $UserCredential `
                -from $UserCredential.username `
                -subject ("" + $global:object.createdby + " Requested - " + $global:object.subject + " ") `
                -BodyAsHtml $body `
                -SmtpServer smtp.office365.com 

            return
        }
    }
}

function Update-OhBeTaskSuccess{
    [cmdletbinding()]
    Param(
        # Task number
        [Parameter(Mandatory=$true)]
        [string]
        $AssignmentID
    )
    $data = @(
        @{name = 'Status'; Value = "Completed"}
    )
    Get-HEATBusinessObject -Type "Task#" -Value $AssignmentID -Field "AssignmentID" | Set-HEATBusinessObject  -Type "Task#" -Data $data -ErrorAction Stop

    Write-OhBeLog -log $global:log -status ("Success! $action") -user $global:object.createdby -RequestNumber $global:object.ServiceReqNumber -TaskNumber $task.AssignmentID
}

function Update-OhBeTaskFailure{
    [cmdletbinding()]
    Param(
        # Task number
        [Parameter(Mandatory=$true)]
        [string]
        $AssignmentID,
        # Task number
        [Parameter(Mandatory=$true)]
        [string]
        $ServiceReqNumber
    )
    $data = @(
        @{name = 'Owner'; Value = ""}
        @{name = 'OwnerTeam'; Value = "Service Delivery"}
    )
    Get-HEATBusinessObject -Type "Task#" -Value $AssignmentID -Field "AssignmentID" | Set-HEATBusinessObject  -Type "Task#" -Data $data -ErrorAction Stop
    Write-OhBeLog -log $global:log -status ("Failed! $action") -user $global:object.createdby -RequestNumber $ServiceReqNumber -TaskNumber $task.AssignmentID

    $data = @(
        @{name = 'Status'; Value = 'Waiting for 3rd Party'}
    )
    Get-HEATBusinessObject -Type 'ServiceReq#' -Value $ServiceReqNumber -Field 'ServiceReqNumber' | Set-HEATBusinessObject -Type 'ServiceReq#' -Data $data
    Write-OhBeLog -log $global:log -status "Changing Request to Waiting for 3rd Party... Waiting on Humans /sigh" -user $global:object.createdby -RequestNumber $global:object.ServiceReqNumber -TaskNumber $task.AssignmentID
}