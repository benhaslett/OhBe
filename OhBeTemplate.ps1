<#
.SYNOPSIS
Template for Oh Be Framework scripts

.DESCRIPTION
!!!READ THIS!!!#This script MUST be run as northernbeaches\svc.powershell on MAOPS
all the credentials are saved in that users profile
it's fine to transport if you know what you are doing (PSHEATAPI module is a pre-requisite, as is the azure powershell module)
You'll need to setup your own stored crednetials if you move it elsewhere or run as another user OR change the password of northernbeaches\svc.powershell

What it does
go fill out this form
[[[Direct Link to Offering Here]]]]
you'll see a service request is created in Ivanti
you'll see tasks in the service request
this script processes these tasks
tests if its change was successful
updates the task if it was
if there are no more tasks it closes the service request

features coming
email HR/manager when we're done
#>

###########
#Set these#
###########
$script = "CessationofEmployment"
$requestname = "Cessation of Employment"


############
#Leave This#
############
Import-Module OhBeFrameWork
$log = "c:\scripts\$script.log"

Write-OhBeLog -log $log -status "Starting up and Looking for Service Requests"

connect-OhBeIvantiFramework -log $log 

connect-OhBeO365ramework -log $log 

$objects = Get-OhBeRequest -requestname $requestname -log $log 

ForEach($object in $objects){
    Write-OhBeLog -log $log -status "Attempting to Process a Service Request" -user $object.createdby -RequestNumber $object.ServiceReqNumber

    $tasks = Get-OhBeTasks -ServiceReqNumber $object.ServiceReqNumber -log $log 
    foreach($task in $tasks){
        Write-OhBeLog -log $log -status "Found a Task!" -user $object.createdby -RequestNumber $object.ServiceReqNumber -TaskNumber $task.AssignmentID

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
            Write-OhBeLog -log $log -status ("Attempting to " + $action) -user $object.createdby -RequestNumber $object.ServiceReqNumber -TaskNumber $task.AssignmentID
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
                Update-OhBeTaskSuccess -AssignmentID $task.AssignmentID -log $log 
            }
            else{
                Update-OhBeTaskFailure -AssignmentID $task.AssignmentID -ServiceReqNumber $object.ServiceReqNumber -log $log 
            }
        }
    }
    review-OhBeTasks -ServiceReqNumber $object.ServiceReqNumber -log $log 
}
Remove-PSSession $Session