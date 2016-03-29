<#
PowerShell Module 'mpsfilesystemutils.psm1'
Version: 0.1.0.0 (development in progress)

Copyright (c) 2016, Miroslav Harlas
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of CompareMatchingPatterns nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#>





Function Start-MPSFileSystemWatcher
{
<#
.SYNOPSIS
Function Start-MPSFileSystemWatcher creates object of type System.IO.FileSystemWatcher and register events.

.LINKS
Original source:
https://mcpmag.com/articles/2015/09/24/changes-to-a-folder-using-powershell.aspx
http://stackoverflow.com/questions/151804/system-io-filesystemwatcher-to-monitor-a-network-server-folder-performance-con
#>
  [cmdletbinding()]
  Param (
  [parameter()]
  [ValidateScript({Test-Path -path $_})]
  [string]$Path,

  [parameter()]
  [ValidateSet('Changed','Created','Deleted','Renamed')]
  [string[]]$EventName,

  [parameter()]
  [string]$Filter,

  [parameter()]
  [ValidateSet('Attributes','CreationTime','DirectoryName','FileName','LastAccess','LastWrite','Security','Size')]
  [string[]]$NotifyFilter,

  [parameter()]
  [switch]$Recurse,

  [parameter()]
  [scriptblock]$Action

  )

  #region Build  FileSystemWatcher

  $FileSystemWatcher  = New-Object -TypeName System.IO.FileSystemWatcher

  If (-NOT $PSBoundParameters.ContainsKey('Path'))
  {
    $Path  = $PWD
  }

  $FileSystemWatcher.Path = $Path
  If ($PSBoundParameters.ContainsKey('Filter'))
  {
    $FileSystemWatcher.Filter = $Filter
  }

  If ($PSBoundParameters.ContainsKey('NotifyFilter')) {


    $FileSystemWatcher.NotifyFilter =  $NotifyFilter
    <#  
                        [System.IO.NotifyFilters]::Attributes,
                        [System.IO.NotifyFilters]::CreationTime,
                        [System.IO.NotifyFilters]::DirectoryName,
                        [System.IO.NotifyFilters]::FileName,
                        [System.IO.NotifyFilters]::LastAccess,
                        [System.IO.NotifyFilters]::LastWrite,
                        [System.IO.NotifyFilters]::Security,
                        [System.IO.NotifyFilters]::Size
    #>
  }

  If (($Recurse.IsPresent) -and ($Recurse -eq $true))
  {
    $FileSystemWatcher.IncludeSubdirectories =  $True
  }
  Else
  {
    $FileSystemWatcher.IncludeSubdirectories =  $True
  }


  If (-NOT $PSBoundParameters.ContainsKey('EventName')){
    $EventName  = 'Changed','Created','Deleted','Renamed'
  }

  If (-NOT $PSBoundParameters.ContainsKey('Action')){

      $Action  = {

              Switch  ($Event.SourceEventArgs.ChangeType) 
              {

                'Renamed'  {
                            $Hash  = [ordered]@{ 
                                        "Path" = $Event.SourceArgs[-1].OldFullPath.ToString(); 
                                        "Action"=$Event.SourceEventArgs.ChangeType.ToString();
                                        "Time" = $Event.TimeGenerated;
                                        "NewPath" = $Event.SourceArgs[-1].FullPath.ToString()
                                        } 
                            }

                Default    {
                            $Hash  = [ordered]@{
                                        "Path" = $Event.SourceArgs[-1].FullPath.ToString(); 
                                        "Action"=$Event.SourceEventArgs.ChangeType.ToString();
                                        "Time" = $Event.TimeGenerated ;
                                        "NewPath" = ""
                                        } 
                            }

              }
            $Object = New-Object -typename PSObject -Property $Hash
            Write-OutPut $Object
      }

  }
#endregion  Build FileSystemWatcher

    #region  Initiate Jobs for FileSystemWatcher
   
  $ObjectEventParams  = @{
          InputObject =  $FileSystemWatcher
          Action =  $Action
  }
 

  ForEach($Item in  $EventName)
  {
      $ObjectEventParams.EventName = $Item
      $ObjectEventParams.SourceIdentifier = "FileSystemWatcher.$($Item)"
      Write-Verbose  "Starting watcher for Event: $($Item)"
      Register-ObjectEvent  @ObjectEventParams
  }
  #endregion  Initiate Jobs for FileSystemWatcher
} 




Function Stop-MPSFileSystemWatcher
{
    [CmdletBinding(DefaultParameterSetName='StopWatcherByJob')]
    param
    (

    [parameter(Mandatory = $false,
               ParameterSetName='StopWatcherByJob')]    
    $FileSystemWatcherJob,

    [parameter(Mandatory=$true,
               ParameterSetName='StopWatcherByJobId')]
    [ValidateNotNullOrEmpty()]
    [int[]]$FileSystemWatcherJobID,

    [parameter(Mandatory=$true,
               ParameterSetName='StopWatcherByEventName')]
    [ValidateSet('Changed','Created','Deleted','Renamed')]
    [string[]]$EventName
    )

    try
    {
        Switch($PSCmdlet.ParameterSetName)
        {
            StopWatcherByJob
                {
                    If($PSBoundParameters.ContainsKey('FileSystemWatcherJob'))
                    {
                        $jobs = $FileSystemWatcherJob
                    }
                    Else
                    {
                        $EventNames = 'FileSystemWatcher.Changed','FileSystemWatcher.Created','FileSystemWatcher.Deleted','FileSystemWatcher.Renamed'
                        $jobs = Get-Job -Name $EventNames -ErrorAction STOP
                    }

                }
            StopWatcherByJobId
                {
                    $jobs = Get-Job -Id $FileSystemWatcherJobID -ErrorAction STOP
                }
            StopWatcherByEventName
                {
                    $EventNames = $EventName | ForEach-Object {$string = 'FileSystemWatcher.' + $_; Write-Output $string}
                    $jobs = Get-Job -Name $EventNames -ErrorAction STOP
                }
        }
    }
    catch
    {
        Write-Warning "No FileSystemWatcher job found. Details: $_"
    }
    $result = @()
    ForEach($job in $jobs)
    {
        If($job.state -ne 'Running')
        {
            Write-Verbose "FileSystemWatcherJob with id $($job.id) is not running"
        }
        Else
        {
            ForEach($outputitem in $job.output)
            {
                Write-OutPut $outputitem
            }
        }
        Unregister-Event -SubscriptionId $job.id -ErrorAction Continue
        Remove-Job -Job $job -Force -ErrorAction Continue
    }
}




Export-ModuleMember Start-MPSFileSystemWatcher
Export-ModuleMember Stop-MPSFileSystemWatcher