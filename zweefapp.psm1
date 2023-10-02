######### Parameters ##########

$club = "zvc" #change to your club, can be retreived from the zweefapp URL >> Todo store club on disk
$client_secret = 'LmwtuTeToDALLZpzDAEG' ### client_secret seems to be fixed for zweef.app, this is a potential security risk because a stolen bearer token can be used on any client.
$bearerTokenPath = $env:LOCALAPPDATA ### path where the bearertoken is stored


####### Nothing to change below this line #######

function Connect-ZweefApp {
     <#
        .SYNOPSIS
        Retreives a bearer token from Zweef.App.

        .DESCRIPTION
        Stores a bearer ZweefAppToken in global variable $ZweefAppToken in memory and on disk for future use from Zweef.App when typing in a correct user/password combination
        It is also possible to store the credentials and pass them as an PScredential object to Connect-ZweefApp

        .PARAMETER credentialsParam
        Specifies the credential object.

        .PARAMETER RefreshBearerToken
        Request a new bearer token.

        .INPUTS
        None. You cannot pipe objects to Connect-ZweefApp.

        .OUTPUTS
        None.

        .EXAMPLE
        PS> Connect-ZweefApp
        username: 
        password:

        .EXAMPLE
        PS> Connect-ZweefApp -credentialObject

    #>
     param (
          [pscredential]$CredentialObject,
          [switch]$RefreshBearerToken
     )
     
     $StoredBearerToken = Get-Content  -Path $bearerTokenPath\zweefappbearertoken.txt | ConvertTo-SecureString
     $StoredBearerToken = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR((($StoredBearerToken))))

     
     If ($StoredBearerToken -and !$RefreshBearerToken) {
          Write-Host "[+] Connecting using bearer token found on disk, use parameter -RefreshBearerToken to create a new token" -ForegroundColor Green
          $global:ZweefAppToken = $StoredBearerToken
          break
     }
     else {
          if ($CredentialObject) {
               $credentials = $CredentialObject
          }
          else {
               $credentials = Get-Credential -Message "Please enter your Zweef.App credentials"
          }
    
          $password = ConvertFrom-SecureString -SecureString $credentials.password -AsPlainText

          $oAuthUri = "https://admin.zweef.app/club/$club/internal_api/auth/login.json"
          $authBody = [Ordered] @{
               grant_type    = "login"
               client_secret = "$client_secret"
               email         = "$($credentials.UserName)"
               password      = "$password"
          }
          try {
               $ZweefAppToken = ""
               $authResponse = Invoke-RestMethod -Method Post -Uri $oAuthUri -Body $authBody -ErrorAction Stop
          }
          catch {
               Write-Host ("[+] Wrong credentials") -ForegroundColor Red
          }
          ### Store bearer ZweefAppToken in ZweefAppToken variable
          $global:ZweefAppToken = $authResponse.access_token
          $global:ZweefAppToken |  ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString |  Set-Content -Path $bearerTokenPath\zweefappbearertoken.txt 
     }

     if ($global:ZweefAppToken) {
          Write-Host "[+] Bearer token loaded in variable zweefAppToken and stored to disk for Zweef.App" -ForegroundColor Green 
     }
}

function Get-ZweefAppVliegdagen {
     <#
        .SYNOPSIS
        Lists all flight day's 

        .DESCRIPTION
        Lists all flight day's. Can be used to get the ID of a specific flightday for use as dag_id parameter in other commands

        .INPUTS
        None. You cannot pipe objects to Get-ZweefAppVliegdagen.

        .OUTPUTS
        None.

        .EXAMPLE
        PS> Get-ZweefAppVliegdagen
    #>

     $url = " https://admin.zweef.app/club/$club/internal_api/days.json"
     # Set the WebRequest headers
     $headers = @{
          'Content-Type' = 'application/json'
          Accept         = 'application/json'
          Authorization  = "Bearer $ZweefAppToken"
     }
     $response = Invoke-restmethod -Method Get -Uri $url -Headers $headers -ErrorAction Stop
     return $response.days
}

function Get-ZweefAppVliegdag {
     <#
        .SYNOPSIS
        Lists a specific flight day

        .DESCRIPTION
        Lists a specific flight day

        .INPUTS
        None. You cannot pipe objects to Get-ZweefAppVliegdagen.

        .OUTPUTS
        None.

        .EXAMPLE
        PS> Get-ZweefAppVliegdag -DagId <dag_id>
    #>
     param (
          [int]$DagId
     )

     $body = @{
          "dag_id" = "$DagId";
      
     }

     $url = "https://admin.zweef.app/$club/zvc/internal_api/aanmeldingen/get_dag.json"
     # Set the WebRequest headers
     $headers = @{
          'Content-Type' = 'application/json'
          Accept         = 'application/json'
          Authorization  = "Bearer $ZweefAppToken"
     }
     $response = Invoke-restmethod -Method Post -Uri $url -Headers $headers -Body ($body | ConvertTo-Json) -ErrorAction Stop 
     return $response
}

function Get-ZweefAppVliegdagAanmeldingen {
     <#
        .SYNOPSIS
        List subscriptions 

        .DESCRIPTION
        List subscriptions of a flight day, if you just run the command without any parameter the first available flight day will be listed

        .INPUTS
        None. You cannot pipe objects to Get-ZweefAppVliegdagAanmeldingen.

        .OUTPUTS
        None.

        .EXAMPLE
        PS> Get-ZweefAppVliegdagAanmeldingen
        .EXAMPLE
        PS> Get-ZweefAppVliegdagAanmeldingen -DagId <dag_id>
    #>
     param (
          [int]$DagId
     )

     if (!$DagId) {
       
     
          $DagId = (Get-ZweefAppVliegdagen | where-object status -eq "open" | sort-object dag_id)[0].dag_id #get first available flight day
     }

     $body = @{
          "dag_id" = "$DagId";
      
     }

     $url = "https://admin.zweef.app/club/$club/internal_api/aanmeldingen/get_dag.json"
     # Set the WebRequest headers
     $headers = @{
          'Content-Type' = 'application/json'
          Accept         = 'application/json'
          Authorization  = "Bearer $ZweefAppToken"
     }
     $response = Invoke-restmethod -Method Post -Uri $url -Headers $headers -Body ($body | ConvertTo-Json) -ErrorAction Stop 
     return $response.aanmeldingen  | Where-Object aangemeld -eq "True" |  select @{Name = "Datum"; Expression = {$_.datum}},@{Name = "Naam"; Expression = {$_.vlieger.name}}, @{Name = "Currency"; Expression = { $_.vlieger.currency.currency } }, @{Name = "Lierstarts"; Expression = { $_.vlieger.currency.lier } }, @{Name = "Sleepstarts"; Expression = { $_.vlieger.currency.sleep } }, @{Name = "DBO starts"; Expression = { $_.vlieger.currency.dbo } }, @{Name = "DBO Uren"; Expression = { $_.vlieger.currency.dbo_uren } }, @{Name = "PIC starts"; Expression = { $_.vlieger.currency.pic } }, @{Name = "PIC uren"; Expression = { $_.vlieger.currency.pic_uren } }, @{Name = "Tag"; Expression = { $_.vlieger.currency.tag } }, @{Name = "Opmerking"; Expression = { $_.opmerking } }

}

function Get-ZweefAppMijnVliegdagen {
     <#
        .SYNOPSIS
        Lists all flight day subscriptions of the user logged in

        .DESCRIPTION
        Lists all flight day subscriptions of the user logged in

        .INPUTS
        None. You cannot pipe objects to Get-ZweefAppMijnVliegdagen.

        .OUTPUTS
        None.

        .EXAMPLE
        PS> Get-ZweefAppMijnVliegdagen
        .EXAMPLE
        PS> Get-ZweefAppMijnVliegdagen -DagId <dag_id>
    #>
     $url = " https://admin.zweef.app/club/$club/internal_api/days.json"
     # Set the WebRequest headers
     $headers = @{
          'Content-Type' = 'application/json'
          Accept         = 'application/json'
          Authorization  = "Bearer $ZweefAppToken"
     }
     $MijnDagen = @()
     $response = Invoke-restmethod -Method Get -Uri $url -Headers $headers -ErrorAction Stop
     foreach ($Aanmelding in $response.mijn_aanmeldingen) {
          foreach ($day in $response.days) {
               if ($day.dag_id -match $Aanmelding) {
                    $MijnDagen += $day
               }
          }
     }
     return $MijnDagen
}

function Get-ZweefAppDagTotaal {

     param (
          [int]$DagId
     )
     if (!$DagId) {
       
     
          $DagId = (Get-ZweefAppVliegdagen | where-object status -ne "open")[0].dag_id #get last closed day
     }

     $body = @{
          "dag_id" = "$DagId";

     }
     $url = "https://admin.zweef.app/club/$club/internal_api/flights/day_total.json"
     # Set the WebRequest headers
     $headers = @{
          'Content-Type' = 'application/json'
          Accept         = 'application/json'
          Authorization  = "Bearer $ZweefAppToken"
     }
     $day_totals = Invoke-restmethod -Method Post -Uri $url -Headers $headers -Body ($body | ConvertTo-Json) -ErrorAction Stop 
     
     $url = "https://admin.zweef.app/club/$club/internal_api/flights/$DagId/flights.json"
     # Set the WebRequest headers
     $headers = @{
          'Content-Type' = 'application/json'
          Accept         = 'application/json'
          Authorization  = "Bearer $ZweefAppToken"
     }
     $flights = Invoke-restmethod -Method Get -Uri $url -Headers $headers  -ErrorAction Stop 
     
     foreach ($day_total in $day_totals) {
          #$Starttijd = @()
          $startTime = $flights.allFlights |  Where-Object { ($_.registratie -eq $day_total.registratie) -and ($_.start_methode -eq $day_total.start_methode) }   | Select-Object @{Name = 'start_tijd'; Expression = { $_.start_tijd -as [DateTime] } } | Sort-Object date
          $landingsTime = $flights.allFlights |  Where-Object { ($_.registratie -eq $day_total.registratie) -and ($_.start_methode -eq $day_total.start_methode) }   | Select-Object @{Name = 'landings_tijd'; Expression = { $_.landings_tijd -as [DateTime] } } | Sort-Object date
          #$startTime[0]
          $day_total | Add-Member -MemberType NoteProperty -Name Vertrektijd -Value $startTime.start_tijd[0].ToString("HH:mm")
          $day_total | Add-Member -MemberType NoteProperty -Name LandingsTijd -Value $landingsTime.landings_tijd[$landingsTime.landings_tijd.lenght - 1].ToString("HH:mm")
          $ts = new-timespan -minutes $day_total.minutes
          $day_total | Add-Member -MemberType NoteProperty -Name Uren -Value $ts.hours
          $day_total | Add-Member -MemberType NoteProperty -Name Minuten -Value $ts.minutes
     }

     
     return $day_totals | Select-Object @{Name = 'Datum'; Expression = { $_.datum } } , @{Name = 'Registratie'; Expression = { $_.registratie } }, @{Name = 'StartMethode'; Expression = { $_.start_methode } }, @{Name = 'Starts'; Expression = { $_.Starts } }, Uren, Minuten, Vertrektijd, Landingstijd
}