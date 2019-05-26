$sut = "Review-EmailToCaseIncidents.ps1"

Describe 'Unit Tests' {
    Context 'Easy Tests' {

        Import-Module OhBeFrameWork
        $func = connect-OhBeIvantiFramework

        it 'We are able to connect to Ivanti' {
            $func | should be $true    
        }

    }
}