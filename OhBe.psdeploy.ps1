Deploy 'Deploy ServerInfo script' {
    By Filesystem {
        FromSource '.\Review-EmailToCaseIncidents.ps1'
        To '\\maops\c$\scripts\'
        Tagged Prod
    }
}