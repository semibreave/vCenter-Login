#return object list in text file
function Get-ObjectList
{
    param($key1)
    
    $id= whoami
    
    $trimmed_id = $id.toString().split('\')[1]

    if($key1 -eq "computer"){$content = Get-Content C:\Users\$trimmed_id\Desktop\computers.txt|Where-Object{$_.trim() -ne ''}}
    
    elseif($key1 -eq "vm"){$content = Import-Csv  C:\Users\$trimmed_id\Desktop\vms.csv}
    

    return $content

}

#return vm with associated vCenter object
function Match-CSV
{
    param($computers,$csv)

    $vm_vc = @()
    
    #Generate VM_VC table
    foreach($computer in $computers)
    {
        Write-Host "Getting vCenter for"$computer
        
        $vc = ($csv|Select-Object vm,vc|Where-Object{$_.vm -eq $computer}).vc
    
        if($vc -ne $null)
        {
           $vm_vc += New-Object psobject -Property @{
                    
                                                        "VM" = $computer
                                                        "VC" = $vc
                     
                                                     }
        }
        
        else
        {
            $vm_vc += New-Object psobject -Property @{
                    
                                                        "VM" = $computer
                                                        "VC" = "null"
                     
                                                     }
 
        
        }
    
       
    }

    cls

    return $vm_vc

}

function Get-CSV_Compliant
{
    param($vm_vc)

    $result = "Pass"

    foreach($vco in $vm_vc)
    {
        if(( (($vco|where{$_.vm -eq $vco.vm}).vc.count) -gt 1 ) -or ($vco.vc -eq "NULL")  )
        {
           $result = "Fail" 
           break
        }
    
    }

    return $result
}

#return vm,vc and it login status object
function Login-ManyVCenter
{
   param($vm_vc,$credential)
   
   Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false |Out-Null
   
   $vc_login_stat = @()
   
    
   foreach($vco in $vm_vc)
   {
      
      Write-Host "Logging to vCenter for" $vco.vm
       
       
       try{ 
            Connect-VIServer $vco.vc -ErrorAction Stop -Credential $credential | Out-Null

            $vc_login_stat +=  New-Object psobject -Property @{
                                                                "VM" = $vco.vm
                                                                "vCenter" = $vco.vc
                                                                "Login"   = "OK"
                                                               }
           }

       catch{
              $vc_login_stat +=  New-Object psobject -Property @{
                                                                    "VM" = $vco.vm
                                                                    "vCenter" = $vco.vc
                                                                    "Login"   = "UTL"
                                                                }
        }
   }

   cls
   
   return $vc_login_stat
}

function Get-VC_Compliant
{
    param ($vc_login_stat)

    $result = "Pass"

    foreach($vco in $vc_login_stat)
    {
        if($vco.login -eq "UTL")
        {
           $result = "Fail" 
           break
        }
    
    }

    return $result

}


$vm_vc_obj = Match-CSV (Get-ObjectList computer)(Get-ObjectList vm)

$csv_compliance = Get-CSV_Compliant($vm_vc_obj)


if($csv_compliance -eq "Pass")
{
    $credential = Get-Credential -Message "Some vCenters required passed credential"
    
    $vc_stat = Login-ManyVCenter $vm_vc_obj $credential

    $vc_compliance = Get-VC_Compliant $vc_stat

    if($vc_compliance -eq "Pass"){

        Write-Host "MAIN MENU"

    }

    else{
        
        Write-Host "Remove or resolve VM with UTL"
        $vc_stat|Select-Object VM,VC,Login

        
    }
}

else
{
    Write-Host "Remove VM with null or multiple vCenter and try again"

    $vm_vc_obj

    
    
}




