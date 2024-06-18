

export PATH=$PATH:$HOME:/var/jenkins_home/ccli-v1.0.2.0-linux-x64/linux-x64:$HOME:/var/jenkins_home

vaultuser=$1

if [[ -z ${vaultuser} ]] ; then
  echo "Must specify a Vaulted Username!"
  exit
fi


# Request a token for the service account with the command:
# ccli requesttoken -url $tenanturl -u $user -pw $password
#
# Note: must provide the password for the service account. The token is
# saved in the file "centrifycli.token" in the requesting user's home directory.

#token="`cat $HOME/centrifycli.token`"

# Get vaulted account id.
VaultAccountID=`/var/jenkins_home/ccli-v1.0.2.0-linux-x64/linux-x64/ccli -s /RedRock/query -j "{'Script':'select ID from VaultAccount where User = \'${vaultuser}\''}" | /var/jenkins_home/jq -r '.Result.Results[].Row.ID'`
# Get vaulted account password.
/var/jenkins_home/ccli-v1.0.2.0-linux-x64/linux-x64/ccli -s /ServerManage/CheckoutPassword -ja ID=$VaultAccountID | /var/jenkins_home/jq -r '.Result.Password'
#ccli saveconfig -o -url https://tfspas.my.centrify.net -u passcheckout@toyota.local -app pcheckout
#ccli requesttoken -pw
