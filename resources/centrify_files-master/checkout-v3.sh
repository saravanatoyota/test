

export PATH=$PATH:$HOME:/var/jenkins_home/ccli-v1.0.2.0-linux-x64/linux-x64:$HOME:/var/jenkins_home

vaultSecret=$1

if [[ -z ${vaultSecret} ]] ; then
  echo "Must specify a Vault Secret!"
  exit
fi


# Request a token for the service account with the command:
# ccli requesttoken -url $tenanturl -u $user -pw $password
#
# Note: must provide the password for the service account. The token is
# saved in the file "centrifycli.token" in the requesting user's home directory.

#token="`cat $HOME/centrifycli.token`"

# Get vaulted account id.
VaultSecretID=`/var/jenkins_home/ccli-v1.0.2.0-linux-x64/linux-x64/ccli -s /RedRock/query -j "{'Script': 'Select DataVault.SecretName,DataVault.ID,DataVault.FolderId,DataVault.ParentPath,DataVault.Type from DataVault where DataVault.SecretName = \"${vaultSecret}\"'}" | /var/jenkins_home/jq -r '.Result.Results[].Row.ID'`
#echo $VaultSecretID
# Get vaulted account password.
/var/jenkins_home/ccli-v1.0.2.0-linux-x64/linux-x64/ccli -s /ServerManage/RetrieveSecretContents -ja ID=$VaultSecretID | /var/jenkins_home/jq -r '.Result.SecretText'
#ccli saveconfig -o -url https://tfspas.my.centrify.net -u passcheckout@toyota.local -app pcheckout
#ccli requesttoken -pw
