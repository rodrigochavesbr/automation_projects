# Define variable of the SSS path
Param(
  [Parameter(Position=1)]
  [String]$sss_path
)

# This function will call bat file of SSS
Function run_sss() {
  &cmd.exe /c "$sss_path\sss\subs_all.bat sdms.properties"
}

# Check arguments and run the script
function main {
  run_sss
}

#
main
