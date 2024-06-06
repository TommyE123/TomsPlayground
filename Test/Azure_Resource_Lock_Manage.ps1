params (
  [Parameter(Mandatory = $true)] [string]$DatabaseIspac,
  [Parameter(Mandatory = $true)] [string]$DatabaseServerName,
  [Parameter(Mandatory = $true)] [string]$EnvironmentName,
  [Parameter(Mandatory = $true)] [string]$IrisDbServer,
  [Parameter(Mandatory = $true)] [string]$MarsDbServer,
  [Parameter(Mandatory = $true)] [string]$UwDbServer
)
{
  # User feedback to inform on what is happening
  $NowStr = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'
  Write-Output $NowStr
  Write-Host   "Deploying SSIS" -ForegroundColor Cyan
  Write-Output "Deploying database from $DatabaseDacpac..."
  Write-Output "... to $DatabaseServerName ..."
  Write-Output "... as $DatabaseName ..."

  Try
  {
    $SSISCatalog = "SSISDB"

    $ProjectFilePath = $DatabaseIspac
    $ProjectName = "JR.MARS.DataImport.SSIS"
    $FolderName = "Medical Assessment Reinsurance System"

    # Load the IntegrationServices Assembly
    [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.IntegrationServices") | Out-Null;

    # Store the IntegrationServices Assembly namespace to avoid typing it every time
    $ISNamespace = "Microsoft.SqlServer.Management.IntegrationServices"

    Write-Output "Connecting to server ..."

    #Create a connection to the server
    $sqlConnectionString = "Data Source=" + $DatabaseServerName + ";Initial Catalog=master;Integrated Security=SSPI;"
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $sqlConnectionString

    # Create the Integration Services object
    $integrationServices = New-Object $ISNamespace".IntegrationServices" $sqlConnection

    $catalog = $integrationServices.Catalogs[$SSISCatalog]
    $folder = $catalog.Folders[$FolderName]

    if (!$folder)
    {
      #Create a folder in SSISDB
      Write-Output "Creating Folder ..."
      $folder = New-Object "$ISNamespace.CatalogFolder" ($catalog, $FolderName, $FolderName)
      $folder.Create()
    }

    # Read the project file, and deploy it to the folder
    Write-Output "Deploying Project ..."
    [byte[]] $projectFile = [System.IO.File]::ReadAllBytes($ProjectFilePath)
    $folder.DeployProject($ProjectName, $projectFile)

    $environment = $folder.Environments[$EnvironmentName]

    if (!$environment)
    {
      Write-Output "Creating environment ..."
      $environment = New-Object $ISNamespace".EnvironmentInfo" ($folder, $EnvironmentName, $EnvironmentName)
      $environment.Create()
    }

    $project = $folder.Projects[$ProjectName]
    $ref = $project.References[$EnvironmentName, $folder.Name]

    if (!$ref)
    {
      # making project refer to this environment
      Write-Output "Adding environment reference to project ..."
      $project.References.Add($EnvironmentName, $folder.Name)
      $project.Alter()
    }

    # Adding variables to our environment
    # Constructor args: variable name, type, default value, sensitivity, description

    $irisVar = $environment.Variables["IrisDatabase_ConnectionString"];
    if (!$irisVar)
    {
      Write-Output "Adding environment variable IRIS ..."
      $environment.Variables.Add("IrisDatabase_ConnectionString", [System.TypeCode]::String, "Data Source=$IrisDbServer;Initial Catalog=db_iris;Integrated Security=True;Application Name=SSIS-Package-{D3B59659-2F8F-4AB6-AF66-1320F9559520};", $false, "Iris Connection String")
      $environment.Alter()
      $irisVar = $environment.Variables["IrisDatabase_ConnectionString"];
    }

    $marsVar = $environment.Variables["MarsDatabase_ConnectionString"];
    if (!$marsVar)
    {
      Write-Output "Adding environment variable MARS ..."
      $environment.Variables.Add("MarsDatabase_ConnectionString", [System.TypeCode]::String, "Data Source=$MarsDbServer;Initial Catalog=db_mars;Integrated Security=True;Application Name=SSIS-Package-{36EAFE0F-4A12-4D8F-8D9E-C409E3A10425};", $false, "Mars Connection String")
      $environment.Alter()
      $marsVar = $environment.Variables["MarsDatabase_ConnectionString"];
    }

    $uwVar = $environment.Variables["UnderwritingDatabase_ConnectionString"];
    if (!$uwVar)
    {
      Write-Output "Adding environment variable UW ..."
      $environment.Variables.Add("UnderwritingDatabase_ConnectionString", [System.TypeCode]::String, "Data Source=$UwDbServer;Initial Catalog=db_underwriting;Provider=SQLNCLI11.1;Integrated Security=SSPI;Auto Translate=False;", $false, "Underwriting Connection String")
      $environment.Alter()
      $uwVar = $environment.Variables["UnderwritingDatabase_ConnectionString"];
    }

    $project.Parameters["IrisDatabase_ConnectionString"].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced, $irisVar.Name)
    $project.Parameters["MarsDatabase_ConnectionString"].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced, $marsVar.Name)
    $project.Parameters["UnderwritingDatabase_ConnectionString"].Set([Microsoft.SqlServer.Management.IntegrationServices.ParameterInfo+ParameterValueType]::Referenced, $uwVar.Name)
    $project.Alter()

    Write-Host "********** SSIS Deployment SUCCESSFUL **********" -ForegroundColor Green
    Write-Host "Please review the script output for details" -ForegroundColor Green
    Write-Output "********** SSIS Deployment SUCCESSFUL **********"
  } Catch
  {
    Write-Error $_
    Write-Host "************ SSIS Deployment FAILED ************" -ForegroundColor Red
    Write-Host "Please review the script output for details" -ForegroundColor Red
    Write-Output "************ SSIS Deployment FAILED ************"
  }
}
