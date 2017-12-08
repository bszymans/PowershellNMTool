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



}#End Class






############################################################################################################################################################
class Network{
          $NodeArray = @()
          $Ports = @()
          $RogueDevices = @()

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
    
    $csv = import-CSV "Baseline.csv"
    forEach($node in $this.NodeArray)
        {
            
            forEach($row in $csv)
                {
                    
                    if($row.hostname -eq $node.hostname)
                        {
                            $node.OpenPortsBaseline = $row.openportsbaseline
      
                        }
                }
        }

    forEach($row in $csv)
        {
            $nodeexists = 0
            forEach($node in $this.NodeArray)
            {
                if($node.hostname -eq $row.hostname)
                    {
                        $nodeexists = 1
                    }
            }
            if($nodeexists -ne 1)
                {
                   
                    $this.NodeArray += [Node]::new($row.hostname, $row.MAC, $row.localIP)
                }
        }

}

getRogue()
    {

        $this.loadBaseline()
        forEach($node in $this.NodeArray)
        {
            if($node.openportsbaseline -eq $NULL)
                {
                    $this.RogueDevices += $node.Hostname
                    
                }
                
        }

    }





    }

##########################################################################################################################
class GUI{

displayGUI() {


Add-Type -AssemblyName System.Windows.Forms

$Form = New-Object system.Windows.Forms.Form
$Form.Text = "Form"
$Form.TopMost = $true
$Form.Width = 756
$Form.Height = 466

$deviceListBox = New-Object system.windows.Forms.ListBox
$deviceListBox.Text = "listBox"
$deviceListBox.Width = 441
$deviceListBox.Height = 240
$deviceListBox.location = new-object system.drawing.point(263,28)
$Form.controls.Add($deviceListBox)

$deviceListBox = New-Object system.windows.Forms.ListBox
$deviceListBox.Text = "listBox"
$deviceListBox.Width = 441
$deviceListBox.Height = 240
$deviceListBox.location = new-object system.drawing.point(263,28)
$Form.controls.Add($deviceListBox)

$outputBox = New-Object system.windows.Forms.ListView
$outputBox.Text = "listView"
$outputBox.Width = 704
$outputBox.Height = 108
$outputBox.location = new-object system.drawing.point(13,313)
$Form.controls.Add($outputBox)

$outputBox = New-Object system.windows.Forms.ListView
$outputBox.Text = "listView"
$outputBox.Width = 704
$outputBox.Height = 108
$outputBox.location = new-object system.drawing.point(13,313)
$Form.controls.Add($outputBox)

$netSpeedtxt = New-Object system.windows.Forms.TextBox
$netSpeedtxt.Width = 100
$netSpeedtxt.Height = 20
$netSpeedtxt.location = new-object system.drawing.point(88,286)
$netSpeedtxt.Font = "Microsoft Sans Serif,10"
$Form.controls.Add($netSpeedtxt)


$netSpeedtxt = New-Object system.windows.Forms.TextBox
$netSpeedtxt.Width = 100
$netSpeedtxt.Height = 20
$netSpeedtxt.location = new-object system.drawing.point(88,286)
$netSpeedtxt.Font = "Microsoft Sans Serif,10"
$Form.controls.Add($netSpeedtxt)

$label11 = New-Object system.windows.Forms.Label
$label11.Text = "Netspeed"
$label11.AutoSize = $true
$label11.Width = 25
$label11.Height = 10
$label11.location = new-object system.drawing.point(19,286)
$label11.Font = "Microsoft Sans Serif,10"
$Form.controls.Add($label11)

$label11 = New-Object system.windows.Forms.Label
$label11.Text = "Netspeed"
$label11.AutoSize = $true
$label11.Width = 25
$label11.Height = 10
$label11.location = new-object system.drawing.point(19,286)
$label11.Font = "Microsoft Sans Serif,10"
$Form.controls.Add($label11)

$setNetSpeedbtn = New-Object system.windows.Forms.Button
$setNetSpeedbtn.Text = "Set NetSpeed"
$setNetSpeedbtn.Width = 117
$setNetSpeedbtn.Height = 30
$setNetSpeedbtn.Add_Click({
write-host "test"
})
$setNetSpeedbtn.location = new-object system.drawing.point(196,275)
$setNetSpeedbtn.Font = "Microsoft Sans Serif,10,style=Bold"
$Form.controls.Add($setNetSpeedbtn)

$setNetSpeedbtn = New-Object system.windows.Forms.Button
$setNetSpeedbtn.Text = "Set NetSpeed"
$setNetSpeedbtn.Width = 117
$setNetSpeedbtn.Height = 30
$setNetSpeedbtn.Add_Click({
write-host "test"
})
$setNetSpeedbtn.location = new-object system.drawing.point(196,275)
$setNetSpeedbtn.Font = "Microsoft Sans Serif,10,style=Bold"
$Form.controls.Add($setNetSpeedbtn)

$label15 = New-Object system.windows.Forms.Label
$label15.Text = "Device List"
$label15.AutoSize = $true
$label15.Width = 25
$label15.Height = 10
$label15.location = new-object system.drawing.point(439,8)
$label15.Font = "Microsoft Sans Serif,10"
$Form.controls.Add($label15)

$refreshbtn = New-Object system.windows.Forms.Button
$refreshbtn.Text = "Refresh Devices"
$refreshbtn.Width = 130
$refreshbtn.Height = 30
$refreshbtn.Add_Click({
write-host "test"
})
$refreshbtn.location = new-object system.drawing.point(569,275)
$refreshbtn.Font = "Microsoft Sans Serif,10,style=Bold"
$Form.controls.Add($refreshbtn)

$refreshbtn = New-Object system.windows.Forms.Button
$refreshbtn.Text = "Refresh Devices"
$refreshbtn.Width = 130
$refreshbtn.Height = 30
$refreshbtn.Add_Click({
write-host "test"
})

$refreshbtn.location = new-object system.drawing.point(569,275)
$refreshbtn.Font = "Microsoft Sans Serif,10,style=Bold"
$Form.controls.Add($refreshbtn)

$scanPortsbtn = New-Object system.windows.Forms.Button
$scanPortsbtn.Text = "Scan Ports"
$scanPortsbtn.Width = 112
$scanPortsbtn.Height = 30
$scanPortsbtn.Add_Click({
write-host "test"
})
$scanPortsbtn.location = new-object system.drawing.point(450,275)
$scanPortsbtn.Font = "Microsoft Sans Serif,10,style=Bold"

$Form.controls.Add($scanPortsbtn)

$scanPortsbtn = New-Object system.windows.Forms.Button
$scanPortsbtn.Text = "Scan Ports"
$scanPortsbtn.Width = 112
$scanPortsbtn.Height = 30
$scanPortsbtn.Add_Click({
#add here code triggered by the event
})
$scanPortsbtn.location = new-object system.drawing.point(450,275)
$scanPortsbtn.Font = "Microsoft Sans Serif,10,style=Bold"
$Form.controls.Add($scanPortsbtn)

$setBaselinebtn = New-Object system.windows.Forms.Button
$setBaselinebtn.Text = "Set Baseline"
$setBaselinebtn.Width = 101
$setBaselinebtn.Height = 30
$setBaselinebtn.Add_Click({
#add here code triggered by the event
})
$setBaselinebtn.location = new-object system.drawing.point(334,275)
$setBaselinebtn.Font = "Microsoft Sans Serif,10,style=Bold"
$Form.controls.Add($setBaselinebtn)

$setBaselinebtn = New-Object system.windows.Forms.Button
$setBaselinebtn.Text = "Set Baseline"
$setBaselinebtn.Width = 101
$setBaselinebtn.Height = 30
$setBaselinebtn.Add_Click({
#add here code triggered by the event
})
$setBaselinebtn.location = new-object system.drawing.point(334,275)
$setBaselinebtn.Font = "Microsoft Sans Serif,10,style=Bold"
$Form.controls.Add($setBaselinebtn)

$label22 = New-Object system.windows.Forms.Label
$label22.Text = "Range"
$label22.AutoSize = $true
$label22.Width = 25
$label22.Height = 10
$label22.location = new-object system.drawing.point(7,22)
$label22.Font = "Microsoft Sans Serif,10"
$Form.controls.Add($label22)

$label22 = New-Object system.windows.Forms.Label
$label22.Text = "Range"
$label22.AutoSize = $true
$label22.Width = 25
$label22.Height = 10
$label22.location = new-object system.drawing.point(7,22)
$label22.Font = "Microsoft Sans Serif,10"
$Form.controls.Add($label22)

$rangeBox = New-Object system.windows.Forms.TextBox
$rangeBox.Text = "24"
$rangeBox.Width = 30
$rangeBox.Height = 20
$rangeBox.location = new-object system.drawing.point(61,22)
$rangeBox.Font = "Microsoft Sans Serif,10"
$Form.controls.Add($rangeBox)

$rangeBox = New-Object system.windows.Forms.TextBox
$rangeBox.Text = "24"
$rangeBox.Width = 30
$rangeBox.Height = 20
$rangeBox.location = new-object system.drawing.point(61,22)
$rangeBox.Font = "Microsoft Sans Serif,10"
$Form.controls.Add($rangeBox)

[void]$Form.ShowDialog()
$Form.Dispose()

}




}





##########################################################################################################################


$Network = New-Object Network
$Network.GetDevices()

#$Network.scanports()
#$Network.setBaseline()
$Network.loadbaseline()
$Network.getRogue()
$gui = new-object gui
$gui.displaygui()
