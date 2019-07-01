
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
    $activity = ("Working on " + $global:task.Subject)
    write-progress -activity $activity -Status $status -PercentComplete 99
    $temp | export-csv $log -NoTypeInformation -Append
}

function connect-OhBeIvantiFramework{
    [CmdletBinding()]
    param(
        # The Path to the log
        [Parameter(mandatory=$true,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
        [System.IO.FileInfo]$Log,
        [Parameter(ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
        [Switch]$prod
    )
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
        if($env:COMPUTERNAME -eq "MAOPS" -or $prod){
            Write-Output "Oh Hello MAOPS or prod Switch! Connecting to Production..."
            Connect-HEATProxy -TenantID northernbeaches.saasitau.com -Role Admin -Credential $Credential
            Write-OhBeLog -status "Connecting to Production" -log $log  
        }
        else{
            Write-Output "Hey! This isn't MAOPS! Connecting to Staging"
            Connect-HEATProxy -TenantID northernbeaches-stg.saasitau.com -Role Admin -Credential $Credential
            Write-OhBeLog -status "Connecting to Staging" -log $log  
        }
    }
    Catch{
        Write-OhBeLog -status "Failed to Sign into Ivanti" -log $log 
    }
}

function connect-OhBeO365ramework{
    [CmdletBinding()]
    param(
        # The Path to the log
        [Parameter(mandatory=$true,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
        [System.IO.FileInfo]$Log
    )
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
        [Parameter(ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
        [string]$requestname,
        # The Path to the log
        [Parameter(mandatory=$true,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
        [System.IO.FileInfo]$Log,
        [Parameter(ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
        [string]$test
    )
    try{
        #There's a bug in this where a certain combination of status's in Ivanti can hang the bot from processing.
        #Eventual fix is to make this a loop that goes over all service requests. Doing them on at a time while we develop the framework
        $request = ""
        try{
            $requests = Get-HEATBusinessObject -Type 'ServiceReq#' -Value $requestname -Field 'Subject' | where-object {$_.status -eq "Submitted" -or $_.status -eq "Active"} | Sort-Object ServiceReqNumber #| Select-Object -first 1
        }
        Catch{
            $requests = Get-HEATBusinessObject -Type 'ServiceReq#' -Value 'Active' -Field 'Status' | Where-Object subject -eq $requestname| Sort-Object ServiceReqNumber #| Select-Object -first 1
        }

    }
    catch{
        Write-OhBeLog -status "No Service Request" -Log $log 
        return
    }
    if($test){
        Write-Output "Getting test request"
        $requests = Get-HEATBusinessObject -Type 'ServiceReq#' -Value $test -Field 'ServiceReqNumber' | Sort-Object ServiceReqNumber #| Select-Object -first 1
    }
    foreach($request in $requests){
        $incompletereqeust = ""
        try{
            Write-OhBeLog -status "Looking for an incomplete reqest to work on" -user $request.createdby -RequestNumber $request.ServiceReqNumber -Log $log 
            $incompletereqeust = Get-HEATRequestOffering -RequestNumber $request.ServiceReqNumber   
        }
        Catch{
            Write-OhBeLog -status "Couldn't find an incomplete reqest to work on" -user $request.createdby -RequestNumber $request.ServiceReqNumber -Log $log 
            return
        }
        $temp = New-Object -TypeName psobject
        $temp | Add-Member -MemberType NoteProperty -Name createdby -Value (Get-HEATBusinessObject -Type 'Employee#' -Field 'LoginID' -Value $incompletereqeust.strCreatedBy).PrimaryEmail   
        $temp | Add-Member -MemberType NoteProperty -Name ManagerEmail -Value (Get-HEATBusinessObject -Type 'Employee#' -Field 'LoginID' -Value $incompletereqeust.strCreatedBy).ManagerEmail   
        $temp | Add-Member -MemberType NoteProperty -Name ServiceReqNumber -Value $request.ServiceReqNumber   
        $temp | Add-Member -MemberType NoteProperty -Name Subject -Value $request.Subject   
                          
        foreach ($param in $incompletereqeust.lstParameters){
            $temp | Add-Member -MemberType NoteProperty -Name $param.strName -Value $param.strDefaultValue    
        }
        Write-OhBeLog -status "Found a request" -user $request.createdby -RequestNumber $request.ServiceReqNumber -Log $log 
        $temp      
    }
}

function Get-OhBeTasks {
    [CmdletBinding()]
    param(
        # Provide teh service request number
        [Parameter(Mandatory=$true)]
        [string]
        $ServiceReqNumber,
        # The Path to the log
        [Parameter(mandatory=$true,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
        [System.IO.FileInfo]$Log
    )
    try{
        $tasks = Get-HEATBusinessObject -Type 'Task#' `
            -Value $ServiceReqNumber `
            -Field 'ParentObjectDisplayID' | `
            Where-Object {$_.status -eq 'Assigned' -or $_.status -eq 'Completed'} | `
            Sort-Object AssignmentID 
    }
    Catch{
        Write-OhBeLog -log $log -status "Problem Finding Tasks $_" -user $object.createdby -RequestNumber $ServiceReqNumber
        return
    }
    If($tasks.status -contains 'Assigned'){
        Write-OhBeLog -log $log -status ("Found " + ($tasks | where-object status -eq Assigned).count + " Tasks") -user $object.createdby -RequestNumber $ServiceReqNumber
        $tasks | Where-Object {$_.status -eq 'Assigned' -and $_.Owner -eq 'oh.be' } #| Select-Object -first 1
    }
    else{
        Write-OhBeLog -log $log -status ("Found " + $tasks.count + " Tasks") -user $object.createdby -RequestNumber $ServiceReqNumber
    }
 }

 function review-OhBeTasks{
    [CmdletBinding()]
    param(
        # Provide the service request number
        [Parameter(Mandatory=$true)]
        [string]
        $ServiceReqNumber,
        # The Path to the log
        [Parameter(mandatory=$true,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
        [System.IO.FileInfo]$Log
    )
    #not sure how wise this is... If we get a list of tasks that is already completed we fire off an email and set the service request to fullfilled.
    #works well in single task requests but can see it getting messy in Multi task proccesses.
    try{
        $tasks = Get-HEATBusinessObject -Type 'Task#' `
            -Value $ServiceReqNumber `
            -Field 'ParentObjectDisplayID' | `
            #Where-Object {($_.status -eq 'Assigned' -or $_.status -eq 'Completed') -and $_.Owner -eq 'oh.be'} | `
            Sort-Object AssignmentID | Where-Object {$_.ParentLink_Category -eq "ServiceReq"}
    }
    Catch{
        Write-OhBeLog -log $log -status "Problem Finding Tasks $_" -user $global:object.createdby -RequestNumber $ServiceReqNumber
        return
    }

    If(($tasks| Where-Object {$_.Owner -eq 'oh.be'}).status -contains 'Assigned'){
        Write-OhBeLog -log $log -status ("Still Found " + ($tasks | where-object status -eq Assigned).count + " tasks Not all tasks are done") -user $object.createdby -RequestNumber $ServiceReqNumber
        $tasks | Where-Object {$_.status -eq 'Assigned' -and $_.Owner -eq 'oh.be'} #| Select-Object -first 1
    }
    else{
        if( @($tasks | Where-Object status -ne "Completed").count -eq 0 ){
            $data = @(
                @{name = 'Status'; Value = 'Fulfilled'}
            )
            Get-HEATBusinessObject -Type 'ServiceReq#' -Value $ServiceReqNumber -Field 'ServiceReqNumber' | Set-HEATBusinessObject -Type 'ServiceReq#' -Data $data
            Write-OhBeLog -log $log -status "Changing Request to Fulfilled... No Waiting on Humans /dance" -user $global:object.createdby -RequestNumber $ServiceReqNumber
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
            $body += "Hi there! This is an eGovernance notifcation that you or someone in your team has made a change in our environment."
            $body +=  "Please review this change and let IT know if it should be reviewed.<br><br>"
            $body += "" + $global:object.createdby + " Requested - " + $global:object.subject + " </br></br>"
            $body += "</br></br>details</br>"
            $body += ($global:object | select createdby, ManagerEmail, ServiceReqNumber, Subject | ConvertTo-Html | Out-String)
            $body += "</br></br>Task Breakdown</br>"
            $body += ($tasks | select-object Subject, Status, Owner | ConvertTo-Html | Out-String)

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
            $recipients = @()
            $recipients += "ben.haslett@northernbeaches.nsw.gov.au"
            IF($null -ne $global:object.createdby){
                $recipients += $global:object.createdby
            }
            IF($null -ne $global:object.ManagerEmail){
                $recipients += $global:object.ManagerEmail
            }            
            Send-MailMessage -To $recipients `
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
        $AssignmentID,
        # The Path to the log
        [Parameter(mandatory=$true,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
        [System.IO.FileInfo]$Log
    )
    $data = @(
        @{name = 'Status'; Value = "Completed"}
    )
    Get-HEATBusinessObject -Type "Task#" -Value $AssignmentID -Field "AssignmentID" | Set-HEATBusinessObject  -Type "Task#" -Data $data -ErrorAction Stop

    Write-OhBeLog -log $log -status ("Success! $action") -user $global:object.createdby -RequestNumber $global:object.ServiceReqNumber -TaskNumber $task.AssignmentID
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
        $ServiceReqNumber,
        # The Path to the log
        [Parameter(mandatory=$true,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
        [System.IO.FileInfo]$Log
    )
    $data = @(
        @{name = 'Owner'; Value = ""}
        @{name = 'OwnerTeam'; Value = "Service Delivery"}
    )
    Get-HEATBusinessObject -Type "Task#" -Value $AssignmentID -Field "AssignmentID" | Set-HEATBusinessObject  -Type "Task#" -Data $data -ErrorAction Stop
    Write-OhBeLog -log $log -status ("Failed! $action") -user $global:object.createdby -RequestNumber $ServiceReqNumber -TaskNumber $task.AssignmentID

    $data = @(
        @{name = 'Status'; Value = 'Waiting for 3rd Party'}
    )
    Get-HEATBusinessObject -Type 'ServiceReq#' -Value $ServiceReqNumber -Field 'ServiceReqNumber' | Set-HEATBusinessObject -Type 'ServiceReq#' -Data $data
    Write-OhBeLog -log $log -status "Changing Request to Waiting for 3rd Party... Waiting on Humans /sigh" -user $global:object.createdby -RequestNumber $global:object.ServiceReqNumber -TaskNumber $task.AssignmentID
}


function get-newdiceword{
    <# Get-NewDiceWord
    .SYNOPSIS
        Grabs Dice Word List and creates a new diceword

    .DESCRIPTION
        Password Good Practice

    .EXAMPLE        
        >Get-NewDiceWord -numberofwords 42


    .PARAMETER 
        numberofwords the number of dice words to use from the list
    #>
    param(
        [Parameter(Mandatory=$false,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
        [string]$numberofwords=3
    )
    $wordlist = ([System.Text.Encoding]::ASCII.GetString((Invoke-WebRequest http://world.std.com/~reinhold/diceware.wordlist.asc -UseBasicParsing).content) -split "-----")[2] -split "`n" #could spend some time improving this to check the pgp key

    $i=0
    $diceword = ""
    while($i -lt $numberofwords){
        $word = (get-culture).TextInfo.ToTitleCase($wordlist[(Get-Random -Minimum 2 -Maximum $wordlist.count)])
        $diceword += $word.substring(6,($word.length - 6)) #hacky hax is where we're at
        $i++
    }
    $diceword += (get-random -Minimum 10 -Maximum 99)
    $diceword += (get-random -InputObject "!","@","#","$","%")
    $diceword 
}
