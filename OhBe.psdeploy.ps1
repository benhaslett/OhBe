Deploy 'Deploy OhBeFrameWork Module' {
    By Filesystem {
        FromSource 'OhBeFrameWork.psm1'
        To '\\maops\c$\windows\system32\WindowsPowerShell\v1.0\Modules\OhBeFrameWork\OhBeFrameWork.psm1'
        Tagged Prod
    }
}