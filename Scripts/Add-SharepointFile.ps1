Param (  
    $Tenant = "",  # tenant name
    $ClientID = "", # azure app client id 
        $Secret = '', # azure app secret
    $SharePoint_SiteID = "",  # sharepoint site id        
    $SharePoint_Path = "",  # sharepoint main path
    $SharePoint_ExportFolder = "",  # folder where to upload file
    $File_Path = "" # path of the file to upload
)  

# example
# Param (  
    # $Tenant = "",  # tenant name
    # $ClientID = "", # azure app client id 
        # $Secret = '', # azure app secret
    # $SharePoint_SiteID = "",  # sharepoint site id        
    # $SharePoint_Path = "https://systanddeploy.sharepoint.com/sites/systanddeploy/Shared%20Documents",  # sharepoint main path
    # $SharePoint_ExportFolder = "Windows/Logs",  # folder where to upload file
    # $File_Path = "D:\MicrosoftEdgeEnterpriseX64.msi" # path of the file to upload
# )  

<#
Getting Sharepoint site id
I have the following Sharepoint site: https://systanddeploy.sharepoint.com/sites/Support
In order to authenticate and upload file we need to get the id of the site.
For this just open your browser and type:
https://m365x53191121.sharepoint.com/sites/systanddeploy/_api/site/id
#>

Function Write_Log
        {
                param(
                $Message_Type,        
                $Message
                )

                $MyDate = "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)                
                write-host  "$MyDate - $Message_Type : $Message"                        
        }        

$Body = @{  
    client_id = $ClientID
    client_secret = $Secret
    scope = "https://graph.microsoft.com/.default"   
    grant_type = 'client_credentials'  
}  

Write_Log -Message_Type "INFO" -Message "SharePoint connexion"        
$Graph_Url = "https://login.microsoftonline.com/$($Tenant).onmicrosoft.com/oauth2/v2.0/token"  

Try
        {
                $AuthorizationRequest = Invoke-RestMethod -Uri $Graph_Url -Method "Post" -Body $Body  
                Write_Log -Message_Type "SUCCESS" -Message "Connected to SharePoint"        
        }
Catch
        {
                Write_Log -Message_Type "ERROR" -Message "Connexion to SharePoint failed"        
                EXIT
        }

$Access_token = $AuthorizationRequest.Access_token  
$Header = @{  
    Authorization = $AuthorizationRequest.access_token  
    "Content-Type"= "application/json"  
    'Content-Range' = "bytes 0-$($fileLength-1)/$fileLength"        
}  

$SharePoint_Graph_URL = "https://graph.microsoft.com/v1.0/sites/$SharePoint_SiteID/drives"  
$BodyJSON = $Body | ConvertTo-Json -Compress  

Write_Log -Message_Type "INFO" -Message "Getting SharePoint site info"        

Try
        {
                $Result = Invoke-RestMethod -Uri $SharePoint_Graph_URL -Method 'GET' -Headers $Header -ContentType "application/json"   
                Write_Log -Message_Type "SUCCESS" -Message "Getting SharePoint site info"                
        }
Catch
        {
                Write_Log -Message_Type "ERROR" -Message "Getting SharePoint site info"        
                EXIT
        }

$DriveID = $Result.value| Where-Object {$_.webURL -eq $SharePoint_Path } | Select-Object id -ExpandProperty id  

$FileName = $File_Path.Split("\")[-1]  
$createUploadSessionUri = "https://graph.microsoft.com/v1.0/sites/$SharePoint_SiteID/drives/$DriveID/root:/$SharePoint_ExportFolder/$($fileName):/createUploadSession"

Write_Log -Message_Type "INFO" -Message "File to upload: $FileName"        
Write_Log -Message_Type "INFO" -Message "Preparing the file for the upload"        

Try
        {
                $uploadSession = Invoke-RestMethod -Uri $createUploadSessionUri -Method 'POST' -Headers $Header -ContentType "application/json" 
                Write_Log -Message_Type "SUCCESS" -Message "Preparing the file for the upload"                        
        }
Catch
        {
                Write_Log -Message_Type "ERROR" -Message "Preparing the file for the upload"                        
                EXIT
        }

$fileInBytes = [System.IO.File]::ReadAllBytes($File_Path)
$fileLength = $fileInBytes.Length

$headers = @{
  'Content-Range' = "bytes 0-$($fileLength-1)/$fileLength"
}

Write_Log -Message_Type "INFO" -Message "Uploading file"        
Try
        {
                $response = Invoke-RestMethod -Method 'Put' -Uri $uploadSession.uploadUrl -Body $fileInBytes -Headers $headers
                Write_Log -Message_Type "SUCCESS" -Message "File has been uploaded"        
        }
Catch
        {
                Write_Log -Message_Type "ERROR" -Message "Failed to upload the file"
                EXIT
        }