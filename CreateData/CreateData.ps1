#########################################################
#Input O365 default tenant domain 
$tenant = "xyji" 
#Input site collection administrator 
$Admin = "xyji@xyji.onmicrosoft.com" 
#Input administrator's password
$Pwd = "1qaz2wsxE" 
#Input the site collection or sub site URL, below that you want to create sub sites 
$SCUrl = "TestData"
#Specify the site template id
$SiteTemplate = "STS#0"


###########################################################
#加载各种dll和moudle
Import-Module MSOnline
Import-Module Microsoft.Online.SharePoint.PowerShell -DisableNameChecking

$scriptdir = $PSScriptRoot
Write-Host "Loading the CSOM library" -foregroundcolor black -backgroundcolor yellow

[void][Reflection.Assembly]::LoadFrom("$scriptdir\dll\Microsoft.SharePoint.Client.dll")
[Void][Reflection.Assembly]::LoadFrom("$scriptdir\dll\Microsoft.SharePoint.Client.Runtime.dll")
[Void][Reflection.Assembly]::LoadFrom("$scriptdir\dll\Microsoft.SharePoint.Client.Taxonomy.dll")

Write-Host "Succesfully loaded the CSOM library for SharePoint Online" -foregroundcolor black -backgroundcolor green

#获取credential
$password = $Pwd | ConvertTo-SecureString -AsPlainText -Force
$APIcredentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($Admin,$password)
$PScredentials = New-Object System.Management.Automation.PSCredential($Admin,$password)

#创建site collection (Team Site)
$SPOAdminCenter = "https://$tenant-admin.sharepoint.com"
try{
	Write-Host "Connect to SPO Admin Center" -foregroundcolor black -backgroundcolor yellow
	Connect-SPOService -Url $SPOAdminCenter -credential $PScredentials
	Write-Host "Succesfully Connect to SPO Admin Center" -foregroundcolor black -backgroundcolor green
}
catch
{
	Write-Warning "Error with connect to SPO :$_" 
}

$url="https://$tenant.sharepoint.com/sites/$SCUrl"

try{	
	Write-Host "Start to create sc $SCUrl..."

    Remove-SPODeletedSite -Identity $url -Confirm false

	New-SPOSite -Url $url -Owner $Admin -StorageQuota 5 -LocaleID 1033 -ResourceQuota 0 -Template $SiteTemplate -Title $SCUrl

	Write-Host "Succesfully create sc $SCUrl..."
}
catch{
	Write-Warning "Error with create sc $SCUrl :$_"
}
###创建Global TermSet###

$ctx = New-Object Microsoft.SharePoint.Client.ClientContext($SPOAdminCenter)
$ctx.Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($Admin,$password)
$ctx.ExecuteQuery()
$session = [Microsoft.SharePoint.Client.Taxonomy.TaxonomySession]::GetTaxonomySession($ctx)
$ctx.Load($session)
$ctx.ExecuteQuery()

$termStores = $session.TermStores
$ctx.Load($termStores)
$ctx.ExecuteQuery()

$taxonomy = $termStores[0]
$ctx.Load($taxonomy)
$ctx.ExecuteQuery()

$group = $taxonomy.CreateGroup("NewPowerShellGroup",[System.Guid]::NewGuid())
$ctx.Load($group)
$ctx.ExecuteQuery()

$termset = $group.CreateTermSet("CreatedTermSet",[System.Guid]::NewGuid(),1033)
$ctx.Load($termset)
$ctx.ExecuteQuery()

foreach($letter in 65..90)
{
	$letter = [char]$letter
	$term = $termset.CreateTerm($letter,1033,[System.Guid]::NewGuid())
	foreach($i in 65..90) #A-Z
	{
		$l = [char]$i
		$term = $term.CreateTerm($l,1033,[System.Guid]::NewGuid())
	}
	$ctx.ExecuteQuery()
}

$a = $termset.Terms.GetByName("A")
$ctx.Load($a)
$ctx.ExecuteQuery()

#连接新创建的site collection
$ctx = New-Object Microsoft.SharePoint.Client.ClientContext($url)
$ctx.Credentials = $APIcredentials
try{
	$ctx.ExecuteQuery()
	Write-Host "Succesfully connect to $SCUrl" -foregroundcolor black -backgroundcolor green
}
catch
{
	Write-Host "Error with connect to $SCUrl :$_" -foregroundcolor black -backgroundcolor red
}

#Active 常用的features

		"*****Document ID Service*****"
		$ctx.Site.Features.Add("b50e3104-6812-424f-a011-cc90e6327318",$true,[Microsoft.SharePoint.Client.FeatureDefinitionScope]::None)
		$ctx.ExecuteQuery()
		"*****Disposition Approval Workflow*****"
		$ctx.Site.Features.Add("c85e5759-f323-4efb-b548-443d2216efb5",$true,[Microsoft.SharePoint.Client.FeatureDefinitionScope]::None)
		$ctx.ExecuteQuery()
		"*****Library and Folder Based Retention*****"
		$ctx.Site.Features.Add("063c26fa-3ccc-4180-8a84-b6f98e991df3",$true,[Microsoft.SharePoint.Client.FeatureDefinitionScope]::None)
		$ctx.ExecuteQuery()
		"*****Publishing Approval Workflow*****"
		$ctx.Site.Features.Add("a44d2aa3-affc-4d58-8db4-f4a3af053188",$true,[Microsoft.SharePoint.Client.FeatureDefinitionScope]::None)
		$ctx.ExecuteQuery()
		"*****Search Server Web Parts*****"
		$ctx.Site.Features.Add("eaf6a128-0482-4f71-9a2f-b1c650680e77",$true,[Microsoft.SharePoint.Client.FeatureDefinitionScope]::None)
		$ctx.ExecuteQuery()
		"*****SharePoint Server Enterprise Site Collection features*****"
		$ctx.Site.Features.Add("8581a8a7-cf16-4770-ac54-260265ddb0b2",$true,[Microsoft.SharePoint.Client.FeatureDefinitionScope]::None)
		$ctx.ExecuteQuery()
		"*****Workflows*****"
		$ctx.Site.Features.Add("0af5989a-3aea-4519-8ab0-85d91abe39ff",$true,[Microsoft.SharePoint.Client.FeatureDefinitionScope]::None)
		$ctx.ExecuteQuery()
		"*****Publishing Infrastrusture Feature*****"
		$ctx.Site.Features.Add("f6924d36-2fa8-4f0b-b16d-06b7250180fa",$true,[Microsoft.SharePoint.Client.FeatureDefinitionScope]::None)
		$ctx.ExecuteQuery()

#创建subsite (各种模板)
function Create-SubSite
{

	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true, Position=1)]
	    [string]$Title,
		
		[Parameter(Mandatory=$true, Position=2)]
	    $web,
		
		[Parameter(Mandatory=$false, Position=3)]
	    [string]$webTemplate = "STS#0",			
		
		[Parameter(Mandatory=$false, Position=4)]
	    [string]$url = "",
		
		[Parameter(Mandatory=$false, Position=5)]
	    [int]$language = 1033,
		
		[Parameter(Mandatory=$false, Position=6)]
	    [bool]$useSamePermissionsAsParentSite = $true
	)
	$url = $Title
    $webCreationInfo.Title = $Title
	$webCreationInfo.Description = "Created by tool"
	$webCreationInfo.Language = $language
	$webCreationInfo.Url = $url
	$webCreationInfo.UseSamePermissionsAsParentSite = $useSamePermissionsAsParentSite
	$webCreationInfo.WebTemplate = $webTemplate

	$newSite = $web.Webs.Add($webCreationInfo)
	try{
		$ctx.ExecuteQuery()
		Write-Host "Succesfully create site" $Title -foregroundcolor black -backgroundcolor green
	}
	catch{
		$usefulerror = $Error[0].Exception.InnerException.Message
        	Write-host "# Creation Failed  #" -BackgroundColor Red -ForegroundColor White 
        	Write-Host "$usefulerror" -foregroundcolor black -backgroundcolor yellow
	}	
}

$webTemplates = @{ #Customized template not covered yet.
				"Team Site" = "STS#0";
				"Blog" = "BLOG#0";
				"Project Site" = "PROJECTSITE#0";
				"Community Site" = "COMMUNITY#0";
				"Document Center" = "BDR#0";
				"Records Center" = "OFFILE#1";
				"Business Intelligence Center" = "BICenterSite#0";
				"Enterprise Search Center" = "SRCHCEN#0";
				"Basic Search Center" = "SRCHCENTERLITE#0";
				"Visio Process Repository" = "visprus#0";
				"Publishing Site1" = "CMSPUBLISHING#0";
				"Publishing Site2" = "BLANKINTERNET#0";
				"Publishing Site With Workflow" = "BLANKINTERNET#2";
				"Enterprise Wiki" = "ENTERWIKI#0";
				"SAP Workflow Site" = "SAPWorkflowSite#0";
			  }
$webCreationInfo = new-object Microsoft.SharePoint.Client.WebCreationInformation
foreach($Key in $webTemplates.Keys)
{
	Create-SubSite -Title $Key -web $ctx.Web -webTemplate $webTemplates[$Key]
}
#连接到某个site
function Open-Site
{
    [CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true, Position=1)]
	    [string]$Url
	)
	
	$Newctx = New-Object Microsoft.SharePoint.Client.ClientContext($Url)
    $Newctx.RequestTimeout = $Global:ctx.RequestTimeout	
    $Newctx.AuthenticationMode = $Global:ctx.AuthenticationMode
    $Newctx.Credentials = $Global:ctx.Credentials

	Write-Host "Check connection" -foregroundcolor black -backgroundcolor yellow

	$Newctx.Load($Newctx.Web)
	$Newctx.Load($Newctx.Site)
	$Newctx.ExecuteQuery()
	
	Set-Variable -Name "ctx" -Value $Newctx -Scope Global
}

#创建多层subsite,3层+

$siteurl = $url

for($i = 1;$i -le 3; $i++ )
{
	Open-Site -Url $siteurl
	Create-SubSite -Title "Sub Site $i" -web $ctx.Web -webTemplate "STS#0"
	$siteurl = $siteurl + "/Sub Site $i"
}


#Team Site中创建各种类型的list/library （包含sub site）

function Create-List
{
	param([Microsoft.SharePoint.Client.ClientContext]$ctx,[string]$name,[int]$type)
	$lci = New-Object Microsoft.SharePoint.Client.ListCreationInformation
	$lci.Title = $name
	$lci.Url = $name.Replace(' ','_')
	$lci.TemplateType = $type
	$list = $ctx.Web.Lists.Add($lci)
	$ctx.Load($list)
	try{
		$ctx.ExecuteQuery()
		Write-Host "Succesfully create list" $name -foregroundcolor black -backgroundcolor green
	}
	catch{
		"Error Creating $name"|Out-File -Append "D:\SupportList.txt"
		"Error Creating $name"
		$usefulerror = $Error[0].Exception.InnerException.Message
        Write-host "# Creation Failed  #" -BackgroundColor Red -ForegroundColor White 
        Write-Host "$usefulerror" -foregroundcolor black -backgroundcolor yellow
	}
	
}
$nlts = @{
			"Announcements" = 104;
			#"Asset Library" = 851;
			"Calendar"   =   106;
			"Contacts"   =    105;
			"Custom List"      =   100;
			"Custom List in Datasheet View"  = 120;
			"Data Connection Library" =  130;
			"Document Library"    =    101;
			#"External List"  =   600;
			"Form Library"  =  115;
			"Issue Tracking"  = 1100;
			"Links"   =  103;
			"Picture Library" = 109;
			#"Promoted Links"  =   170;
			#"Report Library"  =   433;
			"Survey"    =   102;
			"Tasks"  =   171;
			"DiscussionBoard" = 108;
			"WikiPageLibrary" = 119;
			"GanttTasks" = 150;
		}

$siteurl = $url

for($j = 1;$j -le 3; $j++ )
{
	Open-Site -Url $siteurl
	foreach($k in $nlts.Keys)
	{
		Create-List -ctx $ctx -name $k -type $nlts[$k]
	}	
	$siteurl = $siteurl + "/Sub Site $j"
}


#新建site level workflow,并添加到content type和list中
Open-Site -Url $url

Create-List -ctx $ctx -name "Workflow Tasks" -type 171

Create-List -ctx $ctx -name "Workflow History" -type 140

Create-List -ctx $ctx -name "Lib Test Workflow" -type 101

$lib = $ctx.Web.Lists.GetByTitle("Lib Test Workflow")
$ctx.Load($lib)

$waci = New-Object Microsoft.SharePoint.Client.Workflow.WorkflowAssociationCreationInformation
$waci.HistoryList = $ctx.Web.Lists.GetByTitle("Workflow History")
$waci.TaskList = $ctx.Web.Lists.GetByTitle("Workflow Tasks")
$waci.Name = "Approval Workflow Created via PowerShell"
$waci.Template = $ctx.Web.WorkflowTemplates.GetByName("Approval - SharePoint 2010")
$workflow = $lib.WorkflowAssociations.Add($waci)
$ctx.Load($workflow)

$workflow.AutoStartChange = $true
$workflow.AutoStartCreate = $true
$workflow.Enabled = $true
$workflow.Update()
try{
	$ctx.ExecuteQuery()
	Write-Host "Succesfully add workflow to list" -foregroundcolor black -backgroundcolor green
}
catch{
	$usefulerror = $Error[0].Exception.InnerException.Message
    Write-host "# Creation Failed  #" -BackgroundColor Red -ForegroundColor White 
    Write-Host "$usefulerror" -foregroundcolor black -backgroundcolor yellow
}

$ctci = New-Object Microsoft.SharePoint.Client.ContentTypeCreationInformation
$ctci.Name = "Approval Workflow Tester"
$ctci.ParentContentType = $ctx.Web.ContentTypes.GetById("0x01")
$ct = $ctx.Web.ContentTypes.Add($ctci)
$ctx.Load($ct)
$ctwf = $ct.WorkflowAssociations.Add($waci)
$ctx.Load($ctwf)
$ctwf.AutoStartChange = $true
$ctwf.AutoStartCreate = $true
$ctwf.Enabled = $true
$ctwf.Update()
try{
	$ctx.ExecuteQuery()
	Write-Host "Succesfully add content type to site" -foregroundcolor black -backgroundcolor green
}
catch{
	$usefulerror = $Error[0].Exception.InnerException.Message
    Write-host "# Creation Failed  #" -BackgroundColor Red -ForegroundColor White 
    Write-Host "$usefulerror" -foregroundcolor black -backgroundcolor yellow
}

$sitewf = $ctx.Web.WorkflowAssociations.Add($waci)
$ctx.Load($sitewf)
$sitewf.AutoStartChange = $true
$sitewf.AutoStartCreate = $true
$sitewf.Update()
try{
	$ctx.ExecuteQuery()
	Write-Host "Succesfully add workflow to content type" -foregroundcolor black -backgroundcolor green
}
catch{
	$usefulerror = $Error[0].Exception.InnerException.Message
    Write-host "# Creation Failed  #" -BackgroundColor Red -ForegroundColor White 
    Write-Host "$usefulerror" -foregroundcolor black -backgroundcolor yellow
}

#创建site column (各种类型)
Open-Site -Url "$url/Sub Site 1"

$MySingleTextXml = "<Field Type='Text' DisplayName='MySingleTextColumn' Name='MySingleTextColumn' required='FALSE' Group='MySiteColumnsGroup'><Default>It's me</Default></Field>"
$MyMultipleTextXml = "<Field Type='Note' DisplayName='MyMultipleTextColumn' Name='MyMultipleTextColumn' required='FALSE' NumLines='10' RichText='sorry, I don't know' Sortable='FALSE' Group='MySiteColumnsGroup />"
$MyChoiceXml = "<Field Type='Choice' DisplayName='MyChoiceColumn' Name='MyChoiceColumn'  required='FALSE' Group='MySiteColumnsGroup'><CHOICES><CHOICE>Queued</CHOICE><CHOICE>Translated</CHOICE><CHOICE>In Progress</CHOICE><CHOICE>With Human Translator</CHOICE><CHOICE>Throttled</CHOICE><CHOICE>Error</CHOICE></CHOICES><Default>Queued</Default></Field>"
$MyNumberXml = "<Field Type='Number' DisplayName='MyNumberColumn' Name='MyNumberColumn' required='FALSE' Min='1' Max='50' Decimals='2' Group='MySiteColumnsGroup' />"
$MyCurrencyXml = "<Field Type='Currency' DisplayName='MyCurrencyColumn' Name='MyCurrencyColumn' required='FALSE' Group='MySiteColumnsGroup' Min='1' Max='103' Decimals='3' ><Default>5</Default></Field>"
$MyDateXml = "<Field Type='DateTime' DisplayName='MyDateColumn' Name='MyDateColumn' required='FALSE' Format='DateTime' Group='MySiteColumnsGroup' />"
$MyYesorNoXml = "<Field Type='Boolean' DisplayName='MyYesorNoColumn' Name='MyYesorNoColumn' EnforceUniqueValues='FALSE' Indexed='FALSE' Group='MySiteColumnsGroup' ><Default>1</Default></Field>"
$MyHyperlinkXml = "<Field Type='URL' DisplayName='MyHyperlinkColumn' Name='MyHyperlinkColumn' Required='FALSE' EnforceUniqueValues='FALSE' Indexed='FALSE' Format='Hyperlink' Group='MySiteColumnsGroup'  />"
$MyTaskOutComeXml = "<Field Type='OutcomeChoice' DisplayName='MyTaskOutComeColumn' Name='MyTaskOutComeColumn' Required='FALSE' EnforceUniqueValues='FALSE' Indexed='FALSE' Group='MySiteColumnsGroup' ><Default>Rejected</Default><CHOICES><CHOICE>Approved</CHOICE><CHOICE>Rejected</CHOICE></CHOICES></Field>"
$MyFullHtmlXml = "<Field Type='HTML' DisplayName='MyFullHtmlColumn' Name='MyFullHtmlColumn' required='FALSE' Group='MySiteColumnsGroup'/>"
$MyImageXml = "<Field Type='Image' DisplayName='MyImageColumn' Name='MyImageColumn' required='FALSE' Group='MySiteColumnsGroup'/>"
$MyPublishHyperlinkXml = "<Field Type='Link' DisplayName='MyPublishHyperlinkColumn' Name='MyPublishHyperlinkColumn' required='FALSE' Group='MySiteColumnsGroup'/>"
$MySummaryLinkXml ="<Field Type='SummaryLinks' DisplayName='MySummaryLinkColumn' Name='MySummaryLinkColumn' required='FALSE' RichText='TRUE' RichTextMode='FullHtml' Group='MySiteColumnsGroup'/>"
$MyMediaXml = "<Field Type='MediaFieldType' DisplayName='MyMediaColumn' Name='MyMediaColumn' required='FALSE' Group='MySiteColumnsGroup'/>"
$MyPersonGroupXml = "<Field Type='UserMulti' DisplayName='MyPersonGroupColumn' Name='MyPersonGroupColumn' UserSelectionScope='0' UserSelectionMode='PeopleOnly' Sortable='FALSE' Required='FALSE' Mult='FALSE' List='UserInfo' ShowField='ImnName' Group='MySiteColumnsGroup'/>"
$MyLookupMultiXml = "<Field Name='MyLookupMultiColumn' Type='LookupMulti' Mult='TRUE' DisplayName='MyLookupMultiColumn' PrependId='TRUE' List='Self' ShowField='Title'  Group='MySiteColumnsGroup' />"
$LookupWebid = $ctx.Web.id
Create-List -ctx $ctx -name "TestLookupColumnList" -type 100
$lookuplist = $ctx.Web.Lists.GetByTitle("TestLookupColumnList")
$ctx.Load($lookuplist)
$ctx.ExecuteQuery()
$lookuplistid = $lookuplist.id
$MyLookupXml = "<Field DisplayName='MyLookupColumn' Type='Lookup' Required='TRUE' List='$lookuplistid' WebId='$LookupWebid' Name='MyLookupColumn' ShowField='Title'  Group='MySiteColumnsGroup'  />"
$MyDate1Xml = "<Field Type='DateTime' DisplayName='MyDate1' Name='MyDate1' required='FALSE' Format='DateTime' Group='MySiteColumnsGroup' />"
$MyDate2Xml = "<Field Type='DateTime' DisplayName='MyDate2' Name='MyDate2' required='FALSE' Format='DateTime' Group='MySiteColumnsGroup' />"
$MyCaculatedXml = "<Field Type='Calculated' DisplayName='MyCaculatedColumn' Name='MyCaculatedColumn' EnforceUniqueValues='FALSE' Indexed='FALSE' Format='DateOnly' LCID='1033' ResultType='Boolean' ReadOnly='TRUE' Group='MySiteColumnsGroup'><Formula>=[MyDate1]-[MyDate2]</Formula><FormulaDisplayNames>=[MyDate1]-[MyDate2]</FormulaDisplayNames><FieldRefs><FieldRef Name='MyDate1' /><FieldRef Name='MyDate2' /></FieldRefs></Field>"

$xml = "<Field Type='TaxonomyFieldType' DisplayName='New Managed Metadata' StaticName='New Managed Metadata' Name='New Managed Metadata' ShowField='Term1033' DisplaceOnUpgrade='TRUE' Overwrite='TRUE'><Default>2;#A|" + $a.Id + "</Default>
<Customization>
<ArrayOfProperty>
<Property><Name>SspId</Name><Value xmlns:q1='http://www.w3.org/2001/XMLSchema' p4:type='q1:string' xmlns:p4='http://www.w3.org/2001/XMLSchema-instance'>" + $taxonomy.Id + "</Value></Property>
<Property><Name>TermSetId</Name><Value xmlns:q2='http://www.w3.org/2001/XMLSchema' p4:type='q2:string' xmlns:p4='http://www.w3.org/2001/XMLSchema-instance'>" + $termset.Id + "</Value></Property>
<Property><Name>AnchorId</Name><Value xmlns:q3='http://www.w3.org/2001/XMLSchema' p4:type='q3:string' xmlns:p4='http://www.w3.org/2001/XMLSchema-instance'>" + $a.Id + "</Value></Property>
</ArrayOfProperty>
</Customization>
</Field>"
$colXmls = $MySingleTextXml,$MyMultipleTextXml,$MyChoiceXml,$MyNumberXml,$MyCurrencyXml,$MyDateXml,$MyYesorNoXml,$MyHyperlinkXml,$MyTaskOutComeXml,$MyFullHtmlXml,$MyImageXml,$MyPublishHyperlinkXml,$MySummaryLinkXml,$MyMediaXml,$MyPersonGroupXml,$MyLookupMultiXml,$MyLookupXml,$MyDate1Xml,$MyDate2Xml,$MyCaculatedXml,$xml

for($i=0;$i -lt $colXmls.Length;$i++)
{
	$col = $ctx.Web.Fields.AddFieldAsXml($colXmls[$i],$false,[Microsoft.SharePoint.Client.AddFieldOptions]::AddToNoContentType)
	try{
		$ctx.ExecuteQuery()
		Write-Host "Succesfully add site column to site" -foregroundcolor black -backgroundcolor green
	}
	catch
	{
		$usefulerror = $Error[0].Exception.InnerException.Message
    	Write-host "# Creation Failed  #" -BackgroundColor Red -ForegroundColor White 
    	Write-Host "$usefulerror" -foregroundcolor black -backgroundcolor yellow
	}
}

#创建site content type(常用的类型)
Open-Site -Url "$url/Sub Site 1"
$cts = @{
			"Excel based Status Indicator" = "0x00A7470EADF4194E2E9ED1031B61DA088403";  
			"Report" = "0x01010058DDEB47312E4967BFC1576B96E8C3D4";
			"SharePoint List based Status Indicator" = "0x00A7470EADF4194E2E9ED1031B61DA088402";  
			"Web Part Page with Status List" = "0x010100A2E3C117A0C5482FAEE3D57C48CB042F";
			"Announcement"  = "0x0104";                                  
			"Comment"    =      "0x0111";                                  
			"Contact"    =   "0x0106";                                  
			"East Asia Contact"    =    "0x0116";                                  
			"Event"       =            "0x0102";                                  
			"Issue"  = "0x0103";                                  
			"Item"      =       "0x01";
			"Link"    =      "0x0105";                                
			"Message"  =    "0x0107";                                  
			"Post"  = "0x0110";
			"Reservations"    =   "0x0102004F51EFDEA49C49668EF9C6744C8CF87D";
			"Schedule"   =   "0x0102007DBDC1392EAF4EBBBF99E41D8922B264";
			"Schedule and Reservations" =  "0x01020072BB2A38F0DB49C3A96CF4FA85529956";
			"Task"  =  "0x0108";                                  
			"Workflow Task (SharePoint 2013)"  =  "0x0108003365C4474CAE8C42BCE396314E88E51F";
			"Category"    =  "0x010019ACC57FBA4146AFA4C822E719824BED"; 
			"Community Member" =   "0x010027FC2137D8DE4B00A40E14346D070D5201";
			"Basic Page"  =  "0x010109";                                
			"Document"  =  "0x0101";                                  
			"Dublin Core Columns" = "0x01010B";                                
			"Form"   =  "0x010101";                                
			"Link to a Document" = "0x01010A";                                
			"List View Style" = "0x010100734778F2B7DF462491FC91844AE431CF";
			"Master Page"  =  "0x010105";                                
			"Master Page Preview" = "0x010106";                                
			"Picture" = "0x010102";                                
			"Web Part Page" = "0x01010901";                              
			"Wiki Page" = "0x010108";
			"Document Set"  ="0x0120D520"                                                                                                                     
			"Discussion"     =         "0x012002";                                                                                                                       
			"Folder"           =       "0x0120";                                                                                                                         
			"Article Page"      =      "0x010100C568DB52D9D0A14D9B2FDCC96666E9F2007948130EC3DB064584E219954237AF3900242457EFB8B24247815D688C526CD44D";                  
			"Catalog-Item Reuse"  =    "0x010100C568DB52D9D0A14D9B2FDCC96666E9F2007948130EC3DB064584E219954237AF3900B46186789C3140CC85BE610336E86BBB";                   
			"Enterprise Wiki Page"  =  "0x010100C568DB52D9D0A14D9B2FDCC96666E9F2007948130EC3DB064584E219954237AF39004C1F8B46085B4D22B1CDC3DE08CFFB9C";                   
			"Error Page"        =      "0x010100C568DB52D9D0A14D9B2FDCC96666E9F2007948130EC3DB064584E219954237AF3900796F542FC5E446758C697981E370458C";                   
			"Project Page"     =       "0x010100C568DB52D9D0A14D9B2FDCC96666E9F2007948130EC3DB064584E219954237AF39004C1F8B46085B4D22B1CDC3DE08CFFB9C0055EF50AAFF2E4BADA437E4BAE09A30F8";
			"Redirect Page"     =      "0x010100C568DB52D9D0A14D9B2FDCC96666E9F2007948130EC3DB064584E219954237AF3900FD0E870BA06948879DBD5F9813CD8799";                   
			"Welcome Page"       =     "0x010100C568DB52D9D0A14D9B2FDCC96666E9F2007948130EC3DB064584E219954237AF390064DEA0F50FC8C147B0B6EA0636C4A7D4";                   
			"Circulation"         =    "0x01000F389E14C9CE4CE486270B9D4713A5D6";                                                                                         
			"Holiday"             =    "0x01009BE2AB5291BF4C1A986910BD278E4F18";                                                                                         
			"New Word"            =    "0x010018F21907ED4E401CB4F14422ABC65304";                                                                                         
			"Official Notice"     =    "0x01007CE30DD1206047728BAFD1C39A850120";                                                                                         
			"Phone Call Memo"     =   "0x0100807FBAC5EB8A4653B8D24775195B5463";                                                                                         
			"Resource"           =     "0x01004C9F4486FBF54864A7B0A33D02AD19B1";                                                                                         
			"Resource Group"    =      "0x0100CA13F2F8D61541B180952DFB25E3E8E4";                                                                                         
			"Timecard"         =       "0x0100C30DDA8EDB2E434EA22D793D9EE42058";                                                                                         
			"Users"            =       "0x0100FBEEE6F0C500489B99CDA6BB16C398F7";                                                                                         
			"What's New Notification" = "0x0100A2CA87FF01B442AD93F37CD7DD0943EB";                                                                                         
			"Audio"           =        "0x0101009148F5A04DDD49CBA7127AADA5FB792B006973ACD696DC4858A76371B2FB2F439A";                                                     
			"Image"           =        "0x0101009148F5A04DDD49CBA7127AADA5FB792B00AADE34325A8B49CDA8BB4DB53328F214";                                                   
			"Video"           =       "0x0120D520A808";
		}
foreach($k in $cts.Keys)
{
	$ctci = New-Object Microsoft.SharePoint.Client.ContentTypeCreationInformation
	$ctci.ParentContentType = $ctx.Web.ContentTypes.GetById($cts[$k])
	$ctci.Name = "PowerShell Created "+$k
	$ctci.Group = "Newly Created Group"
	$contentType = $ctx.Web.ContentTypes.Add($ctci)
	$ctx.Load($contentType)
}
try{
	$ctx.ExecuteQuery()
	Write-Host "Succesfully add content type to site" -foregroundcolor black -backgroundcolor green
}
catch{
	$usefulerror = $Error[0].Exception.InnerException.Message
    Write-host "# Creation Failed  #" -BackgroundColor Red -ForegroundColor White 
    Write-Host "$usefulerror" -foregroundcolor black -backgroundcolor yellow
}

#设置常用的list settings
Open-Site -Url "$url/Sub Site 1"
Create-List -ctx $ctx -name "TestCustomList" -type 100
try{
$Testlist = $ctx.Web.Lists.GetByTitle("TestCustomList")
$ctx.Load($Testlist)
$Testlist.EnableVersioning = $true
$Testlist.OnQuickLaunch = $true
$Testlist.Description = "This is to test the list settings..."
$Testlist.ContentTypesEnabled = $true
#$Testlist.ValidationFormula = "=Created=Modified"
#$Testlist.ValidationMessage = "Functional"
$Testlist.MajorVersionLimit = 3
$Testlist.Update()
$ctx.ExecuteQuery()
$Testlist.RootFolder.Properties["Ratings_VotingExperience"] = "Likes"
$Testlist.Update()
$enterprise = $Testlist.ParentWeb.AvailableFields.GetById("23f27201-bee3-471e-b2e7-b64fd8b7ca38")
$ctx.Load($enterprise)
$ctx.ExecuteQuery()
$col = $Testlist.Fields.AddFieldAsXml("<Field Type='Text' DisplayName='Text1' StaticName='Text1' Name='Text1' RowOrdinal='0'><Default>Guten Abend</Default></Field>",$true,[Microsoft.SharePoint.Client.AddFieldOptions]::AddFieldToDefaultView)
$target = $Testlist.Fields.AddFieldAsXml("<Field ID='61cbb965-1e04-4273-b658-eedaa662f48d' Type='TargetTo' Name='TargetTo' DisplayName='Target Audiences' Required='FALSE' />",$true,[Microsoft.SharePoint.Client.AddFieldOptions]::AddFieldToDefaultView)
$enterpriseSetting = $Testlist.Fields.Add($enterprise)
$ctx.ExecuteQuery()
$col = $Testlist.Fields.GetByTitle("Text1")
$col.DefaultValue = Get-Random
$col.Update()
$ctx.ExecuteQuery()
Write-Host "Succesfully modify list settigns" -foregroundcolor black -backgroundcolor green
}
catch
{
	$usefulerror = $Error[0].Exception.InnerException.Message
    Write-host "# Creation Failed  #" -BackgroundColor Red -ForegroundColor White 
    Write-Host "$usefulerror" -foregroundcolor black -backgroundcolor yellow
}
#添加workflow
$waci = New-Object Microsoft.SharePoint.Client.Workflow.WorkflowAssociationCreationInformation
$waci.HistoryList = $ctx.Web.Lists.GetByTitle("Workflow History")
$waci.TaskList = $ctx.Web.Lists.GetByTitle("Workflow Tasks")
$waci.Name = "Approval Workflow Created via PowerShell"
$waci.Template = $ctx.Web.WorkflowTemplates.GetByName("Approval - SharePoint 2010")
$workflow = $Testlist.WorkflowAssociations.Add($waci)
$ctx.Load($workflow)

$workflow.AutoStartChange = $true
$workflow.AutoStartCreate = $true
$workflow.Enabled = $true
$workflow.Update()
try{
	$ctx.ExecuteQuery()
	Write-Host "Succesfully add workflow to list" -foregroundcolor black -backgroundcolor green
}
catch{
	$usefulerror = $Error[0].Exception.InnerException.Message
    Write-host "# Creation Failed  #" -BackgroundColor Red -ForegroundColor White 
    Write-Host "$usefulerror" -foregroundcolor black -backgroundcolor yellow
}

#创建list columns(各种类型)

$SingleTextListColumnXml = "<Field Type='Text' DisplayName='SingleTextListColumn' Name='SingleTextListColumn' MaxLength='254' required='FALSE' EnforceUniqueValues='FALSE' Indexed='FALSE' />"
$MultipleTextListColumnXml = "<Field Type='Note' DisplayName='MultipleTextListColumn' Name='MultipleTextListColumn' NumLines='10' RichText='TRUE' RichTextMode='FullHtml' Sortable='FALSE' required='FALSE' EnforceUniqueValues='FALSE' />"
$ChoiceListColumnXml = "<Field Type='Choice' DisplayName='ChoiceListColumn' Name='ChoiceListColumn' Format='Dropdown' required='FALSE' EnforceUniqueValues='FALSE' Indexed='FALSE' ><CHOICES><CHOICE>Queued</CHOICE><CHOICE>Translated</CHOICE><CHOICE>In Progress</CHOICE><CHOICE>With Human Translator</CHOICE><CHOICE>Throttled</CHOICE><CHOICE>Error</CHOICE></CHOICES><Default>Queued</Default></Field>"
$NumberListColumnXml = "<Field Type='Number' DisplayName='NumberListColumn' Name='NumberListColumn' required='FALSE' EnforceUniqueValues='FALSE' Indexed='FALSE'/>"
$CurrencyListColumnXml = "<Field Type='Currency' DisplayName='CurrencyListColumn' Name='CurrencyListColumn' required='FALSE' EnforceUniqueValues='FALSE' Indexed='FALSE'/>"
$DateTimeListColumnXml = "<Field Type='DateTime' DisplayName='DateTimeListColumn' Name='DateTimeListColumn' required='FALSE' EnforceUniqueValues='FALSE' Indexed='FALSE'/>"
$YesorNoListColumnXml = "<Field Type='Boolean' DisplayName='YesorNoListColumn' Name='YesorNoListColumn' required='FALSE' Indexed='FALSE' />"
$HyperlinkListColumnXml = "<Field Type='URL' DisplayName='HyperlinkListColumn' Name='HyperlinkListColumn' Required='FALSE' EnforceUniqueValues='FALSE' Indexed='FALSE' Format='Hyperlink' />"
$TaskOutComeListColumnXml = "<Field Type='OutcomeChoice' DisplayName='TaskOutComeListColumn' Name='TaskOutComeListColumn' Required='FALSE' EnforceUniqueValues='FALSE' Indexed='FALSE' ><Default>Rejected</Default><CHOICES><CHOICE>Approved</CHOICE><CHOICE>Rejected</CHOICE></CHOICES></Field>"
$LookupWebid = $ctx.Web.id
Create-List -ctx $ctx -name "TestListLookupColumnList" -type 100
$Testlookuplist = $ctx.Web.Lists.GetByTitle("TestListLookupColumnList")
$ctx.Load($Testlookuplist)
$ctx.ExecuteQuery()
$lookuplistid = $Testlookuplist.id
$LookupListColumnXml = "<Field DisplayName='LookupListColumn' Type='Lookup' Required='TRUE' List='$lookuplistid' WebId='$LookupWebid' ShowField='Title'/>"
$PersonGroupListColumnXml = "<Field Type='User' DisplayName='PersonGroupListColumn' Name='PersonGroupListColumn' StaticName='PersonGroupListColumn' UserSelectionScope='0' UserSelectionMode='PeopleOnly' Sortable='FALSE' required='FALSE' EnforceUniqueValues='FALSE' Indexed='FALSE'/>"
$PersonGroupMultiListColumnXml = "<Field Type='UserMulti' DisplayName='PersonGroupMultiListColumn' Name='PersonGroupMultiListColumn' StaticName='PersonGroupMultiListColumn' UserSelectionScope='0' UserSelectionMode='PeopleOnly' Mult='TRUE' Sortable='FALSE' required='FALSE' EnforceUniqueValues='FALSE' Indexed='FALSE'/>"
$Date1Xml = "<Field Type='DateTime' DisplayName='Date1' Name='Date1' required='FALSE' EnforceUniqueValues='FALSE' Indexed='FALSE'/>"
$Date2Xml = "<Field Type='DateTime' DisplayName='Date2' Name='Date2' required='FALSE' EnforceUniqueValues='FALSE' Indexed='FALSE'/>"
$CaculatedListColumnXml = "<Field Type='Calculated' DisplayName='CaculatedListColumn' ResultType='DateTime' ReadOnly='TRUE' Name='CaculatedListColumn'><Formula>=[Date1]-[Date2]</Formula><FieldRefs><FieldRef Name='Date1' /><FieldRef Name='Date2' /></FieldRefs></Field>"

$TermXml = "<Field Type='TaxonomyFieldType' DisplayName='New Managed Metadata List Column' StaticName='New Managed Metadata List Column' Name='New Managed Metadata List Column' ShowField='Term1033' DisplaceOnUpgrade='TRUE' Overwrite='TRUE'><Default>2;#A|" + $a.Id + "</Default>
<Customization>
<ArrayOfProperty>
<Property><Name>SspId</Name><Value xmlns:q1='http://www.w3.org/2001/XMLSchema' p4:type='q1:string' xmlns:p4='http://www.w3.org/2001/XMLSchema-instance'>" + $taxonomy.Id + "</Value></Property>
<Property><Name>TermSetId</Name><Value xmlns:q2='http://www.w3.org/2001/XMLSchema' p4:type='q2:string' xmlns:p4='http://www.w3.org/2001/XMLSchema-instance'>" + $termset.Id + "</Value></Property>
<Property><Name>AnchorId</Name><Value xmlns:q3='http://www.w3.org/2001/XMLSchema' p4:type='q3:string' xmlns:p4='http://www.w3.org/2001/XMLSchema-instance'>" + $a.Id + "</Value></Property>
</ArrayOfProperty>
</Customization>
</Field>"

$colXmls = $SingleTextListColumnXml,$MultipleTextListColumnXml,$ChoiceListColumnXml,$NumberListColumnXml,$CurrencyListColumnXml,$DateTimeListColumnXml,$YesorNoListColumnXml,$HyperlinkListColumnXml,$TaskOutComeListColumnXml,$LookupListColumnXml,$PersonGroupListColumnXml,$PersonGroupMultiListColumnXml,$Date1Xml,$Date2Xml,$CaculatedListColumnXml,$TermXml

for($i=0;$i -lt $colXmls.Length;$i++)
{
	$col = $Testlist.Fields.AddFieldAsXml($colXmls[$i],$true,[Microsoft.SharePoint.Client.AddFieldOptions]::AddFieldToDefaultView)
	try{
		$ctx.ExecuteQuery()
		Write-Host "Succesfully add list column to list" -foregroundcolor black -backgroundcolor green
	}
	catch
	{
		$usefulerror = $Error[0].Exception.InnerException.Message
    	Write-host "# Creation Failed  #" -BackgroundColor Red -ForegroundColor White 
    	Write-Host "$usefulerror" -foregroundcolor black -backgroundcolor yellow
	}
}

#创建list content type(常用类型)
Open-Site -Url $url
$lcts = @{
			"Announcement"  = "0x0104";                                  
			"Comment"    =      "0x0111";                                  
			"Contact"    =   "0x0106";                                                                  
			"Event"       =            "0x0102";                                  
			"Issue"  = "0x0103";                                  
			"Link"    =      "0x0105";                                
			"Message"  =    "0x0107";                                  
			"Post"  = "0x0110";
			"Task"  =  "0x0108";                                  			
		}
foreach($k in $lcts.Keys)
{
	$ctx.Load($ctx.Web.ContentTypes)
	$ctx.Load($ctx.Web.Webs)
	$ctx.ExecuteQuery()
	$ContentType = $ctx.Web.ContentTypes.GetById($lcts[$k])	
	$subweb = $ctx.Web.Webs | ?{$_.Url.contains("/Sub Site 1")}
	$ctx.Load($subweb)
	$ctx.Load($subweb.lists)
	$ctx.ExecuteQuery()
	$Testlist = $subweb.lists.GetByTitle("TestCustomList")
	$ctx.ExecuteQuery()
	$ContentTypes = $Testlist.ContentTypes
	$ctx.Load($ContentTypes)
	$ctx.ExecuteQuery()
	$ctReturn = $ContentTypes.AddExistingContentType($ContentType)
	$ctx.Load($ctReturn)
}
try{
	$ctx.ExecuteQuery()
	Write-host "Content Type" $ContentType.Name "Added to " $Testlist.Title "" -ForegroundColor Green
}
catch{
	$usefulerror = $Error[0].Exception.InnerException.Message
    Write-host "# Creation Failed  #" -BackgroundColor Red -ForegroundColor White 
    Write-Host "$usefulerror" -foregroundcolor black -backgroundcolor yellow
}

#添加content type到library中
$lcts = @{
			"Basic Page"  =  "0x010109";                                
			"Document"  =  "0x0101";                                  			                
			"Link to a Document" = "0x01010A";                                			                          
			"Picture" = "0x010102";                                
			"Web Part Page" = "0x01010901";                              
			"Wiki Page" = "0x010108";
			"Document Set"  ="0x0120D520"                                                                                                                     
			"Discussion"     =         "0x012002";                                                                                                                       
			"Folder"           =       "0x0120";                                                                                                                                                                                                                  
			"Audio"           =        "0x0101009148F5A04DDD49CBA7127AADA5FB792B006973ACD696DC4858A76371B2FB2F439A";                                                     
			"Image"           =        "0x0101009148F5A04DDD49CBA7127AADA5FB792B00AADE34325A8B49CDA8BB4DB53328F214";                                                   
			"Video"           =       "0x0120D520A808";                                 			
		}
foreach($k in $lcts.Keys)
{
	$ctx.Load($ctx.Web.ContentTypes)
	$ctx.Load($ctx.Web.Webs)
	$ctx.ExecuteQuery()
	$ContentType = $ctx.Web.ContentTypes.GetById($lcts[$k])	
	$subweb = $ctx.Web.Webs | ?{$_.Url.contains("/Sub Site 1")}
	$ctx.Load($subweb)
	$ctx.Load($subweb.lists)
	$ctx.ExecuteQuery()
	$Testlist = $subweb.lists.GetByTitle("Document Library")
	$ctx.ExecuteQuery()
	$ContentTypes = $Testlist.ContentTypes
	$ctx.Load($ContentTypes)
	$ctx.ExecuteQuery()
	$ctReturn = $ContentTypes.AddExistingContentType($ContentType)
	$ctx.Load($ctReturn)
}
try{
	$ctx.ExecuteQuery()
	Write-host "Content Type" $ContentType.Name "Added to " $Testlist.Title "" -ForegroundColor Green
}
catch{
	$usefulerror = $Error[0].Exception.InnerException.Message
    Write-host "# Creation Failed  #" -BackgroundColor Red -ForegroundColor White 
    Write-Host "$usefulerror" -foregroundcolor black -backgroundcolor yellow
}

#创建带10个version的item
function Create-ListItems
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true, Position=1)]
		[string]$csvPath, 
		
		[Parameter(Mandatory=$true, Position=2)]
		[string]$listName
	)

    $list = $ctx.Web.Lists.GetByTitle($listName)
    
    $csvPathUnicode = $csvPath -replace ".csv", "_unicode.csv"
    Get-Content $csvPath | Out-File $csvPathUnicode
    $csv = Import-Csv $csvPathUnicode
    foreach ($line in $csv)
    {
        $itemCreateInfo = new-object Microsoft.SharePoint.Client.ListItemCreationInformation
        $listItem = $list.AddItem($itemCreateInfo)
        
        foreach ($prop in $line.psobject.properties)
        {
            $listItem[$prop.Name] = $prop.Value
        }
        
        $listItem.Update()
        try{
            $ctx.ExecuteQuery()
            Write-host "Item created successfully" -ForegroundColor Green
        }
        catch{
            $usefulerror = $Error[0].Exception.InnerException.Message
            Write-host "# Creation Failed  #" -BackgroundColor Red -ForegroundColor White 
            Write-Host "$usefulerror" -foregroundcolor black -backgroundcolor yellow
        }


		foreach($i in 1..10)
		{
			 $listItem["SingleTextListColumn"] = "change $i"
			 $listItem.Update()
        
            try{
                $ctx.ExecuteQuery()
                Write-host "Item edited successfully" -ForegroundColor Green
             }
             catch{
                $usefulerror = $Error[0].Exception.InnerException.Message
                Write-host "# Creation Failed  #" -BackgroundColor Red -ForegroundColor White 
                Write-Host "$usefulerror" -foregroundcolor black -backgroundcolor yellow
             }
			 
		}
		
    }
}
Open-Site -Url "$url/Sub Site 1"
$csvPath = "$scriptdir\items.csv"
Create-ListItems -csvPath $csvPath -listName "TestCustomList"

#上传file,并check in/check out,带version

function Join-Parts
{
	[CmdletBinding()]
    param
    (
		[Parameter(Mandatory=$false, Position=1)]
        $Parts = $null,
		
		[Parameter(Mandatory=$false, Position=2)]
        $Separator = ''
    )

    $returnValue = (($Parts | ? { $_ } | % { ([string]$_).trim($Separator) } | ? { $_ } ) -join $Separator)

    if (-not ($returnValue.StartsWith("http", "CurrentCultureIgnoreCase")))
    {
        # is a relative path so add the seperator in front
        $returnValue = $Separator + $returnValue
    }

    return $returnValue
}

function Convert-FileVariablesToValues
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true, Position=1)]
		[System.IO.FileSystemInfo]$file
	)

	$filePath = $file.FullName
	$tempFilePath = "$filePath.temp"
	
	Write-Host "Replacing variables at $filePath" -foregroundcolor black -backgroundcolor yellow
    	
	$serverRelativeUrl = $spps.Site.ServerRelativeUrl
	if ($serverRelativeUrl -eq "/") {
		$serverRelativeUrl = ""
	}
	
	(get-content $filePath) | foreach-object {$_ -replace "~SiteCollection", $serverRelativeUrl } | set-content $tempFilePath
    
	return Get-Item -Path $tempFilePath
}

function Upload-Files
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true, Position=1)]
		[string]$folderPath, 
		
		[Parameter(Mandatory=$true, Position=2)]
		[string]$doclib, 
		
		[Parameter(Mandatory=$false, Position=3)]
		[bool]$checkoutNecessary = $false
	)

    # for each file in folder Copy-File()
    $files = Get-ChildItem -Path $folderPath -Recurse
    foreach ($file in $files)
    {
        $folder = $file.FullName.Replace($folderPath,'')
        $targetPath = $doclib + $folder
        $targetPath = $targetPath.Replace('\','/')
        Copy-File $file $targetPath $checkoutNecessary
    }
	Get-ChildItem $folderPath -Filter *.temp | Remove-Item
}

function Copy-File
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true, Position=1)]
		[System.IO.FileSystemInfo]$file, 
		
		[Parameter(Mandatory=$true, Position=2)]
		[string]$targetPath, 
		
		[Parameter(Mandatory=$true, Position=3)]
		[bool]$checkoutNecessary
	)

    if ($file.PsIsContainer)
    {
        Add-Folder $targetPath
    }
    else
    {
        $filePath = $file.FullName
        
		Write-Host "Copying file $filePath to $targetPath" -foregroundcolor black -backgroundcolor yellow
		
        
        if ($checkoutNecessary)
        {
            # Set the error action to silent to try to check out the file if it exists
            $ErrorActionPreference = "SilentlyContinue"
            Submit-CheckOut $targetPath
            $ErrorActionPreference = "Stop"
        }
        
		$arrExtensions = ".html", ".js", ".master", ".txt", ".css", ".aspx"
		
		if ($arrExtensions -contains $file.Extension)
		{
			$tempFile = Convert-FileVariablesToValues -file $file
	        Save-File $targetPath $tempFile
		} 
		else
		{
			Save-File $targetPath $file
		}
        
        if ($checkoutNecessary)
        {
            Submit-CheckOut $targetPath
            Submit-CheckIn $targetPath
        }
    }
}


function Save-File
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true, Position=1)]
		[string]$targetPath, 
	
		[Parameter(Mandatory=$true, Position=2)]
		[System.IO.FileInfo]$file
	)
	
	$targetPath = Join-Parts -Separator '/' -Parts $ctx.Web.ServerRelativeUrl, $targetPath
	
    $fs = $file.OpenRead()
    [Microsoft.SharePoint.Client.File]::SaveBinaryDirect($ctx, $targetPath, $fs, $true)
    $fs.Close()
}



function Submit-CheckOutFile
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true, Position=1)]
		[string]$targetPath #"/Shared Documents/test.txt"
	)
	
	$targetPath = Join-Parts -Separator '/' -Parts $ctx.Web.ServerRelativeUrl, $targetPath

    $remotefile = $ctx.Web.GetFileByServerRelativeUrl($targetPath)
    $ctx.Load($remotefile)
    $ctx.ExecuteQuery()
    
    if ($remotefile.CheckOutType -eq [Microsoft.SharePoint.Client.CheckOutType]::None)
    {
        $remotefile.CheckOut()
    }
    try{
        $ctx.ExecuteQuery()
        Write-host "CheckOut file successfully" -ForegroundColor Green
    }
    catch{
        $usefulerror = $Error[0].Exception.InnerException.Message
        Write-host "# CheckOut file failed #" -BackgroundColor Red -ForegroundColor White 
        Write-Host "$usefulerror" -foregroundcolor black -backgroundcolor yellow
    }
}

function Submit-CheckInFile
{
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory=$true, Position=1)]
		[string]$targetPath
	)
	
	$targetPath = Join-Parts -Separator '/' -Parts $ctx.Web.ServerRelativeUrl, $targetPath
	
    $remotefile = $ctx.Web.GetFileByServerRelativeUrl($targetPath)
    $ctx.Load($remotefile)
    $ctx.ExecuteQuery()
    
    $remotefile.CheckIn("",[Microsoft.SharePoint.Client.CheckinType]::MajorCheckIn)
    try{
        $ctx.ExecuteQuery()
        Write-host "CheckIn file successfully" -ForegroundColor Green
    }
    catch{
        $usefulerror = $Error[0].Exception.InnerException.Message
        Write-host "# CheckIn file failed #" -BackgroundColor Red -ForegroundColor White 
        Write-Host "$usefulerror" -foregroundcolor black -backgroundcolor yellow
    }
}

Open-Site -Url "$url/Sub Site 1"
Upload-Files -folderPath "$scriptdir\Files" -doclib "/Document_Library"
Submit-CheckOutFile -targetPath "/Document_Library/test1.txt"
Submit-CheckOutFile -targetPath "/Document_Library/test1.txt"
Submit-CheckInFile -targetPath "/Document_Library/test1.txt"

<#Views
$enum = [Microsoft.SharePoint.Client.ViewType]
$names = $enum.GetEnumValues()
foreach($type in $names)
{
	$vci = New-Object Microsoft.SharePoint.Client.ViewCreationInformation
	$vci.Title = "Newly Created "+$type.ToString()
	$vci.ViewTypeKind = $type
	$view = $list.Views.Add($vci)
	$ctx.Load($view)
	try{
		$ctx.ExecuteQuery()
		}
	catch
		{
			"Error occured while creating "+ $type.ToString() +" view"
			"Error occured while creating "+ $type.ToString() +" view"|Out-File -Append "D:\SupportList.txt"
		}
}
#>
<#workflow
Open-Site -Url $url

Create-List -ctx $ctx -name "Workflow Tasks" -type 171

Create-List -ctx $ctx -name "Workflow History" -type 140

Create-List -ctx $ctx -name "Lib Test Workflow" -type 101

$lib = $ctx.Web.Lists.GetByTitle("Lib Test Workflow")
$ctx.Load($lib)

$waci = New-Object Microsoft.SharePoint.Client.Workflow.WorkflowAssociationCreationInformation
$waci.HistoryList = $ctx.Web.Lists.GetByTitle("Workflow History")
$waci.TaskList = $ctx.Web.Lists.GetByTitle("Workflow Tasks")
$waci.Name = "Approval Workflow Created via PowerShell"
$waci.Template = $ctx.Web.WorkflowTemplates.GetByName("Approval - SharePoint 2010")
$workflow = $lib.WorkflowAssociations.Add($waci)
$ctx.Load($workflow)

$workflow.AutoStartChange = $true
$workflow.AutoStartCreate = $true
$workflow.Enabled = $true
$workflow.Update()
try{
	$ctx.ExecuteQuery()
	Write-Host "Succesfully add workflow to list" -foregroundcolor black -backgroundcolor green
}
catch{
	$usefulerror = $Error[0].Exception.InnerException.Message
    Write-host "# Creation Failed  #" -BackgroundColor Red -ForegroundColor White 
    Write-Host "$usefulerror" -foregroundcolor black -backgroundcolor yellow
}

$ctci = New-Object Microsoft.SharePoint.Client.ContentTypeCreationInformation
$ctci.Name = "Approval Workflow Tester"
$ctci.ParentContentType = $ctx.Web.ContentTypes.GetById("0x01")
$ct = $ctx.Web.ContentTypes.Add($ctci)
$ctx.Load($ct)
$ctwf = $ct.WorkflowAssociations.Add($waci)
$ctx.Load($ctwf)
$ctwf.AutoStartChange = $true
$ctwf.AutoStartCreate = $true
$ctwf.Enabled = $true
$ctwf.Update()
try{
	$ctx.ExecuteQuery()
	Write-Host "Succesfully add content type to site" -foregroundcolor black -backgroundcolor green
}
catch{
	$usefulerror = $Error[0].Exception.InnerException.Message
    Write-host "# Creation Failed  #" -BackgroundColor Red -ForegroundColor White 
    Write-Host "$usefulerror" -foregroundcolor black -backgroundcolor yellow
}

$sitewf = $ctx.Web.WorkflowAssociations.Add($waci)
$ctx.Load($sitewf)
$sitewf.AutoStartChange = $true
$sitewf.AutoStartCreate = $true
$sitewf.Update()
try{
	$ctx.ExecuteQuery()
	Write-Host "Succesfully add workflow to content type" -foregroundcolor black -backgroundcolor green
}
catch{
	$usefulerror = $Error[0].Exception.InnerException.Message
    Write-host "# Creation Failed  #" -BackgroundColor Red -ForegroundColor White 
    Write-Host "$usefulerror" -foregroundcolor black -backgroundcolor yellow
}
#>

