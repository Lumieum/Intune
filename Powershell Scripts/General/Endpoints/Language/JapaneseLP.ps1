$UserLanguageList = New-WinUserLanguageList -Language "ja-JP"
$UserLanguageList.Add("ja-JP")
$UserLanguageList[0].Handwriting = $True?
Set-WinUserLanguageList -LanguageList $UserLanguageList -force