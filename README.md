# OhBe Framework

This is a framework built on the great work of Audaxdreik on PSHEATAPI https://github.com/audaxdreik/PSHEATAPI

The intention of this framework is to make it quick and easy to build powershell based automation that leverages
Ivanti Service Manager (cloud edition) Service Request Offerings.

Many IT departments have lots of scripts but it's often difficult to wrap them up in a UI that a customer can use.
Ivanti Service Manager provides an excellent framework to build UIs and track progress of scripted Self-Service automation.

Key advangates of using ISM as a Self-Service Automation Platform
* Easy to Build and understand User Interfaces
* Self Contained Backend to Track Status
* PSHEATAPI makes it trivial to pull User form input into Powershell
* ISM functions as a System of Record so we (and our auditors) can easily review who did what when 

It's early days for this project any feedback is welcome. It works great for our purposes but probably isn't very portable.

## Getting Started

###
Head over to https://github.com/audaxdreik/PSHEATAPI and the PSHEATAPI module up and running.

Then download and install the OhBe module in your PS profile. $env:PSModulePath (Or See the usage section below for for psake, pester script)

Import the module file using Import-Module OhBeFrameWork.psm1

Import the Oh Be OhBeTemplate.rox file into Ivanti Service Manager as a New Request Offering note the name. Hook up some tasks and note the name.

Then use the OhBeTemplate.ps1 to pull your Service Request Tasks into PowerShell. Use the Names noted in above.

Copy your existing script into the task block (or write a new script)

Create a pass/fail test to see if your script worked.

When the template first runs it'll ask for credentials when it needs them
* Ivanti Service Manager API account
* O365 Tennant rights (if we need to perform tasks in O365)
* O365 email account to email out our reports

Make sure to review this module well before rolling into production!


## Usage

A ```psake``` script has been created to manage the various operations related to testing and deployment of ```OhBeFrameWork.psm1```

### Build Operations


* Test the script via Pester and Script Analyzer  
```powershell

.\build.ps1
```
    
* Test the script with Pester only  
```powershell

.\build.ps1 -Task Test
```
    
* Test the script with Script Analyzer only  
```powershell

.\build.ps1 -Task Analyze
```
    
* Deploy the script via PSDeploy  
```powershell

.\build.ps1 -Task Deploy
```

## Important Note on Deployment!
the Connect-ohbeframework function is host aware and will only connect to the production tennant if it's running on the Prod Server MAOPS! This is supposed to stop testers from spamming users... It won't work but we tried. Really we should have script that breaks all the user emails in Staging. 

## To Do
* emailing out of the framework is only supported via O365 as that is our current scenario - feel free to hack something else in.
* Test Test Test!