$sut = "OhBeFrameWork.psm1"
$log = "$env:TEMP\OhBeUnitTest.log"


Describe 'Unit Tests' {
    Context 'Easy Tests' {

        Import-Module OhBeFrameWork
        $func = connect-OhBeIvantiFramework -log $log
        it 'We are able to connect to Ivanti' {
            $func | should contain $true    
        }

        <#$request = Get-OhBeRequest -requestname "Cessation of Employment" -log $log

        it 'We can get a request'{
            $request.ServiceReqNumber | should be $true
        }#>
    }
}