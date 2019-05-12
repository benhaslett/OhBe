#!!!READ THIS!!!#
#This script MUST be run as northernbeaches\svc.powershell on MAOPS
#all the credentials are saved in that users profile
#it's fine to transport if you know what you are doing (PSHEATAPI module is a pre-requisite, as is the azure powershell module)
#You'll need to setup your own stored crednetials if you move it elsewhere or run as another user OR change the password of northernbeaches\svc.powershell

#What it does
#go fill out this form
#https://northernbeaches.saasitau.com/ - DIRECT LINK TO OFFERING
#you'll see a service request is created in Ivanti
#you'll see a task in the service request
#this bot processes this task
#tests if its change was successful
#updates the task if it was
#if there are no more tasks it closes the service request

#features coming
#when a task fails assign it to a human to review
#perform tasks faster
#email HR when we're done

###########
#Set these#
###########
$script = "CessationofEmployment"
$requestname = "Cessation of Employment"


############
#Leave This#
############
Import-Module C:\users\ben.haslett\OneDrive\Powershell\OhBe\OhBeFrameWork.psm1
$global:log = "c:\scripts\$script.log"

Write-OhBeLog -log $log -status "Starting up and Looking for Service Requests"

connect-OhBeIvantiFramework

connect-OhBeO365ramework

$objects = Get-OhBeRequest -requestname $requestname

ForEach($object in $objects){
    Write-OhBeLog -log $log -status "Attempting to Process a Service Request" -user $object.createdby -RequestNumber $object.ServiceReqNumber

    $tasks = Get-OhBeTasks -ServiceReqNumber $object.ServiceReqNumber
    foreach($task in $tasks){
        Write-OhBeLog -log $log -status "Found a Task!" -user $object.createdby -RequestNumber $ServiceReqNumber -TaskNumber $task.AssignmentID

        ##########################################################
        #Set task names in IFs - $task.Subject -like "TASKNAME *"#
        ##########################################################

        if($task.Subject -like "TASK NAME HERE*"){
            ###########################
            #Set task names in $action#
            ###########################
            $action = "TASK NAME HERE"

            ############
            #Leave This#
            ############
            Write-OhBeLog -log $log -status ("Attempting to " + $action) -user $object.createdby -RequestNumber $ServiceReqNumber -TaskNumber $task.AssignmentID
            $success = $true

            ########################################################
            #Put your Code here $object pulls data from Ivanti Form#
            ########################################################

            #do something with the data pulled from the forms it'll be in $object

            $object

            ##########################################################
            #Put your test here and set success to $false if it fails#
            ##########################################################
            if($true<#PUT TEST HERE#>){    
                $success = $true
            }
            else{
                $success = $false
            }

            ###############################################
            #Leave this as is for a single task workflow  #
            #Multiple task flows are fullied out of the if#
            ###############################################   
            if($success){
                Update-OhBeTaskSuccess -AssignmentID $task.AssignmentID
            }
            else{
                Update-OhBeTaskFailure -AssignmentID $task.AssignmentID -ServiceReqNumber $object.ServiceReqNumber
            }
        }
    }
}
Remove-PSSession $Session