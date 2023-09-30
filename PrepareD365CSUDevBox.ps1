# Set prerequisites
$GitGlobalUserName         = "Dmytro Sindeli" 
$tenant                    = "vertexinc.com"
$vmAdminUserName           = "vmadmin"
$saPassword                = "G/7gwmfohn5bacdf4oo"
$GitGlobalEmail            = "$($GitGlobalUserName.Replace(" ", ".").ToLower())@$tenant" 


###############################

function invoke-choco {
    Param(
        [switch] $silent,
        [switch] $returnValue,
        [parameter(mandatory = $true, position = 0)][string] $command,
        [parameter(mandatory = $false, position = 1, ValueFromRemainingArguments = $true)] $remaining
    )
    begin
    {
        If(!(Get-Command -Name choco.exe -ErrorAction SilentlyContinue))
        {
            Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))  
            Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1
        }
        function CmdDo {
            Param(
                [string] $command = "",
                [string] $arguments = "",
                [switch] $silent,
                [switch] $returnValue
            )

            $oldNoColor = "$env:NO_COLOR"
            $env:NO_COLOR = "Y"
            $oldEncoding = [Console]::OutputEncoding
            #[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            try {
                $result = $true
                $pinfo = New-Object System.Diagnostics.ProcessStartInfo
                $pinfo.FileName = $command
                $pinfo.RedirectStandardError = $true
                $pinfo.RedirectStandardOutput = $true
                $pinfo.WorkingDirectory = Get-Location
                $pinfo.UseShellExecute = $false
                $pinfo.Arguments = $arguments
                $p = New-Object System.Diagnostics.Process
                $p.StartInfo = $pinfo
                $p.Start() | Out-Null
    
                $outtask = $p.StandardOutput.ReadToEndAsync()
                $errtask = $p.StandardError.ReadToEndAsync()
                $p.WaitForExit();

                $message = $outtask.Result
                $err = $errtask.Result

                if ("$err" -ne "") {
                    $message += "$err"
                }
        
                $message = $message.Trim()

                if ($p.ExitCode -eq 0) {
                    if (!$silent) {
                        Write-Host $message
                    }
                    if ($returnValue) {
                        $message.Replace("`r","").Split("`n")
                    }
                }
                else {
                    $message += "`n`nExitCode: "+$p.ExitCode + "`nCommandline: $command $arguments"
                    throw $message
                }
            }
            finally {
            #    [Console]::OutputEncoding = $oldEncoding
                $env:NO_COLOR = $oldNoColor
            }
        }
    }
    process
    {
        $arguments = "$command "
        $remaining | ForEach-Object {
            if ("$_".IndexOf(" ") -ge 0 -or "$_".IndexOf('"') -ge 0) {
                $arguments += """$($_.Replace('"','\"'))"" "
            }
            else {
                $arguments += "$_ "
            }
        }
        cmdDo -command choco -arguments $arguments -silent:$silent -returnValue:$returnValue
        
        refreshenv
    }
}


$buildPath = "$($env:USERPROFILE)\Downloads"
Set-Location $buildPath

#install sql server 2022
Start-BitsTransfer -Source ([URI]("https://ciellosarchive.blob.core.windows.net/iso/enu_sql_server_2022_enterprise_edition_x64_dvd_aa36de9e.iso?sp=r&st=2023-09-28T15:38:22Z&se=2033-09-28T23:38:22Z&spr=https&sv=2022-11-02&sr=b&sig=tbQ%2B2jntPu2Jpxn0ZEsci5GbVUw5n8idZDB1c75Vhv8%3D")) -Destination enu_sql_server_2022_enterprise_edition_x64_dvd_aa36de9e.iso
$mountDest = Mount-DiskImage -ImagePath $buildPath\enu_sql_server_2022_enterprise_edition_x64_dvd_aa36de9e.iso
$hostName = [System.Net.Dns]::GetHostEntry("").HostName

$installCommand = "F:\setup.exe /Q /IACCEPTSQLSERVERLICENSETERMS /ACTION='install' /PID='J4V48-P8MM4-9N3J9-HD97X-DYMRM' /FEATURES=SQL,AS,IS /INSTANCENAME=MSSQLSERVER /SQLSYSADMINACCOUNTS='$hostName\$vmAdminUserName' /SECURITYMODE='SQL' /SAPWD='$saPassword' /ASSYSADMINACCOUNTS='$hostName\$vmAdminUserName'" 
Invoke-Expression -Command $installCommand

###### Install software
invoke-choco install git.install --force -y
invoke-choco install visualstudiocode vscode-gitlens vscode-csharp vscode-powershell vscode-intellicode --force -y
invoke-choco install visualstudio2022buildtools --package-parameters "--passive --locale en-US" --force -y
invoke-choco install -y python visualstudio2022-workload-vctools visualstudio2022-workload-nativedesktop visualstudio2022-workload-netweb visualstudio2022-workload-node --force
invoke-choco install sql-server-management-studio --force -y
invoke-choco install nodejs-lts -y
Install-WindowsFeature -name Web-Server -IncludeManagementTools -IncludeAllSubFeature
Add-WindowsFeature NET-HTTP-Activation
invoke-choco install webdeploy -y
invoke-choco install urlrewrite -y
invoke-choco install dotnetcore-sdk dotnet-6.0-sdk dotnet-7.0-sdk dotnet-aspnetcoremodule-v2 --force -y

#set firewall rules
Remove-NetFirewallRule -Group "Custom SQL"
New-NetFirewallRule -Group "Custom SQL" -DisplayName "SQL Default Instance" -Direction Inbound –Protocol TCP –LocalPort 1433 -Action allow
New-NetFirewallRule -Group "Custom SQL" -DisplayName "SQL Admin Connection" -Direction Inbound –Protocol TCP –LocalPort 1434 -Action allow
New-NetFirewallRule -Group "Custom SQL" -DisplayName "SQL Always On VNN" -Direction Inbound -Protocol TCP -LocalPort 1764 -Action allow 
New-NetFirewallRule -Group "Custom SQL" -DisplayName "SQL Always On AG Endpoint" -Direction Inbound -Protocol TCP -LocalPort 5022 -Action allow
New-NetFirewallRule -Group "Custom SQL" -DisplayName "Azure Load Balancer probe" -Direction Inbound -Protocol TCP -LocalPort 59999 -Action allow
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Enable-NetFirewallRule -DisplayGroup "Remote Event Log Management"
Enable-NetFirewallRule -DisplayGroup "Remote Service Management"
Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"
Enable-NetFirewallRule -DisplayGroup "Performance Logs and Alerts"
Enable-NetFirewallRule -DisplayGroup "Remote Volume Management"
New-NetFirewallRule -DisplayName "SQLServer default instance" -Direction Inbound -LocalPort 1433 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "SQLServer Browser service" -Direction Inbound -LocalPort 1434 -Protocol UDP -Action Allow

netsh firewall set portopening protocol = TCP port = 1433 name = SQLPort mode = ENABLE scope = SUBNET profile = CURRENT


#set github configs
git config --global user.name $GitGlobalUserName
git config --global user.email $GitGlobalEmail


# Set vscode as default git editor
git config --global core.editor 'code --wait'

# Set vscode as default git diff tool
git config --global diff.tool vscode
git config --global difftool.vscode.cmd 'code --wait --diff $LOCAL $REMOTE'

# Set vscode as default git merge tool
git config --global merge.tool vscode
git config --global mergetool.vscode.cmd 'code --wait $MERGED'

# Add alias to git log with pretty format
git config --global alias.lg "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"

# List all git configurations
git config --list
