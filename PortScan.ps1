Class Node {
    [String] $HostName = ""
    [String] $MACAddress = ""
    [String] $IPv4Address = "localhost"

    [String]$OpenPortsCurrent = ""
    [String]$OpenPortsBaseline = ""

Node(){
}
Node([String]$Hostname, [String]$MACAddress, [String]$IPV4Address)
{
    $this.HostName = $Hostname
    $this.MACAddress = $MACAddress
    $this.IPv4Address = $IPV4Address
    
}
   [Void]GetOpenPorts()
    {
      
      $this.OpenPortsCurrent = ""
      write-host ($this.OpenPortsBaseline -eq $null)
      $Ports = Import-Csv "\Ports.csv" 
      
      foreach($port in $Ports.GetEnumerator())
      {
         
          $TCPClient = New-Object System.Net.Sockets.TcpClient
          $portResult = $TCPClient.BeginConnect($this.IPv4Address, $port.ports, $null, $null)
          $Wait = $portResult.AsyncWaitHandle.WaitOne(1000)
        
          if ($portResult.IsCompleted  -eq $true)
          {
              $this.OpenPortsCurrent += $port.ports + " "
          }
          if ($Wait)
          {
              try {
                  $Null = $TCPClient.EndConnect($portResult)
              }catch {
                   Write-Warning $_
              }
          }
          $TCPClient.Dispose()
      }
    }
    
    [Void]SetPortBaseline()
    {
        $this.OpenPortsBaseline = $this.OpenPortsCurrent 
    }

    [String]GetPortBaseline()
    {
        return $this.OpenPortsBaseline
    }


SetAdapterSpeed($option = 0, [PSCredential] $credentials)
{
    if($option -eq 1)
    {
        # change to 100/Full
        Invoke-Command -Computer $this.HostName -Authentication Kerberos -Credential $credentials -ScriptBlock{Set-NetAdapterAdvancedProperty -DisplayName 'Speed & Duplex' -DisplayValue '100 Mbps Full Duplex'}
    }else{
        # change to Auto Negotiation
        Invoke-Command -Computer $this.Hostname -Authentication Kerberos -Credential $credentials -ScriptBlock{Set-NetAdapterAdvancedProperty -DisplayName 'Speed & Duplex' -DisplayValue 'Auto Negotiation'}
    }

}

[String]GetAdapterSpeed([PSCredential] $credentials)
{ 

    $info = Invoke-Command -Computer $this.Hostname -Authentication Kerberos -Credential $credentials  -ScriptBlock{Get-NetAdapterAdvancedProperty -Name Eth* -DisplayName "Speed & Duplex"}
    return $info.DisplayValue
}


}
############################################################################################################################################################
class Network{
          $NodeArray = @()
          $Ports = @()

GetDevices()
{

    # get ip address of local machine
    $ip = get-WmiObject Win32_NetworkAdapterConfiguration|Where {$_.Ipaddress.length -gt 1} 
    $localIP = $ip.ipaddress[0] 

    #create obect for ping
    $ping = new-object System.Net.NetworkInformation.Ping
    $pingTimeout = 100

    # remove last octet from ip and replace with 1 to 254
    $temp = $localIP.split('.')

    for($i = 1; $i -lt 255; $i++)
    {
        $temp[-1] = $i
        $localIP = $temp -join '.'
        if ($ping.send($localIP,$pingTimeout).status -eq "Success")
            {
                try
                {
                 $hostname = ([Net.DNS]::GetHostEntry($localIP)).Hostname
                 $MAC  = (arp -a $localIP | select-string -pattern "([0-9A-F]{2}([:-][0-9A-F]{2}){5})" -ALL).Matches.Value
                 $this.NodeArray += [Node]::new($hostname, $MAC, $localIP)

                }catch
                {
                   
                   $MAC = (arp -a $localIP | select-string -pattern "([0-9A-F]{2}([:-][0-9A-F]{2}){5})" -ALL).Matches.Value
                   $this.NodeArray += [Node]::new($localIP, $MAC, $localIP)
                }
            }
    }

}

scanPorts()
{
    ForEach ($node in $this.NodeArray)
    {
        $node.GetOpenPorts()
    } 
}


setBaseline()
{
    if(test-path "Baseline.csv")
        {
            rm "Baseline.csv"
        }
    ForEach ($node in $this.NodeArray)
    {
        $node.OpenPortsBaseline = $node.OpenPortsCurrent
        Export-CSV -InputObject $node -path "Baseline.csv" -append
    }   

    
}
loadBaseline()
{
    

}


}

##########################################################################################################################
class GUI{





}





##########################################################################################################################


#$Network = New-Object Network
#$Network.GetDevices()
#$Network.scanports()
$Network.setBaseline()