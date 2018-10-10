GC 'C:\csv_run\reboots.csv' | %{
	If (Test-Connection $_ -Quiet -Count 1){
	"$_ is UP"
	}
	Else{
	"$_ is Down"
	}
} | tee-object -FilePath "C:\reboots_up.txt"
