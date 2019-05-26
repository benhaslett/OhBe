properties {
    $script = "./Review-EmailToCaseIncidents.ps1"
}

task default -depends Analyze, Test

task Analyze {
    $saResults = Invoke-ScriptAnalyzer -Path "Review-EmailToCaseIncidents.ps1" -Severity @('Error', 'Warning') -Recurse -Verbose:$true
    if ($saResults) {
        $saResults | Format-Table  
        Write-Error -Message 'One or more Script Analyzer errors/warnings where found. Build cannot continue!'        
    }
}

task Test {
    $testResults = Invoke-Pester -Path "./review-emailtocaseincidents.tests.ps1" -PassThru
    if ($testResults.FailedCount -gt 0) {
        $testResults | Format-List
        Write-Error -Message 'One or more Pester tests failed. Build cannot continue!'
    }
}

task Deploy -depends Analyze, Test {
    Invoke-PSDeploy -Path '.\review-emailtocaseincidents.psdeploy.ps1' -Force -Verbose:$VerbosePreference
}