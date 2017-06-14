Function Unzip-File()
{
    param([string]$ZipFile,[string]$TargetFolder)
    #ȷ��Ŀ���ļ��б������,Ŀ���ļ��д��� ������ļ���
    if(!(Test-Path $TargetFolder))
    {
        mkdir $TargetFolder
    }else{
    	del -Recurse -Force $TargetFolder\*
    }
    $shellApp = New-Object -ComObject Shell.Application
    $files = $shellApp.NameSpace($ZipFile).Items()
    $shellApp.NameSpace($TargetFolder).CopyHere($files)
}
Unzip-File -ZipFile d:\caffe-static\package\wgetwin-1_5_3_1-binary.zip -TargetFolder d:\caffe-static\tools\wget