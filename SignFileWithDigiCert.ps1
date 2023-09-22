function Sign-BinaryFile {
    param (
        [Parameter(HelpMessage = "The DigiCert host", Mandatory = $false)]
        [string] $SM_HOST = "https://clientauth.one.digicert.com",
        [Parameter(HelpMessage = "The DigiCert API Key", Mandatory = $true)]
        [string] $SM_API_KEY,
        [Parameter(HelpMessage = "The DigiCert certificate local path (p12)", Mandatory = $false)]
        [string] $SM_CLIENT_CERT_FILE,
        [Parameter(HelpMessage = "The DigiCert certificate URL (p12)", Mandatory = $false)]
        [string] $SM_CLIENT_CERT_FILE_URL,
        [Parameter(HelpMessage = "The DigiCert certificate password", Mandatory = $true)]
        [SecureString] $SM_CLIENT_CERT_PASSWORD,
        [Parameter(HelpMessage = "The DigiCert certificate thumbprint(fingerprint)", Mandatory = $true)]
        [string] $SM_CODE_SIGNING_CERT_SHA1_HASH,    
        [Parameter(HelpMessage = "A file to sign", Mandatory = $true)]
        [string] $FILE
    )
    begin{
        $tempDirectory = "c:\temp"
        $certLocation = ""
        if (!(Test-Path -Path $tempDirectory))
        {
            [System.IO.Directory]::CreateDirectory($tempDirectory)
        }

        if(-not (Test-Path $FILE ))
        {
            Write-Error "File $FILE is not found! Check the path."
            exit 1;
        }
        if(-not (Test-Path $SM_CLIENT_CERT_FILE ))
        {            
            if(![string]::IsNullOrEmpty($SM_CLIENT_CERT_FILE_URL))
            {
                $certLocation = Join-Path $tempDirectory "digiCert.p12"
                Invoke-WebRequest -Uri "$SM_CLIENT_CERT_FILE_URL" -OutFile $certLocation
                if(Test-Path $certLocation)
                {
                    $SM_CLIENT_CERT_FILE = $certLocation
                }
            }

            if(-not (Test-Path $SM_CLIENT_CERT_FILE ))
            {
                Write-Error "Certificate $SM_CLIENT_CERT_FILE is not found! Check the path."
                exit 1;
            }
        }

        $currentLocation = Get-Location
        #set env variables
        $env:SM_CLIENT_CERT_FILE = $SM_CLIENT_CERT_FILE
        $env:SM_HOST = $SM_HOST 
        $env:SM_API_KEY = $SM_API_KEY
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SM_CLIENT_CERT_PASSWORD)
        $UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        $env:SM_CLIENT_CERT_PASSWORD = $UnsecurePassword       

    }
    process{
        try {
            Set-Location $tempDirectory
            if(-not (Test-Path -Path .\smtools-windows-x64.msi ))
            {
                curl -X GET https://one.digicert.com/signingmanager/api-ui/v1/releases/smtools-windows-x64.msi/download -H "x-api-key:$($SM_API_KEY)" -o smtools-windows-x64.msi 
                msiexec /i smtools-windows-x64.msi /quiet /qn 
            }
            Set-Location "C:\Program Files\DigiCert\DigiCert One Signing Manager Tools"
    
            if($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){
                Write-Output "===============Healthcheck================"
                .\smctl.exe healthcheck
                Write-Output "===============KeyPair list================"
                .\smctl.exe keypair ls 
            }  
            $signMessage = $(.\smctl.exe sign --fingerprint $SM_CODE_SIGNING_CERT_SHA1_HASH --input $FILE )
            if($signMessage.Contains("FAILED")){throw;}
            if($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){
                .\smctl.exe sign verify --input $FILE
            }        
            
            Write-Output "File '$($FILE)' was signed successful!"
        }
        catch {
            Write-Output "Something went wrong! Read the healthcheck"
            .\smctl.exe healthcheck
        }
    }
    end{
        Clear-Content $env:SM_HOST -Force -ErrorAction SilentlyContinue
        Clear-Content $env:SM_API_KEY -Force -ErrorAction SilentlyContinue
        Clear-Content $env:SM_CLIENT_CERT_PASSWORD -Force -ErrorAction SilentlyContinue
        Set-Location $currentLocation
        if((Test-Path $certLocation ))
        {  
            Remove-Item $certLocation -Force -ErrorAction SilentlyContinue
        }
    }
}
